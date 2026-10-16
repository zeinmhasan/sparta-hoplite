import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/geo.dart';
import '../core/theme.dart';
import 'models.dart';
import 'route_geometry.dart';

// Seluruh isi file ini adalah data simulasi untuk demo. Tidak ada yang berasal
// dari ATCS, GOBIS, atau model prediksi sungguhan.

const userName = 'Raya';
const userCity = 'Surabaya, Jawa Timur';

const origin = Place(
  id: 'origin',
  name: 'Lokasi Saya',
  address: 'Jalan Keputih, Surabaya',
  point: LatLng(-7.2893, 112.8003),
  icon: Icons.my_location_rounded,
);

/// Nama jalan di posisi pengguna, untuk laporan suara di luar navigasi.
const originRoad = 'Keputih';

const places = [
  Place(
    id: 'tp',
    name: 'Tunjungan Plaza',
    address: 'Jl. Jend. Basuki Rahmat, Genteng',
    point: LatLng(-7.2622, 112.7391),
    icon: Icons.local_mall_outlined,
    halte: 'Halte Tunjungan',
  ),
  Place(
    id: 'gubeng',
    name: 'Stasiun Gubeng',
    address: 'Jl. Gubeng Masjid, Gubeng',
    point: LatLng(-7.2653, 112.7520),
    icon: Icons.train_outlined,
    halte: 'Halte Gubeng',
  ),
  Place(
    id: 'balaikota',
    name: 'Balai Kota Surabaya',
    address: 'Jl. Taman Surya, Genteng',
    point: LatLng(-7.2590, 112.7474),
    icon: Icons.account_balance_outlined,
    halte: 'Halte Balai Kota',
  ),
  Place(
    id: 'kbs',
    name: 'Kebun Binatang Surabaya',
    address: 'Jl. Setail, Wonokromo',
    point: LatLng(-7.2960, 112.7366),
    icon: Icons.park_outlined,
    halte: 'Halte Joyoboyo',
  ),
  Place(
    id: 'purabaya',
    name: 'Terminal Purabaya',
    address: 'Jl. Letjen Sutoyo, Waru',
    point: LatLng(-7.3508, 112.7247),
    icon: Icons.directions_bus_outlined,
    halte: 'Halte Purabaya',
  ),
];

// ---------------------------------------------------------------- Lalu lintas

const _l = TrafficLevel.lancar, _s = TrafficLevel.sedang, _p = TrafficLevel.padat;

const citySummary = CitySummary(_s, 62);

const insights = [
  Insight(
    road: 'Jl. Ahmad Yani',
    when: 'pukul 17.00 WIB',
    level: _p,
    detail: 'Volume kendaraan arah Waru diprediksi naik 38% menjelang jam pulang kerja.',
    advice: 'Berangkat sebelum 16.30 atau gunakan Jl. Jemursari sebagai alternatif.',
    confidence: 87,
  ),
  Insight(
    road: 'Jl. Kertajaya',
    when: '30 menit lagi',
    level: _p,
    detail: 'Antrean di Simpang Kertajaya – Raya Sulawesi diprediksi memanjang hingga 400 meter.',
    advice: 'Lampu hijau arah barat direkomendasikan diperpanjang 15 detik.',
    confidence: 82,
  ),
  Insight(
    road: 'Jl. Raya Darmo',
    when: '15 menit lagi',
    level: _s,
    detail: 'Arus mulai melambat di depan Kebun Binatang Surabaya karena jam masuk sekolah.',
    advice: 'Waktu tempuh bertambah sekitar 4 menit.',
    confidence: 79,
  ),
  Insight(
    road: 'Jl. Dr. Ir. H. Soekarno (MERR)',
    when: 'hingga 60 menit ke depan',
    level: _l,
    detail: 'Arus dua arah stabil dengan kecepatan rata-rata 42 km/jam.',
    advice: 'Rute ini aman dipilih untuk perjalanan ke Surabaya Timur.',
    confidence: 91,
  ),
];

// Cuaca simulasi satu hari: cerah sampai siang, berawan sore, hujan ringan 17.00-18.59.
const _tempByHour = [24, 24, 24, 24, 24, 25, 26, 27, 28, 29, 30, 31, 32, 32, 31, 30, 29, 27, 26, 26, 25, 25, 25, 24];

