# SPARTA Hoplite

Aplikasi mobile (Flutter) modul SPARTA, sistem lalu lintas cerdas Surabaya, untuk lomba Gemastik.
Saat ini berupa build demo: tampilan dan interaksi diutamakan, logika boleh simulasi.

Balas pengguna dalam bahasa Indonesia.

## Sumber konteks

- `konteks_sparta.txt`: penjelasan seluruh ekosistem SPARTA. Fokus kita hanya Hoplite.
- `gambar/`: referensi UI dan logo. Tema warna harus mengikuti referensi ini (`app/lib/core/theme.dart`).
- `app/README.md`: cara menjalankan, struktur folder, dan daftar bagian yang disimulasikan.
- PRD di Claude Docs: https://claude.ai/code/artifact/8cb48dc2-d569-4ae2-81cc-a00597816b93.
  Jika fitur berubah, PRD ikut diperbarui.

## Aturan kerja

- Tanpa API key. Peta ringkas memakai `flutter_map` + ubin `tile.openstreetmap.org`; navigasi memakai
  `maplibre_gl` + gaya OpenFreeMap `liberty`; pencarian memakai Photon; rute memakai OSRM.
  Jangan pakai ubin CARTO (sekarang bertanda air "API KEY REQUIRED").
- Suara memakai TTS dan pengenal suara bawaan perangkat (`flutter_tts`, `speech_to_text`). Wake word
  belum ada karena `porcupine_flutter` butuh access key; begitu juga LLM cadangan untuk jawaban tak terduga.
- `flutter_riverpod` dikunci di 2.x (StateProvider, StateNotifier). Jangan naikkan ke 3.x.
- Lebar format 120 kolom (sudah diatur di `app/analysis_options.yaml`).
- Sebelum melapor selesai: `flutter analyze` dan `flutter test` di `app/`.
- Di Git Bash, heredoc sering merusak escape. Tulis skrip ke file dulu, lalu jalankan.

## Menguji di emulator

Emulator `Medium_Phone` (`emulator-5554`, 1080x2400) hampir penuh, jadi `adb install -r` gagal dengan
INSTALL_FAILED_INSUFFICIENT_STORAGE. Urutannya:

```
flutter build apk --debug --target-platform android-x64
adb uninstall id.sparta.sparta_hoplite
adb install build/app/outputs/flutter-apk/app-debug.apk
```

Pasang ulang memutus sesi `flutter run` milik pengguna; beri tahu mereka agar menjalankan
`flutter run -d emulator-5554` lagi. `adb shell input tap` hanya satu jari, jadi gestur cubit, putar,
dan miring dua jari tidak bisa diuji otomatis.

## Status per 2026-10-10

Semua layar sudah jadi dan disetujui pengguna sampai revisi navigasi 3D (kendaraan mobil/motor 3D,
tiang lampu 3D, gedung 3D transparan saat diperbesar, tombol zoom).

Revisi Voice Co-Pilot (2026-10-10, dari `PRD-Hoplite-Revisi-Voice-Copilot.md`) sudah ditulis:

- Kode di `app/lib/features/voice/`: `intent.dart` (aturan kata untuk jawaban), `voice_engine.dart`
  (TTS dan pengenal suara perangkat), `copilot.dart` (giliran bicara, `VoiceConfig`), `trip_copilot.dart`
  (pemicu proaktif, siaran, saran rute), `voice_widgets.dart` (tombol mikrofon, panel suara, saklar).
- `app/lib/features/route/trip_session.dart` menyatukan simulator, skenario, dan co-pilot untuk kedua
  layar navigasi. `nav_sim.dart` kini punya ruas macet (`SlowZone`) dan `switchRoute`.
- Skenario kejadian per perjalanan ada di `tripScenario` (`mock_data.dart`).
- Tab Pulse Report menjadi layar suara; formulir lama pindah ke `/report-form`
  (`report_form_screen.dart`). Detail laporan suara menampilkan isi tool call `report_traffic`.
- Android: izin `RECORD_AUDIO` dan `queries` untuk pengenal suara dan TTS.
- `app/README.md` dan PRD di Claude Docs sudah memuat revisi ini.

`flutter analyze` bersih dan `flutter test` lulus (19 tes). APK release berhasil dibangun
(`app/build/app/outputs/flutter-apk/app-release.apk`, 83 MB) tetapi belum dijalankan di perangkat mana
pun; pengguna akan mencobanya di HP sendiri.

Catatan build di laptop pengguna (drive C hampir penuh, emulator menolak menyala karena disk):

- Flutter 3.38.2 ada di `E:\tools\flutter`, tidak di PATH. Pakai `PUB_CACHE=E:\tools\pub-cache` dan
  `GRADLE_USER_HOME=D:\gradle-home`.
- Flutter 3.38 meminta NDK 28.2.13676358, yang tidak muat di drive C. APK di atas dibangun dengan NDK
  27.1.12297006 yang sudah terpasang, lewat `gradlew assembleRelease -I <init script>` yang menyetel
  `android.ndkVersion` di `afterEvaluate`. File proyek tidak diubah untuk itu.

Belum diuji di perangkat:

- Voice Co-Pilot seluruhnya: suara TTS bahasa Indonesia, pengenalan jawaban, izin mikrofon, tombol
  mikrofon dan speaker, pindah rute di peta 3D, dan tata letak panel suara di layar navigasi.
- Navigasi 3D: gestur dua jari, tombol `-`, tombol 2D/3D, Pusatkan, lembar lampu, tombol tutup,
  cadangan 12 detik ke `/navigate-2d`, dan berhenti penuh di lampu merah.
- Navigasi cadangan (`navigation_screen.dart`) setelah dirapikan memakai `nav_sim.dart` dan `nav_widgets.dart`.
- Build release di HP sungguhan. `SPARTA-Hoplite-v1.0.0.apk` (di root repo, hasil `flutter build apk --release`
  per 2026-10-08) baru dicoba di emulator: beranda, rute, dan navigasi 3D jalan. Bangun ulang jika kode berubah.
  APK itu belum memuat Voice Co-Pilot.

Belum diputuskan pengguna:

- Wake word: kata kuncinya apa, dan mesinnya. Pilihan yang sudah dibahas: Porcupine (andal, butuh
  AccessKey Picovoice dan file `.ppn`, melanggar aturan tanpa API key) atau openWakeWord (tanpa key,
  tetapi alur ONNX harus ditulis sendiri di Flutter dan model kata kunci dilatih pengguna di Colab).
- Ambang pemicu proaktif (50% kecepatan normal selama 4 detik, jeda 45 detik) masih nilai simulasi.
- Tombol tengah navigasi bawah membuka Pulse Report (alternatifnya Panic Button).
- Nilai hex warna masih perkiraan dari gambar, belum dari Figma.
- Backend TypeScript (Hono) bersifat opsional dan belum dibuat.
