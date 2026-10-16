import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/mock_data.dart' as mock;
import '../../data/models.dart';
import '../../data/state.dart';
import '../voice/copilot.dart';
import '../voice/intent.dart';
import '../community/community_feed.dart';
import '../rewards/rewards_screen.dart';
import '../voice/voice_widgets.dart';
import 'evidence_camera_screen.dart';

/// Tahap satu laporan: pengguna bicara, AI mengklasifikasi, kamera terbuka
/// untuk foto bukti, lalu laporan terkirim.
enum _Stage { idle, listening, classifying, camera, needsPhoto, sending }

/// Pulse Report: satu cara melapor. Ketuk mikrofon, sebutkan kejadiannya, foto
/// buktinya. Jenis laporan diklasifikasi dari ucapan; lokasi dan waktu diisi
/// otomatis dari GPS.
class PulseScreen extends ConsumerStatefulWidget {
  const PulseScreen({super.key});

  @override
  ConsumerState<PulseScreen> createState() => _PulseScreenState();
}

class _PulseScreenState extends ConsumerState<PulseScreen> {
  late final VoiceCopilot _copilot = ref.read(copilotProvider);
  _Stage _stage = _Stage.idle;
  ClassifiedReport? _classified;
  String? _photo;
  DateTime? _sentAt;

  bool get _busy => _stage != _Stage.idle;

  @override
  void dispose() {
    // Ditunda satu langkah: pendengar co-pilot tidak boleh dibangun ulang saat layar dibongkar.
    Future.microtask(_copilot.cancel);
    super.dispose();
  }

  void _go(_Stage stage) {
    if (mounted) setState(() => _stage = stage);
  }

  /// Mengucapkan [text] tanpa menahan langkah berikutnya.
  void _say(String text) => unawaited(_copilot.run(() => _copilot.say(text)));