Weather weatherAt(int hour) {
  final sky = switch (hour) {
    >= 6 && < 15 => Sky.cerah,
    15 || 16 => Sky.berawan,
    17 || 18 => Sky.hujan,
    _ => Sky.malam,
  };
  final rain = switch (sky) {
    Sky.cerah => 5,
    Sky.berawan => 35,
    Sky.hujan => 70,
    Sky.malam => 20,
  };
  return Weather(sky, _tempByHour[hour], rain);
}

/// Satu kalimat dampak cuaca ke perjalanan, dipakai kartu cuaca di Home.
String weatherImpact(int hour) {
  if (hour >= 5 && hour < 17) {
    return 'Hujan ringan diperkirakan pukul 17.00. Waktu tempuh bisa naik ±15%, pertimbangkan berangkat lebih awal.';
  }
  if (hour == 17 || hour == 18) {
    return 'Sedang hujan ringan. Waktu tempuh naik ±15% dan jalan licin, jaga jarak aman.';
  }
  return 'Cuaca malam ini berawan tanpa hujan. Tidak ada dampak cuaca pada perjalanan.';
}

// Satu baris per rute, satu kolom per profil kepadatan (lihat trafficProfile di models.dart,
// yang memetakan hari dan jam berangkat ke kolom ini). Kolom 3 adalah jam puncak. Rute pertama
// paling terdampak, sehingga rekomendasi AI berpindah rute pada jam sibuk.
const _segmentPatterns = [
  ['LLSLLL', 'LSSLLL', 'LSPSSL', 'SPPPSL', 'LSPPSL', 'LSSSLL', 'LLSLLL', 'LLLLLL'],
  ['LSSPSL', 'LSSPSL', 'SSSPSL', 'SSPPSS', 'SSPPSS', 'LSSPSL', 'LSSSSL', 'LSSLLL'],
  ['SPPSPS', 'SPPSPS', 'SPPPPS', 'PPPPPS', 'PPPPPP', 'SPPPPS', 'SPPSSS', 'SSPSSL'],
];
const _levelPatterns = [
  [_l, _s, _p, _p, _p, _s, _l, _l],
  [_s, _s, _s, _p, _p, _s, _s, _s],
  [_p, _p, _p, _p, _p, _p, _s, _s],
];
const _delayPatterns = [
  [0, 3, 9, 16, 10, 5, 2, 0],
  [1, 2, 4, 8, 8, 5, 3, 1],
  [3, 4, 7, 11, 13, 9, 6, 3],
];
const _motorFactors = [0.88, 0.8, 0.74];

List<TrafficLevel> _parse(String pattern) =>
    pattern.split('').map((c) => c == 'L' ? _l : (c == 'S' ? _s : _p)).toList();

/// Rute tersimpan untuk tempat populer; null jika tempatnya tidak punya data tersimpan.
List<RouteOption>? buildRoutes(String placeId) {
  final geos = kRouteGeo[placeId];
  return geos == null ? null : routesFromGeo(geos);
}

/// Menempelkan data simulasi (ETA, kepadatan, siklus lampu) ke geometri rute.
List<RouteOption> routesFromGeo(List<RouteGeo> geos) {
  return [
    for (var i = 0; i < geos.length; i++)
      RouteOption(
        index: i,
        km: geos[i].km,
        via: geos[i].via,
        points: [for (final p in geos[i].pts) LatLng(p[0], p[1])],
        minutesByProfile: [for (final d in _delayPatterns[i]) (geos[i].km * 2.35).round() + d],
        levelByProfile: _levelPatterns[i],
        segmentsByProfile: [for (final p in _segmentPatterns[i]) _parse(p)],
        motorFactor: _motorFactors[i],
        intersections: [
          for (var j = 0; j < geos[i].cross.length; j++)
            Intersection(
              name: geos[i].cross[j].name,
              fraction: geos[i].cross[j].frac,
              greenSec: 22 + (j * 7 + i * 5) % 16,
              redSec: 26 + (j * 13 + i * 9) % 24,
              offset: j * 23 + i * 11,
            ),
        ],
      ),
  ];
}

/// Catatan AI di Detail Rute, sesuai hari dan jam berangkat.
String routeNote(RouteOption route, Departure d) {
  // Profil 7 adalah kondisi paling lengang (dini hari).
  final delta = route.minutesByProfile[d.profile] - route.minutesByProfile[7];
  final source = d.isNow
      ? 'Kondisi saat ini dari data ATCS'
      : 'Prediksi dari pola ${dayNames[d.time.weekday - 1]} '
            'pukul ${d.time.hour.toString().padLeft(2, '0')}.00 beberapa pekan terakhir';
  if (delta <= 0) return '$source. Rute ini lengang seperti dini hari.';
  return '$source. ETA $delta menit lebih lama dibanding saat lengang.';
}

