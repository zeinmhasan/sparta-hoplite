import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models.dart';

/// Kecepatan jelajah simulasi dalam meter per detik. Dipercepat agar perjalanan
/// selesai dalam beberapa menit; di layar ditampilkan sebagai [cruiseKmh].
const cruiseSpeed = 30.0;
const cruiseKmh = 50;
const _slowest = 10.0;

/// Jarak berhenti sebelum titik simpang saat lampu merah.
const _stopGap = 6.0;

/// Keadaan kendaraan pada satu frame navigasi.
class NavFrame {
  const NavFrame({
    required this.meters,
    required this.speed,
    required this.position,
    required this.bearing,
    required this.waiting,
  });
  final double meters;
  final double speed;
  final LatLng position;

  /// Arah hadap kendaraan dalam derajat dari utara, sudah dihaluskan.
  final double bearing;

  /// Sedang berhenti menunggu lampu merah.
  final bool waiting;

  int get kmh => (speed / cruiseSpeed * cruiseKmh).round();
}

enum Turn {
  straight(Icons.straight_rounded, 'Lurus ke'),
  left(Icons.turn_left_rounded, 'Belok kiri ke'),
  right(Icons.turn_right_rounded, 'Belok kanan ke');

  const Turn(this.icon, this.verb);
  final IconData icon;
  final String verb;
}

/// Arah belok di simpang, dibaca dari bentuk garis rute sebelum dan sesudahnya.
Turn turnAt(RouteOption route, Intersection x) {
  final step = 60 / route.sampler.totalMeters;
  final before = route.sampler.bearingAt(x.fraction - step, spanMeters: 50);
  final after = route.sampler.bearingAt(x.fraction + step, spanMeters: 50);
  final delta = (after - before + 540) % 360 - 180;
  return delta > 30 ? Turn.right : (delta < -30 ? Turn.left : Turn.straight);
}

Intersection? nextIntersection(RouteOption route, double meters) {
  final total = route.sampler.totalMeters;
  for (final x in route.intersections) {
    if (x.fraction * total > meters + 1) return x;
  }
  return null;
}

String distanceLabel(double meters) => meters >= 1000
    ? '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km'
    : '${math.max(10, (meters / 10).round() * 10)} m';

/// Saran sinkronisasi dengan lampu simpang berikutnya.
String lightAdvice(RouteOption route, NavFrame frame, DateTime now) {
  final next = nextIntersection(route, frame.meters);
  if (next == null) return 'Tidak ada lampu lagi sampai tujuan';
  final light = next.stateAt(now);
  final distance = next.fraction * route.sampler.totalMeters - frame.meters;
  if (frame.waiting) return 'Berhenti di lampu merah, hijau dalam ${light.remaining} dtk';
  if (light.green) {
    return distance / cruiseSpeed < light.remaining
        ? 'Lampu masih hijau saat Anda tiba'
        : 'Lampu berganti merah sebelum Anda tiba';
  }
  return distance / cruiseSpeed >= light.remaining
      ? 'Lampu sudah hijau saat Anda tiba'
      : 'Jaga ${frame.kmh} km/jam agar tiba saat hijau';
}

/// Simulasi kendaraan di sepanjang rute. Kecepatannya menyesuaikan lampu
/// simpang berikutnya: melambat agar tiba saat hijau, dan berhenti di garis
/// henti jika lampu masih merah.
class NavSimulator {
  NavSimulator(this.route) : _bearing = route.sampler.bearingAt(0);

  final RouteOption route;
  double _meters = 0;
  double _speed = 0;
  double _bearing;

  double get meters => _meters;
  bool get arrived => _meters >= route.sampler.totalMeters - 1;

  /// Maju [dt] detik dan mengembalikan keadaan kendaraan sesudahnya.
  NavFrame step(double dt, DateTime now) {
    final total = route.sampler.totalMeters;
    final next = nextIntersection(route, _meters);

    var target = cruiseSpeed;
    var limit = total;
    if (next != null) {
      final light = next.stateAt(now);
      final distance = next.fraction * total - _meters;
      if (!light.green) {
        if (distance / cruiseSpeed < light.remaining) {
          target = (distance / light.remaining).clamp(_slowest, cruiseSpeed).toDouble();
        }
        limit = next.fraction * total - _stopGap;
      }
    }
    _speed += (target - _speed) * math.min(1, dt * 2.5);
    final moved = math.min(_meters + _speed * dt, limit);
    final waiting = moved >= limit && limit < total;
    if (waiting) _speed = 0;
    _meters = math.max(_meters, moved);

    final t = _meters / total;
    final turn = (route.sampler.bearingAt(t) - _bearing + 540) % 360 - 180;
    _bearing = (_bearing + turn * math.min(1, dt * 4)) % 360;
    return NavFrame(meters: _meters, speed: _speed, position: route.sampler.at(t), bearing: _bearing, waiting: waiting);
  }
}
