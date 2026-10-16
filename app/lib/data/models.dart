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

const dayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

/// Pola lalu lintas Surabaya per jam (00-23), satu digit per jam. Digit adalah
/// indeks profil kepadatan di data rute, diurutkan dari lengang ke puncak:
/// 7, 0, 6, 1, 5, 2, 4, 3. Simulasi: puncak pagi 07.00 dan sore 17.00 di hari
/// kerja, salat Jumat siang, malam minggu, dan Car Free Day Minggu pagi.
const _weekdayPattern = '777770134566161243351607';
const _fridayPattern = '777770134562261243351607';
const _saturdayPattern = '777777706155111522434510';
const _sundayPattern = '777777611655666152516077';

/// Indeks profil kepadatan untuk hari dan jam [time].
int trafficProfile(DateTime time) {
  final pattern = switch (time.weekday) {
    DateTime.friday => _fridayPattern,
    DateTime.saturday => _saturdayPattern,
    DateTime.sunday => _sundayPattern,
    _ => _weekdayPattern,
  };
  return int.parse(pattern[time.hour]);
}

/// Waktu berangkat untuk prediksi kemacetan. Prediksi memakai pola lalu lintas
/// pada hari dan jam itu. [Departure.now] mengikuti jam saat dibaca.
class Departure {
  const Departure._(this._at);
  Departure.at(DateTime time) : _at = time;

  static const now = Departure._(null);

  final DateTime? _at;
  bool get isNow => _at == null;
  DateTime get time => _at ?? DateTime.now();
  int get profile => trafficProfile(time);

  /// Misalnya "Hari ini", "Besok", atau "Senin, 19 Okt".
  static String dayLabel(DateTime day, DateTime today) {
    final diff = DateTime(day.year, day.month, day.day).difference(DateTime(today.year, today.month, today.day));
    return switch (diff.inDays) {
      0 => 'Hari ini',
      1 => 'Besok',
      _ => '${dayNames[day.weekday - 1]}, ${day.day} ${_monthNames[day.month - 1]}',
    };
  }

  /// Misalnya "Sekarang • 14.32" atau "Besok • 07.00".
  String get label {
    final t = time;
    final clock = formatClock(t).replaceAll(':', '.');
    return isNow ? 'Sekarang • $clock' : '${dayLabel(t, DateTime.now())} • $clock';
  }

  @override
  bool operator ==(Object other) => other is Departure && other._at == _at;

  @override
  int get hashCode => _at.hashCode;