// ------------------------------------------------------------- Suroboyo Bus

const busCorridor = 'R2';

/// Koridor bus memakai geometri rute utama Keputih – Tunjungan.
final PathSampler busLine = PathSampler([for (final p in kRouteGeo['tp']![0].pts) LatLng(p[0], p[1])]);

const busStops = [
  BusStop('Terminal Keputih', 0.0),
  BusStop('Halte ITS', 0.17),
  BusStop('Halte Kertajaya Indah', 0.36),
  BusStop('Halte Dharmawangsa', 0.55),
  BusStop('Halte Gubeng', 0.70),
  BusStop('Halte Urip Sumoharjo', 0.86),
  BusStop('Halte Tunjungan', 1.0),
];
const boardingStop = BusStop('Halte ITS', 0.17);

/// Satu putaran koridor disimulasikan 5 menit; di layar dianggap 30 menit.
const _loopSeconds = 300;
const _lineMinutes = 30;
const busCodes = ['SB-07', 'SB-12', 'SB-03'];
const busOccupancy = [0.55, 0.82, 0.34];

class BusSnapshot {
  const BusSnapshot(this.index, this.progress);
  final int index;
  final double progress;
  String get code => busCodes[index];
  double get occupancy => busOccupancy[index];
  LatLng get position => busLine.at(progress);

  /// Menit sampai bus ini tiba di halte; null jika halte sudah terlewati.
  int? minutesTo(BusStop stop) {
    if (stop.fraction < progress) return null;
    return ((stop.fraction - progress) * _lineMinutes).ceil();
  }
}

List<BusSnapshot> busesAt(DateTime time) {
  final t = (time.millisecondsSinceEpoch / 1000 % _loopSeconds) / _loopSeconds;
  return [for (var i = 0; i < busCodes.length; i++) BusSnapshot(i, (t + i / busCodes.length) % 1)];
}

/// Bus terdekat yang belum melewati halte naik.
BusSnapshot nextBusAt(DateTime time) {
  final buses = busesAt(time);
  final coming = buses.where((b) => b.progress <= boardingStop.fraction).toList()
    ..sort((a, b) => b.progress.compareTo(a.progress));
  if (coming.isNotEmpty) return coming.first;
  return (buses..sort((a, b) => b.progress.compareTo(a.progress))).first;
}

/// Menit sampai bus berikutnya tiba di halte naik, termasuk bus yang masih di putaran sebelumnya.
int nextBusMinutes(DateTime time) {
  final bus = nextBusAt(time);
  final gap = (boardingStop.fraction - bus.progress + 1) % 1;
  return (gap * _lineMinutes).ceil().clamp(1, _lineMinutes);
}

List<TransitPlan> buildTransitPlans(Place destination) =>
    _transitPlans(destination, destination.halte.isEmpty ? 'halte terdekat' : destination.halte);

List<TransitPlan> _transitPlans(Place destination, String halte) => [
  TransitPlan(
    title: 'Rute Tercepat',
    minutes: 30,
    cost: 'Rp 5.000',
    level: _l,
    steps: [
      const TransitStep(TransitStepKind.start, 'Lokasi Saya', 'Jalan kaki 4 menit ke Halte ITS'),
      TransitStep(TransitStepKind.ride, 'Naik Bus $busCorridor (Ke Tunjungan)', 'Arah Keputih - Tunjungan • 5 halte'),
      TransitStep(TransitStepKind.end, destination.name, 'Turun di $halte, jalan kaki 3 menit'),
    ],
  ),
  TransitPlan(
    title: 'Rute Terhemat',
    minutes: 38,
    cost: 'Rp 2.500',
    level: _s,
    steps: [
      const TransitStep(TransitStepKind.start, 'Lokasi Saya', 'Jalan kaki 4 menit ke Halte ITS'),
      TransitStep(TransitStepKind.ride, 'Naik Bus $busCorridor (Ke Tunjungan)', 'Tarif pelajar/mahasiswa • 5 halte'),
      const TransitStep(
        TransitStepKind.walk,
        'Pindah ke Feeder Wira Wiri',
        'Gratis dalam 2 jam dengan tiket yang sama',
      ),
      TransitStep(TransitStepKind.end, destination.name, 'Turun di $halte, jalan kaki 2 menit'),
    ],
  ),
];

// --------------------------------------------------------- Transit Assistant

const assistantGreeting =
    'Halo $userName! Saya Transit Assistant. Tanyakan rute, tarif, atau jadwal Suroboyo Bus, saya bantu arahkan.';

