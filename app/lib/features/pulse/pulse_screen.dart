import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/mock_data.dart' as mock;
import '../../data/models.dart';
import '../../data/state.dart';
import '../voice/copilot.dart';
import '../voice/voice_widgets.dart';

/// Pulse Report versi suara: satu ketukan pada mikrofon, satu jawaban pendek,
/// dan laporan terkirim. Selama navigasi, Hoplite yang bertanya duluan.
class PulseScreen extends ConsumerStatefulWidget {
  const PulseScreen({super.key});

  @override
  ConsumerState<PulseScreen> createState() => _PulseScreenState();
}

class _PulseScreenState extends ConsumerState<PulseScreen> {
  late final VoiceCopilot _copilot = ref.read(copilotProvider);

  @override
  void dispose() {
    // Ditunda satu langkah: pendengar co-pilot tidak boleh dibangun ulang saat layar dibongkar.
    Future.microtask(_copilot.cancel);
    super.dispose();
  }

  /// Lapor atas inisiatif pengguna. Lokasinya posisi pengguna saat ini.
  Future<void> _report() async {
    final repository = ref.read(repositoryProvider);
    final reports = ref.read(reportsProvider.notifier);
    await _copilot.run(() async {
      final asked = DateTime.now();
      final reply = await askWhatToReport(_copilot);
      if (reply == null) return;
      final now = DateTime.now();
      final report = await repository.reportTraffic(
        TrafficCall(
          type: reply.value.type,
          severity: reply.value.severity,
          position: mock.origin.point,
          heading: 0,
          speedKmh: 0,
          road: mock.originRoad,
          timestamp: now,
          utterances: reply.utterances,
          seconds: now.difference(asked).inSeconds,
        ),
      );
      reports.add(report);
      await _copilot.say('Oke, dilaporkan.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final copilot = ref.watch(copilotProvider);
    final reports = ref.watch(reportsProvider);
    final now = ref.watch(nowProvider);
    final lastVoice = reports.where((r) => r.byVoice).firstOrNull;

    Widget toggle(String title, String subtitle, bool value, ValueChanged<bool>? onChanged) => SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      activeTrackColor: AppColors.maroon,
      title: Text(title, style: AppText.bodyStrong),
      subtitle: Text(subtitle, style: AppText.caption),
      value: value,
      onChanged: onChanged,
    );

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          ScreenHeader(
            title: 'Pulse Report',
            trailing: TextButton.icon(
              onPressed: () => context.push('/reports'),
              icon: const Icon(Icons.history_rounded, size: 18, color: AppColors.maroon),
              label: const Text(
                'Laporan Saya',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.maroon),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                const Text('Lapor tanpa menyentuh layar', style: AppText.sectionTitle),
                const SizedBox(height: 6),
                Text(
                  'Ketuk mikrofon, lalu sebutkan kejadiannya. Lokasi, arah, dan waktu diisi otomatis.',
                  style: AppText.body.copyWith(color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 22),
                Center(
                  child: MicButton(copilot: copilot, onTap: _report, size: 128),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Contoh: “macet parah”, “kecelakaan”, “banjir”, “jalan ditutup”',
                  textAlign: TextAlign.center,
                  style: AppText.caption,
                ),
                const SizedBox(height: 14),
                VoiceDock(copilot: copilot),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.gps_fixed_rounded, size: 18, color: AppColors.maroon),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(mock.origin.address, style: AppText.body.copyWith(fontWeight: FontWeight.w500)),
                    ),
                    const Text('Lokasi otomatis', style: AppText.caption),
                  ],
                ),
                if (lastVoice != null) ...[const SizedBox(height: 16), _LastReport(report: lastVoice, now: now)],
                const SizedBox(height: 22),
                const SectionLabel('Saat navigasi'),
                const SizedBox(height: 10),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      toggle(
                        'Mode suara',
                        'Hoplite berbicara dan mendengarkan selama navigasi',
                        copilot.enabled,
                        (value) => copilot.enabled = value,
                      ),
                      const Divider(indent: 16),
                      toggle(
                        'Hoplite bertanya duluan',
                        'Saat laju turun jauh di bawah normal: “Di sini macet?”',
                        copilot.enabled && copilot.proactive,
                        copilot.enabled ? (value) => copilot.proactive = value : null,
                      ),
                      const Divider(indent: 16),
                      toggle(
                        'Siaran kondisi jalan',
                        'Kejadian di rute depan dan tawaran rute alternatif',
                        copilot.enabled && copilot.broadcast,
                        copilot.enabled ? (value) => copilot.broadcast = value : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const SectionLabel('Suara dibanding formulir'),
                const SizedBox(height: 10),
                _Comparison(reports: reports),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => context.push('/report-form'),
                  icon: const Icon(Icons.add_a_photo_outlined, size: 20),
                  label: const Text('Lapor dengan Foto'),
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

/// Laporan suara terakhir, sebagai bukti di layar bahwa laporan sudah masuk.
class _LastReport extends StatelessWidget {
  const _LastReport({required this.report, required this.now});
  final Report report;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final trust = report.trustAt(now);
    return AppCard(
      onTap: () => context.push('/reports/${report.id}'),
      child: Row(
        children: [
          Icon(report.icon, color: AppColors.maroon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${report.title} • ${report.call!.severity.label.toLowerCase()}', style: AppText.bodyStrong),
                const SizedBox(height: 3),
                Text('${report.location} • ${trust ?? 'Belum terverifikasi'}', style: AppText.caption),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

/// Rata-rata interaksi dan waktu per laporan, suara dibanding formulir.
class _Comparison extends StatelessWidget {
  const _Comparison({required this.reports});
  final List<Report> reports;

  @override
  Widget build(BuildContext context) {
    Widget column(String title, IconData icon, String unit, bool voice) {
      final measured = reports.where((r) => r.byVoice == voice && r.interactions != null).toList();
      String average(int? Function(Report r) of) =>
          (measured.fold(0, (sum, r) => sum + (of(r) ?? 0)) / measured.length).toStringAsFixed(1).replaceAll('.', ',');
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppColors.maroon),
                const SizedBox(width: 6),
                Text(title, style: AppText.caption),
              ],
            ),
            const SizedBox(height: 8),
            if (measured.isEmpty)
              const Text('Belum ada laporan', style: AppText.body)
            else ...[
              Text(
                '${average((r) => r.interactions)} $unit',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
              const SizedBox(height: 2),
              Text('${average((r) => r.seconds)} detik • ${measured.length} laporan', style: AppText.caption),
            ],
          ],
        ),
      );
    }

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          column('Lewat suara', Icons.mic_none_rounded, 'ucapan', true),
          const SizedBox(width: 12),
          column('Lewat formulir', Icons.touch_app_outlined, 'ketukan', false),
        ],
      ),
    );
  }
}
