import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Suara masuk dan keluar perangkat. Dipisah dari logika co-pilot supaya dialog
/// bisa diuji tanpa mikrofon dan speaker.
abstract class VoiceEngine {
  /// Menyiapkan TTS dan meminta izin mikrofon. Aman dipanggil berulang.
  Future<void> prepare();

  /// False jika pengenal suara tidak ada atau izin mikrofon ditolak; jawaban
  /// lalu hanya bisa lewat tombol di layar.
  bool get canListen;

  /// Selesai saat kalimat habis diucapkan atau dihentikan.
  Future<void> speak(String text);

  /// Mendengarkan satu jawaban. Null jika tidak ada ucapan sampai [timeout]
  /// atau dihentikan lewat [stop].
  Future<String?> listen({required Duration timeout, void Function(String partial)? onPartial});

  /// Menghentikan ucapan dan pendengaran yang sedang berjalan.
  Future<void> stop();
}

/// TTS dan pengenal suara bawaan perangkat, bahasa Indonesia, tanpa API key.
/// Rekaman tidak disimpan: yang keluar dari sini hanya teks hasil pengenalan.
class DeviceVoiceEngine implements VoiceEngine {
  final _tts = FlutterTts();
  final _stt = SpeechToText();
  Future<void>? _preparing;
  bool _canListen = false;
  Completer<String?>? _hearing;
  Completer<void>? _muted;

  @override
  bool get canListen => _canListen;

  @override
  Future<void> prepare() => _preparing ??= _prepare();

  Future<void> _prepare() async {
    try {
      await _tts.setLanguage('id-ID');
      await _tts.setSpeechRate(0.52);
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {
      // Tanpa mesin TTS, pertanyaan tetap tampil sebagai teks di layar.
    }
    try {
      _canListen = await _stt.initialize(
        onStatus: (status) {
          if (status == SpeechToText.doneStatus) _finish();
        },
        onError: (_) => _finish(),
      );
    } catch (_) {
      _canListen = false;
    }
  }

  String _heard = '';

  void _finish() {
    final hearing = _hearing;
    if (hearing != null && !hearing.isCompleted) hearing.complete(_heard.isEmpty ? null : _heard);
  }

  @override
  Future<void> speak(String text) async {
    await prepare();
    final muted = _muted = Completer<void>();
    final clock = Stopwatch()..start();
    try {
      await _tts.speak(text).timeout(const Duration(seconds: 20));
    } catch (_) {
      // Lihat _prepare: gagal bicara tidak boleh memutus dialog.
    }
    // Perangkat tanpa mesin TTS langsung kembali. Beri waktu membaca teksnya di
    // layar, kecuali memang dihentikan lewat [stop].
    if (clock.elapsedMilliseconds < 400 && !muted.isCompleted) {
      await Future.any([muted.future, Future<void>.delayed(Duration(milliseconds: 900 + text.length * 45))]);
    }
  }

  @override
  Future<String?> listen({required Duration timeout, void Function(String partial)? onPartial}) async {
    await prepare();
    final hearing = _hearing = Completer<String?>();
    _heard = '';
    // Batas waktu juga berlaku tanpa pengenal suara, supaya pertanyaan tidak menggantung.
    final guard = Timer(timeout + const Duration(seconds: 1), _finish);
    if (_canListen) {
      try {
        await _stt.listen(
          onResult: (SpeechRecognitionResult result) {
            _heard = result.recognizedWords;
            onPartial?.call(_heard);
            if (result.finalResult) _finish();
          },
          listenOptions: SpeechListenOptions(
            localeId: 'id_ID',
            listenFor: timeout,
            pauseFor: const Duration(seconds: 3),
            partialResults: true,
            cancelOnError: true,
          ),
        );
      } catch (_) {
        _finish();
      }
    }
    final heard = await hearing.future;
    guard.cancel();
    if (_stt.isListening) await _stt.stop();
    return heard;
  }

  @override
  Future<void> stop() async {
    _heard = '';
    _finish();
    final muted = _muted;
    if (muted != null && !muted.isCompleted) muted.complete();
    try {
      await _tts.stop();
      if (_canListen) await _stt.cancel();
    } catch (_) {
      // Tidak ada yang sedang berjalan.
    }
  }
}