const assistantSuggestions = [
  'Berapa tarif Suroboyo Bus?',
  'Bagaimana ke Tunjungan Plaza?',
  'Kapan bus berikutnya tiba?',
  'Bisa bayar pakai apa?',
];

AssistantReply assistantAnswer(String question, DateTime now) {
  final q = question.toLowerCase();
  if (q.contains('tarif') || q.contains('harga') || q.contains('biaya') || q.contains('ongkos')) {
    return const AssistantReply(
      'Tarif Suroboyo Bus Rp 5.000 untuk umum dan Rp 2.500 untuk pelajar atau mahasiswa. '
      'Satu tiket berlaku 2 jam, jadi pindah koridor atau naik feeder tidak perlu bayar lagi.',
    );
  }
  if (q.contains('bayar') || q.contains('qris') || q.contains('tunai') || q.contains('kartu')) {
    return const AssistantReply(
      'Pembayaran non-tunai: QRIS, kartu uang elektronik, atau lewat aplikasi GOBIS. '
      'Pembayaran tunai tidak dilayani di dalam bus.',
    );
  }
  if (q.contains('kapan') || q.contains('jadwal') || q.contains('berikutnya') || q.contains('jam')) {
    final minutes = nextBusMinutes(now);
    return AssistantReply(
      'Bus $busCorridor berikutnya tiba di Halte ITS sekitar $minutes menit lagi. '
      'Setelah itu bus datang tiap ±10 menit. Layanan beroperasi 05.30 sampai 21.00 WIB.',
    );
  }
  if (q.contains('ke ') || q.contains('rute') || q.contains('tunjungan') || q.contains('naik apa')) {
    return const AssistantReply(
      'Dari lokasi Anda, jalan kaki 4 menit ke Halte ITS lalu naik Bus R2 arah Tunjungan. '
      'Turun di Halte Tunjungan, total sekitar 30 menit. Dibanding mobil pribadi pada jam sibuk, Anda hemat ±12 menit.',
      showTransitCard: true,
    );
  }
  return const AssistantReply(
    'Saya bisa membantu soal rute, tarif, jadwal, dan cara bayar Suroboyo Bus. Coba pilih salah satu pertanyaan di bawah.',
  );
}

// -------------------------------------------------------------- Pulse Report

const reportLocations = [
  'Jl. Ahmad Yani, Surabaya',
  'Jl. Kertajaya, Surabaya',
  'Jl. Raya Darmo, Surabaya',
  'Jalan Keputih, Surabaya',
];

/// Warna gradasi untuk kotak foto contoh.
const samplePhotoColors = [
  [Color(0xFF4B6CB7), Color(0xFF182848)],
  [Color(0xFFF2994A), Color(0xFF8E1616)],
  [Color(0xFF134E5E), Color(0xFF71B280)],
  [Color(0xFF3A3D40), Color(0xFF181719)],
];

List<Report> seedReports(DateTime now) => [
  Report(
    id: 'SP-2610-0412',
    category: ReportCategory.kerusakan,
    description: 'Lubang cukup dalam di lajur kiri, berbahaya untuk motor.',
    location: 'Jl. Kertajaya, Surabaya',
    createdAt: now.subtract(const Duration(hours: 3)),
    photoCount: 2,
    priority: 'Sedang',
    fixedStatus: ReportStatus.diproses,
  ),
  Report(
    id: 'SP-2610-0377',
    category: ReportCategory.gangguan,
    description: 'Pohon tumbang menutup satu lajur setelah hujan angin.',
    location: 'Jl. Raya Darmo, Surabaya',
    createdAt: now.subtract(const Duration(days: 1, hours: 2)),
    photoCount: 1,
    priority: 'Tinggi',
    fixedStatus: ReportStatus.selesai,
  ),
];

// ------------------------------------------------------------ Voice Co-Pilot

/// Kejadian simulasi di satu perjalanan, pengganti data Pulse/Ephor.
class TripScenario {
  const TripScenario({required this.events, required this.quietJam});
  final List<RoadEvent> events;

  /// Kemacetan yang belum diketahui Pulse, bahan pertanyaan "Di sini macet?".
  final SlowZone? quietJam;

  /// Ruas tempat kendaraan merayap jika melewati rute [route].
  List<SlowZone> slowZones(RouteOption route) {
    final total = route.sampler.totalMeters;
    return [
      ?quietJam,
      for (final e in events)
        if (e.routeIndex == route.index && e.type == IncidentType.macet)
          SlowZone(e.fraction * total - e.lengthMeters / 2, e.fraction * total + e.lengthMeters / 2, 0.25),
    ];
  }
}

