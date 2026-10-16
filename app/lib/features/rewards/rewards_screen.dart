import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/mock_data.dart' as mock;
import '../../data/models.dart';
import '../../data/state.dart';

/// Pil saldo di kepala layar; ketuk untuk membuka Saldo Pulse.
class WalletPill extends ConsumerWidget {
  const WalletPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(balanceProvider);
    return Material(
      color: AppColors.gold.withValues(alpha: 0.14),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => context.push('/rewards'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance_wallet_rounded, size: 17, color: Color(0xFF9A5F00)),
              const SizedBox(width: 6),
              Text(
                rupiah(balance),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF7A4B00)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu saldo berwarna: saldo, jenjang pelapor, dan kemajuan ke jenjang berikutnya.
class WalletCard extends ConsumerWidget {
  const WalletCard({super.key, this.onTap, this.compact = false});
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(balanceProvider);
    final verified = ref.watch(verifiedCountProvider);
    final level = ref.watch(reporterLevelProvider);
    final next = level.next;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [AppColors.maroon, Color(0xFFB4322A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [BoxShadow(color: Color(0x338E1616), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, size: 18, color: Color(0xFFFFC55A)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Saldo Pulse',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.military_tech_rounded, size: 14, color: Color(0xFFFFC55A)),
                          const SizedBox(width: 4),
                          Text(
                            level.label,
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  rupiah(balance),
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                if (!compact) ...[
                  const SizedBox(height: 2),
                  const Text(
                    'Untuk Suroboyo Bus, Wira Wiri, dan wisata kota',
                    style: TextStyle(fontSize: 12.5, color: Colors.white70),
                  ),
                ],
                if (next != null) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: verified / next.minVerified,
                      minHeight: 6,
                      color: const Color(0xFFFFC55A),
                      backgroundColor: Colors.white24,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$verified dari ${next.minVerified} laporan terverifikasi menuju ${next.label}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Saldo Pulse: cara mendapat saldo, voucher aktif, katalog penukaran, dan riwayat.
class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(balanceProvider);
    final entries = ref.watch(walletEntriesProvider);
    final now = ref.watch(nowProvider);
    final vouchers = [
      for (final v in ref.watch(walletProvider).vouchers)
        if (v.validUntil.isAfter(now)) v,
    ];
    final categories = {for (final item in mock.rewardCatalog) item.category};

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'Saldo Pulse'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  const WalletCard(),
                  const SizedBox(height: 22),
                  const SectionLabel('Cara menambah saldo'),
                  const SizedBox(height: 10),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        _EarnRow(
                          icon: Icons.mic_rounded,
                          title: 'Lapor kondisi jalan',
                          subtitle: 'Saldo masuk setelah laporan terverifikasi',
                          amount: rewardPerReport,
                        ),
                        const Divider(indent: 64, height: 1),
                        _EarnRow(
                          icon: Icons.groups_2_rounded,
                          title: 'Konfirmasi laporan warga',
                          subtitle: 'Pastikan kejadian masih ada atau sudah aman',
                          amount: rewardPerConfirmation,
                        ),
                        const Divider(indent: 64, height: 1),
                        const _EarnRow(
                          icon: Icons.local_fire_department_rounded,
                          title: 'Bonus pelapor aktif',
                          subtitle: '5 laporan terverifikasi dalam seminggu',
                          amount: 10000,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Laporan yang tidak terverifikasi atau terbukti palsu tidak mendapat saldo.',
                    style: AppText.caption,
                  ),
                  if (vouchers.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    const SectionLabel('Voucher aktif'),
                    const SizedBox(height: 10),
                    for (final v in vouchers) ...[_VoucherTile(voucher: v), const SizedBox(height: 10)],
                  ],
                  for (final category in categories) ...[
                    const SizedBox(height: 22),
                    SectionLabel('Tukar saldo • $category'),
                    const SizedBox(height: 10),
                    // Dua kolom; tinggi tiap baris mengikuti isi kartu terpanjang, jadi nama
                    // yang turun baris di layar sempit tidak terpotong.
                    ..._pairs([
                      for (final item in mock.rewardCatalog)
                        if (item.category == category)
                          _RewardTile(
                            item: item,
                            affordable: balance >= item.price,
                            onTap: () => _redeem(context, ref, item),
                          ),
                    ]),
                  ],
                  const SizedBox(height: 22),
                  const SectionLabel('Riwayat saldo'),
                  const SizedBox(height: 10),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        for (final (i, e) in entries.take(10).indexed) ...[
                          if (i > 0) const Divider(indent: 16, endIndent: 16, height: 1),
                          _HistoryRow(entry: e, now: now),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _pairs(List<Widget> tiles) => [
    for (var i = 0; i < tiles.length; i += 2) ...[
      if (i > 0) const SizedBox(height: 12),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: tiles[i]),
            const SizedBox(width: 12),
            Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox()),
          ],
        ),
      ),
    ],
  ];

  Future<void> _redeem(BuildContext context, WidgetRef ref, RewardItem item) async {
    final voucher = await showModalBottomSheet<Voucher>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => _RedeemSheet(item: item),
    );
    if (voucher != null && context.mounted) context.push('/voucher/${voucher.id}');
  }
}

class _EarnRow extends StatelessWidget {
  const _EarnRow({required this.icon, required this.title, required this.subtitle, required this.amount});
  final IconData icon;
  final String title;
  final String subtitle;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.maroon.withValues(alpha: 0.08),
        child: Icon(icon, color: AppColors.maroon, size: 20),
      ),
      title: Text(title, style: AppText.bodyStrong),
      subtitle: Text(subtitle, style: AppText.caption),
      trailing: Text(
        '+${rupiah(amount)}',
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.lancar),
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({required this.item, required this.affordable, required this.onTap});
  final RewardItem item;
  final bool affordable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const Spacer(),
              Text(
                rupiah(item.price),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: affordable ? AppColors.maroon : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
          const SizedBox(height: 2),
          Text(item.unit, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.caption),
        ],
      ),
    );
  }
}

