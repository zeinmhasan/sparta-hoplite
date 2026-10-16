import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/mock_data.dart' as mock;
import '../../data/models.dart';
import '../../data/state.dart';

class PanicScreen extends ConsumerStatefulWidget {
  const PanicScreen({super.key});

  @override
  ConsumerState<PanicScreen> createState() => _PanicScreenState();
}

class _PanicScreenState extends ConsumerState<PanicScreen> with SingleTickerProviderStateMixin {
  /// SOS harus ditahan 3 detik supaya tidak terpicu tak sengaja.
  late final _hold = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  DateTime? _activatedAt;

  @override
  void initState() {
    super.initState();
    _hold.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        HapticFeedback.heavyImpact();
        setState(() => _activatedAt = DateTime.now());
        _hold.reset();
      }
    });
  }

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _release() {
    if (_hold.isAnimating) {
      _hold.reverse();
      toast(context, 'Tahan tombol SOS selama 3 detik');
    }
  }

  void _cancel() {
    setState(() => _activatedAt = null);
    toast(context, 'Sinyal darurat dibatalkan');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const ScreenHeader(title: 'Panic Button'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                const Row(
                  children: [
                    Icon(Icons.location_on_outlined, color: AppColors.navy),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LOKASI SAYA',
                          style: TextStyle(fontSize: 10, letterSpacing: 0.8, color: AppColors.textSecondary),
                        ),
                        SizedBox(height: 2),
                        Text('Jalan Keputih, Surabaya', style: AppText.bodyStrong),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 28),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _activatedAt == null
                      ? _SosButton(hold: _hold, onDown: _hold.forward, onUp: _release)
                      : _ActiveCard(activatedAt: _activatedAt!, onCancel: _cancel),
                ),
                const SizedBox(height: 24),
                for (final contact in mock.emergencyContacts) ...[
                  _ContactCard(contact: contact),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SosButton extends StatelessWidget {
  const _SosButton({required this.hold, required this.onDown, required this.onUp});
  final AnimationController hold;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 4),
        const Text(
          'Saya membutuhkan bantuan:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text),
        ),
        const SizedBox(height: 22),
        GestureDetector(
          onTapDown: (_) => onDown(),
          onTapUp: (_) => onUp(),
          onTapCancel: onUp,
          child: AnimatedBuilder(
            animation: hold,
            builder: (context, _) => SizedBox(
              width: 236,
              height: 236,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 232,
                    height: 232,
                    child: CircularProgressIndicator(
                      value: hold.value,
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                      backgroundColor: AppColors.emergency.withValues(alpha: 0.12),
                      valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                    ),
                  ),
                  Transform.scale(
                    scale: 1 - hold.value * 0.06,
                    child: Container(
                      width: 204,
                      height: 204,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.emergency,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emergency.withValues(alpha: 0.35),
                            blurRadius: 28 + hold.value * 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Text(
                        hold.value > 0 ? '${3 - (hold.value * 3).floor()}' : 'SOS',
                        style: const TextStyle(
                          fontSize: 60,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Tahan 3 detik untuk bantuan darurat',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Tampilan setelah SOS aktif: bantuan dalam perjalanan dengan ETA mundur.
class _ActiveCard extends ConsumerWidget {
  const _ActiveCard({required this.activatedAt, required this.onCancel});
  final DateTime activatedAt;
  final VoidCallback onCancel;

  static const _etaSeconds = 240;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elapsed = ref.watch(nowProvider).difference(activatedAt).inSeconds.clamp(0, _etaSeconds);
    final left = _etaSeconds - elapsed;
    final eta = '${(left ~/ 60).toString().padLeft(2, '0')}:${(left % 60).toString().padLeft(2, '0')}';

    Widget step(String text, bool done) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: done ? Colors.white : Colors.white54,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: done ? Colors.white : Colors.white60)),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.emergency,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.emergency.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.sensors_rounded,
                color: Colors.white,
                size: 30,
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(begin: 0.85, end: 1.15, duration: 700.ms),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Sinyal darurat terkirim',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Bantuan dalam perjalanan', style: TextStyle(fontSize: 13, color: Colors.white70)),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                left == 0 ? 'Tiba' : eta,
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text('Unit Patroli Satlantas', style: TextStyle(fontSize: 13, color: Colors.white70)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          step('Lokasi Anda dibagikan ke Command Center', true),
          step('Unit terdekat menerima panggilan', elapsed >= 3),
          step('Kontak darurat Anda diberi tahu', elapsed >= 6),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white70),
              shape: const StadiumBorder(),
            ),
            child: const Text('Batalkan, saya aman'),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.contact});
  final EmergencyContact contact;

  @override
  Widget build(BuildContext context) {
    void call() => showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isDismissible: false,
      builder: (context) => _CallSheet(contact: contact),
    );

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: call,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: contact.color.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(contact.icon, color: contact.color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.name, style: AppText.cardTitle.copyWith(fontSize: 17)),
                const SizedBox(height: 2),
                Text(
                  contact.number,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: contact.numberColor),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: AppColors.field, shape: BoxShape.circle),
            child: const Icon(Icons.call_outlined, color: AppColors.navy, size: 20),
          ),
        ],
      ),
    );
  }
}

/// Simulasi panggilan; tidak membuka dialer sungguhan.
class _CallSheet extends StatefulWidget {
  const _CallSheet({required this.contact});
  final EmergencyContact contact;

  @override
  State<_CallSheet> createState() => _CallSheetState();
}

class _CallSheetState extends State<_CallSheet> {
  late final Timer _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contact = widget.contact;
    final connected = _seconds >= 3;
    final talk = _seconds - 3;
    final status = connected
        ? 'Tersambung ${(talk ~/ 60).toString().padLeft(2, '0')}:${(talk % 60).toString().padLeft(2, '0')}'
        : 'Menghubungi...';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            const SizedBox(height: 8),
            Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(color: contact.color.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Icon(contact.icon, color: contact.color, size: 40),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1, end: connected ? 1 : 1.1, duration: 600.ms),
            const SizedBox(height: 16),
            Text(contact.name, style: AppText.sectionTitle),
            const SizedBox(height: 2),
            Text(contact.number, style: AppText.caption),
            const SizedBox(height: 12),
            Text(
              status,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: connected ? AppColors.lancar : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            const Text('Lokasi Anda ikut dikirim: Jalan Keputih, Surabaya', style: AppText.caption),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(backgroundColor: AppColors.emergency),
              icon: const Icon(Icons.call_end_rounded, size: 20),
              label: const Text('Akhiri Panggilan'),
            ),
            const SizedBox(height: 10),
            const Text('Jika panggilan terputus, hubungi 112 langsung.', style: AppText.caption),
          ],
        ),
      ),
    );
  }
}