/// Nama jalan di posisi [meters] pada rute, dibaca dari simpang yang mengapitnya.
String roadAt(RouteOption route, double meters) {
  final total = route.sampler.totalMeters;
  final passed = route.intersections.where((x) => x.fraction * total <= meters);
  if (passed.isNotEmpty) return passed.last.roads.last;
  return route.intersections.isEmpty
      ? route.via.split(' & ').first.replaceFirst('Jl. ', '')
      : route.intersections.first.roads.first;
}

/// Skenario untuk perjalanan yang dimulai di rute [start]:
/// 1. kemacetan tak terlapor tak jauh dari titik berangkat,
/// 2. kemacetan yang sudah diketahui Pulse di ruas terpadat setelah rute lain
///    berpisah, sehingga ada rute alternatif yang menghindarinya,
/// 3. genangan menjelang tujuan di tiap rute, dan
/// 4. satu kejadian di luar rute, yang tidak boleh ikut disiarkan.
TripScenario tripScenario(List<RouteOption> routes, RouteOption start, Departure departure) {
  final total = start.sampler.totalMeters;
  var split = 0.0;
  for (final other in routes) {
    if (other.index != start.index) split = math.max(split, start.sampler.sharedPrefixMeters(other.sampler));
  }

  final earliest = (split + 500) / total;
  final levels = start.segments(departure);
  var worst = -1;
  for (var i = 0; i < levels.length; i++) {
    final center = (i + 0.5) / levels.length;
    if (center < earliest || center > 0.85) continue;
    if (worst < 0 || levels[i].index > levels[worst].index) worst = i;
  }
  final jamAt = worst < 0 ? earliest.clamp(0.3, 0.85).toDouble() : (worst + 0.5) / levels.length;

  return TripScenario(
    quietJam: total > 1500 ? const SlowZone(200, 450, 0.22) : null,
    events: [
      RoadEvent(
        id: 'macet-${start.index}',
        type: IncidentType.macet,
        road: roadAt(start, jamAt * total),
        routeIndex: start.index,
        fraction: jamAt,
        lengthMeters: 300,
        delayMinutes: 10,
      ),
      for (final route in routes) _puddle(route, route.index == start.index ? math.min(jamAt + 0.2, 0.93) : 0.7),
      const RoadEvent(id: 'luar-rute', type: IncidentType.kecelakaan, road: 'Mayjend Sungkono'),
    ],
  );
}

RoadEvent _puddle(RouteOption route, double fraction) => RoadEvent(
  id: 'genangan-${route.index}',
  type: IncidentType.banjir,
  road: roadAt(route, fraction * route.sampler.totalMeters),
  routeIndex: route.index,
  fraction: fraction,
);

// -------------------------------------------------------------- Panic Button

const emergencyContacts = [
  EmergencyContact(
    name: 'Command Center',
    number: '112 · Command Center Surabaya',
    icon: Icons.support_agent_rounded,
    color: AppColors.emergency,
    numberColor: AppColors.emergency,
  ),
  EmergencyContact(
    name: 'Bengkel Terdekat',
    number: 'Bengkel Keputih Motor · 450 m',
    icon: Icons.car_repair_rounded,
    color: Color(0xFF8A6D00),
    numberColor: AppColors.textSecondary,
  ),
];

// ---------------------------------------------------------------- Notifikasi