  @override
  String toString() => isNow ? 'now' : _at!.toIso8601String();
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
    required this.minutesByProfile,
    required this.levelByProfile,
    required this.segmentsByProfile,
    required this.intersections,
    required this.motorFactor,
  }) : sampler = PathSampler(points);

  final int index;
  final double km;
  final String via;
  final List<LatLng> points;
  final PathSampler sampler;
  final List<int> minutesByProfile;
  final List<TrafficLevel> levelByProfile;
  final List<List<TrafficLevel>> segmentsByProfile;
  final List<Intersection> intersections;
  final double motorFactor;

  int minutes(Departure d, VehicleMode mode) {
    final base = minutesByProfile[d.profile];
    return mode == VehicleMode.motor ? (base * motorFactor).round() : base;
  }

  TrafficLevel level(Departure d) => levelByProfile[d.profile];

  /// Rute yang sama untuk arah sebaliknya, dipakai saat asal dan tujuan ditukar.
  RouteOption reversed() => RouteOption(
    index: index,
    km: km,
    via: via,
    points: points.reversed.toList(),
    minutesByProfile: minutesByProfile,
    levelByProfile: levelByProfile,
    segmentsByProfile: [for (final s in segmentsByProfile) s.reversed.toList()],
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
  List<TrafficLevel> segments(Departure d) => segmentsByProfile[d.profile];

  /// Potongan garis rute per ruas kepadatan, mulai dari pecahan [from] rute.
  /// Ruas yang seluruhnya sudah terlewati tidak ikut, jadi navigasi hanya
  /// menggambar sisa perjalanan.
  List<(TrafficLevel, List<LatLng>)> remainingSlices(Departure d, {double from = 0}) {
    final levels = segments(d);
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

/// Jenis kejadian yang bisa dilaporkan lewat suara, sama dengan parameter
/// `type` pada tool `report_traffic`.
enum IncidentType {
  macet('macet', 'Macet', 'macet', Icons.traffic_rounded, ReportCategory.gangguan),
  kecelakaan('kecelakaan', 'Kecelakaan', 'kecelakaan', Icons.car_crash_outlined, ReportCategory.kecelakaan),
  banjir('banjir', 'Banjir', 'genangan', Icons.flood_outlined, ReportCategory.banjir),
  jalanDitutup('jalan_ditutup', 'Jalan ditutup', 'penutupan jalan', Icons.block_rounded, ReportCategory.jalanDitutup),
  lainnya('lainnya', 'Gangguan lain', 'gangguan', Icons.warning_amber_rounded, ReportCategory.gangguan);

  const IncidentType(this.wire, this.label, this.spoken, this.icon, this.category);

  /// Nilai yang dikirim ke Pulse.
  final String wire;
  final String label;

  /// Sebutan di kalimat siaran, mis. "ada genangan di Jalan X".
  final String spoken;
  final IconData icon;
  final ReportCategory category;
}

enum Severity {
  ringan('Ringan'),
  sedang('Sedang'),
  parah('Parah');

  const Severity(this.label);
  final String label;
}

/// Satu panggilan tool `report_traffic`. Jenis dan tingkat keparahan berasal
/// dari jawaban pengguna; sisanya diisi otomatis dari posisi kendaraan, tidak
/// pernah dari pemahaman bahasa.
class TrafficCall {
  const TrafficCall({
    required this.type,
    required this.severity,
    required this.position,
    required this.heading,
    required this.speedKmh,
    required this.road,
    required this.timestamp,
    this.crawling = false,
    this.utterances = 1,
    this.seconds = 0,
  });
  final IncidentType type;
  final Severity severity;
  final LatLng position;
  final double heading;
  final int speedKmh;

  /// Kecepatan saat melapor jauh di bawah normal ruas, sehingga laporan macet
  /// langsung didukung data kecepatan.
  final bool crawling;

  /// Nama jalan tempat laporan dibuat, tanpa awalan "Jl.".
  final String road;
  final DateTime timestamp;

  /// Jumlah ucapan pengguna dan detik dari pertanyaan sampai laporan siap
  /// dikirim, untuk dibandingkan dengan laporan lewat formulir.
  final int utterances;
  final int seconds;

  String get segmentId => 'sby-${road.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';

  Map<String, dynamic> toJson() => {
    'name': 'report_traffic',
    'parameters': {'type': type.wire, 'severity': severity.name},
    'auto_filled': {
      'lat': double.parse(position.latitude.toStringAsFixed(5)),
      'lng': double.parse(position.longitude.toStringAsFixed(5)),
      'heading': heading.round(),
      'timestamp': timestamp.toIso8601String(),
      'road_segment_id': segmentId,
      'speed': speedKmh,
    },
  };
}

/// Ruas macet simulasi dalam meter dari awal rute; kendaraan melaju [factor]
/// kali kecepatan normal di dalamnya.
class SlowZone {
  const SlowZone(this.from, this.to, this.factor);
  final double from;
  final double to;
  final double factor;
}

/// Kejadian dari Pulse/Ephor di sekitar perjalanan, bahan Mode Siaran.
class RoadEvent {
  const RoadEvent({
    required this.id,
    required this.type,
    required this.road,
    this.routeIndex,
    this.fraction = 0,
    this.lengthMeters = 0,
    this.delayMinutes = 0,
    this.verified = true,
  });
  final String id;
  final IncidentType type;
  final String road;

  /// Rute yang dilewati kejadian ini; null jika berada di luar semua rute.
  final int? routeIndex;

  /// Posisi di sepanjang rute, 0 sampai 1.
  final double fraction;

  /// Panjang antrean; 0 untuk kejadian di satu titik.
  final double lengthMeters;
  final int delayMinutes;

  /// False untuk laporan tunggal yang belum didukung pengguna lain atau data kecepatan.
  final bool verified;
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
    this.call,
    this.speedConfirmed = false,
    this.interactions,
    this.seconds,
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

  /// Terisi untuk laporan lewat suara.
  final TrafficCall? call;

  /// Laporan macet yang cocok dengan kecepatan kendaraan saat dilaporkan.
  final bool speedConfirmed;

  /// Jumlah ketukan atau ucapan dan lama waktu sampai laporan terkirim.
  final int? interactions;
  final int? seconds;

  bool get byVoice => call != null;
  String get title => call?.type.label ?? category.flatLabel;
  IconData get icon => call?.type.icon ?? category.icon;

  /// Detik sampai laporan suara tunggal didukung pengguna lain (simulasi).
  static const _peerSeconds = 20;

  /// Null jika belum terverifikasi; selain itu alasan laporan dipercaya.
  String? trustAt(DateTime now) {
    if (!byVoice) return 'Terverifikasi AI';
    if (speedConfirmed) return 'Cocok dengan data kecepatan';
    return now.difference(createdAt).inSeconds >= _peerSeconds ? 'Dikonfirmasi 3 pengguna' : null;
  }

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
