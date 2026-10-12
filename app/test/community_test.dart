import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sparta_hoplite/data/mock_data.dart' as mock;
import 'package:sparta_hoplite/data/models.dart';
import 'package:sparta_hoplite/data/state.dart';

void main() {
  test('rupiah memakai titik ribuan', () {
    expect(rupiah(5000), 'Rp5.000');
    expect(rupiah(17500), 'Rp17.500');
    expect(rupiah(500), 'Rp500');
    expect(rupiah(-15000), '−Rp15.000');
  });

  test('jenjang pelapor naik menurut jumlah laporan terverifikasi', () {
    expect(ReporterLevel.of(0), ReporterLevel.warga);
    expect(ReporterLevel.of(12), ReporterLevel.pengawas);
    expect(ReporterLevel.of(30), ReporterLevel.garda);
    expect(ReporterLevel.garda.next, isNull);
  });

  test('saldo bertambah saat laporan terverifikasi dan berkurang saat ditukar', () {
    var now = DateTime.now();
    final container = ProviderContainer(overrides: [nowProvider.overrideWith((ref) => now)]);
    addTearDown(container.dispose);

    final start = container.read(balanceProvider);
    expect(start, 15500);
    expect(container.read(reporterLevelProvider), ReporterLevel.pengawas);

    container
        .read(reportsProvider.notifier)
        .add(
          Report(
            id: 'SP-1',
            category: ReportCategory.kecelakaan,
            description: '',
            location: 'Jl. Raya Menur, Gubeng, Surabaya',
            createdAt: now,
            photoCount: 1,
            priority: 'Tinggi',
            call: TrafficCall(
              type: IncidentType.kecelakaan,
              severity: Severity.sedang,
              position: mock.origin.point,
              heading: 0,
              speedKmh: 0,
              road: 'Raya Menur',
              timestamp: now,
              transcript: 'ada kecelakaan',
              photoPath: '/cache/CAP1.jpg',
            ),
          ),
        );
    expect(container.read(balanceProvider), start, reason: 'belum terverifikasi');
    final mine = container.read(citizenFeedProvider).firstWhere((r) => r.mine);
    expect(mine.status, CitizenStatus.menunggu);
    expect(mine.area, 'Gubeng');

    now = now.add(const Duration(seconds: 25));
    container.refresh(nowProvider);
    expect(container.read(balanceProvider), start + rewardPerReport);
    expect(container.read(verifiedCountProvider), mock.seedVerifiedReports + 1);

    final bus = mock.rewardCatalog.firstWhere((item) => item.id == 'suroboyo-bus');
    final voucher = container.read(walletProvider.notifier).redeem(bus);
    expect(voucher.code, matches(RegExp(r'^SPR-[A-Z0-9]{4}-[A-Z0-9]{4}$')));
    expect(container.read(balanceProvider), start + rewardPerReport - bus.price);
  });

  test('laporan yang menunggu terverifikasi setelah dikonfirmasi warga ketiga', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    CitizenReport pending() => container.read(citizenFeedProvider).firstWhere((r) => r.id == 'w-1033');
    expect(pending().status, CitizenStatus.menunggu);
    container.read(myVotesProvider.notifier).state = {'w-1033': Vote(true, DateTime.now())};
    expect(pending().status, CitizenStatus.terverifikasi);
    expect(pending().stillThere, 3);
  });
}