const notifications = [
  AppNotification(
    icon: Icons.traffic_rounded,
    color: AppColors.padat,
    title: 'Jl. Ahmad Yani diprediksi padat',
    body: 'Kemacetan diperkirakan mulai pukul 17.00 WIB. Ketuk untuk melihat rute alternatif.',
    time: '5 menit lalu',
    route: '/route',
    unread: true,
  ),
  AppNotification(
    icon: Icons.flood_rounded,
    color: AppColors.navy,
    title: 'Warga melaporkan banjir di Jl. Kertajaya Indah',
    body: '27 warga mengonfirmasi genangan setinggi lutut. Ketuk untuk melihat foto dan penanganannya.',
    time: '18 menit lalu',
    route: '/community/w-1039',
    unread: true,
  ),
  AppNotification(
    icon: Icons.account_balance_wallet_rounded,
    color: AppColors.lancar,
    title: 'Saldo Pulse bertambah Rp2.500',
    body: 'Laporan kerusakan jalan di Jl. Kertajaya terverifikasi. Tukar saldo dengan tiket Suroboyo Bus.',
    time: '3 jam lalu',
    route: '/rewards',
  ),
  AppNotification(
    icon: Icons.directions_bus_rounded,
    color: AppColors.teal,
    title: 'Bus R2 mendekati Halte ITS',
    body: 'Bus tiba beberapa menit lagi. Ketuk untuk melacak posisinya.',
    time: '12 menit lalu',
    route: '/bus',
    unread: true,
  ),
  AppNotification(
    icon: Icons.campaign_rounded,
    color: AppColors.purple,
    title: 'Laporan SP-2610-0412 sedang diproses',
    body: 'Petugas Dishub menuju lokasi kerusakan jalan di Jl. Kertajaya.',
    time: '2 jam lalu',
    route: '/reports',
  ),
  AppNotification(
    icon: Icons.check_circle_rounded,
    color: AppColors.lancar,
    title: 'Laporan SP-2610-0377 selesai',
    body: 'Pohon tumbang di Jl. Raya Darmo sudah dievakuasi. Terima kasih atas laporan Anda.',
    time: 'Kemarin',
    route: '/reports',
  ),
  AppNotification(
    icon: Icons.wb_cloudy_rounded,
    color: AppColors.navy,
    title: 'Hujan diperkirakan sore ini',
    body: 'Waktu tempuh rata-rata naik 15% saat hujan. Pertimbangkan berangkat lebih awal.',
    time: 'Kemarin',
  ),
];

// ------------------------------------------------------------ Laporan warga

/// Instansi yang menerima laporan menurut jenisnya.
String handlerFor(IncidentType type) => switch (type) {
  IncidentType.macet || IncidentType.jalanDitutup => 'Dishub Surabaya',
  IncidentType.banjir => 'DSDABM Surabaya',
  IncidentType.kecelakaan || IncidentType.lainnya => 'Command Center 112',
};

