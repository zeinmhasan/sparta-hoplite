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

## Status per 2026-10-08

Semua layar sudah jadi dan disetujui pengguna sampai revisi navigasi 3D (kendaraan mobil/motor 3D,
tiang lampu 3D, gedung 3D transparan saat diperbesar, tombol zoom).

Belum diuji di perangkat:

- Navigasi 3D: gestur dua jari, tombol `-`, tombol 2D/3D, Pusatkan, lembar lampu, tombol tutup,
  cadangan 12 detik ke `/navigate-2d`, dan berhenti penuh di lampu merah.
- Navigasi cadangan (`navigation_screen.dart`) setelah dirapikan memakai `nav_sim.dart` dan `nav_widgets.dart`.
- Build release di HP sungguhan. `SPARTA-Hoplite-v1.0.0.apk` (di root repo, hasil `flutter build apk --release`
  per 2026-10-08) baru dicoba di emulator: beranda, rute, dan navigasi 3D jalan. Bangun ulang jika kode berubah.

Belum diputuskan pengguna:

- Tombol tengah navigasi bawah membuka Pulse Report (alternatifnya Panic Button).
- Nilai hex warna masih perkiraan dari gambar, belum dari Figma.
- Backend TypeScript (Hono) bersifat opsional dan belum dibuat.
