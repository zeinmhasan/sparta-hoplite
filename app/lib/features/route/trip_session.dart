import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock_data.dart' as mock;
import '../../data/models.dart';
import '../../data/state.dart';
import '../voice/copilot.dart';
import '../voice/trip_copilot.dart';
import 'nav_sim.dart';

/// Satu perjalanan navigasi: simulator kendaraan, skenario kejadian di jalan,
/// dan co-pilot suara yang mengikutinya. Dipakai navigasi 3D dan cadangannya.
class TripSession {
  TripSession(WidgetRef ref, int routeIndex, {required VoidCallback onReroute})
    : copilot = ref.read(copilotProvider),
      departure = ref.read(departureProvider),
      vehicle = ref.read(vehicleModeProvider) {
    final routes = ref.read(tripRoutesProvider).value!;
    final route = routes.firstWhere((r) => r.index == routeIndex);
    final scenario = mock.tripScenario(routes, route, departure);
    final repository = ref.read(repositoryProvider);
    final reports = ref.read(reportsProvider.notifier);

    sim = NavSimulator(route, slowZones: scenario.slowZones(route));
    trip = TripCopilot(
      copilot: copilot,
      routes: routes,
      route: route,
      events: scenario.events,
      minutesOf: (r) => r.minutes(departure, vehicle),
      send: (call) async => reports.add(await repository.reportTraffic(call)),
      confirm: (event, stillThere) => repository.confirmEvent(event, stillThere: stillThere),
      onReroute: (next) {
        sim.switchRoute(next, slowZones: scenario.slowZones(next));
        onReroute();
      },
    );
    copilot.engine.prepare();
  }

  final VoiceCopilot copilot;
  final Departure departure;
  final VehicleMode vehicle;
  late final NavSimulator sim;
  late final TripCopilot trip;

  RouteOption get route => sim.route;
  int get minutes => route.minutes(departure, vehicle);

  /// Memajukan kendaraan [dt] detik dan memberi tahu co-pilot.
  NavFrame step(double dt, DateTime now) {
    final frame = sim.step(dt, now);
    trip.onFrame(frame, dt, now);
    return frame;
  }

  /// Menghentikan ucapan saat layar ditutup. Ditunda satu langkah karena
  /// pendengar co-pilot tidak boleh dibangun ulang di tengah pembongkaran layar.
  void close() => Future.microtask(copilot.cancel);
}