/// Laporan warga lain di sekitar Surabaya timur, waktunya relatif terhadap [now].
List<CitizenReport> citizenReports(DateTime now) {
  DateTime ago(int minutes) => now.subtract(Duration(minutes: minutes));
  FollowUp step(String title, String detail, int minutesAgo) => FollowUp(title, detail, ago(minutesAgo));
  return [
    CitizenReport(
      id: 'w-1042',
      type: IncidentType.kecelakaan,
      severity: Severity.sedang,
      road: 'Jl. Raya Menur',
      area: 'Gubeng',
      point: const LatLng(-7.2836, 112.7662),
      createdAt: ago(7),
      reporter: 'Dimas A.',
      reporterLevel: 'Garda Kota',
      photo: 'assets/images/reports/kecelakaan.jpg',
      note: 'Ada tabrakan dua mobil di perempatan, lajur kanan ketutup',
      stillThere: 14,
      cleared: 1,
      status: CitizenStatus.ditangani,
      handler: 'Command Center 112',
      followUps: [
        step('Diterima SPARTA Pulse', 'Diklasifikasi AI sebagai kecelakaan, tingkat sedang', 7),
        step('Diteruskan ke Command Center 112', 'Prioritas tinggi karena menutup lajur', 6),
        step('Petugas di lokasi', 'Polantas dan Dishub mengatur arus di perempatan', 2),
      ],
    ),
    CitizenReport(
      id: 'w-1039',
      type: IncidentType.banjir,
      severity: Severity.parah,
      road: 'Jl. Kertajaya Indah',
      area: 'Mulyorejo',
      point: const LatLng(-7.2794, 112.7781),
      createdAt: ago(19),
      reporter: 'Siti N.',
      reporterLevel: 'Pengawas Jalan',
      photo: 'assets/images/reports/banjir.jpg',
      note: 'Banjir parah, setinggi lutut, motor banyak yang mogok',
      stillThere: 27,
      cleared: 3,
      status: CitizenStatus.ditangani,
      handler: 'DSDABM Surabaya',
      followUps: [
        step('Diterima SPARTA Pulse', 'Diklasifikasi AI sebagai banjir, tingkat parah', 19),
        step('Diteruskan ke DSDABM Surabaya', 'Dinas Sumber Daya Air dan Bina Marga', 17),
        step('Rumah pompa dioperasikan', 'Pompa air menyala, genangan diperkirakan surut 40 menit', 8),
      ],
    ),
    CitizenReport(
      id: 'w-1036',
      type: IncidentType.macet,
      severity: Severity.parah,
      road: 'Jl. Ir. H. Soekarno (MERR)',
      area: 'Sukolilo',
      point: const LatLng(-7.2967, 112.7834),
      createdAt: ago(33),
      reporter: 'Bagus P.',
      reporterLevel: 'Pengawas Jalan',
      photo: 'assets/images/reports/macet.jpg',
      note: 'Macet total arah Kenjeran, hampir nggak gerak',
      stillThere: 31,
      cleared: 4,
      status: CitizenStatus.terverifikasi,
      handler: 'Dishub Surabaya',
      followUps: [
        step('Diterima SPARTA Pulse', 'Cocok dengan data kecepatan kendaraan di ruas ini', 33),
        step('Lampu ATCS disesuaikan', 'Fase hijau arah Kenjeran diperpanjang 20 detik', 25),
      ],
    ),
    CitizenReport(
      id: 'w-1033',
      type: IncidentType.lainnya,
      severity: Severity.sedang,
      road: 'Jl. Pemuda',
      area: 'Genteng',
      point: const LatLng(-7.2648, 112.7463),
      createdAt: ago(48),
      reporter: 'Rina K.',
      reporterLevel: 'Warga Peduli',
      photo: 'assets/images/reports/kerumunan.jpg',
      note: 'Kerumunan massa, separuh jalan tertutup',
      stillThere: 2,
      cleared: 0,
      status: CitizenStatus.menunggu,
      handler: 'Command Center 112',
      followUps: [step('Diterima SPARTA Pulse', 'Menunggu konfirmasi warga sekitar', 48)],
    ),
    CitizenReport(
      id: 'w-1027',
      type: IncidentType.jalanDitutup,
      severity: Severity.parah,
      road: 'Jl. Arief Rahman Hakim',
      area: 'Sukolilo',
      point: const LatLng(-7.2889, 112.7874),
      createdAt: ago(95),
      reporter: 'Hendra W.',
      reporterLevel: 'Garda Kota',
      photo: 'assets/images/reports/ambles.jpg',
      note: 'Jalan ambles, satu lajur ditutup pakai pembatas',
      stillThere: 19,
      cleared: 0,
      status: CitizenStatus.ditangani,
      handler: 'DSDABM Surabaya',
      followUps: [
        step('Diterima SPARTA Pulse', 'Diklasifikasi AI sebagai jalan ditutup, tingkat parah', 95),
        step('Diteruskan ke DSDABM Surabaya', 'Tim perbaikan jalan dijadwalkan', 80),
        step('Pengalihan arus', 'Dishub memasang rambu pengalihan ke Jl. Klampis Jaya', 60),
      ],
    ),
    CitizenReport(
      id: 'w-1018',
      type: IncidentType.lainnya,
      severity: Severity.ringan,
      road: 'Jl. Raya Darmo',
      area: 'Wonokromo',
      point: const LatLng(-7.2905, 112.7372),
      createdAt: ago(260),
      reporter: 'Ayu L.',
      reporterLevel: 'Pengawas Jalan',
      photo: 'assets/images/reports/pohon.jpg',
      note: 'Pohon tumbang di trotoar, sebagian ke badan jalan',
      stillThere: 9,
      cleared: 12,
      status: CitizenStatus.selesai,
      handler: 'DLH Surabaya',
      followUps: [
        step('Diterima SPARTA Pulse', 'Diklasifikasi AI sebagai gangguan, tingkat ringan', 260),
        step('Diteruskan ke DLH Surabaya', 'Dinas Lingkungan Hidup, satgas pohon', 245),
        step('Selesai', 'Pohon sudah dipotong dan diangkut', 150),
      ],
    ),
  ];
}

// -------------------------------------------------------------- Saldo Pulse

/// Laporan terverifikasi pengguna sebelum sesi ini, untuk jenjang pelapor.
const seedVerifiedReports = 12;

