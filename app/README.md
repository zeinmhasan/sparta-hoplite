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
- `lib/features/` satu folder per fitur: home, route, transit, pulse, panic, notifications, profile, splash
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
- Pulse Report: foto contoh; status laporan maju sendiri pada detik ke-8, 18, dan 30.
- Panic Button: tidak ada panggilan atau sinyal yang benar-benar dikirim.
