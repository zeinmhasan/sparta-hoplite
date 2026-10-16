# SPARTA Hoplite (build demo)

Prototipe interaktif aplikasi mobile SPARTA Hoplite. ETA, kepadatan, lampu lalu
lintas, bus, dan laporan adalah simulasi di dalam aplikasi
(`lib/data/mock_data.dart`); tidak ada backend, ATCS, atau GPS sungguhan.

Tiga hal memakai layanan terbuka berbasis OpenStreetMap, semuanya tanpa API key
dan butuh internet (`lib/data/live_routing.dart`, `lib/core/map_view.dart`):
ubin peta, pencarian tempat saat mengetik (Photon), dan geometri rute ke tempat
di luar daftar populer (OSRM).

Navigasi layar penuh memakai mesin peta vektor MapLibre dengan gaya OpenFreeMap
(juga tanpa API key): gedung 3D saat diperbesar, serta mobil, motor, dan tiang
lampu lalu lintas yang disusun dari balok 3D (`lib/features/route/nav_models3d.dart`).
Jika peta vektor gagal dimuat dalam 12 detik, layar menawarkan navigasi standar
di atas peta ubin (`navigation_screen.dart`), yang juga dipakai di web.

## Voice Co-Pilot

Revisi dari pelaporan lewat layar: Hoplite berbicara dan mendengarkan, jadi melapor
cukup dengan satu jawaban pendek. Kodenya di `lib/features/voice/`.

- Selama navigasi Hoplite bertanya duluan ("Di sini macet?") saat laju turun di bawah
  setengah kecepatan normal ruas selama 4 detik. Perlambatan karena lampu merah tidak dihitung.
- Jawaban "ya", "tidak", "parah", atau nama kejadian (macet, kecelakaan, banjir, jalan
  ditutup) dipahami dengan aturan kata di `intent.dart`, termasuk ucapan sehari-hari dan
  Suroboyoan. Jawaban tidak jelas ditanya ulang satu kali, lalu batal tanpa laporan.
- Laporan dikirim sebagai tool call `report_traffic`. Jawaban hanya mengisi `type` dan
  `severity`; posisi, arah, kecepatan, ruas, dan waktu diisi dari kendaraan.
- Mode Siaran: kecelakaan, banjir, dan penutupan di rute depan disiarkan segera; kemacetan
  digabung dan dibatasi 2 siaran per menit; kejadian di luar rute dilewati. Hoplite diam
  di sekitar belokan.
- Saran rute alternatif selalu menyebut selisih menit, dan hanya ditawarkan selama
  persimpangannya masih di depan. Tanpa jawaban berarti tetap di rute.
- Tombol speaker di layar navigasi mematikan mode suara seketika. Tombol mikrofon besar
  (navigasi dan tab Pulse Report) memulai laporan atas inisiatif pengguna.
- Layar hanya pelengkap: teks ucapan dan pilihan jawaban yang bisa diketuk, untuk tempat
  bising atau perangkat tanpa pengenal suara.

Suara memakai TTS dan pengenal suara bawaan perangkat (`flutter_tts`, `speech_to_text`,
bahasa Indonesia), tanpa API key. Ambang dan batasnya ada di `VoiceConfig`
(`lib/features/voice/copilot.dart`).

Belum dibuat, dan alasannya:

- Wake word. Mesin on-device yang disarankan PRD (`porcupine_flutter`) butuh access key,
  sedangkan proyek ini tanpa API key. Aktivasi sekarang lewat tombol.
- LLM cadangan untuk jawaban tak terduga (butuh API key). Saat ini hanya aturan kata.
- Mode pejalan kaki, GPS sungguhan (`geolocator`), layanan latar belakang, antrean
  laporan saat sinyal lemah, dan backend Pulse.

## Menjalankan

```
flutter pub get
flutter emulators --launch Medium_Phone
flutter run
```

Untuk demo, pakai build release agar animasi halus:

```
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Struktur

- `lib/core/` tema, router, navigasi bawah, peta, widget bersama
- `lib/data/` model, data mock, repository, state (Riverpod)
- `lib/features/` satu folder per fitur: home, route, transit, pulse, voice, panic, notifications, profile, splash
- `tool/gen_routes.mjs` mengambil geometri rute dan nama simpang dari OSRM lalu
  menulis `lib/data/route_geometry.dart`. Jalankan ulang hanya jika tujuan berubah.

## Yang disimulasikan

- Prediksi kemacetan: delapan set data tetap per rute (profil lengang sampai puncak). Hari dan jam
  berangkat (hari ini sampai 6 hari ke depan) dipetakan ke profil itu oleh `trafficProfile`: puncak
  07.00 dan 17.00 di hari kerja, salat Jumat siang, malam minggu, Car Free Day Minggu pagi.
- Navigasi: kendaraan melaju di rute dengan kecepatan simulasi (ditampilkan 50 km/jam),
  melambat atau berhenti mengikuti siklus lampu simpang berikutnya.
- Lampu lalu lintas: siklus tetap yang dihitung dari jam perangkat.
- Suroboyo Bus: tiga bus berputar di koridor tiap 5 menit.
- Transit Assistant: jawaban tetap berdasarkan kata kunci.
- Pulse Report: foto contoh; status laporan maju sendiri pada detik ke-8, 18, dan 30.
- Voice Co-Pilot: kejadian di jalan berasal dari `tripScenario` di `mock_data.dart`, bukan dari
  Pulse/Ephor. Tiap perjalanan punya kemacetan tak terlapor 200 m setelah berangkat, kemacetan
  10 menit di ruas terpadat setelah rute lain berpisah, genangan menjelang tujuan, dan satu
  kejadian di luar rute. Verifikasi laporan juga simulasi: laporan macet saat kendaraan merayap
  langsung dianggap cocok dengan data kecepatan, laporan lain "dikonfirmasi 3 pengguna" setelah
  20 detik. Angka pembanding formulir pada dua laporan contoh adalah angka contoh.
- Panic Button: tidak ada panggilan atau sinyal yang benar-benar dikirim.