/// Layanan Pemkot Surabaya yang bisa dibayar dengan saldo. Harga mengikuti
/// tarif umum: Suroboyo Bus dan Wira Wiri Rp5.000, KBS Rp15.000, Museum
/// Sepuluh Nopember Rp8.000, THP Kenjeran Rp10.000, SSCT Rp10.000.
const rewardCatalog = [
  RewardItem(
    id: 'suroboyo-bus',
    name: 'Suroboyo Bus',
    operator: 'Dishub Kota Surabaya',
    category: 'Transportasi',
    price: 5000,
    unit: '1 perjalanan, semua koridor',
    icon: Icons.directions_bus_rounded,
    color: Color(0xFFD32F2F),
    howTo: 'Pindai QR di validator pintu bus, atau tunjukkan ke pramudi.',
    validFor: Duration(hours: 24),
  ),
  RewardItem(
    id: 'wira-wiri',
    name: 'Wira Wiri Suroboyo',
    operator: 'Feeder Dishub Kota Surabaya',
    category: 'Transportasi',
    price: 5000,
    unit: '1 perjalanan, 11 rute feeder',
    icon: Icons.airport_shuttle_rounded,
    color: Color(0xFF00897B),
    howTo: 'Pindai QR di validator feeder saat naik.',
    validFor: Duration(hours: 24),
  ),
  RewardItem(
    id: 'ssct',
    name: 'Bus SSCT',
    operator: 'Surabaya Sightseeing & City Tour',
    category: 'Transportasi',
    price: 10000,
    unit: '1 kursi tur keliling kota',
    icon: Icons.tour_rounded,
    color: Color(0xFF1565C0),
    howTo: 'Tunjukkan QR di Tourism Information Center Balai Pemuda sebelum berangkat.',
    validFor: Duration(days: 30),
  ),
  RewardItem(
    id: 'parkir',
    name: 'Parkir Tepi Jalan',
    operator: 'Dishub Kota Surabaya',
    category: 'Transportasi',
    price: 5000,
    unit: 'Potongan Rp5.000 di titik e-parking',
    icon: Icons.local_parking_rounded,
    color: Color(0xFF5E35B1),
    howTo: 'Tunjukkan QR ke juru parkir resmi saat membayar.',
    validFor: Duration(days: 7),
  ),
  RewardItem(
    id: 'kbs',
    name: 'Kebun Binatang Surabaya',
    operator: 'PD Taman Satwa KBS',
    category: 'Wisata kota',
    price: 15000,
    unit: '1 tiket masuk',
    icon: Icons.pets_rounded,
    color: Color(0xFF2E7D32),
    howTo: 'Tukarkan QR di loket KBS, buka pukul 08.00 sampai 16.00.',
    validFor: Duration(days: 30),
  ),
  RewardItem(
    id: 'museum-10-nopember',
    name: 'Museum Sepuluh Nopember',
    operator: 'Kawasan Tugu Pahlawan',
    category: 'Wisata kota',
    price: 8000,
    unit: '1 tiket masuk museum',
    icon: Icons.account_balance_rounded,
    color: Color(0xFF8E1616),
    howTo: 'Tunjukkan QR di loket museum.',
    validFor: Duration(days: 30),
  ),
  RewardItem(
    id: 'thp-kenjeran',
    name: 'Taman Hiburan Pantai Kenjeran',
    operator: 'Pemerintah Kota Surabaya',
    category: 'Wisata kota',
    price: 10000,
    unit: '1 tiket masuk',
    icon: Icons.beach_access_rounded,
    color: Color(0xFFEF6C00),
    howTo: 'Tunjukkan QR di gerbang masuk THP Kenjeran.',
    validFor: Duration(days: 30),
  ),
];

/// Riwayat saldo sebelum sesi ini.
List<WalletEntry> seedWallet(DateTime now) {
  DateTime ago(int hours) => now.subtract(Duration(hours: hours));
  return [
    WalletEntry(
      title: 'Laporan kerusakan jalan terverifikasi',
      detail: 'Jl. Kertajaya, Surabaya',
      amount: rewardPerReport,
      time: ago(3),
    ),
    WalletEntry(
      title: 'Konfirmasi laporan warga',
      detail: 'Macet • Jl. Ahmad Yani',
      amount: rewardPerConfirmation,
      time: ago(20),
    ),
    WalletEntry(
      title: 'Laporan pohon tumbang terverifikasi',
      detail: 'Jl. Raya Darmo, Surabaya',
      amount: rewardPerReport,
      time: ago(26),
    ),
    WalletEntry(title: 'Tiket Suroboyo Bus', detail: 'Koridor R2 • Halte ITS', amount: -5000, time: ago(50)),
    WalletEntry(
      title: 'Bonus pelapor aktif',
      detail: '5 laporan terverifikasi dalam seminggu',
      amount: 10000,
      time: ago(74),
    ),
    WalletEntry(
      title: 'Laporan banjir terverifikasi',
      detail: 'Jl. Dharmahusada, Surabaya',
      amount: rewardPerReport,
      time: ago(98),
    ),
    WalletEntry(
      title: 'Laporan macet terverifikasi',
      detail: 'Jl. Raya ITS, Surabaya',
      amount: rewardPerReport,
      time: ago(120),
    ),
  ];
}
