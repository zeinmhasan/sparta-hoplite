import '../../data/mock_data.dart' show roadAt;
import '../../data/models.dart';
import '../route/nav_sim.dart';
import 'copilot.dart';
import 'intent.dart';

/// Mengenali perlambatan yang bertahan: kecepatan di bawah ambang relatif
/// terhadap kecepatan normal ruas selama durasi tertentu.
class SlowdownDetector {
  SlowdownDetector(this.config);
  final VoiceConfig config;
  double _slowFor = 0;

  /// [excused] menandai perlambatan yang sudah ada penjelasannya, mis. lampu merah.
  bool update(double dt, {required double speed, required double normal, bool excused = false}) {
    _slowFor = excused || speed >= normal * config.slowRatio ? 0 : _slowFor + dt;
    return _slowFor >= config.slowSeconds;
  }
}

/// Nama jalan untuk diucapkan: singkatan dibaca penuh, dan nama populer di
/// dalam kurung dipakai menggantikan nama resminya.
String spokenRoad(String road) {
  final popular = RegExp(r'\(([^)]+)\)').firstMatch(road);
  if (popular != null) return 'Jalan ${popular.group(1)}';
  final full = road
      .replaceAll('Mayjend', 'Mayor Jenderal')
      .replaceAll('Jend.', 'Jenderal')
      .replaceAll('Dr.', 'Doktor')
      .replaceAll('Ir.', 'Insinyur')
      .replaceAll('H.', 'Haji');
  return 'Jalan $full';
}

String spokenDistance(double meters) {
  if (meters < 950) return '${(meters / 100).round().clamp(1, 9) * 100} meter';
  final halves = (meters / 500).round();
  return halves.isEven ? '${halves ~/ 2} kilometer' : '${halves ~/ 2},5 kilometer';
}

/// Rute alternatif yang layak ditawarkan untuk menghindari kemacetan di depan.
class Detour {
  const Detour(this.route, this.road, this.splitMeters, this.savedMinutes);
  final RouteOption route;

  /// Jalan pertama yang membedakannya dari rute sekarang.
  final String road;

  /// Jarak dari titik berangkat sampai kedua rute berpisah.
  final double splitMeters;
  final int savedMinutes;
}

/// Co-pilot selama satu perjalanan. Dipanggil tiap frame navigasi; memutuskan
/// kapan bertanya duluan, menyiarkan kejadian di depan, dan menawarkan rute
/// alternatif. Tidak ada yang ditampilkan untuk diperhatikan: semuanya suara.
class TripCopilot {
  TripCopilot({
    required this.copilot,
    required this.routes,
    required RouteOption route,
    required this.events,
    required this.minutesOf,
    required this.send,
    required this.confirm,
    required this.onReroute,
  }) : _route = route,
       _detector = SlowdownDetector(copilot.config) {
    _readTurns();
  }

  final VoiceCopilot copilot;
  final List<RouteOption> routes;
  final List<RoadEvent> events;

  /// Perkiraan menit tempuh satu rute untuk jam berangkat dan kendaraan terpilih.
  final int Function(RouteOption route) minutesOf;
  final Future<void> Function(TrafficCall call) send;
  final Future<void> Function(RoadEvent event, bool stillThere) confirm;
  final void Function(RouteOption route) onReroute;

  final SlowdownDetector _detector;
  RouteOption _route;
  List<double> _turns = const [];
  NavFrame? _frame;
  DateTime _now = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _started;
  DateTime? _quietUntil;
  DateTime? _lastQuestion;
  final _broadcasts = <DateTime>[];
  final _done = <String>{};
  bool _episodeHandled = false;

  VoiceConfig get _config => copilot.config;
  double get _total => _route.sampler.totalMeters;
  RouteOption get route => _route;

  /// Kejadian yang sudah disiarkan, urut waktu.
  List<String> get announced => _done.toList();

  void _readTurns() {
    _turns = [
      for (final x in _route.intersections)
        if (turnAt(_route, x) != Turn.straight) x.fraction * _total,
    ];
  }

