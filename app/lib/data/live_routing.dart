import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'models.dart';
import 'route_geometry.dart';

// Dua layanan terbuka berbasis OpenStreetMap, keduanya tanpa API key:
// Photon untuk pencarian tempat saat mengetik, OSRM untuk geometri rute.
// Ini satu-satunya data sungguhan di aplikasi; ETA dan kepadatan tetap simulasi.

const _headers = {'User-Agent': 'sparta-hoplite-demo/1.0'};
const _timeout = Duration(seconds: 12);

/// Batas pencarian: kotak yang melingkupi Surabaya dan sekitarnya.
const _surabayaBox = '112.59,-7.40,112.86,-7.17';

Future<List<Place>> searchPlacesOnline(String query) async {
  final uri = Uri.https('photon.komoot.io', '/api/', {
    'q': query,
    'lat': '-7.2756',
    'lon': '112.7426',
    'limit': '8',
    'bbox': _surabayaBox,
  });
  final response = await http.get(uri, headers: _headers).timeout(_timeout);
  if (response.statusCode != 200) throw Exception('Pencarian gagal (${response.statusCode})');

  final features = jsonDecode(utf8.decode(response.bodyBytes))['features'] as List;
  final places = <Place>[];
  final seen = <String>{};
  for (final feature in features) {
    final props = feature['properties'] as Map<String, dynamic>;
    final name = props['name'] as String?;
    final address = [props['street'], props['district'], props['city']].whereType<String>().join(', ');
    if (name == null || !seen.add('$name|$address'.toLowerCase())) continue;
    final coords = feature['geometry']['coordinates'] as List;
    places.add(
      Place(
        id: 'osm-${props['osm_id']}',
        name: name,
        address: address.isEmpty ? 'Surabaya' : address,
        point: LatLng((coords[1] as num).toDouble(), (coords[0] as num).toDouble()),
        icon: _iconFor(props['osm_key'] as String?, props['osm_value'] as String?),
      ),
    );
  }
  return places;
}

IconData _iconFor(String? key, String? value) => switch ((key, value)) {
  ('shop', _) => Icons.local_mall_outlined,
  ('amenity', 'restaurant' || 'cafe' || 'fast_food' || 'food_court') => Icons.restaurant_outlined,
  ('amenity', 'university' || 'school' || 'college') => Icons.school_outlined,
  ('amenity', 'hospital' || 'clinic') => Icons.local_hospital_outlined,
  ('amenity', 'place_of_worship') => Icons.mosque_outlined,
  ('amenity', 'bus_station') => Icons.directions_bus_outlined,
  ('railway', _) => Icons.train_outlined,
  ('highway', _) => Icons.signpost_outlined,
  ('tourism' || 'leisure', _) => Icons.attractions_outlined,
  _ => Icons.place_outlined,
};

/// Sampai tiga rute dari [from] ke [to], diurutkan dari yang terpendek.
Future<List<RouteGeo>> fetchRouteGeometry(LatLng from, LatLng to) async {
  final found = [
    for (final route in await _osrm([from, to], alternatives: '3')) _toGeo(route),
  ];

  // Lengkapi sampai tiga rute dengan titik singgah di kiri dan kanan garis lurus.
  final dLat = to.latitude - from.latitude, dLng = to.longitude - from.longitude;
  final length = math.sqrt(dLat * dLat + dLng * dLng);
  for (final side in [1, -1]) {
    if (found.length >= 3 || length == 0) break;
    final shift = math.min(0.012, length * 0.35) * side;
    final via = LatLng(
      (from.latitude + to.latitude) / 2 - dLng / length * shift,
      (from.longitude + to.longitude) / 2 + dLat / length * shift,
    );
    // Server demo OSRM membatasi satu permintaan per detik.
    await Future.delayed(const Duration(milliseconds: 1100));
    try {
      final geo = _toGeo((await _osrm([from, via, to], alternatives: 'false')).first);
      if (found.every((f) => (f.km - geo.km).abs() > 0.3)) found.add(geo);
    } catch (_) {
      // Rute alternatif bersifat tambahan; rute utama sudah ada.
    }
  }
  found.sort((a, b) => a.km.compareTo(b.km));
  return found.take(3).toList();
}

Future<List<Map<String, dynamic>>> _osrm(List<LatLng> points, {required String alternatives}) async {
  final coords = points.map((p) => '${p.longitude},${p.latitude}').join(';');
  final uri = Uri.parse(
    'https://router.project-osrm.org/route/v1/driving/$coords'
    '?alternatives=$alternatives&geometries=geojson&overview=full&steps=true',
  );
  final response = await http.get(uri, headers: _headers).timeout(_timeout);
  final body = response.statusCode == 200 ? jsonDecode(response.body) as Map<String, dynamic> : null;
  if (body == null || body['code'] != 'Ok') throw Exception('Rute tidak ditemukan');
  return (body['routes'] as List).cast<Map<String, dynamic>>();
}

