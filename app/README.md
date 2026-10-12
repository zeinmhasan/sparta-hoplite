# SPARTA Hoplite (build demo)

Prototipe interaktif aplikasi mobile SPARTA Hoplite. ETA, kepadatan, lampu lalu
lintas, bus, dan laporan adalah simulasi di dalam aplikasi
(`lib/data/mock_data.dart`); tidak ada backend, ATCS, atau GPS sungguhan.

Tiga hal memakai layanan terbuka berbasis OpenStreetMap, semuanya tanpa API key
dan butuh internet (`lib/data/live_routing.dart`, `lib/core/map_view.dart`):
ubin peta, pencarian tempat saat mengetik dan nama jalan dari GPS (Photon), dan
geometri rute ke tempat di luar daftar populer (OSRM).

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
- Tombol speaker di layar navigasi mematikan mode suara seketika. Tombol mikrofon di layar
  navigasi memulai laporan atas inisiatif pengguna; selama mengemudi laporan cukup suara.
- Layar hanya pelengkap: teks ucapan dan pilihan jawaban yang bisa diketuk, untuk tempat
  bising atau perangkat tanpa pengenal suara.

### Pulse Report: satu cara melapor

Tab tengah hanya punya satu alur (`lib/features/pulse/pulse_screen.dart`):

1. Ketuk mikrofon dan sebutkan kejadiannya ("ada kecelakaan", "macet parah").
2. "AI" mengklasifikasi jenis dan keparahan, lengkap dengan angka keyakinan. Ini gimik:
   hasilnya dari aturan kata `intent.dart`, angkanya dari `classifierConfidence`.
3. Kamera di dalam aplikasi langsung terbuka (`evidence_camera_screen.dart`, paket `camera`).
   Foto bukti wajib: kamera ditutup tanpa foto berarti laporan belum terkirim.
4. Setelah memotret, laporan langsung terkirim. Lokasi diisi dari GPS sungguhan
   (`lib/data/device_location.dart`, paket `geolocator`) dan nama jalannya dari Photon;
   tanpa GPS, lokasi diganti titik asal demo (Keputih).

Formulir lapor dengan foto dan perbandingan suara dengan formulir sudah dihapus. Lokasi
dicari saat tab dibuka, bukan saat pengguna bicara, supaya dialog izin lokasi tidak memotong
dialog suara.

Suara memakai TTS dan pengenal suara bawaan perangkat (`flutter_tts`, `speech_to_text`,
bahasa Indonesia), tanpa API key. Ambang dan batasnya ada di `VoiceConfig`
(`lib/features/voice/copilot.dart`).

Belum dibuat, dan alasannya:

- Wake word. Mesin on-device yang disarankan PRD (`porcupine_flutter`) butuh access key,
  sedangkan proyek ini tanpa API key. Aktivasi sekarang lewat tombol.
- LLM cadangan untuk jawaban tak terduga (butuh API key). Saat ini hanya aturan kata.
- Mode pejalan kaki, GPS sungguhan selama navigasi, layanan latar belakang, antrean
  laporan saat sinyal lemah, dan backend Pulse.

## Laporan Warga dan Saldo Pulse

Revisi dari dosen: laporan warga juga terlihat oleh sesama pengguna, dan pelapor aktif
mendapat saldo untuk layanan milik Pemkot Surabaya.

- **Laporan Warga** (tab kedua di Pulse Report, kartu di Home, `lib/features/community/`):
  peta sebaran, saringan jenis, dan kartu bergambar berisi jenis, lokasi, jarak, waktu,
  pelapor beserta jenjangnya, dan jumlah konfirmasi. Laporan bergambar milik pengguna ikut
  tampil sebagai "Kamu". Detail laporan memuat konfirmasi warga ("Masih ada" / "Sudah aman")
  dan tindak lanjut instansi (Dishub, DSDABM, DLH, Command Center 112). Laporan yang menunggu
  terverifikasi setelah 3 warga mengonfirmasi.
- **Saldo Pulse** (`lib/features/rewards/`, `/rewards`): laporan terverifikasi +Rp2.500,
  konfirmasi laporan warga +Rp500, bonus 5 laporan terverifikasi seminggu +Rp10.000.
  Jenjang pelapor: Warga Peduli (0), Pengawas Jalan (10), Garda Kota (30 laporan terverifikasi).
  Notifikasi saldo masuk muncul di mana pun saat laporan terverifikasi (`main.dart`).
