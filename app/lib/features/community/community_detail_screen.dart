import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/map_view.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/state.dart';
import 'community_feed.dart';
import 'community_widgets.dart';

/// Detail laporan warga lain: foto, konfirmasi warga, dan tindak lanjut pemerintah.
class CommunityDetailScreen extends ConsumerWidget {
  const CommunityDetailScreen({super.key, required this.reportId});
  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(citizenFeedProvider).where((r) => r.id == reportId).firstOrNull;
    final now = ref.watch(nowProvider);
    final user = ref.watch(userPointProvider);
    final vote = ref.watch(myVotesProvider)[reportId];
    if (report == null) {
      return const Scaffold(
        body: SafeArea(
          child: Column(children: [ScreenHeader(title: 'Laporan Warga')]),
        ),
      );
    }

    void confirm(bool stillThere) {
      ref.read(myVotesProvider.notifier).update((votes) => {...votes, reportId: Vote(stillThere, DateTime.now())});
      ref
          .read(walletProvider.notifier)
          .earn(
            WalletEntry(
              title: 'Konfirmasi laporan warga',
              detail: '${report.type.label} • ${report.road}',
              amount: rewardPerConfirmation,
              time: DateTime.now(),
            ),
          );
      rewardToast(
        ScaffoldMessenger.of(context),
        'Terima kasih sudah mengonfirmasi',
        rewardPerConfirmation,
        onOpen: () => context.push('/rewards'),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 280,
            backgroundColor: AppColors.maroon,
            foregroundColor: Colors.white,
            title: const Text('Laporan Warga'),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CitizenPhoto(report: report),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [Color(0x99000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            sliver: SliverList.list(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [IncidentChip(report.type), CitizenStatusChip(report.status)],
                ),
                const SizedBox(height: 12),
                Text(report.road, style: AppText.sectionTitle),
                const SizedBox(height: 4),
                Text(
                  '${report.area}, Surabaya • ${distanceTo(user, report.point)} dari kamu • '
                  'Tingkat ${report.severity.label.toLowerCase()} • ${timeAgo(report.createdAt, now)}',
                  style: AppText.caption,
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ReporterAvatar(name: report.reporter, size: 36),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(report.reporter, style: AppText.bodyStrong),
                                Text(report.reporterLevel, style: AppText.caption),
                              ],
                            ),
                          ),
                          const AiBadge(label: 'Diklasifikasi AI'),
                        ],
                      ),
                      if (report.note.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('“${report.note}”', style: AppText.body.copyWith(height: 1.45)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const SectionLabel('Konfirmasi warga'),
                const SizedBox(height: 10),
                _Votes(report: report, vote: vote, onVote: confirm),
                const SizedBox(height: 22),
                SectionLabel(
                  'Tindak lanjut',
                  trailing: report.handler == null ? null : Text(report.handler!, style: AppText.caption),
                ),
                const SizedBox(height: 12),
                for (final (i, step) in report.followUps.indexed)
                  _FollowUpStep(step: step, now: now, last: i == report.followUps.length - 1),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 160,
                    child: AppMap(
                      fitPoints: [report.point],
                      followZoom: 15,
                      interactive: false,
                      layers: [
                        MarkerLayer(markers: [iconMarker(report.point, report.type.icon, incidentColor(report.type))]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => context.go('/route'),
                  icon: const Icon(Icons.alt_route_rounded, size: 20),
                  label: const Text('Cari rute yang menghindari lokasi ini'),
                  style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Jumlah warga yang menyatakan masih ada dan sudah aman, dan tombol konfirmasi.
const _voteText = TextStyle(fontSize: 14, fontWeight: FontWeight.w700);

class _Votes extends StatelessWidget {
  const _Votes({required this.report, required this.vote, required this.onVote});
  final CitizenReport report;
  final Vote? vote;
  final ValueChanged<bool> onVote;

  @override
  Widget build(BuildContext context) {
    final total = report.stillThere + report.cleared;
    final share = total == 0 ? 0.0 : report.stillThere / total;
    final done = report.status == CitizenStatus.selesai;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${report.stillThere}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.padat),
              ),
              const SizedBox(width: 6),
              const Text('masih ada', style: AppText.caption),
              const Spacer(),
              const Text('sudah aman', style: AppText.caption),
              const SizedBox(width: 6),
              Text(
                '${report.cleared}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.lancar),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 8,
              color: AppColors.padat,
              backgroundColor: AppColors.lancar.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 14),
          if (vote != null)
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.lancar),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    vote!.stillThere
                        ? 'Kamu mengonfirmasi kejadian ini masih ada.'
                        : 'Kamu mengonfirmasi lokasi ini sudah aman.',
                    style: AppText.body.copyWith(fontSize: 13),
                  ),
                ),
              ],
            )
          else if (done)
            const Text('Laporan sudah selesai ditangani.', style: AppText.caption)
          else ...[
            const Text('Kamu di sekitar lokasi? Bantu pastikan kondisinya.', style: AppText.caption),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => onVote(true),
                    icon: const Icon(Icons.warning_amber_rounded, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Masih ada', maxLines: 1, style: _voteText),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.maroon,
                      minimumSize: const Size.fromHeight(46),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onVote(false),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Sudah aman', maxLines: 1, style: _voteText),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Dapat saldo ${rupiah(rewardPerConfirmation)} untuk tiap konfirmasi.', style: AppText.caption),
          ],
        ],
      ),
    );
  }
}

class _FollowUpStep extends StatelessWidget {
  const _FollowUpStep({required this.step, required this.now, required this.last});
  final FollowUp step;
  final DateTime now;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: last ? AppColors.maroon : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.maroon, width: 2),
                ),
                child: Icon(Icons.check_rounded, size: 13, color: last ? Colors.white : AppColors.maroon),
              ),
              if (!last) Expanded(child: Container(width: 2, color: AppColors.maroon.withValues(alpha: 0.3))),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 1, bottom: last ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(step.title, style: AppText.bodyStrong)),
                      Text(timeAgo(step.time, now), style: AppText.caption),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(step.detail, style: AppText.caption),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
