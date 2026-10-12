import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/mock_data.dart' as mock;
import '../../data/state.dart';
import '../rewards/rewards_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verified = ref.watch(verifiedCountProvider);

    Widget stat(String value, String label) => Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.maroon),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppText.caption, textAlign: TextAlign.center),
        ],
      ),
    );

    Widget menu(IconData icon, String title, String subtitle, VoidCallback onTap) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: AppColors.maroon.withValues(alpha: 0.08),
        child: Icon(icon, color: AppColors.maroon, size: 20),
      ),
      title: Text(title, style: AppText.bodyStrong),
      subtitle: Text(subtitle, style: AppText.caption),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
      onTap: onTap,
    );

    void soon() => toast(context, 'Segera hadir');

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          const Text('Profil', style: AppText.screenTitle),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.maroon,
                      child: Text(
                        'R',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(mock.userName, style: AppText.cardTitle),
                          SizedBox(height: 3),
                          Text(mock.userCity, style: AppText.caption),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                Row(
                  children: [
                    stat('42', 'Perjalanan\nbulan ini'),
                    stat('18', 'Naik Suroboyo\nBus'),
                    stat('$verified', 'Laporan\nterverifikasi'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          WalletCard(onTap: () => context.push('/rewards')),
          const SizedBox(height: 16),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                menu(
                  Icons.redeem_rounded,
                  'Saldo & Hadiah',
                  'Tukar saldo dengan tiket bus dan wisata kota',
                  () => context.push('/rewards'),
                ),
                const Divider(indent: 72),
                menu(Icons.two_wheeler_rounded, 'Kendaraan utama', 'Motor • L 1234 AB', soon),
                const Divider(indent: 72),
                menu(Icons.bookmark_outline_rounded, 'Tempat tersimpan', 'Rumah, Kampus ITS, Kantor', soon),
                const Divider(indent: 72),
                menu(
                  Icons.campaign_outlined,
                  'Laporan Saya',
                  'Pantau status laporan Pulse',
                  () => context.push('/reports'),
                ),
                const Divider(indent: 72),
                menu(
                  Icons.notifications_none_rounded,
                  'Notifikasi',
                  'Peringatan kemacetan dan bus',
                  () => context.push('/notifications'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Row(
              children: [
                Image.asset('assets/images/logo.png', width: 40),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SPARTA Hoplite', style: AppText.bodyStrong),
                      SizedBox(height: 2),
                      Text('Versi 1.0.0 • Pemerintah Kota Surabaya', style: AppText.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
