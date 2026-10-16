import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/state.dart';
import 'evidence_camera_screen.dart';

Color _statusColor(ReportStatus status) => switch (status) {
  ReportStatus.terkirim => AppColors.textSecondary,
  ReportStatus.dibaca => AppColors.navy,
  ReportStatus.diproses => const Color(0xFFB07A00),
  ReportStatus.selesai => AppColors.lancar,
};

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class MyReportsScreen extends ConsumerWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsProvider);
    final now = ref.watch(nowProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'Laporan Saya'),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: reports.length,
                separatorBuilder: (context, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final report = reports[i];
                  final photo = report.photoPath;
                  return AppCard(
                    onTap: () => context.push('/reports/${report.id}'),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: AppColors.maroon.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: photo == null ? Icon(report.icon, color: AppColors.maroon) : evidenceImage(photo),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(report.title, style: AppText.cardTitle.copyWith(fontSize: 15)),
                              const SizedBox(height: 3),
                              Text(report.location, style: AppText.caption),
                              const SizedBox(height: 3),
                              Text('${report.id} • ${timeAgo(report.createdAt, now)}', style: AppText.caption),
                            ],
                          ),
                        ),
                        _StatusChip(report.statusAt(now)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportDetailScreen extends ConsumerWidget {
  const ReportDetailScreen({super.key, required this.reportId});
  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(reportsProvider).firstWhere((r) => r.id == reportId);
    final now = ref.watch(nowProvider);
    final status = report.statusAt(now);
    final call = report.call;
    final trust = report.trustAt(now);
    final photo = report.photoPath;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'Status Laporan'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  if (photo != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(aspectRatio: 4 / 3, child: evidenceImage(photo)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(report.icon, color: AppColors.maroon),
                            const SizedBox(width: 10),
                            Expanded(child: Text(report.title, style: AppText.cardTitle)),
                            _StatusChip(status),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(report.description, style: AppText.body.copyWith(height: 1.45)),
                        const Divider(height: 28),
                        _InfoRow(icon: Icons.tag_rounded, text: report.id),
                        _InfoRow(icon: Icons.location_on_outlined, text: report.location),
                        if (call == null)
                          _InfoRow(
                            icon: Icons.photo_library_outlined,
                            text: '${report.photoCount} foto • ${timeAgo(report.createdAt, now)}',
                          )
                        else
                          _InfoRow(
                            icon: Icons.mic_none_rounded,
                            text: [
                              'Lewat suara',
                              if (photo != null) '1 foto bukti',
                              timeAgo(report.createdAt, now),
                            ].join(' • '),
                          ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            AiBadge(label: 'Prioritas ${report.priority}'),
                            const SizedBox(width: 8),
                            Icon(
                              trust == null ? Icons.hourglass_top_rounded : Icons.verified_rounded,
                              size: 16,
                              color: trust == null ? AppColors.textSecondary : AppColors.lancar,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              trust ?? 'Belum terverifikasi',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: trust == null ? AppColors.textSecondary : AppColors.lancar,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (call != null) ...[
                    const SizedBox(height: 22),
                    const SectionLabel('Data laporan'),
                    const SizedBox(height: 10),
                    AppCard(
                      child: Column(
                        children: [
                          _DataRow(
                            'Jenis',
                            '${call.type.label} • ${call.severity.label}',
                            badge: call.confidence == null ? null : 'AI ${(call.confidence! * 100).round()}%',
                          ),
                          if (call.transcript.isNotEmpty) _DataRow('Ucapan', '“${call.transcript}”'),
                          _DataRow(
                            'Koordinat',
                            '${call.position.latitude.toStringAsFixed(5)}, '
                                '${call.position.longitude.toStringAsFixed(5)}',
                          ),
                          _DataRow('Waktu', dateTimeLabel(call.timestamp)),
                          if (call.speedKmh > 0) _DataRow('Kecepatan', '${call.speedKmh} km/jam'),
                          _DataRow('Bukti', photo == null ? 'Laporan suara saat berkendara' : '1 foto dari kamera'),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  const SectionLabel(
                    'Perjalanan laporan',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LiveDot(),
                        SizedBox(width: 6),
                        Text('Real-time', style: AppText.caption),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final step in ReportStatus.values)
                    _StatusStep(
                      step: step,
                      done: step.index < status.index || status == ReportStatus.selesai,
                      current: step == status && status != ReportStatus.selesai,
                      last: step == ReportStatus.values.last,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 17, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppText.body.copyWith(fontSize: 13))),
        ],
      ),
    );
  }
}

class _StatusStep extends StatelessWidget {
  const _StatusStep({required this.step, required this.done, required this.current, required this.last});
  final ReportStatus step;
  final bool done;
  final bool current;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final reached = done || current;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: done ? AppColors.maroon : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: reached ? AppColors.maroon : AppColors.border, width: 2),
                ),
                child: done
                    ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                    : (current ? const Center(child: LiveDot(color: AppColors.maroon)) : null),
              ),
              if (!last)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    width: 2,
                    color: done ? AppColors.maroon : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 3, bottom: last ? 0 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: AppText.bodyStrong.copyWith(color: reached ? AppColors.text : AppColors.textSecondary),
                  ),
                  const SizedBox(height: 3),
                  Text(reached ? step.note : 'Menunggu', style: AppText.caption),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow(this.label, this.value, {this.badge});
  final String label;
  final String value;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 92, child: Text(label, style: AppText.caption)),
          Expanded(child: Text(value, style: AppText.body.copyWith(fontSize: 13.5))),
          if (badge != null) AiBadge(label: badge!),
        ],
      ),
    );
  }
}
