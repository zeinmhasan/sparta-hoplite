import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/geo.dart';
import '../core/theme.dart';

enum TrafficLevel {
  lancar('Lancar', AppColors.lancar, Color(0xFF1B6E3D)),
  sedang('Sedang', AppColors.sedang, Color(0xFF7A5F00)),
  padat('Padat', AppColors.padat, Color(0xFF9B1C1C));

  const TrafficLevel(this.label, this.color, this.onTint);
  final String label;
  final Color color;
  final Color onTint;
  Color get tint => color.withValues(alpha: 0.16);
}

/// Jam berangkat untuk prediksi kemacetan: sekarang sampai 6 jam ke depan.
enum Horizon {
  now(0, 'Sekarang'),
  m30(30, '30 menit lagi'),
  h1(60, '1 jam lagi'),
  h2(120, '2 jam lagi'),
  h3(180, '3 jam lagi'),
  h4(240, '4 jam lagi'),
  h5(300, '5 jam lagi'),
  h6(360, '6 jam lagi');

  const Horizon(this.minutes, this.label);
  final int minutes;
  final String label;
}

enum VehicleMode {
  mobil('Mobil', Icons.directions_car_filled_outlined),
  motor('Motor', Icons.two_wheeler_rounded);

  const VehicleMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

class Place {
  const Place({
    required this.id,
    required this.name,
    required this.address,
    required this.point,
    required this.icon,
    this.halte = '',
  });
  final String id;
  final String name;
  final String address;
  final LatLng point;
  final IconData icon;
  final String halte;
}

class LightState {
  const LightState(this.green, this.remaining);
  final bool green;
  final int remaining;
  Color get color => green ? AppColors.lancar : AppColors.padat;
  String get label => green ? 'Hijau' : 'Merah';
}

class Intersection {
  const Intersection({
    required this.name,
    required this.fraction,
    required this.greenSec,
    required this.redSec,
    required this.offset,
  });
  final String name;

  /// Nama jalan sebelum dan sesudah simpang, dari "Simpang A – B".
  List<String> get roads => name.replaceFirst('Simpang ', '').split(' – ');

  /// Posisi simpang di sepanjang rute, 0 sampai 1.
  final double fraction;
  final int greenSec;
  final int redSec;
  final int offset;

  LightState stateAt(DateTime time) {
    final cycle = greenSec + redSec;
    final phase = (time.millisecondsSinceEpoch ~/ 1000 + offset) % cycle;
    return phase < greenSec ? LightState(true, greenSec - phase) : LightState(false, cycle - phase);
  }
}

class RouteOption {
  RouteOption({
    required this.index,
    required this.km,
    required this.via,
    required this.points,
    required this.minutesByHorizon,
    required this.levelByHorizon,
    required this.segmentsByHorizon,
    required this.intersections,
    required this.motorFactor,
  }) : sampler = PathSampler(points);

  final int index;
  final double km;
  final String via;
  final List<LatLng> points;
  final PathSampler sampler;
  final List<int> minutesByHorizon;
  final List<TrafficLevel> levelByHorizon;
  final List<List<TrafficLevel>> segmentsByHorizon;
  final List<Intersection> intersections;
  final double motorFactor;

  int minutes(Horizon h, VehicleMode mode) {
    final base = minutesByHorizon[h.index];
    return mode == VehicleMode.motor ? (base * motorFactor).round() : base;
  }

  TrafficLevel level(Horizon h) => levelByHorizon[h.index];

  /// Rute yang sama untuk arah sebaliknya, dipakai saat asal dan tujuan ditukar.
  RouteOption reversed() => RouteOption(
    index: index,
    km: km,
    via: via,
    points: points.reversed.toList(),
    minutesByHorizon: minutesByHorizon,
    levelByHorizon: levelByHorizon,
    segmentsByHorizon: [for (final s in segmentsByHorizon) s.reversed.toList()],
    motorFactor: motorFactor,
    intersections: [
      for (final x in intersections.reversed)
        // Arah dibalik, jadi "Simpang A – B" dilewati sebagai "Simpang B – A".
        Intersection(
          name: 'Simpang ${x.roads.reversed.join(' – ')}',
          fraction: 1 - x.fraction,
          greenSec: x.greenSec,
          redSec: x.redSec,
          offset: x.offset,
        ),
    ],
  );
  List<TrafficLevel> segments(Horizon h) => segmentsByHorizon[h.index];

