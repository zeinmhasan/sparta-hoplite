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
/// dari ucapan pengguna; sisanya diisi otomatis dari GPS atau posisi kendaraan,
/// tidak pernah dari pemahaman bahasa.
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
    this.transcript = '',
    this.confidence,
    this.photoPath,
    this.address,
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

  /// Alamat lengkap dari GPS; null untuk laporan selama navigasi (di Surabaya).
  final String? address;
  final DateTime timestamp;

  /// Ucapan pengguna yang diklasifikasi, dan keyakinan klasifikasinya (0 sampai 1).
  final String transcript;
  final double? confidence;

  /// Foto bukti dari kamera. Wajib untuk laporan dari tab Pulse Report;
  /// laporan selama navigasi cukup suara karena pengemudi tidak boleh memotret.
  final String? photoPath;

  String get segmentId => 'sby-${road.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';

  Map<String, dynamic> toJson() => {
    'name': 'report_traffic',
    'parameters': {'type': type.wire, 'severity': severity.name},
    if (transcript.isNotEmpty)
      'classifier': {
        'transcript': transcript,
        if (confidence != null) 'confidence': double.parse(confidence!.toStringAsFixed(2)),
      },
    'auto_filled': {
      'lat': double.parse(position.latitude.toStringAsFixed(5)),
      'lng': double.parse(position.longitude.toStringAsFixed(5)),
      'heading': heading.round(),
      'timestamp': timestamp.toIso8601String(),
      'road_segment_id': segmentId,
      'speed': speedKmh,
    },
    if (photoPath != null) 'evidence': {'photo': photoPath!.split(RegExp(r'[/\\]')).last},
  };
}

/// Lokasi pelapor di luar navigasi. [live] false berarti GPS tidak tersedia
/// dan lokasi diganti titik asal demo.
class ReportSpot {
  const ReportSpot({
    required this.point,
    required this.road,
    required this.address,
    required this.live,
    required this.at,
  });
  final LatLng point;

  /// Nama jalan tanpa awalan "Jl.".
  final String road;
  final String address;
  final bool live;

  /// Waktu lokasi ini didapat.
  final DateTime at;
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

  bool get byVoice => call != null;
  String get title => call?.type.label ?? category.flatLabel;
  IconData get icon => call?.type.icon ?? category.icon;
  String? get photoPath => call?.photoPath;

  /// Detik sampai laporan suara tunggal didukung pengguna lain (simulasi).
  static const _peerSeconds = 20;

  /// Saat laporan suara terverifikasi: langsung jika cocok dengan data
  /// kecepatan, selain itu setelah didukung pengguna lain. Null untuk laporan lama.
  DateTime? get verifiedAt {
    if (!byVoice) return null;
    return speedConfirmed ? createdAt : createdAt.add(const Duration(seconds: _peerSeconds));
  }

