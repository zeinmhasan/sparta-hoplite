import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Mengambil titik dan potongan garis di sepanjang polyline berdasarkan jarak,
/// supaya marker bergerak dengan kecepatan rata walau titiknya tidak merata.
class PathSampler {
  PathSampler(this.points) {
    _cum = [0];
    for (var i = 1; i < points.length; i++) {
      _cum.add(_cum.last + _meters(points[i - 1], points[i]));
    }
  }

  final List<LatLng> points;
  late final List<double> _cum;

  double get totalMeters => _cum.last;

  static double _meters(LatLng a, LatLng b) {
    final dx = (a.longitude - b.longitude) * 111320 * math.cos(a.latitude * math.pi / 180);
    final dy = (a.latitude - b.latitude) * 110540;
    return math.sqrt(dx * dx + dy * dy);
  }

  int _segmentAt(double meters) {
    var lo = 0, hi = _cum.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) ~/ 2;
      if (_cum[mid] <= meters) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  LatLng at(double t) {
    final meters = t.clamp(0.0, 1.0) * totalMeters;
    final i = _segmentAt(meters);
    final span = _cum[i + 1] - _cum[i];
    final f = span == 0 ? 0.0 : (meters - _cum[i]) / span;
    final a = points[i], b = points[i + 1];
    return LatLng(a.latitude + (b.latitude - a.latitude) * f, a.longitude + (b.longitude - a.longitude) * f);
  }

  /// Arah hadap di titik [t] dalam derajat dari utara (searah jarum jam),
  /// dirata-rata sepanjang [spanMeters] supaya belokan tidak menyentak.
  double bearingAt(double t, {double spanMeters = 90}) {
    final half = spanMeters / 2 / totalMeters;
    return const Distance().bearing(at(t - half), at(t + half));
  }

  List<LatLng> slice(double from, double to) {
    final start = _segmentAt(from.clamp(0.0, 1.0) * totalMeters);
    final end = _segmentAt(to.clamp(0.0, 1.0) * totalMeters);
    return [at(from), ...points.sublist(start + 1, end + 1), at(to)];
  }

  /// Panjang ruas awal (meter) yang sama persis dengan garis [other]: jarak
  /// dari titik berangkat sampai kedua rute berpisah.
  double sharedPrefixMeters(PathSampler other) {
    var i = 0;
    while (i + 1 < points.length && i + 1 < other.points.length && _meters(points[i + 1], other.points[i + 1]) < 3) {
      i++;
    }
    return _cum[i];
  }
}