  void onFrame(NavFrame frame, double dt, DateTime now) {
    _frame = frame;
    _now = now;
    _started ??= now;

    final slow = _detector.update(dt, speed: frame.speed, normal: cruiseSpeed, excused: frame.yielding);
    if (!slow) _episodeHandled = false;
    if (!copilot.enabled || copilot.busy) return;
    final rested = !now.isBefore(_quietUntil ?? _started!);

    final lastQuestion = _lastQuestion;
    final cooled = lastQuestion == null || now.difference(lastQuestion) >= _config.questionCooldown;
    if (slow && !_episodeHandled && copilot.proactive && cooled && rested) {
      _episodeHandled = true;
      _lastQuestion = now;
      final known = _jamAt(frame.meters);
      _start(known == null ? _askJam : () => _askStill(known));
      return;
    }

    if (!copilot.broadcast || _maneuvering(frame.meters)) return;
    if (now.difference(_started!) < _config.startQuiet) return;

    // P1 disiarkan segera. P2 menunggu jeda bicara dan batas siaran per menit.
    final incident = _nextIncident(frame.meters);
    if (incident != null) return _start(() => _announce(incident));
    _broadcasts.removeWhere((t) => now.difference(t) >= const Duration(minutes: 1));
    if (!rested || _broadcasts.length >= _config.maxBroadcastsPerMinute) return;
    final jams = _jamsAhead(frame.meters);
    if (jams.isNotEmpty) _start(() => _announceJams(jams));
  }

  void _start(Future<void> Function() dialog) {
    copilot.run(() async {
      await dialog();
      _quietUntil = _now.add(_config.speechGap);
    });
  }

  bool _maneuvering(double meters) =>
      _turns.any((turn) => turn - meters < _config.maneuverBefore && meters - turn < _config.maneuverAfter);

  Iterable<RoadEvent> get _onRoute => events.where((e) => e.routeIndex == _route.index);

  double _startOf(RoadEvent e) => e.fraction * _total - e.lengthMeters / 2;

  /// Kemacetan yang sudah diketahui Pulse di posisi [meters].
  RoadEvent? _jamAt(double meters) {
    for (final e in _onRoute) {
      final start = _startOf(e);
      if (e.type == IncidentType.macet && meters > start - 50 && meters < start + e.lengthMeters + 50) return e;
    }
    return null;
  }

  RoadEvent? _nextIncident(double meters) {
    for (final e in _onRoute) {
      final distance = _startOf(e) - meters;
      if (e.type != IncidentType.macet &&
          !_done.contains(e.id) &&
          distance > 0 &&
          distance <= _config.incidentLookahead) {
        return e;
      }
    }
    return null;
  }

  List<RoadEvent> _jamsAhead(double meters) => [
    for (final e in _onRoute)
      if (e.type == IncidentType.macet &&
          !_done.contains(e.id) &&
          _startOf(e) - meters > 100 &&
          _startOf(e) - meters <= _config.jamLookahead)
        e,
  ];

  // ------------------------------------------------------------- Pelaporan

  /// Lapor atas inisiatif pengguna, dari tombol mikrofon.
  Future<void> userReport() async {
    if (_frame == null) return;
    await copilot.run(() async {
      final asked = _now;
      final reply = await askWhatToReport(copilot);
      if (reply != null) await _report(reply.value, reply.utterances, asked);
      _quietUntil = _now.add(_config.speechGap);
    });
  }

  Future<void> _askJam() async {
    final asked = _now;
    final reply = await copilot.ask(
      'Di sini macet?',
      decide: decideJam,
      options: const ['Ya', 'Tidak', 'Parah'],
      again: 'Maaf, di sini macet? Ya atau tidak.',
      giveUp: 'Oke, tidak jadi.',
    );
    if (reply == null) return;
    final intent = reply.value.intent;
    if (intent == null) {
      await copilot.say('Oke.');
      return;
    }
    await _report(intent, reply.utterances, asked);
  }

  /// Memanggil tool `report_traffic`. Posisi, arah, kecepatan, ruas, dan waktu
  /// dibaca dari kendaraan saat itu, bukan dari ucapan.
  Future<void> _report(ReportIntent intent, int utterances, DateTime asked) async {
    final frame = _frame;
    if (frame == null) return;
    await send(
      TrafficCall(
        type: intent.type,
        severity: intent.severity,
        position: frame.position,
        heading: frame.bearing,
        speedKmh: frame.kmh,
        road: roadAt(_route, frame.meters),
        timestamp: _now,
        crawling: frame.speed < cruiseSpeed * _config.slowRatio,
        utterances: utterances,
        seconds: _now.difference(asked).inSeconds,
      ),
    );
    await copilot.say('Oke, dilaporkan.');
  }