double _meters(List a, List b) => math.sqrt(
  math.pow(((a[1] as num) - (b[1] as num)) * 110540, 2) + math.pow(((a[0] as num) - (b[0] as num)) * 111320, 2),
);

String _shortName(String name) => name
    .replaceFirst(RegExp(r'^(Jalan|Jl\.?)\s+', caseSensitive: false), '')
    .replaceAll('Doktor ', 'Dr. ')
    .replaceAll('Insinyur ', 'Ir. ')
    .replaceAll('Haji ', 'H. ')
    .replaceFirst('Dr. Ir. H. Soekarno', 'Dr. Ir. H. Soekarno (MERR)')
    .replaceFirst('Mayor Jenderal ', 'Mayjend ')
    .replaceFirst('Moehammad Jasin Polisi Istimewa', 'Polisi Istimewa')
    .replaceFirst('Panglima Besar Sudirman', 'Panglima Sudirman')
    .replaceFirst('Jenderal ', 'Jend. ')
    .replaceFirst('Rachmat', 'Rahmat')
    .trim();

/// Nama jalan tanpa gelar dan pangkat, untuk mengenali dua ejaan jalan yang sama
/// (mis. "Mayjend Sungkono" dan "Mayor Jend. Sungkono").
String _core(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r'(mayjend|mayor|jend|jenderal|raya|hr|dr|ir|h).?'), '')
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim();

bool _sameRoad(String a, String b) {
  final x = _core(a), y = _core(b);
  return x.isEmpty || y.isEmpty || x.contains(y) || y.contains(x);
}

// Gang bernomor romawi (mis. "Mojo IV") bukan simpang berlampu.
final _gang = RegExp(r'\s[IVX]+$');

/// Mengubah satu rute OSRM menjadi [RouteGeo]: titik dirapikan, simpang diambil
/// dari manuver tempat nama jalan berganti, lalu dipilih lima yang tersebar.
RouteGeo _toGeo(Map<String, dynamic> route) {
  final full = (route['geometry']['coordinates'] as List).cast<List>();
  final cumulative = <double>[0];
  for (var i = 1; i < full.length; i++) {
    cumulative.add(cumulative.last + _meters(full[i], full[i - 1]));
  }
  final total = cumulative.last;

  double fractionOf(List location) {
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < full.length; i++) {
      final d = _meters(full[i], location);
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return total == 0 ? 0 : cumulative[best] / total;
  }

  final steps = [for (final leg in route['legs'] as List) ...(leg['steps'] as List).cast<Map<String, dynamic>>()];
  final candidates = <CrossGeo>[];
  final roadMeters = <String, double>{};
  for (var i = 0; i < steps.length; i++) {
    final name = _shortName(steps[i]['name'] as String? ?? '');
    if (name.isNotEmpty) {
      roadMeters[name] = (roadMeters[name] ?? 0) + (steps[i]['distance'] as num).toDouble();
    }
    if (i == 0) continue;
    final previous = _shortName(steps[i - 1]['name'] as String? ?? '');
    if (name.isEmpty ||
        previous.isEmpty ||
        _sameRoad(name, previous) ||
        _gang.hasMatch(name) ||
        _gang.hasMatch(previous)) {
      continue;
    }
    final fraction = fractionOf(steps[i]['maneuver']['location'] as List);
    if (fraction > 0.06 && fraction < 0.96) candidates.add(CrossGeo('Simpang $previous – $name', fraction));
  }

  final picked = <CrossGeo>[];
  for (final target in [0.15, 0.33, 0.5, 0.68, 0.86]) {
    final free = candidates.where((c) => picked.every((p) => (p.frac - c.frac).abs() > 0.07)).toList();
    if (free.isEmpty) break;
    picked.add(free.reduce((a, b) => (b.frac - target).abs() < (a.frac - target).abs() ? b : a));
  }
  picked.sort((a, b) => a.frac.compareTo(b.frac));

  final roads = roadMeters.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final via = roads.take(2).map((e) => 'Jl. ${e.key}').join(' & ');

  // Buang titik yang terlalu rapat agar garis ringan digambar.
  final thinned = <List>[full.first];
  for (final point in full.sublist(1, full.length - 1)) {
    if (_meters(point, thinned.last) >= 25) thinned.add(point);
  }
  thinned.add(full.last);

  return RouteGeo(((route['distance'] as num) / 100).round() / 10, via.isEmpty ? 'jalan lokal' : via, picked, [
    for (final p in thinned) [(p[1] as num).toDouble(), (p[0] as num).toDouble()],
  ]);
}