- **Tukar saldo**: voucher QR (`qr_flutter`) sekali pakai untuk layanan Pemkot Surabaya.
  Harga mengikuti tarif umum hasil riset (Oktober 2026):

  | Layanan | Pengelola | Harga |
  | --- | --- | --- |
  | Suroboyo Bus | Dishub Kota Surabaya | Rp5.000 |
  | Wira Wiri Suroboyo (11 rute feeder) | Dishub Kota Surabaya | Rp5.000 |
  | Bus SSCT (city tour) | Pemkot Surabaya | Rp10.000 |
  | Parkir tepi jalan (potongan) | Dishub Kota Surabaya | Rp5.000 |
  | Kebun Binatang Surabaya | PD Taman Satwa KBS | Rp15.000 |
  | Museum Sepuluh Nopember | Kawasan Tugu Pahlawan | Rp8.000 |
  | Taman Hiburan Pantai Kenjeran | Pemkot Surabaya | Rp10.000 |

  Harga SSCT dan THP Kenjeran berasal dari berita lama; periksa ulang di
  tiketwisata.surabaya.go.id bila perlu angka pasti.

Teks di layar ditulis seperti aplikasi yang sudah rilis: tidak ada kata "demo" atau
"simulasi". Detail laporan menampilkan "Data laporan" yang mudah dibaca, bukan JSON tool call.

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
- `lib/features/` satu folder per fitur: home, route, transit, pulse, voice, community, rewards, panic,
  notifications, profile, splash
- `tool/gen_routes.mjs` mengambil geometri rute dan nama simpang dari OSRM lalu
  menulis `lib/data/route_geometry.dart`. Jalankan ulang hanya jika tujuan berubah.

## Yang disimulasikan

- Prediksi kemacetan: delapan set data tetap per rute, satu per jam berangkat
  (Sekarang, 30 menit, 1 sampai 6 jam). Puncaknya dibuat sekitar 2 jam dari sekarang.
- Navigasi: kendaraan melaju di rute dengan kecepatan simulasi (ditampilkan 50 km/jam),
  melambat atau berhenti mengikuti siklus lampu simpang berikutnya.
- Lampu lalu lintas: siklus tetap yang dihitung dari jam perangkat.
- Suroboyo Bus: tiga bus berputar di koridor tiap 5 menit.
- Transit Assistant: jawaban tetap berdasarkan kata kunci.
- Pulse Report: mikrofon, kamera, dan GPS sungguhan; klasifikasi AI dan pengirimannya simulasi.
  Status laporan maju sendiri pada detik ke-8, 18, dan 30. Foto bukti hanya disimpan di cache
  perangkat selama aplikasi berjalan.
- Voice Co-Pilot: kejadian di jalan berasal dari `tripScenario` di `mock_data.dart`, bukan dari
  Pulse/Ephor. Tiap perjalanan punya kemacetan tak terlapor 200 m setelah berangkat, kemacetan
  10 menit di ruas terpadat setelah rute lain berpisah, genangan menjelang tujuan, dan satu
  kejadian di luar rute. Verifikasi laporan juga simulasi: laporan macet saat kendaraan merayap
  langsung dianggap cocok dengan data kecepatan, laporan lain "dikonfirmasi 3 pengguna" setelah
  20 detik.
- Panic Button: tidak ada panggilan atau sinyal yang benar-benar dikirim.
- Laporan Warga: enam laporan warga lain di `citizenReports` (`mock_data.dart`), waktunya relatif
  terhadap saat aplikasi dibuka. Konfirmasi hanya tersimpan selama aplikasi berjalan.
- Saldo Pulse: riwayat awal di `seedWallet`, saldo awal Rp15.500. Voucher QR tidak terhubung ke
  validator mana pun.

## Kredit foto

Foto laporan warga di `assets/images/reports/` dari Wikimedia Commons:

- `macet.jpg`: Dede2008, CC BY-SA 4.0, "Traffic jam in Duren Tiga bus stop, Jakarta, August 2024"
- `banjir.jpg`: VOA Indonesian Service, domain publik, "A car tries to drive through Jakarta's flooded streets"
- `kecelakaan.jpg`: Shuets Udono, CC BY-SA 2.0, "Japanese car accident"
- `pohon.jpg`: Vauxford, CC BY-SA 4.0, "Fallen Tree in Dormer Place, Leamington Spa (1)"
- `ambles.jpg`: Jack Merridew, domain publik, "Ubud-Jalan Raya-Pothole-2009"
- `kerumunan.jpg`: Hariadhi, CC BY-SA 4.0, "Kemacetan di pertigaan Jalan Gatot Subroto dan Pejompongan Raya"