  Future<void> _askStill(RoadEvent jam) async {
    final reply = await copilot.ask(
      'Masih macet?',
      decide: decideStill,
      options: const ['Ya', 'Tidak'],
      again: 'Masih macet di sini? Ya atau tidak.',
    );
    if (reply == null) return;
    await confirm(jam, reply.value);
    await copilot.say('Oke, diperbarui.');
  }

  // ---------------------------------------------------------------- Siaran

  Future<void> _announce(RoadEvent incident) async {
    _done.add(incident.id);
    _broadcasts.add(_now);
    final road = spokenRoad(incident.road);
    final distance = spokenDistance(_startOf(incident) - _frame!.meters);
    // Laporan tunggal tidak disiarkan sebagai fakta.
    await copilot.say(
      incident.verified
          ? 'Hati-hati, $distance lagi ada ${incident.type.spoken} di $road.'
          : 'Ada laporan ${incident.type.spoken} di $road, belum terverifikasi.',
    );
  }

  /// Kemacetan di depan digabung jadi satu siaran. Jika ada rute yang
  /// menghindarinya dan terhitung lebih cepat, Hoplite menawarkan pindah.
  Future<void> _announceJams(List<RoadEvent> jams) async {
    _done.addAll(jams.map((e) => e.id));
    _broadcasts.add(_now);
    final delay = jams.fold(0, (sum, e) => sum + e.delayMinutes);
    final roads = jams.map((e) => spokenRoad(e.road)).toSet().join(' dan ');
    final news = 'Di depan $roads macet sekitar $delay menit.';

    final detour = bestDetour(jams, _frame!.meters);
    if (detour == null) {
      await copilot.say(news);
      return;
    }
    final via = spokenRoad(detour.road);
    final reply = await copilot.ask(
      '$news Lewat $via lebih cepat ${detour.savedMinutes} menit. Mau pindah?',
      decide: decideYesNo,
      options: const ['Ya', 'Tidak'],
      again: 'Mau pindah rute? Ya atau tidak.',
    );
    // Tidak ada jawaban dianggap tidak.
    if (reply == null) return;
    if (!reply.value) {
      await copilot.say('Oke, tetap di rute ini.');
    } else if (_frame!.meters > detour.splitMeters - 30) {
      await copilot.say('Persimpangannya sudah lewat, tetap di rute ini.');
    } else {
      _route = detour.route;
      _readTurns();
      onReroute(detour.route);
      await copilot.say('Oke, pindah lewat $via.');
    }
  }

  double _minutesLeft(RouteOption route, double meters) =>
      minutesOf(route) * (1 - meters / route.sampler.totalMeters).clamp(0.0, 1.0);

  /// Rute lain yang berpisah sebelum kemacetan, masih sempat diambil, dan
  /// menghemat waktu paling banyak dibanding bertahan di rute sekarang.
  Detour? bestDetour(List<RoadEvent> jams, double meters) {
    final delay = jams.fold(0, (sum, e) => sum + e.delayMinutes);
    Detour? best;
    for (final other in routes) {
      if (other.index == _route.index) continue;
      final split = _route.sampler.sharedPrefixMeters(other.sampler);
      if (split - meters < _config.decisionMeters || jams.any((e) => _startOf(e) < split)) continue;
      final saved = (_minutesLeft(_route, meters) + delay - _minutesLeft(other, meters)).round();
      if (saved < _config.minSavingMinutes || (best != null && saved <= best.savedMinutes)) continue;
      // Dinamai dari jalan pertama setelah berpisah yang bukan jalan macet itu sendiri.
      final after = other.intersections.where((x) => x.fraction * other.sampler.totalMeters > split + 100);
      final roads = after.expand((x) => x.roads).where((road) => jams.every((e) => e.road != road));
      best = Detour(other, roads.isEmpty ? roadAt(other, split + 100) : roads.first, split, saved);
    }
    return best;
  }
}