  /// Null jika belum terverifikasi; selain itu alasan laporan dipercaya.
  String? trustAt(DateTime now) {
    if (!byVoice) return 'Terverifikasi AI';
    if (speedConfirmed) return 'Cocok dengan data kecepatan';
    return now.isBefore(verifiedAt!) ? null : 'Dikonfirmasi 3 pengguna';
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

// ------------------------------------------------------------ Laporan warga

/// Tahap laporan warga seperti terlihat oleh pengguna lain.
enum CitizenStatus {
  menunggu('Menunggu konfirmasi', Icons.hourglass_top_rounded, AppColors.textSecondary),
  terverifikasi('Terverifikasi', Icons.verified_rounded, AppColors.lancar),
  ditangani('Ditangani petugas', Icons.engineering_rounded, Color(0xFFB07A00)),
  selesai('Selesai', Icons.check_circle_rounded, AppColors.navy);

  const CitizenStatus(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

/// Satu langkah tindak lanjut pemerintah atas laporan warga.
class FollowUp {
  const FollowUp(this.title, this.detail, this.time);
  final String title;
  final String detail;
  final DateTime time;
}

/// Konfirmasi pengguna atas laporan warga lain.
class Vote {
  const Vote(this.stillThere, this.at);

  /// True "masih ada", false "sudah aman".
  final bool stillThere;
  final DateTime at;
}

/// Laporan Pulse yang tampil di umpan Laporan Warga, milik siapa pun.
class CitizenReport {
  const CitizenReport({
    required this.id,
    required this.type,
    required this.severity,
    required this.road,
    required this.area,
    required this.point,
    required this.createdAt,
    required this.reporter,
    required this.reporterLevel,
    required this.photo,
    required this.note,
    required this.stillThere,
    required this.cleared,
    required this.status,
    this.handler,
    this.followUps = const [],
    this.photoIsFile = false,
    this.mine = false,
  });
  final String id;
  final IncidentType type;
  final Severity severity;

  /// Nama jalan lengkap dengan awalan, mis. "Jl. Ahmad Yani".
  final String road;
  final String area;
  final LatLng point;
  final DateTime createdAt;
  final String reporter;
  final String reporterLevel;

  /// Path aset, atau path file jika [photoIsFile].
  final String photo;
  final bool photoIsFile;

  /// Ucapan pelapor saat melapor.
  final String note;

  /// Jumlah warga yang menyatakan kejadian masih ada atau sudah aman.
  final int stillThere;
  final int cleared;
  final CitizenStatus status;

  /// Instansi yang menangani, mis. "Dishub Surabaya".
  final String? handler;
  final List<FollowUp> followUps;
  final bool mine;

  CitizenReport withVotes(int stillThere, int cleared) => CitizenReport(
    id: id,
    type: type,
    severity: severity,
    road: road,
    area: area,
    point: point,
    createdAt: createdAt,
    reporter: reporter,
    reporterLevel: reporterLevel,
    photo: photo,
    note: note,
    stillThere: stillThere,
    cleared: cleared,
    status: status,
    handler: handler,
    followUps: followUps,
    photoIsFile: photoIsFile,
    mine: mine,
  );
}

// -------------------------------------------------------------- Saldo Pulse

/// Besaran saldo untuk tiap kontribusi yang terverifikasi.
const rewardPerReport = 2500;
const rewardPerConfirmation = 500;

/// Jenjang pelapor menurut jumlah laporan terverifikasi.
enum ReporterLevel {
  warga('Warga Peduli', 0),
  pengawas('Pengawas Jalan', 10),
  garda('Garda Kota', 30);

  const ReporterLevel(this.label, this.minVerified);
  final String label;
  final int minVerified;

  static ReporterLevel of(int verified) => values.lastWhere((l) => verified >= l.minVerified);
  ReporterLevel? get next => index + 1 < values.length ? values[index + 1] : null;
}

/// Layanan milik Pemerintah Kota Surabaya yang bisa dibayar dengan saldo.
class RewardItem {
  const RewardItem({
    required this.id,
    required this.name,
    required this.operator,
    required this.category,
    required this.price,
    required this.unit,
    required this.icon,
    required this.color,
    required this.howTo,
    required this.validFor,
  });
  final String id;
  final String name;
  final String operator;
  final String category;
  final int price;
  final String unit;
  final IconData icon;
  final Color color;

  /// Cara memakai voucher di lokasi.
  final String howTo;
  final Duration validFor;
}

/// Satu baris riwayat saldo: positif untuk saldo masuk, negatif untuk penukaran.
class WalletEntry {
  const WalletEntry({required this.title, required this.detail, required this.amount, required this.time});
  final String title;
  final String detail;
  final int amount;
  final DateTime time;
}

/// Voucher hasil penukaran saldo, ditunjukkan sebagai kode QR.
class Voucher {
  const Voucher({required this.id, required this.item, required this.code, required this.issuedAt});
  final String id;
  final RewardItem item;
  final String code;
  final DateTime issuedAt;

  DateTime get validUntil => issuedAt.add(item.validFor);
}

/// Rupiah dengan titik ribuan, mis. 17500 -> "Rp17.500".
String rupiah(int amount) {
  final digits = amount.abs().toString();
  final grouped = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => '.');
  return '${amount < 0 ? '−' : ''}Rp$grouped';
}
