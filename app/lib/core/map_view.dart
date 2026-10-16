import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/models.dart';
import 'theme.dart';

/// Peta dasar aplikasi: ubin jalan asli Surabaya dari OpenStreetMap, tanpa API
/// key. Rute dan marker digambar lewat [layers].
class AppMap extends StatelessWidget {
  const AppMap({
    super.key,
    required this.fitPoints,
    this.layers = const [],
    this.interactive = true,
    this.padding = const EdgeInsets.all(36),
    this.controller,
    this.followZoom,
    this.allowRotate = false,
    this.showAttribution = true,
    this.onPositionChanged,
  });

  final List<LatLng> fitPoints;
  final List<Widget> layers;
  final bool interactive;
  final EdgeInsets padding;
  final MapController? controller;

  /// Jika diisi, peta dibuka di titik pertama [fitPoints] pada zoom ini,
  /// bukan memuat seluruh titik. Dipakai mode navigasi.
  final double? followZoom;

  /// Izinkan pengguna memutar peta dengan dua jari.
  final bool allowRotate;
  final bool showAttribution;
  final PositionCallback? onPositionChanged;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: fitPoints.first,
        initialZoom: followZoom ?? 13,
        initialCameraFit: followZoom != null
            ? null
            : CameraFit.bounds(bounds: LatLngBounds.fromPoints(fitPoints), padding: padding),
        backgroundColor: const Color(0xFFEDEAE6),
        onPositionChanged: onPositionChanged,
        interactionOptions: InteractionOptions(
          flags: !interactive
              ? InteractiveFlag.none
              : (allowRotate ? InteractiveFlag.all : InteractiveFlag.all & ~InteractiveFlag.rotate),
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'id.sparta.sparta_hoplite',
          maxZoom: 19,
        ),
        ...layers,
        if (showAttribution) const Align(alignment: Alignment.bottomRight, child: MapAttribution()),
      ],
    );
  }
}

class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      color: Colors.white70,
      child: const Text('© OpenStreetMap contributors', style: TextStyle(fontSize: 8, color: Colors.black54)),
    );
  }
}

/// Garis rute yang diwarnai per ruas menurut kepadatan pada waktu berangkat terpilih.
/// [from] adalah pecahan rute yang sudah dilewati dan tidak digambar lagi.
PolylineLayer trafficLine(RouteOption route, Departure departure, {double width = 6, double from = 0}) {
  return PolylineLayer(
    polylines: [
      Polyline(
        points: from <= 0 ? route.points : route.sampler.slice(from, 1),
        color: Colors.white,
        strokeWidth: width + 4,
      ),
      for (final (level, points) in route.remainingSlices(departure, from: from))
        Polyline(points: points, color: level.color, strokeWidth: width),
    ],
  );
}

/// Garis rute polos, dipakai untuk pratinjau dan koridor bus.
PolylineLayer plainLine(List<LatLng> points, {Color color = AppColors.navy, double width = 5}) {
  return PolylineLayer(
    polylines: [
      Polyline(points: points, color: Colors.white, strokeWidth: width + 3),
      Polyline(points: points, color: color, strokeWidth: width),
    ],
  );
}

Marker dotMarker(LatLng point, Color color, {double size = 18}) {
  return Marker(
    point: point,
    width: size,
    height: size,
    child: Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4)],
      ),
    ),
  );
}

/// Marker ikon bulat yang selalu tegak walau peta diputar. [stretch] menarik
/// marker ke atas untuk mengimbangi pemipihan saat peta dimiringkan.
Marker iconMarker(LatLng point, IconData icon, Color color, {double size = 34, double stretch = 1}) {
  return Marker(
    point: point,
    width: size,
    height: size,
    rotate: true,
    child: Transform.scale(
      scaleY: stretch,
      child: _IconDot(icon: icon, color: color, size: size),
    ),
  );
}

class _IconDot extends StatelessWidget {
  const _IconDot({required this.icon, required this.color, required this.size});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.52),
    );
  }
}

/// Tombol bulat putih yang melayang di atas peta.
class MapButton extends StatelessWidget {
  const MapButton({super.key, required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black38,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AppColors.maroon, size: 22),
        ),
      ),
    );
  }
}
