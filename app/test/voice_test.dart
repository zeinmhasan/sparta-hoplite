import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:sparta_hoplite/data/mock_data.dart' as mock;
import 'package:sparta_hoplite/data/models.dart';
import 'package:sparta_hoplite/features/route/nav_sim.dart';
import 'package:sparta_hoplite/features/voice/copilot.dart';
import 'package:sparta_hoplite/features/voice/intent.dart';
import 'package:sparta_hoplite/features/voice/trip_copilot.dart';
import 'package:sparta_hoplite/features/voice/voice_engine.dart';

/// Mesin suara tiruan: mencatat ucapan Hoplite dan menjawab dari antrean.
/// Jawaban null berarti pengguna diam.
class FakeEngine implements VoiceEngine {
  FakeEngine([List<String?> answers = const []]) : answers = Queue.of(answers);
  final Queue<String?> answers;
  final spoken = <String>[];

  @override
  bool get canListen => true;

  @override
  Future<void> prepare() async {}

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<String?> listen({required Duration timeout, void Function(String partial)? onPartial}) async =>
      answers.isEmpty ? null : answers.removeFirst();

  @override
  Future<void> stop() async {}
}

/// Satu perjalanan simulasi ke Tunjungan Plaza lewat rute [routeIndex].
class Drive {
  Drive(List<String?> answers, {int routeIndex = 0}) : engine = FakeEngine(answers) {
    final routes = mock.buildRoutes('tp')!;
    final route = routes[routeIndex];
    final scenario = mock.tripScenario(routes, route, Horizon.now);
    copilot = VoiceCopilot(engine);
    sim = NavSimulator(route, slowZones: scenario.slowZones(route));
    trip = TripCopilot(
      copilot: copilot,
      routes: routes,
      route: route,
      events: scenario.events,
      minutesOf: (r) => r.minutes(Horizon.now, VehicleMode.mobil),
      send: (call) async => calls.add(call),
      confirm: (event, stillThere) async => confirmations.add((event.id, stillThere)),
      onReroute: (next) {
        reroutedAt = sim.meters;
        sim.switchRoute(next, slowZones: scenario.slowZones(next));
      },
    );
  }

  final FakeEngine engine;
  late final VoiceCopilot copilot;
  late final NavSimulator sim;
  late final TripCopilot trip;
  final calls = <TrafficCall>[];
  final confirmations = <(String, bool)>[];
  double? reroutedAt;

  /// Melaju sampai tujuan dengan langkah 0,1 detik.
  Future<void> toDestination() async {
    var now = DateTime(2026, 10, 9, 8);
    for (var step = 0; step < 40000 && !sim.arrived; step++) {
      now = now.add(const Duration(milliseconds: 100));
      trip.onFrame(sim.step(0.1, now), 0.1, now);
      await null;
    }
    expect(sim.arrived, isTrue);
  }
}