  Future<void> _report() async {
    if (_busy) return;
    // Ucapan sebelumnya (mis. "Laporan terkirim") dipotong supaya bisa langsung melapor lagi.
    if (_copilot.busy) {
      _copilot.cancel();
      for (var i = 0; i < 20 && _copilot.busy; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
    _go(_Stage.listening);
    final reply = await _copilot.run(() => askWhatToReport(_copilot));
    if (!mounted) return;
    if (reply == null) return _go(_Stage.idle);

    // Klasifikasi AI di demo ini simulasi: hasilnya dari aturan kata di intent.dart.
    _go(_Stage.classifying);
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    final intent = reply.value;
    _classified = ClassifiedReport(intent, reply.heard, classifierConfidence(reply.heard, intent));
    _say('${intent.type.label}, ${intent.severity.label.toLowerCase()}. Ambil foto buktinya.');
    await _openCamera();
  }

  Future<void> _openCamera() async {
    _go(_Stage.camera);
    final photo = await context.push<String>('/report-camera', extra: _classified);
    if (!mounted) return;
    if (photo == null) {
      _go(_Stage.needsPhoto);
      return;
    }
    await _send(photo);
  }

  Future<void> _send(String photo) async {
    final classified = _classified!;
    final repository = ref.read(repositoryProvider);
    final reports = ref.read(reportsProvider.notifier);
    setState(() {
      _photo = photo;
      _stage = _Stage.sending;
    });
    // Lokasi dicari saat layar dibuka, bukan saat pengguna bicara, supaya dialog izin
    // atau akurasi lokasi tidak memotong dialog suara. Dicari ulang jika sudah basi.
    final known = ref.read(reportSpotProvider).value;
    if (known != null && DateTime.now().difference(known.at) > const Duration(minutes: 2)) {
      ref.invalidate(reportSpotProvider);
    }
    final spot = await ref
        .read(reportSpotProvider.future)
        .timeout(
          const Duration(seconds: 12),
          onTimeout: () => ReportSpot(
            point: mock.origin.point,
            road: mock.originRoad,
            address: mock.origin.address,
            live: false,
            at: DateTime.now(),
          ),
        );
    final report = await repository.reportTraffic(
      TrafficCall(
        type: classified.intent.type,
        severity: classified.intent.severity,
        position: spot.point,
        heading: 0,
        speedKmh: 0,
        road: spot.road,
        address: spot.address,
        timestamp: DateTime.now(),
        transcript: classified.transcript,
        confidence: classified.confidence,
        photoPath: photo,
      ),
    );
    reports.add(report);
    _classified = null;
    _sentAt = DateTime.now();
    _go(_Stage.idle);
    _say('Laporan terkirim. Terima kasih.');
  }

  void _cancel() {
    _classified = null;
    _go(_Stage.idle);
    _say('Oke, laporan dibatalkan.');
  }

  /// Langkah yang sedang berjalan di penanda alur; -1 jika tidak ada.
  int get _step => switch (_stage) {
    _Stage.idle => _sentAt != null && DateTime.now().difference(_sentAt!) < const Duration(seconds: 4) ? 4 : -1,
    _Stage.listening => 0,
    _Stage.classifying => 1,
    _Stage.camera || _Stage.needsPhoto => 2,
    _Stage.sending => 3,
  };

  @override
  Widget build(BuildContext context) {
    final copilot = ref.watch(copilotProvider);
    final reports = ref.watch(reportsProvider);
    final now = ref.watch(nowProvider);
    final spot = ref.watch(reportSpotProvider);
    final lastVoice = reports.where((r) => r.byVoice).firstOrNull;

    Widget toggle(String title, String subtitle, bool value, ValueChanged<bool>? onChanged) => SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      activeTrackColor: AppColors.maroon,
      title: Text(title, style: AppText.bodyStrong),
      subtitle: Text(subtitle, style: AppText.caption),
      value: value,
      onChanged: onChanged,
    );

    final lapor = ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const Text('Lapor cukup dengan suara', style: AppText.sectionTitle),
        const SizedBox(height: 6),
        Text(
          'Ketuk mikrofon dan sebutkan kejadiannya. AI mengenali jenis laporannya, lalu kamera terbuka '
          'untuk foto bukti. Lokasi dan waktu terisi otomatis.',
          style: AppText.body.copyWith(color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 18),
        _FlowSteps(current: _step),
        const SizedBox(height: 22),
        Center(
          child: MicButton(copilot: copilot, onTap: _report, size: 128),
        ),
        const SizedBox(height: 14),
        const Text(
          'Contoh: “macet parah”, “ada kecelakaan”, “banjir”, “jalan ditutup”',
          textAlign: TextAlign.center,
          style: AppText.caption,
        ),
        const SizedBox(height: 14),
        if (!_busy) ...[const _RewardHint(), const SizedBox(height: 14)],
        VoiceDock(copilot: copilot),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: switch (_stage) {
            _Stage.classifying => const _Classifying(key: ValueKey('classifying')),
            _Stage.camera || _Stage.needsPhoto => _Evidence(
              key: const ValueKey('evidence'),
              report: _classified!,
              missing: _stage == _Stage.needsPhoto,
              onCamera: _openCamera,
              onCancel: _cancel,
            ),
            _Stage.sending => _Sending(key: const ValueKey('sending'), photo: _photo!, report: _classified!),
            _ => const SizedBox.shrink(),
          },
        ),
        const SizedBox(height: 8),
        _SpotRow(spot: spot, onRefresh: () => ref.invalidate(reportSpotProvider)),
        if (lastVoice != null && !_busy) ...[const SizedBox(height: 16), _LastReport(report: lastVoice, now: now)],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.push('/reports'),
            icon: const Icon(Icons.history_rounded, size: 18, color: AppColors.maroon),
            label: const Text(
              'Riwayat laporan saya',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.maroon),
            ),
          ),
        ),
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
        const SizedBox(height: 8),
        const Text(
          'Saat mengemudi, laporan cukup suara tanpa foto supaya mata tetap di jalan.',
          style: AppText.caption,
        ),
      ],
    );

    return DefaultTabController(
      length: 2,
      initialIndex: GoRouterState.of(context).uri.queryParameters['tab'] == 'warga' ? 1 : 0,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const ScreenHeader(title: 'Pulse Report', trailing: WalletPill()),
            const _Tabs(),
            Expanded(child: TabBarView(children: [lapor, const CommunityFeed()])),
          ],
        ),
      ),
    );
  }
}

/// Pilihan Lapor dan Laporan Warga, berbentuk segmen.
class _Tabs extends StatelessWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(12)),
      child: TabBar(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        labelColor: AppColors.maroon,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(height: 36, text: 'Lapor'),
          Tab(height: 36, text: 'Laporan Warga'),
        ],
      ),
    );
  }
}

/// Ajakan singkat: laporan terverifikasi menambah saldo.
class _RewardHint extends StatelessWidget {
  const _RewardHint();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.gold.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/rewards'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF9A5F00)),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Dapat ${rupiah(rewardPerReport)} tiap laporan terverifikasi. ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: 'Tukar dengan tiket Suroboyo Bus, Wira Wiri, atau KBS.'),
                    ],
                  ),
                  style: AppText.body.copyWith(fontSize: 13, height: 1.35, color: const Color(0xFF5C3B00)),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9A5F00)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Penanda empat langkah melapor; langkah [current] menyala, yang sebelumnya selesai.
class _FlowSteps extends StatelessWidget {
  const _FlowSteps({required this.current});
  final int current;

