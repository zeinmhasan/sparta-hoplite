import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/mock_data.dart' as mock;
import '../../data/models.dart';
import '../../data/state.dart';
import '../community/community_feed.dart';
import '../community/community_widgets.dart';
import 'insights_screen.dart';
import 'weather_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  Future<void> _search(BuildContext context, WidgetRef ref) async {
    final place = await pickDestination(context);
    if (place == null || !context.mounted) return;
    ref.read(destinationProvider.notifier).state = place;
    ref.read(swappedProvider.notifier).state = false;
    context.go('/route');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(overviewProvider).value;
    final summary = overview?.summary ?? mock.citySummary;
    final topInsight = (overview?.insights ?? mock.insights).first;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_greeting, ${mock.userName}! 👋',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text),
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                        SizedBox(width: 2),
                        Text(mock.userCity, style: AppText.caption),
                      ],
                    ),
                  ],
                ),
              ),
              _BellButton(onTap: () => context.push('/notifications')),
            ],
          ),
          const SizedBox(height: 18),
          WeatherCard(traffic: summary.level),
          const SizedBox(height: 16),
          _SearchBar(onTap: () => _search(context, ref)),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: Text('AI Traffic Insight', style: AppText.sectionTitle)),
              TextButton(
                onPressed: () => context.push('/insights'),
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.maroon),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _InsightCard(insight: topInsight, onTap: () => showInsightSheet(context, topInsight)),
          const SizedBox(height: 14),
          _TransitCard(onTap: () => context.go('/transit')),
          const SizedBox(height: 18),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FeatureTile(
                  label: 'Smart\nRoute',
                  icon: Icons.near_me_outlined,
                  color: AppColors.navy,
                  onTap: () => context.go('/route'),
                ),
                const SizedBox(width: 10),
                _FeatureTile(
                  label: 'Transportasi\nUmum',
                  icon: Icons.directions_bus_outlined,
                  color: AppColors.teal,
                  onTap: () => context.go('/transit'),
                ),
                const SizedBox(width: 10),
                _FeatureTile(
                  label: 'Pulse\nReport',
                  icon: Icons.campaign_outlined,
                  color: AppColors.purple,
                  onTap: () => context.go('/pulse'),
                ),
                const SizedBox(width: 10),
                _FeatureTile(
                  label: 'Panic\nButton',
                  icon: Icons.emergency_rounded,
                  color: AppColors.emergency,
                  onTap: () => context.go('/panic'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: Text('Laporan Warga', style: AppText.sectionTitle)),
              TextButton(
                onPressed: () => context.go('/pulse?tab=warga'),
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.maroon),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const _CitizenStrip(),
        ].animate(interval: 50.ms).fadeIn(duration: 300.ms).slideY(begin: 0.06, end: 0, curve: Curves.easeOut),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Material(
          color: Colors.white,
          shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
          child: IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: AppColors.navy),
            onPressed: onTap,
          ),
        ),
        Positioned(
          right: 10,
          top: 10,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: AppColors.emergency,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFEFEDEC),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: AppColors.textSecondary),
              SizedBox(width: 12),
              Expanded(
                child: Text('Mau ke mana hari ini?', style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
              ),
              Icon(Icons.tune_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight, required this.onTap});
  final Insight insight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kemacetan diprediksi di', style: AppText.caption),
                const SizedBox(height: 6),
                Text('${insight.road} ${insight.when}', style: AppText.cardTitle.copyWith(height: 1.35)),
                const SizedBox(height: 12),
                StatusBadge(insight.level),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const _Illustration(
            icon: Icons.traffic_rounded,
            colors: [Color(0xFFE6ECF7), Color(0xFFCBD8EE)],
            iconColor: AppColors.navy,
          ),
        ],
      ),
    );
  }
}

class _TransitCard extends StatelessWidget {
  const _TransitCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rekomendasi Transportasi Umum', style: AppText.bodyStrong),
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Naik Suroboyo Bus dapat menghemat 12 menit',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.35, color: AppColors.text),
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.route_outlined, size: 15, color: AppColors.textSecondary),
                        SizedBox(width: 4),
                        Text('Koridor ${mock.busCorridor} • Halte ITS', style: AppText.caption),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              _Illustration(
                icon: Icons.directions_bus_rounded,
                colors: [Color(0xFFFFF3CC), Color(0xFFFFE08A)],
                iconColor: AppColors.navy,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.icon, required this.colors, required this.iconColor});
  final IconData icon;
  final List<Color> colors;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: iconColor, size: 34),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.label, required this.icon, required this.color, required this.onTap});

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(height: 12),
                // Label mengecil di layar sempit alih-alih pindah baris, jadi semua tile tetap dua
                // baris dan sama tinggi. Kedua baris diperkecil bersama supaya ukurannya sama.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Laporan warga terbaru yang masih aktif, digeser ke samping.
class _CitizenStrip extends ConsumerWidget {
  const _CitizenStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    final user = ref.watch(userPointProvider);
    final reports = ref.watch(citizenFeedProvider).where((r) => r.status != CitizenStatus.selesai).take(5).toList();

    return SizedBox(
      height: 214,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: reports.length,
        separatorBuilder: (context, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final r = reports[i];
          return SizedBox(
            width: 236,
            child: AppCard(
              padding: EdgeInsets.zero,
              onTap: () => openCitizenReport(context, r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CitizenPhoto(report: r),
                        Positioned(left: 8, top: 8, child: IncidentChip(r.type)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.road, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
                        const SizedBox(height: 2),
                        Text('${distanceTo(user, r.point)} • ${timeAgo(r.createdAt, now)}', style: AppText.caption),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(r.status.icon, size: 14, color: r.status.color),
                            const SizedBox(width: 4),
                            Text(
                              '${r.status.label} • ${r.stillThere} warga',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: r.status.color),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
