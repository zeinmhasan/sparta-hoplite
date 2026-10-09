import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/mock_data.dart' as mock;
import '../../data/models.dart';
import '../../data/state.dart';

class TransitScreen extends ConsumerStatefulWidget {
  const TransitScreen({super.key});

  @override
  ConsumerState<TransitScreen> createState() => _TransitScreenState();
}

class _TransitScreenState extends ConsumerState<TransitScreen> {
  int _tab = 0;

  Future<void> _pickDestination() async {
    final place = await pickDestination(context);
    if (place != null) ref.read(destinationProvider.notifier).state = place;
  }

  @override
  Widget build(BuildContext context) {
    final destination = ref.watch(destinationProvider);
    final plans = ref.watch(transitPlansProvider(destination));

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/assistant'),
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.auto_awesome_rounded, size: 20),
        label: const Text(
          'Transit Assistant',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const ScreenHeader(title: 'Transportasi Umum'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                children: [
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      children: [
                        TripFields(
                          from: mock.origin.name,
                          to: destination.name,
                          onTapFrom: () => toast(context, 'Lokasi Saya mengikuti posisi Anda saat ini'),
                          onTapTo: _pickDestination,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _TabButton(
                              label: 'Rute Tercepat',
                              selected: _tab == 0,
                              onTap: () => setState(() => _tab = 0),
                            ),
                            _TabButton(
                              label: 'Rute Terhemat',
                              selected: _tab == 1,
                              onTap: () => setState(() => _tab = 1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _NextBusCard(),
                  const SizedBox(height: 18),
                  const Text(
                    'Berikut rekomendasi perjalanan menggunakan Suroboyo Bus:',
                    style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  plans.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => Text('Rencana gagal dimuat: $error', style: AppText.caption),
                    data: (list) => _PlanCard(
                      key: ValueKey('$_tab-${destination.id}'),
                      plan: list[_tab],
                    ).animate().fadeIn(duration: 260.ms).slideY(begin: 0.05, end: 0),
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

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: selected ? AppColors.maroon : Colors.transparent, width: 2.5)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? AppColors.maroon : AppColors.text,
            ),
          ),
        ),
      ),
    );
  }
}

/// Kedatangan bus berikutnya di halte naik, diperbarui tiap detik.
class _NextBusCard extends ConsumerWidget {
  const _NextBusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    final bus = mock.nextBusAt(now);
    final minutes = mock.nextBusMinutes(now);

    return AppCard(
      color: AppColors.teal,
      onTap: () => context.push('/bus'),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(Icons.directions_bus_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const LiveDot(color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      'Bus ${mock.busCorridor} • ${bus.code}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Tiba di ${mock.boardingStop.name} dalam $minutes menit',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
            child: const Text(
              'Lacak Bus',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.teal),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({super.key, required this.plan});
  final TransitPlan plan;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_bus_rounded, color: AppColors.maroon),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  plan.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.maroon),
                ),
              ),
              StatusBadge(plan.level),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < plan.steps.length; i++) _StepRow(step: plan.steps[i], last: i == plan.steps.length - 1),
          const Divider(height: 28),
          // Ditumpuk ke bawah supaya tidak tertutup tombol Transit Assistant.
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text('Total waktu: ± ${plan.minutes} menit', style: AppText.bodyStrong.copyWith(fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.payments_outlined, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text('Estimasi biaya: ${plan.cost}', style: AppText.bodyStrong.copyWith(fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.last});
  final TransitStep step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final ride = step.kind == TransitStepKind.ride;
    final marker = switch (step.kind) {
      TransitStepKind.start => const Icon(Icons.radio_button_checked_rounded, color: AppColors.navy, size: 26),
      TransitStepKind.end => const Icon(Icons.location_on_rounded, color: AppColors.emergency, size: 26),
      TransitStepKind.ride => Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(7)),
        child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 16),
      ),
      TransitStepKind.walk => Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(7)),
        child: const Icon(Icons.transfer_within_a_station_rounded, color: Colors.white, size: 16),
      ),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                marker,
                if (!last) Expanded(child: Container(width: 2, color: AppColors.border)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: last ? 0 : 18),
              padding: ride ? const EdgeInsets.all(12) : const EdgeInsets.only(top: 2),
              decoration: ride
                  ? BoxDecoration(
                      color: AppColors.field,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title, style: AppText.bodyStrong.copyWith(color: ride ? AppColors.maroon : AppColors.text)),
                  const SizedBox(height: 3),
                  Text(step.subtitle, style: AppText.caption.copyWith(fontSize: 12.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
