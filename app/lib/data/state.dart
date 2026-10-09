import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mock_data.dart' as mock;
import 'models.dart';
import 'repository.dart';

final repositoryProvider = Provider<HopliteRepository>((ref) => MockRepository());

/// Detak tiap detik; menggerakkan lampu lalu lintas, posisi bus, dan status laporan.
final _clockProvider = StreamProvider<DateTime>(
  (ref) => Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
);
final nowProvider = Provider<DateTime>((ref) => ref.watch(_clockProvider).value ?? DateTime.now());

final horizonProvider = StateProvider<Horizon>((ref) => Horizon.now);
final vehicleModeProvider = StateProvider<VehicleMode>((ref) => VehicleMode.mobil);

/// True jika asal dan tujuan ditukar: berangkat dari tempat terpilih menuju Lokasi Saya.
final swappedProvider = StateProvider<bool>((ref) => false);
final destinationProvider = StateProvider<Place>((ref) => mock.places.first);

final overviewProvider = FutureProvider<TrafficOverview>((ref) => ref.watch(repositoryProvider).trafficOverview());

final routesProvider = FutureProvider.family<List<RouteOption>, Place>(
  (ref, destination) => ref.watch(repositoryProvider).routes(destination),
);

/// Rute perjalanan yang sedang dilihat, sudah dibalik jika asal dan tujuan ditukar.
final tripRoutesProvider = Provider<AsyncValue<List<RouteOption>>>((ref) {
  final routes = ref.watch(routesProvider(ref.watch(destinationProvider)));
  if (!ref.watch(swappedProvider)) return routes;
  return routes.whenData((list) => [for (final r in list) r.reversed()]);
});

final transitPlansProvider = FutureProvider.family<List<TransitPlan>, Place>(
  (ref, destination) => ref.watch(repositoryProvider).transitPlans(destination),
);

final notificationsProvider = FutureProvider<List<AppNotification>>(
  (ref) => ref.watch(repositoryProvider).notifications(),
);

class ReportsNotifier extends StateNotifier<List<Report>> {
  ReportsNotifier() : super(mock.seedReports(DateTime.now()));

  void add(Report report) => state = [report, ...state];
}

final reportsProvider = StateNotifierProvider<ReportsNotifier, List<Report>>((ref) => ReportsNotifier());

/// Rute diurutkan dari yang tercepat untuk horizon dan kendaraan terpilih;
/// yang pertama menjadi Rute Rekomendasi AI.
List<RouteOption> rankRoutes(List<RouteOption> routes, Horizon h, VehicleMode mode) =>
    [...routes]..sort((a, b) => a.minutes(h, mode).compareTo(b.minutes(h, mode)));
