import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'intent.dart';
import 'voice_engine.dart';

/// Ambang dan batas co-pilot suara. Nilainya disetel untuk simulasi demo, yang
/// berjalan beberapa kali lebih cepat dari perjalanan sungguhan; nilai lapangan
/// ditetapkan saat uji (PRD, pertanyaan terbuka 3).
class VoiceConfig {
  const VoiceConfig({
    this.slowRatio = 0.5,
    this.slowSeconds = 4,
    this.questionCooldown = const Duration(seconds: 45),
    this.listenFor = const Duration(seconds: 6),
    this.maxBroadcastsPerMinute = 2,
    this.speechGap = const Duration(seconds: 8),
    this.startQuiet = const Duration(seconds: 15),
    this.incidentLookahead = 1500,
    this.jamLookahead = 5000,
    this.decisionMeters = 500,
    this.minSavingMinutes = 2,
    this.maneuverBefore = 180,
    this.maneuverAfter = 60,
  });

  /// Hoplite bertanya jika kecepatan di bawah [slowRatio] kali kecepatan normal
  /// ruas selama [slowSeconds] detik.
  final double slowRatio;
  final double slowSeconds;

  /// Jeda minimal antara dua pertanyaan proaktif.
  final Duration questionCooldown;
  final Duration listenFor;

  final int maxBroadcastsPerMinute;

  /// Hening minimal setelah Hoplite selesai bicara.
  final Duration speechGap;

  /// Tidak ada siaran selama ini sejak navigasi dimulai.
  final Duration startQuiet;

  /// Jarak (meter) di depan untuk menyiarkan kejadian P1 dan kemacetan.
  final double incidentLookahead;
  final double jamLookahead;

  /// Rute alternatif hanya ditawarkan jika persimpangannya masih sejauh ini,
  /// supaya ada waktu mendengar dan menjawab.
  final double decisionMeters;
  final int minSavingMinutes;

  /// Hoplite diam dari [maneuverBefore] meter sebelum belokan sampai
  /// [maneuverAfter] meter sesudahnya.
  final double maneuverBefore;
  final double maneuverAfter;
}

enum VoicePhase { idle, speaking, listening }

/// Jawaban yang dipahami, beserta jumlah ucapan pengguna sampai dipahami.
class Answered<A> {
  const Answered(this.value, this.utterances);
  final A value;
  final int utterances;
}

/// Pengatur giliran bicara: Hoplite berbicara, lalu mendengarkan satu jawaban
/// pendek. Mikrofon baru dibuka setelah TTS selesai, jadi suara Hoplite sendiri
/// tidak pernah terbaca sebagai jawaban.
class VoiceCopilot extends ChangeNotifier {
  VoiceCopilot(this.engine, {this.config = const VoiceConfig()});

  final VoiceEngine engine;
  final VoiceConfig config;

  VoicePhase _phase = VoicePhase.idle;
  String _caption = '';
  String _heard = '';
  List<String> _options = const [];
  bool _enabled = true;
  bool _proactive = true;
  bool _broadcast = true;
  bool _busy = false;
  String? _tapped;

  /// Bertambah tiap mode suara dimatikan; dialog yang sedang berjalan berhenti.
  int _generation = 0;

  VoicePhase get phase => _phase;

  /// Kalimat yang sedang diucapkan atau baru ditanyakan.
  String get caption => _caption;

  /// Ucapan pengguna yang sedang dikenali.
  String get heard => _heard;

  /// Jawaban yang juga bisa diketuk, untuk tempat bising atau tanpa mikrofon.
  List<String> get options => _options;
  bool get busy => _busy;

  bool get enabled => _enabled;
  bool get proactive => _proactive;
  bool get broadcast => _broadcast;

  /// Tombol darurat: mematikan mode suara dan menghentikan ucapan saat itu juga.
  set enabled(bool value) {
    if (value == _enabled) return;
    _enabled = value;
    if (!value) cancel();
    notifyListeners();
  }