  static const _steps = [
    (Icons.mic_none_rounded, 'Ucapkan'),
    (Icons.auto_awesome_outlined, 'AI klasifikasi'),
    (Icons.photo_camera_outlined, 'Foto bukti'),
    (Icons.send_rounded, 'Terkirim'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 2,
                margin: const EdgeInsets.only(bottom: 22),
                color: i <= current ? AppColors.maroon : AppColors.border,
              ),
            ),
          _step(i),
        ],
      ],
    );
  }

  Widget _step(int i) {
    final (icon, label) = _steps[i];
    final done = i < current;
    final active = i == current;
    final color = active || done ? AppColors.maroon : AppColors.textSecondary;
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: active ? AppColors.maroon : (done ? AppColors.maroon.withValues(alpha: 0.1) : Colors.white),
              shape: BoxShape.circle,
              border: Border.all(color: active || done ? AppColors.maroon : AppColors.border, width: 1.5),
            ),
            child: Icon(done ? Icons.check_rounded : icon, size: 18, color: active ? Colors.white : color),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.visible,
            softWrap: false,
            style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }
}

class _Classifying extends StatelessWidget {
  const _Classifying({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.purple,
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1100.ms, color: Colors.white),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI mengklasifikasi laporan…', style: AppText.bodyStrong),
                SizedBox(height: 3),
                Text('Mengenali jenis kejadian dan tingkat keparahan dari ucapan', style: AppText.caption),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purple),
          ),
        ],
      ),
    );
  }
}

/// Hasil klasifikasi, dan saat kamera ditutup tanpa foto, pengingat bahwa foto wajib.
class _Evidence extends StatelessWidget {
  const _Evidence({
    super.key,
    required this.report,
    required this.missing,
    required this.onCamera,
    required this.onCancel,
  });
  final ClassifiedReport report;
  final bool missing;
  final VoidCallback onCamera;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ClassifiedRow(report: report),
          const Divider(height: 22),
          if (!missing)
            const Row(
              children: [
                Icon(Icons.photo_camera_outlined, size: 18, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Text('Membuka kamera untuk foto bukti…', style: AppText.caption),
              ],
            )
          else ...[
            const Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 18, color: AppColors.emergency),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Foto bukti wajib. Laporan belum dikirim.',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.emergency),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onCamera,
                    icon: const Icon(Icons.photo_camera_rounded, size: 18),
                    label: const Text('Ambil Foto'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.maroon,
                      minimumSize: const Size.fromHeight(46),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ClassifiedRow extends StatelessWidget {
  const _ClassifiedRow({required this.report});
  final ClassifiedReport report;

  @override
  Widget build(BuildContext context) {
    final intent = report.intent;
    return Row(
      children: [
        Icon(intent.type.icon, color: AppColors.maroon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${intent.type.label} • ${intent.severity.label}', style: AppText.bodyStrong),
              if (report.transcript.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('“${report.transcript}”', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
              ],
            ],
          ),
        ),
        AiConfidence(confidence: report.confidence),
      ],
    );
  }
}

class _Sending extends StatelessWidget {
  const _Sending({super.key, required this.photo, required this.report});
  final String photo;
  final ClassifiedReport report;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 56, height: 56, child: evidenceImage(photo)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${report.intent.type.label} • ${report.intent.severity.label}', style: AppText.bodyStrong),
                const SizedBox(height: 3),
                const Text('Mengirim ke SPARTA Pulse dengan lokasi GPS…', style: AppText.caption),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.maroon),
          ),
        ],
      ),
    );
  }
}

/// Lokasi yang ikut terkirim, dari GPS perangkat. Diketuk untuk mencari ulang.
class _SpotRow extends StatelessWidget {
  const _SpotRow({required this.spot, required this.onRefresh});
  final AsyncValue<ReportSpot> spot;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final value = spot.value;
    final locating = value == null || spot.isLoading;
    final row = Row(
      children: [
        Icon(value?.live ?? true ? Icons.gps_fixed_rounded : Icons.gps_off_rounded, size: 18, color: AppColors.maroon),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value?.address ?? 'Mencari lokasi GPS…',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.body.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 8),
        Text(locating ? 'Mencari…' : (value.live ? 'GPS otomatis' : 'GPS tidak aktif'), style: AppText.caption),
        if (!locating) ...[
          const SizedBox(width: 4),
          const Icon(Icons.refresh_rounded, size: 16, color: AppColors.textSecondary),
        ],
      ],
    );
    return InkWell(
      onTap: locating ? null : onRefresh,
      borderRadius: BorderRadius.circular(10),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: row),
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
    final photo = report.photoPath;
    return AppCard(
      onTap: () => context.push('/reports/${report.id}'),
      child: Row(
        children: [
          if (photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(width: 52, height: 52, child: evidenceImage(photo)),
            )
          else
            Icon(report.icon, color: AppColors.maroon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${report.title} • ${report.call!.severity.label.toLowerCase()}', style: AppText.bodyStrong),
                const SizedBox(height: 3),
                Text(
                  '${report.location} • ${trust ?? 'Belum terverifikasi'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
