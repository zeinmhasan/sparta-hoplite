import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_location.dart';
import 'mock_data.dart' as mock;
import 'models.dart';
import 'repository.dart';

final repositoryProvider = Provider<HopliteRepository>((ref) => MockRepository());

/// Detak tiap detik; menggerakkan lampu lalu lintas, posisi bus, dan status laporan.
final _clockProvider = StreamProvider<DateTime>(
  (ref) => Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
);
final nowProvider = Provider<DateTime>((ref) => ref.watch(_clockProvider).value ?? DateTime.now());

final departureProvider = StateProvider<Departure>((ref) => Departure.now);
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

/// Lokasi pelapor dari GPS. Disegarkan tiap kali melapor dari tab Pulse Report.
final reportSpotProvider = FutureProvider<ReportSpot>((ref) => locateReporter());

// ------------------------------------------------------------ Laporan warga

final _othersProvider = Provider<List<CitizenReport>>((ref) => mock.citizenReports(DateTime.now()));

/// Konfirmasi pengguna atas laporan warga lain, per id laporan.
final myVotesProvider = StateProvider<Map<String, Vote>>((ref) => const {});

/// Umpan Laporan Warga: laporan bergambar milik pengguna dan laporan warga lain,
/// terbaru di atas. Laporan yang menunggu konfirmasi terverifikasi setelah 3 warga.
final citizenFeedProvider = Provider<List<CitizenReport>>((ref) {
  final now = ref.watch(nowProvider);
  final votes = ref.watch(myVotesProvider);
  final level = ref.watch(reporterLevelProvider).label;
  final feed = [
    for (final r in ref.watch(reportsProvider))
      if (r.photoPath != null) _citizenFromReport(r, now, level),
    for (final r in ref.watch(_othersProvider)) _withVote(r, votes[r.id]),
  ];
  return feed..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

CitizenReport _withVote(CitizenReport r, Vote? vote) {
  if (vote == null) return r;
  final stillThere = vote.stillThere;
  final voted = r.withVotes(r.stillThere + (stillThere ? 1 : 0), r.cleared + (stillThere ? 0 : 1));
  if (r.status != CitizenStatus.menunggu || voted.stillThere < 3) return voted;
  return CitizenReport(
    id: r.id,
    type: r.type,
    severity: r.severity,
    road: r.road,
    area: r.area,
    point: r.point,
    createdAt: r.createdAt,
    reporter: r.reporter,
    reporterLevel: r.reporterLevel,
    photo: r.photo,
    note: r.note,
    stillThere: voted.stillThere,
    cleared: voted.cleared,
    status: CitizenStatus.terverifikasi,
    handler: r.handler,
    followUps: [
      ...r.followUps,
      FollowUp('Terverifikasi warga', '${voted.stillThere} warga mengonfirmasi kejadian ini', vote.at),
    ],
  );
}

CitizenReport _citizenFromReport(Report r, DateTime now, String level) {
  final call = r.call!;
  final trusted = r.trustAt(now) != null;
  final status = switch (r.statusAt(now)) {
    ReportStatus.selesai => CitizenStatus.selesai,
    ReportStatus.diproses => CitizenStatus.ditangani,
    _ => trusted ? CitizenStatus.terverifikasi : CitizenStatus.menunggu,
  };
  final parts = r.location.split(', ');
  final handler = mock.handlerFor(call.type);
  final steps = [
    FollowUp('Diterima SPARTA Pulse', 'Diklasifikasi AI sebagai ${call.type.label.toLowerCase()}', r.createdAt),
    if (trusted) FollowUp('Terverifikasi', r.trustAt(now)!, r.verifiedAt!),
    for (final (i, s) in [ReportStatus.dibaca, ReportStatus.diproses, ReportStatus.selesai].indexed)
      if (r.statusAt(now).index >= s.index)
        FollowUp(
          i == 0 ? 'Diteruskan ke $handler' : s.label,
          s.note,
          r.createdAt.add(Duration(seconds: [8, 18, 30][i])),
        ),
  ];
  return CitizenReport(
    id: r.id,
    type: call.type,
    severity: call.severity,
    road: parts.first,
    area: parts.length >= 3 ? parts[parts.length - 2] : 'Surabaya',
    point: call.position,
    createdAt: r.createdAt,
    reporter: 'Kamu',
    reporterLevel: level,
    photo: call.photoPath!,
    photoIsFile: true,
    note: call.transcript,
    stillThere: trusted ? 3 : 0,
    cleared: 0,
    status: status,
    handler: handler,
    followUps: steps,
    mine: true,
  );
}

// -------------------------------------------------------------- Saldo Pulse

class WalletState {
  const WalletState(this.entries, this.vouchers);
  final List<WalletEntry> entries;
  final List<Voucher> vouchers;
}

class WalletNotifier extends StateNotifier<WalletState> {
  WalletNotifier() : super(WalletState(mock.seedWallet(DateTime.now()), const []));

  final _random = math.Random();

  void earn(WalletEntry entry) => state = WalletState([entry, ...state.entries], state.vouchers);

  /// Menukar saldo dengan voucher [item]. Saldo cukup diperiksa pemanggil.
  Voucher redeem(RewardItem item) {
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    String chunk() => List.generate(4, (_) => letters[_random.nextInt(letters.length)]).join();
    final now = DateTime.now();
    final voucher = Voucher(
      id: 'v${now.millisecondsSinceEpoch}',
      item: item,
      code: 'SPR-${chunk()}-${chunk()}',
      issuedAt: now,
    );
    final entry = WalletEntry(title: item.name, detail: item.unit, amount: -item.price, time: now);
    state = WalletState([entry, ...state.entries], [voucher, ...state.vouchers]);
    return voucher;
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) => WalletNotifier());

/// Laporan suara pengguna yang sudah terverifikasi saat ini.
final verifiedOwnReportsProvider = Provider<List<Report>>((ref) {
  final now = ref.watch(nowProvider);
  return [
    for (final r in ref.watch(reportsProvider))
      if (r.verifiedAt != null && !now.isBefore(r.verifiedAt!)) r,
  ];
});

/// Riwayat saldo lengkap, terbaru di atas. Laporan suara yang terverifikasi
/// otomatis menambah saldo.
final walletEntriesProvider = Provider<List<WalletEntry>>((ref) {
  final earned = [
    for (final r in ref.watch(verifiedOwnReportsProvider))
      WalletEntry(
        title: 'Laporan ${r.title.toLowerCase()} terverifikasi',
        detail: r.location,
        amount: rewardPerReport,
        time: r.verifiedAt!,
      ),
  ];
  return [...earned, ...ref.watch(walletProvider).entries]..sort((a, b) => b.time.compareTo(a.time));
});

final balanceProvider = Provider<int>((ref) => ref.watch(walletEntriesProvider).fold(0, (sum, e) => sum + e.amount));

final verifiedCountProvider = Provider<int>(
  (ref) => mock.seedVerifiedReports + ref.watch(verifiedOwnReportsProvider).length,
);

final reporterLevelProvider = Provider<ReporterLevel>((ref) => ReporterLevel.of(ref.watch(verifiedCountProvider)));

/// Rute diurutkan dari yang tercepat untuk waktu berangkat dan kendaraan terpilih;
/// yang pertama menjadi Rute Rekomendasi AI.
List<RouteOption> rankRoutes(List<RouteOption> routes, Departure d, VehicleMode mode) =>
    [...routes]..sort((a, b) => a.minutes(d, mode).compareTo(b.minutes(d, mode)));