  /// Potongan garis rute per ruas kepadatan, mulai dari pecahan [from] rute.
  /// Ruas yang seluruhnya sudah terlewati tidak ikut, jadi navigasi hanya
  /// menggambar sisa perjalanan.
  List<(TrafficLevel, List<LatLng>)> remainingSlices(Horizon h, {double from = 0}) {
    final levels = segments(h);
    final n = levels.length;
    return [
      for (var i = 0; i < n; i++)
        if ((i + 1) / n > from) (levels[i], sampler.slice(math.max(i / n, from), (i + 1) / n)),
    ];
  }

  String get kmLabel => '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
}

class CitySummary {
  const CitySummary(this.level, this.percent);
  final TrafficLevel level;
  final int percent;
}

enum Sky {
  cerah('Cerah', Icons.wb_sunny_rounded, Color(0xFFF5B800)),
  berawan('Berawan', Icons.cloud_rounded, Color(0xFF8FA3B8)),
  hujan('Hujan ringan', Icons.umbrella_rounded, Color(0xFF3B82C4)),
  malam('Berawan', Icons.nights_stay_rounded, AppColors.navy);

  const Sky(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

class Weather {
  const Weather(this.sky, this.temp, this.rainChance);
  final Sky sky;
  final int temp;
  final int rainChance;
}

class Insight {
  const Insight({
    required this.road,
    required this.when,
    required this.level,
    required this.detail,
    required this.advice,
    required this.confidence,
  });
  final String road;
  final String when;
  final TrafficLevel level;
  final String detail;
  final String advice;
  final int confidence;
}

class TrafficOverview {
  const TrafficOverview(this.summary, this.insights);
  final CitySummary summary;
  final List<Insight> insights;
}

class BusStop {
  const BusStop(this.name, this.fraction);
  final String name;
  final double fraction;
}

enum TransitStepKind { start, walk, ride, end }

class TransitStep {
  const TransitStep(this.kind, this.title, this.subtitle);
  final TransitStepKind kind;
  final String title;
  final String subtitle;
}

class TransitPlan {
  const TransitPlan({
    required this.title,
    required this.steps,
    required this.minutes,
    required this.cost,
    required this.level,
  });
  final String title;
  final List<TransitStep> steps;
  final int minutes;
  final String cost;
  final TrafficLevel level;
}

class AssistantReply {
  const AssistantReply(this.text, {this.showTransitCard = false});
  final String text;
  final bool showTransitCard;
}

class AppNotification {
  const AppNotification({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.time,
    this.route,
    this.unread = false,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String time;
  final String? route;
  final bool unread;
}

enum ReportCategory {
  kecelakaan('Kecelakaan', Icons.car_crash_outlined),
  banjir('Banjir', Icons.flood_outlined),
  jalanDitutup('Jalan\nDitutup', Icons.block_rounded),
  event('Event', Icons.event_outlined),
  gangguan('Gangguan\nLalu Lintas', Icons.warning_amber_rounded),
  kerusakan('Kerusakan\nJalan', Icons.construction_rounded);

  const ReportCategory(this.label, this.icon);
  final String label;
  final IconData icon;
  String get flatLabel => label.replaceAll('\n', ' ');
}

enum ReportStatus {
  terkirim('Terkirim', 'Laporan diterima sistem SPARTA Pulse'),
  dibaca('Dibaca', 'Operator Dishub membuka laporan di SPARTA Ephor'),
  diproses('Diproses', 'Petugas lapangan sedang menangani'),
  selesai('Selesai', 'Penanganan selesai dan arus kembali normal');

  const ReportStatus(this.label, this.note);
  final String label;
  final String note;
}

class Report {
  const Report({
    required this.id,
    required this.category,
    required this.description,
    required this.location,
    required this.createdAt,
    required this.photoCount,
    required this.priority,
    this.fixedStatus,
  });
  final String id;
  final ReportCategory category;
  final String description;
  final String location;
  final DateTime createdAt;
  final int photoCount;
  final String priority;

  /// Laporan lama punya status tetap; laporan baru maju sendiri seiring waktu.
  final ReportStatus? fixedStatus;

  static const _stepSeconds = [8, 18, 30];

  ReportStatus statusAt(DateTime now) {
    if (fixedStatus != null) return fixedStatus!;
    final elapsed = now.difference(createdAt).inSeconds;
    if (elapsed >= _stepSeconds[2]) return ReportStatus.selesai;
    if (elapsed >= _stepSeconds[1]) return ReportStatus.diproses;
    if (elapsed >= _stepSeconds[0]) return ReportStatus.dibaca;
    return ReportStatus.terkirim;
  }
}

class EmergencyContact {
  const EmergencyContact({
    required this.name,
    required this.number,
    required this.icon,
    required this.color,
    required this.numberColor,
  });
  final String name;
  final String number;
  final IconData icon;
  final Color color;
  final Color numberColor;
}

String formatClock(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
