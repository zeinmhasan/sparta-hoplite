import '../../data/models.dart';

// Lapisan pemahaman jawaban berbasis aturan. Jawaban dirancang satu-dua kata,
// jadi daftar kata sudah menangani hampir semuanya tanpa biaya dan jeda LLM.
// Jawaban yang tidak cocok dikembalikan kosong; pemanggil bertanya ulang sekali.
// LLM kecil sebagai cadangan (PRD bagian 7) belum dipasang karena butuh API key.

/// Isi satu jawaban: setuju atau tidak, jenis kejadian, dan tingkat keparahan.
/// Bagian yang tidak disebut bernilai null.
class VoiceAnswer {
  const VoiceAnswer({this.confirm, this.type, this.severity});
  final bool? confirm;
  final IncidentType? type;
  final Severity? severity;
}

class ReportIntent {
  const ReportIntent(this.type, this.severity);
  final IncidentType type;
  final Severity severity;
}

/// Keputusan dari jawaban atas pertanyaan lapor: melapor, atau tidak jadi
/// ([intent] null).
class ReportDecision {
  const ReportDecision(this.intent);
  final ReportIntent? intent;
}

// Frasa berkata sangkal yang justru berarti parah, tertutup, atau masih macet.
const _stuckPhrases = ['tidak bergerak', 'tidak gerak', 'nggak gerak', 'gak gerak', 'tidak jalan', 'gak jalan'];
const _blockedPhrases = ['tidak bisa lewat', 'nggak bisa lewat', 'gak bisa lewat', 'tidak bisa dilewati'];
const _stillPhrases = ['belum lancar', 'belum jalan', 'belum bisa'];

// Termasuk ucapan Suroboyoan: "iyo", "yo", "nggih", "gak", "ora", "mboten".
const _yes = {
  'ya', 'iya', 'iyo', 'yo', 'yoi', 'yap', 'yes', 'betul', 'benar', 'bener', 'oke', 'ok', 'okay', 'boleh', //
  'mau', 'pindah', 'setuju', 'masih', 'nggih', 'inggih', 'lanjut', 'gas',
};
const _no = {
  'tidak', 'nggak', 'enggak', 'ngga', 'gak', 'ga', 'tak', 'ndak', 'bukan', 'belum', 'jangan', 'batal', //
  'lancar', 'ora', 'mboten', 'no', 'sudah',
};

const _parah = {'parah', 'banget', 'total', 'berat', 'panjang', 'stuck', 'sekali'};
const _sedang = {'sedang', 'lumayan', 'merayap'};
const _ringan = {'ringan', 'sedikit', 'dikit', 'agak', 'kecil'};

// Penyebab didahulukan dari gejala: "macet karena kecelakaan" dilaporkan sebagai kecelakaan.
const _types = {
  IncidentType.kecelakaan: {'kecelakaan', 'tabrakan', 'tabrak', 'nabrak', 'tertabrak', 'laka', 'terguling'},
  IncidentType.banjir: {'banjir', 'kebanjiran', 'genangan', 'tergenang'},
  IncidentType.jalanDitutup: {'ditutup', 'tutup', 'tertutup', 'penutupan', 'dialihkan', 'pengalihan'},
  IncidentType.lainnya: {'tumbang', 'lubang', 'berlubang', 'rusak', 'mogok', 'perbaikan', 'galian', 'demo'},
  IncidentType.macet: {'macet', 'padat', 'merayap', 'antre', 'antri', 'tersendat', 'ramai'},
};

VoiceAnswer parseAnswer(String heard) {
  var text = heard.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Menghapus frasa dari [text] dan melaporkan apakah ada yang ditemukan.
  bool take(List<String> phrases) {
    var found = false;
    for (final phrase in phrases) {
      if (text.contains(phrase)) {
        text = text.replaceAll(phrase, ' ');
        found = true;
      }
    }
    return found;
  }

  final stuck = take(_stuckPhrases);
  final blocked = take(_blockedPhrases);
  final still = take(_stillPhrases);
  final words = text.split(' ').toSet();
  bool any(Set<String> list) => words.any(list.contains);

  IncidentType? type = blocked ? IncidentType.jalanDitutup : null;
  for (final entry in _types.entries) {
    if (type == null && any(entry.value)) type = entry.key;
  }
  final severity = stuck || any(_parah)
      ? Severity.parah
      : (any(_ringan) ? Severity.ringan : (any(_sedang) ? Severity.sedang : null));
  final confirm = any(_no) ? false : (still || any(_yes) ? true : null);
  return VoiceAnswer(confirm: confirm, type: type, severity: severity);
}

/// Jawaban atas "Di sini macet?". "Ya" dan "parah" melaporkan macet; menyebut
/// kejadian lain melaporkan kejadian itu, walau diawali "tidak".
ReportDecision? decideJam(VoiceAnswer a) {
  final type = a.type;
  if (type != null && type != IncidentType.macet) {
    return ReportDecision(ReportIntent(type, a.severity ?? Severity.sedang));
  }
  if (a.confirm == false) return const ReportDecision(null);
  if (type == null && a.severity == null && a.confirm == null) return null;
  return ReportDecision(ReportIntent(IncidentType.macet, a.severity ?? Severity.sedang));
}

/// Jawaban atas "Lapor apa?". Di sini "ya" saja belum cukup untuk melapor.
ReportDecision? decideOpen(VoiceAnswer a) {
  final type = a.type;
  if (type != null && !(type == IncidentType.macet && a.confirm == false)) {
    return ReportDecision(ReportIntent(type, a.severity ?? Severity.sedang));
  }
  if (a.confirm == false) return const ReportDecision(null);
  if (a.severity != null) return ReportDecision(ReportIntent(IncidentType.macet, a.severity!));
  return null;
}

/// Jawaban ya/tidak, mis. atas tawaran pindah rute.
bool? decideYesNo(VoiceAnswer a) => a.confirm;

/// Jawaban atas "Masih macet?": "parah" atau "macet" saja juga berarti masih.
bool? decideStill(VoiceAnswer a) => a.confirm ?? (a.severity != null || a.type == IncidentType.macet ? true : null);