class _RedeemSheet extends ConsumerWidget {
  const _RedeemSheet({required this.item});
  final RewardItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(balanceProvider);
    final enough = balance >= item.price;
    final validity = item.validFor.inHours < 48 ? '${item.validFor.inHours} jam' : '${item.validFor.inDays} hari';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(item.icon, color: item.color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: AppText.cardTitle),
                      Text(item.operator, style: AppText.caption),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SheetRow(Icons.confirmation_number_outlined, item.unit),
            _SheetRow(Icons.schedule_rounded, 'Berlaku $validity setelah ditukar'),
            _SheetRow(Icons.qr_code_2_rounded, item.howTo),
            const Divider(height: 28),
            Row(
              children: [
                const Text('Saldo kamu', style: AppText.body),
                const Spacer(),
                Text(rupiah(balance), style: AppText.bodyStrong),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('Sisa setelah ditukar', style: AppText.body),
                const Spacer(),
                Text(enough ? rupiah(balance - item.price) : '-', style: AppText.bodyStrong),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: enough
                  ? () => Navigator.of(context).pop(ref.read(walletProvider.notifier).redeem(item))
                  : null,
              style: FilledButton.styleFrom(backgroundColor: AppColors.maroon, minimumSize: const Size.fromHeight(50)),
              child: Text(enough ? 'Tukar ${rupiah(item.price)}' : 'Saldo kurang ${rupiah(item.price - balance)}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppText.body.copyWith(fontSize: 13.5, height: 1.35))),
        ],
      ),
    );
  }
}

class _VoucherTile extends StatelessWidget {
  const _VoucherTile({required this.voucher});
  final Voucher voucher;

  @override
  Widget build(BuildContext context) {
    final item = voucher.item;
    return AppCard(
      onTap: () => context.push('/voucher/${voucher.id}'),
      child: Row(
        children: [
          Icon(Icons.qr_code_2_rounded, size: 34, color: item.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: AppText.bodyStrong),
                Text('Berlaku sampai ${dateTimeLabel(voucher.validUntil)}', style: AppText.caption),
              ],
            ),
          ),
          const Text(
            'Tampilkan',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.maroon),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.now});
  final WalletEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final earn = entry.amount > 0;
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: (earn ? AppColors.lancar : AppColors.maroon).withValues(alpha: 0.1),
        child: Icon(
          earn ? Icons.south_west_rounded : Icons.north_east_rounded,
          size: 17,
          color: earn ? AppColors.lancar : AppColors.maroon,
        ),
      ),
      title: Text(entry.title, style: AppText.bodyStrong.copyWith(fontSize: 13.5)),
      subtitle: Text(
        '${entry.detail} • ${timeAgo(entry.time, now)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.caption,
      ),
      trailing: Text(
        earn ? '+${rupiah(entry.amount)}' : rupiah(entry.amount),
        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: earn ? AppColors.lancar : AppColors.text),
      ),
    );
  }
}
