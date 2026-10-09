import 'live_routing.dart';
import 'mock_data.dart' as mock;
import 'models.dart';

/// Satu pintu data untuk semua fitur. Demo memakai [MockRepository]; nanti
/// implementasi lain bisa memanggil API SPARTA tanpa mengubah layar.
abstract class HopliteRepository {
  Future<TrafficOverview> trafficOverview();
  Future<List<Place>> searchPlaces(String query);
  Future<List<RouteOption>> routes(Place destination);
  Future<List<TransitPlan>> transitPlans(Place destination);
  Future<AssistantReply> askAssistant(String question);
  Future<Report> submitReport({
    required ReportCategory category,
    required String description,
    required String location,
    required int photoCount,
  });
  Future<List<AppNotification>> notifications();
}

class MockRepository implements HopliteRepository {
  /// Jeda buatan agar layar terasa memuat data dari jaringan.
  Future<void> _latency([int ms = 450]) => Future.delayed(Duration(milliseconds: ms));

  @override
  Future<TrafficOverview> trafficOverview() async {
    await _latency(300);
    return const TrafficOverview(mock.citySummary, mock.insights);
  }

  @override
  Future<List<Place>> searchPlaces(String query) => searchPlacesOnline(query);

  /// Tempat populer memakai rute tersimpan. Tempat lain dihitung langsung dari
  /// OSRM, lalu ETA dan kepadatannya tetap diisi data simulasi.
  @override
  Future<List<RouteOption>> routes(Place destination) async {
    final saved = mock.buildRoutes(destination.id);
    if (saved != null) {
      await _latency(600);
      return saved;
    }
    return mock.routesFromGeo(await fetchRouteGeometry(mock.origin.point, destination.point));
  }

  @override
  Future<List<TransitPlan>> transitPlans(Place destination) async {
    await _latency();
    return mock.buildTransitPlans(destination);
  }

  @override
  Future<AssistantReply> askAssistant(String question) async {
    await _latency(1100);
    return mock.assistantAnswer(question, DateTime.now());
  }

  @override
  Future<Report> submitReport({
    required ReportCategory category,
    required String description,
    required String location,
    required int photoCount,
  }) async {
    await _latency(1200);
    final now = DateTime.now();
    final serial = (now.millisecondsSinceEpoch ~/ 1000 % 9000 + 1000).toString();
    return Report(
      id: 'SP-2610-$serial',
      category: category,
      description: description,
      location: location,
      createdAt: now,
      photoCount: photoCount,
      priority: category == ReportCategory.kecelakaan || category == ReportCategory.banjir ? 'Tinggi' : 'Sedang',
    );
  }

  @override
  Future<List<AppNotification>> notifications() async {
    await _latency(300);
    return mock.notifications;
  }
}
