import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../data/models.dart';

// Model 3D sederhana untuk peta navigasi. Tiap model disusun dari balok: persegi
// panjang di tanah yang diberi alas (b) dan tinggi (h) dalam meter, lalu digambar
// mesin peta sebagai fill-extrusion. Ukurannya dibesarkan dengan [scale] supaya
// tetap terlihat dari ketinggian kamera navigasi.

typedef Feature = Map<String, dynamic>;

Map<String, dynamic> featureCollection(List<Feature> features) => {'type': 'FeatureCollection', 'features': features};

/// Meter per dp layar pada zoom MapLibre (ubin 512 px) di lintang [latitude].
double metersPerDp(double zoom, double latitude) => 78271.517 * math.cos(latitude * math.pi / 180) / math.pow(2, zoom);

/// Skala model agar panjang kendaraan sekitar 64 dp di layar: mendekati ukuran
/// asli saat diperbesar, dan dibesarkan saat kamera menjauh.
double modelScale(double zoom, double latitude) => (64 * metersPerDp(zoom, latitude) / 4.4).clamp(1.2, 10.0);

/// Satu balok. Posisi dan ukurannya dalam meter pada kerangka model: x ke kanan,
/// y ke depan, relatif terhadap [origin] yang menghadap [bearing].
Feature _box(
  LatLng origin,
  double bearing,
  double scale, {
  required double x,
  required double y,
  required double width,
  required double length,
  required double base,
  required double height,
  required String color,
}) {
  final theta = bearing * math.pi / 180;
  final cosT = math.cos(theta), sinT = math.sin(theta);
  final metersPerLng = 111320 * math.cos(origin.latitude * math.pi / 180);

  List<double> corner(double dx, double dy) {
    final px = (x + dx) * scale, py = (y + dy) * scale;
    final east = px * cosT + py * sinT;
    final north = -px * sinT + py * cosT;
    return [origin.longitude + east / metersPerLng, origin.latitude + north / 110540];
  }

  final w = width / 2, l = length / 2;
  return {
    'type': 'Feature',
    'properties': {'color': color, 'b': base * scale, 'h': height * scale},
    'geometry': {
      'type': 'Polygon',
      'coordinates': [
        [corner(-w, -l), corner(w, -l), corner(w, l), corner(-w, l), corner(-w, -l)],
      ],
    },
  };
}

const _maroon = '#8E1616';

/// Bodi kendaraan putih supaya kontras di atas garis rute hijau, kuning, maupun merah.
const _body = '#F4F2F0';
const _tyre = '#1F1F22';
const _glass = '#22314F';

/// Mobil: empat roda, bodi, kabin, lampu depan dan lampu belakang.
List<Feature> _car(LatLng at, double bearing, double s) {
  Feature box(double x, double y, double w, double l, double b, double h, String c) =>
      _box(at, bearing, s, x: x, y: y, width: w, length: l, base: b, height: h, color: c);
  return [
    for (final x in [-0.85, 0.85])
      for (final y in [-1.35, 1.35]) box(x, y, 0.32, 0.78, 0, 0.72, _tyre),
    box(0, 0, 1.86, 4.4, 0.3, 0.98, _body),
    box(0, -0.25, 1.62, 2.3, 0.98, 1.52, _glass),
    box(0, -0.25, 1.5, 1.7, 1.52, 1.58, _maroon),
    for (final x in [-0.6, 0.6]) box(x, 2.16, 0.42, 0.14, 0.58, 0.84, '#FFE9A8'),
    for (final x in [-0.6, 0.6]) box(x, -2.16, 0.42, 0.14, 0.58, 0.84, '#FF3B30'),
  ];
}

/// Motor dengan pengendara: dua roda, rangka, setang, badan, dan helm.
List<Feature> _motorcycle(LatLng at, double bearing, double s) {
  Feature box(double x, double y, double w, double l, double b, double h, String c) =>
      _box(at, bearing, s, x: x, y: y, width: w, length: l, base: b, height: h, color: c);
  return [
    box(0, 0.78, 0.24, 0.72, 0, 0.7, _tyre),
    box(0, -0.78, 0.24, 0.72, 0, 0.7, _tyre),
    box(0, 0, 0.38, 1.5, 0.42, 0.92, _body),
    box(0, 0.6, 0.82, 0.1, 1.02, 1.14, _tyre),
    box(0, -0.2, 0.5, 0.62, 0.92, 1.08, _tyre),
    box(0, -0.12, 0.56, 0.4, 1.08, 1.68, _glass),
    box(0, -0.06, 0.36, 0.38, 1.68, 2.02, _maroon),
    box(0, -1.12, 0.22, 0.08, 0.72, 0.88, '#FF3B30'),
  ];
}

/// Kendaraan pengguna di [position]. Motor dibesarkan sedikit karena lebih ramping.
List<Feature> vehicleModel(VehicleMode mode, LatLng position, double bearing, double scale) =>
    mode == VehicleMode.motor ? _motorcycle(position, bearing, scale * 1.35) : _car(position, bearing, scale);

/// Tiang lampu lalu lintas di sisi kiri jalan (lalu lintas Indonesia di lajur
/// kiri), menghadap kendaraan yang datang dari arah [bearing].
List<Feature> trafficLightModel(LatLng crossing, double bearing, bool green, double scale) {
  final s = scale * 0.7;
  Feature box(double w, double l, double b, double h, String c) =>
      _box(crossing, bearing, s, x: -5.2, y: 1.5, width: w, length: l, base: b, height: h, color: c);
  // Dari bawah ke atas: tiang, lalu kotak lampu hijau, kuning, merah. Lampu yang
  // tidak menyala digambar gelap.
  return [
    box(0.5, 0.5, 0, 5.0, '#5A5E66'),
    box(1.75, 1.05, 4.85, 5.0, '#22252B'),
    box(1.6, 0.9, 5.0, 6.1, green ? '#2ECC71' : '#20352A'),
    box(1.6, 0.9, 6.1, 7.2, '#4A4326'),
    box(1.6, 0.9, 7.2, 8.3, green ? '#3A2422' : '#F0362B'),
    box(1.75, 1.05, 8.3, 8.5, '#22252B'),
  ];
}

/// Tiang bendera di titik tujuan.
List<Feature> destinationModel(LatLng at, double scale) {
  Feature box(double x, double w, double l, double b, double h, String c) =>
      _box(at, 0, scale, x: x, y: 0, width: w, length: l, base: b, height: h, color: c);
  return [box(0, 0.3, 0.3, 0, 9, '#F5F5F5'), box(1.15, 2.0, 0.22, 6.6, 9, _maroon)];
}