  set proactive(bool value) {
    _proactive = value;
    notifyListeners();
  }

  set broadcast(bool value) {
    _broadcast = value;
    notifyListeners();
  }

  /// Menghentikan dialog yang sedang berjalan, mis. saat layar ditutup.
  void cancel() {
    _generation++;
    _tapped = null;
    engine.stop();
    _show(VoicePhase.idle);
  }

  void _show(VoicePhase phase, {String caption = '', List<String> options = const [], String heard = ''}) {
    _phase = phase;
    _caption = caption;
    _options = options;
    _heard = heard;
    notifyListeners();
  }

  /// Menjalankan satu dialog. Mengembalikan null tanpa menjalankannya jika mode
  /// suara mati atau dialog lain masih berlangsung.
  Future<T?> run<T>(Future<T?> Function() dialog) async {
    if (!_enabled || _busy) return null;
    _busy = true;
    final generation = _generation;
    try {
      return await dialog();
    } finally {
      _busy = false;
      if (generation == _generation) _show(VoicePhase.idle);
    }
  }

  /// Mengucapkan [text]. False jika mode suara dimatikan sebelum selesai.
  Future<bool> say(String text) async {
    if (!_enabled) return false;
    final generation = _generation;
    _show(VoicePhase.speaking, caption: text);
    await engine.speak(text);
    return generation == _generation;
  }

  /// Bertanya lalu mendengarkan. Jawaban yang tidak dipahami [decide] ditanya
  /// ulang satu kali dengan [again]; setelah itu dialog dibatalkan dengan
  /// ucapan [giveUp]. Diam dianggap tidak menjawab dan tidak ditanya ulang.
  Future<Answered<A>?> ask<A>(
    String question, {
    required A? Function(VoiceAnswer answer) decide,
    required List<String> options,
    required String again,
    String? giveUp,
  }) async {
    final generation = _generation;
    for (var attempt = 1; attempt <= 2; attempt++) {
      final prompt = attempt == 1 ? question : again;
      if (!await say(prompt)) return null;
      _tapped = null;
      _show(VoicePhase.listening, caption: prompt, options: options);
      final spoken = await engine.listen(
        timeout: config.listenFor,
        onPartial: (partial) {
          if (generation == _generation && _phase == VoicePhase.listening) {
            _show(VoicePhase.listening, caption: prompt, options: options, heard: partial);
          }
        },
      );
      if (generation != _generation) return null;
      final heard = _tapped ?? spoken;
      _tapped = null;
      if (heard == null) return null;
      final value = decide(parseAnswer(heard));
      if (value != null) return Answered(value, attempt);
    }
    if (giveUp != null) await say(giveUp);
    return null;
  }

  /// Jawaban lewat ketukan pada salah satu [options].
  void answer(String text) {
    if (_phase != VoicePhase.listening) return;
    _tapped = text;
    engine.stop();
  }

  @override
  void dispose() {
    _generation++;
    engine.stop();
    super.dispose();
  }
}

/// Dialog lapor atas inisiatif pengguna (tombol mikrofon). Null jika batal.
Future<Answered<ReportIntent>?> askWhatToReport(VoiceCopilot copilot) async {
  final reply = await copilot.ask(
    'Lapor apa?',
    decide: decideOpen,
    options: const ['Macet', 'Kecelakaan', 'Banjir', 'Jalan ditutup'],
    again: 'Macet, kecelakaan, banjir, atau jalan ditutup?',
    giveUp: 'Oke, tidak jadi.',
  );
  final intent = reply?.value.intent;
  if (reply == null) return null;
  if (intent == null) {
    await copilot.say('Oke, tidak jadi.');
    return null;
  }
  return Answered(intent, reply.utterances);
}

final voiceEngineProvider = Provider<VoiceEngine>((ref) => DeviceVoiceEngine());

final copilotProvider = ChangeNotifierProvider<VoiceCopilot>((ref) => VoiceCopilot(ref.watch(voiceEngineProvider)));