void main() {
  test('jawaban pendek dan ucapan sehari-hari dipetakan ke jenis dan keparahan', () {
    ReportIntent? jam(String heard) => decideJam(parseAnswer(heard))?.intent;

    expect(jam('ya')!.severity, Severity.sedang);
    expect(jam('Iyo')!.type, IncidentType.macet);
    expect(jam('parah')!.severity, Severity.parah);
    expect(jam('macet banget')!.severity, Severity.parah);
    expect(jam('nggak gerak sama sekali')!.severity, Severity.parah);
    expect(jam('agak padat')!.severity, Severity.ringan);
    expect(jam('ada kecelakaan')!.type, IncidentType.kecelakaan);
    expect(jam('tidak, tapi banjir')!.type, IncidentType.banjir);

    // Menolak berarti tidak melapor; jawaban tak dikenal bukan keputusan.
    for (final no in ['tidak', 'gak', 'ora', 'tidak macet', 'lancar', 'tidak parah']) {
      expect(decideJam(parseAnswer(no)), isNotNull, reason: no);
      expect(jam(no), isNull, reason: no);
    }
    expect(decideJam(parseAnswer('eh sebentar')), isNull);

    ReportIntent? open(String heard) => decideOpen(parseAnswer(heard))?.intent;
    expect(open('jalan ditutup')!.type, IncidentType.jalanDitutup);
    expect(open('gak bisa lewat')!.type, IncidentType.jalanDitutup);
    expect(open('pohon tumbang')!.type, IncidentType.lainnya);
    expect(open('macet karena tabrakan')!.type, IncidentType.kecelakaan);
    expect(decideOpen(parseAnswer('ya')), isNull);

    expect(decideYesNo(parseAnswer('boleh')), isTrue);
    expect(decideYesNo(parseAnswer('nggak usah')), isFalse);
    expect(decideStill(parseAnswer('masih')), isTrue);
    expect(decideStill(parseAnswer('belum lancar')), isTrue);
    expect(decideStill(parseAnswer('sudah lancar')), isFalse);
  });

  test('perlambatan baru dihitung setelah bertahan, dan lampu merah tidak dihitung', () {
    final detector = SlowdownDetector(const VoiceConfig(slowRatio: 0.5, slowSeconds: 4));
    bool tick(double speed, {bool excused = false}) => detector.update(1, speed: speed, normal: 30, excused: excused);

    expect([tick(10), tick(10), tick(10)], everyElement(isFalse));
    expect(tick(10), isTrue);
    expect(tick(20), isFalse, reason: 'kembali di atas ambang');
    expect([for (var i = 0; i < 10; i++) tick(0, excused: true)], everyElement(isFalse));
  });

  test('jawaban tidak jelas ditanya ulang sekali lalu batal; diam langsung batal', () async {
    final unclear = FakeEngine(['hmm', 'eh sebentar', 'ya']);
    final first = await VoiceCopilot(
      unclear,
    ).ask('Di sini macet?', decide: decideJam, options: const [], again: 'Ulang?', giveUp: 'Oke, tidak jadi.');
    expect(first, isNull);
    expect(unclear.spoken, ['Di sini macet?', 'Ulang?', 'Oke, tidak jadi.']);

    final retried = FakeEngine(['hmm', 'parah']);
    final second = await VoiceCopilot(
      retried,
    ).ask('Di sini macet?', decide: decideJam, options: const [], again: 'Ulang?');
    expect(second!.utterances, 2);
    expect(second.value.intent!.severity, Severity.parah);

    final silent = FakeEngine([null]);
    expect(
      await VoiceCopilot(silent).ask('Di sini macet?', decide: decideJam, options: const [], again: 'Ulang?'),
      isNull,
    );
    expect(silent.spoken, ['Di sini macet?']);
  });

  test('ya, ya: laporan macet terkirim lalu pindah ke rute yang lebih cepat', () async {
    final drive = Drive(['ya', 'ya']);
    await drive.toDestination();

    final said = drive.engine.spoken;
    expect(said[0], 'Di sini macet?');
    expect(said[1], 'Oke, dilaporkan.');
    expect(said[2], allOf(contains('macet sekitar 10 menit'), contains('lebih cepat'), endsWith('Mau pindah?')));
    expect(said[3], startsWith('Oke, pindah lewat'));
    expect(said[4], allOf(startsWith('Hati-hati'), contains('genangan')));
    expect(said, hasLength(5));

    // Isi tool call: jawaban hanya menentukan jenis dan keparahan.
    final call = drive.calls.single;
    expect(call.type, IncidentType.macet);
    expect(call.crawling, isTrue);
    expect(call.speedKmh, lessThan(cruiseKmh * 0.5));
    final json = call.toJson();
    expect(json['parameters'], {'type': 'macet', 'severity': 'sedang'});
    expect(
      (json['auto_filled'] as Map).keys,
      containsAll(['lat', 'lng', 'heading', 'timestamp', 'road_segment_id', 'speed']),
    );

    // Pindah terjadi sebelum kedua rute berpisah, dan kejadian di luar rute tidak pernah disiarkan.
    final routes = mock.buildRoutes('tp')!;
    expect(drive.trip.route.index, 1);
    expect(drive.reroutedAt, lessThan(routes[0].sampler.sharedPrefixMeters(routes[1].sampler)));
    expect(drive.trip.announced, isNot(contains('luar-rute')));
    expect(drive.confirmations, isEmpty);
  });

  test('tidak, tidak: tanpa laporan, tetap di rute, lalu ditanya "masih macet?"', () async {
    final drive = Drive(['tidak', 'tidak', 'ya']);
    await drive.toDestination();

    expect(drive.calls, isEmpty);
    expect(drive.trip.route.index, 0);
    expect(
      drive.engine.spoken,
      containsAllInOrder(['Oke.', 'Oke, tetap di rute ini.', 'Masih macet?', 'Oke, diperbarui.']),
    );
    expect(drive.confirmations, [('macet-0', true)]);
  });

  test('tawaran rute tanpa jawaban dianggap tidak', () async {
    final drive = Drive(['ya', null]);
    await drive.toDestination();
    expect(drive.trip.route.index, 0);
    expect(drive.reroutedAt, isNull);
  });

  test('mode suara mati: Hoplite tidak berbicara sama sekali', () async {
    final drive = Drive(['ya', 'ya'])..copilot.enabled = false;
    await drive.toDestination();
    expect(drive.engine.spoken, isEmpty);
    expect(drive.calls, isEmpty);
  });

  test('siaran dibatasi per menit dan tidak menyela di sekitar belokan', () async {
    final drive = Drive([]);
    final times = <DateTime>[];
    final route = drive.sim.route;
    final total = route.sampler.totalMeters;
    final turns = [
      for (final x in route.intersections)
        if (turnAt(route, x) != Turn.straight) x.fraction * total,
    ];

    var now = DateTime(2026, 10, 9, 8);
    var heard = 0;
    while (!drive.sim.arrived) {
      now = now.add(const Duration(milliseconds: 100));
      final frame = drive.sim.step(0.1, now);
      drive.trip.onFrame(frame, 0.1, now);
      if (drive.engine.spoken.length > heard) {
        heard = drive.engine.spoken.length;
        times.add(now);
        expect(turns.where((t) => t - frame.meters < 180 && frame.meters - t < 60), isEmpty, reason: 'di belokan');
      }
      await null;
    }
    for (final t in times) {
      expect(
        times.where((other) => !other.isBefore(t) && other.difference(t).inSeconds < 60).length,
        lessThanOrEqualTo(3),
      );
    }
  });

  test('laporan tunggal belum terverifikasi sampai didukung pengguna lain atau data kecepatan', () {
    final start = DateTime(2026, 10, 9, 8);
    Report report({required bool speedConfirmed}) => Report(
      id: 'x',
      category: ReportCategory.gangguan,
      description: '',
      location: '',
      createdAt: start,
      photoCount: 0,
      priority: 'Sedang',
      speedConfirmed: speedConfirmed,
      call: TrafficCall(
        type: IncidentType.macet,
        severity: Severity.sedang,
        position: mock.origin.point,
        heading: 0,
        speedKmh: 0,
        road: 'Keputih',
        timestamp: start,
      ),
    );

    expect(report(speedConfirmed: true).trustAt(start), isNotNull);
    expect(report(speedConfirmed: false).trustAt(start), isNull);
    expect(report(speedConfirmed: false).trustAt(start.add(const Duration(seconds: 30))), isNotNull);
  });

  test('nama jalan dan jarak dibaca wajar oleh TTS', () {
    expect(spokenRoad('Dr. Ir. H. Soekarno (MERR)'), 'Jalan MERR');
    expect(spokenRoad('Jend. Basuki Rahmat'), 'Jalan Jenderal Basuki Rahmat');
    expect(spokenDistance(430), '400 meter');
    expect(spokenDistance(1040), '1 kilometer');
    expect(spokenDistance(1500), '1,5 kilometer');
  });
}
