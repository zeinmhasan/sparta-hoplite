import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sparta_hoplite/core/geo.dart';
import 'package:sparta_hoplite/data/mock_data.dart' as mock;
import 'package:sparta_hoplite/data/models.dart';
import 'package:sparta_hoplite/data/state.dart';

void main() {
  // Senin 12 Oktober 2026: 05.00 masih lengang, 17.00 puncak jam pulang kerja.
  final quiet = Departure.at(DateTime(2026, 10, 12, 5));
  final rush = Departure.at(DateTime(2026, 10, 12, 17));
  final week = [
    for (var day = 12; day <= 18; day++)
      for (var hour = 0; hour < 24; hour++) Departure.at(DateTime(2026, 10, day, hour)),
  ];

  test('setiap tujuan punya tiga rute dengan simpang dan data per profil kepadatan', () {
    for (final place in mock.places) {
      final routes = mock.buildRoutes(place.id)!;
      expect(routes, hasLength(3), reason: place.name);
      for (final route in routes) {
        expect(route.points.length, greaterThan(10));
        expect(route.intersections, isNotEmpty);
        expect(route.minutesByProfile, hasLength(8));
        expect(route.levelByProfile, hasLength(8));
        expect(route.segments(rush), hasLength(6));
      }
    }
  });

  test('rute rekomendasi adalah yang tercepat untuk departure dan kendaraan terpilih', () {
    final routes = mock.buildRoutes('tp')!;
    for (final departure in week) {
      for (final mode in VehicleMode.values) {
        final ranked = rankRoutes(routes, departure, mode);
        expect(ranked.first.minutes(departure, mode), lessThanOrEqualTo(ranked.last.minutes(departure, mode)));
      }
    }
  });

  test('lampu lalu lintas selalu punya sisa detik positif dan berganti fase', () {
    final light = mock.buildRoutes('tp')!.first.intersections.first;
    final start = DateTime(2026, 10, 9, 8);
    final states = [for (var s = 0; s < 200; s++) light.stateAt(start.add(Duration(seconds: s)))];
    expect(states.every((s) => s.remaining > 0), isTrue);
    expect(states.any((s) => s.green), isTrue);
    expect(states.any((s) => !s.green), isTrue);
  });

  test('rekomendasi AI berpindah rute saat jam sibuk', () {
    final routes = mock.buildRoutes('tp')!;
    expect(rankRoutes(routes, quiet, VehicleMode.mobil).first.index, 0);
    expect(rankRoutes(routes, rush, VehicleMode.mobil).first.index, 1);
    final eta = routes.first.minutes;
    expect(eta(rush, VehicleMode.mobil) - eta(quiet, VehicleMode.mobil), greaterThan(10));
  });

  test('prediksi mengikuti hari dan jam berangkat', () {
    // Jumat siang ada salat Jumat, Senin siang tidak.
    expect(trafficProfile(DateTime(2026, 10, 16, 12)), isNot(trafficProfile(DateTime(2026, 10, 12, 12))));
    // Minggu 17.00 tidak sepadat Senin 17.00.
    final routes = mock.buildRoutes('tp')!;
    final sunday = Departure.at(DateTime(2026, 10, 18, 17));
    expect(routes.first.minutes(sunday, VehicleMode.mobil), lessThan(routes.first.minutes(rush, VehicleMode.mobil)));
  });

  test('rute yang ditukar berjalan terbalik dengan simpang yang sama', () {
    final route = mock.buildRoutes('tp')!.first;
    final back = route.reversed();
    expect(back.points.first, route.points.last);
    expect(back.intersections.first.roads, route.intersections.last.roads.reversed.toList());
    expect(back.intersections.first.fraction, closeTo(1 - route.intersections.last.fraction, 1e-9));
    expect(back.segments(rush), route.segments(rush).reversed.toList());
  });

  test('arah hadap mengikuti arah garis', () {
    final east = PathSampler(const [LatLng(-7.28, 112.74), LatLng(-7.28, 112.76)]);
    final north = PathSampler(const [LatLng(-7.28, 112.74), LatLng(-7.26, 112.74)]);
    expect(east.bearingAt(0.5), closeTo(90, 1));
    expect(north.bearingAt(0.5), closeTo(0, 1));
  });

  test('PathSampler memotong garis tanpa kehilangan ujungnya', () {
    final sampler = PathSampler(const [LatLng(0, 0), LatLng(0, 1), LatLng(0, 3)]);
    expect(sampler.at(0).longitude, 0);
    expect(sampler.at(1).longitude, 3);
    expect(sampler.at(0.5).longitude, closeTo(1.5, 1e-9));
    final slice = sampler.slice(0.2, 0.8);
    expect(slice.first.longitude, closeTo(0.6, 1e-9));
    expect(slice.last.longitude, closeTo(2.4, 1e-9));
    expect(slice, hasLength(3));
  });

  test('garis rute navigasi hanya memuat sisa perjalanan', () {
    final route = mock.buildRoutes('tp')!.first;
    final levels = route.segments(quiet);
    expect(route.remainingSlices(quiet), hasLength(levels.length));

    // Di tengah ruas keempat dari enam: tiga ruas pertama hilang, dan garis mulai tepat di kendaraan.
    const from = 3.5 / 6;
    final rest = route.remainingSlices(quiet, from: from);
    expect([for (final (level, _) in rest) level], levels.sublist(3));
    expect(rest.first.$2.first, route.sampler.at(from));
    expect(rest.last.$2.last, route.points.last);
  });

  test('selalu ada bus berikutnya dalam 10 menit dan status laporan maju', () {
    final start = DateTime(2026, 10, 9, 8);
    for (var s = 0; s < 300; s += 7) {
      expect(mock.nextBusMinutes(start.add(Duration(seconds: s))), inInclusiveRange(1, 10));
    }
    final report = Report(
      id: 'x',
      category: ReportCategory.kecelakaan,
      description: '',
      location: '',
      createdAt: start,
      photoCount: 1,
      priority: 'Tinggi',
    );
    expect(report.statusAt(start), ReportStatus.terkirim);
    expect(report.statusAt(start.add(const Duration(seconds: 40))), ReportStatus.selesai);
  });
}
