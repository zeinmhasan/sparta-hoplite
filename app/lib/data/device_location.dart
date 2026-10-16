import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'live_routing.dart';
import 'mock_data.dart' as mock;
import 'models.dart';

/// Lokasi pelapor dari GPS perangkat. Jika GPS mati, izin ditolak, atau tidak
/// ada sinyal, lokasi diganti titik asal demo supaya laporan tetap bisa dikirim.
Future<ReportSpot> locateReporter() async {
  final fallback = ReportSpot(
    point: mock.origin.point,
    road: mock.originRoad,
    address: mock.origin.address,
    live: false,
    at: DateTime.now(),
  );
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return fallback;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return fallback;

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );
    } catch (_) {
      position = await Geolocator.getLastKnownPosition();
    }
    if (position == null) return fallback;

    final point = LatLng(position.latitude, position.longitude);
    final coordinates = '${point.latitude.toStringAsFixed(5)} / ${point.longitude.toStringAsFixed(5)}';
    try {
      final named = await reverseGeocode(point);
      if (named != null) {
        return ReportSpot(point: point, road: named.$1, address: named.$2, live: true, at: DateTime.now());
      }
    } catch (_) {
      // Tanpa internet nama jalan tidak terbaca; koordinat GPS tetap dikirim.
    }
    return ReportSpot(
      point: point,
      road: 'Titik GPS',
      address: 'Titik GPS $coordinates',
      live: true,
      at: DateTime.now(),
    );
  } catch (_) {
    return fallback;
  }
}
