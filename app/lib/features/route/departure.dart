import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/state.dart';

/// Jam pada saat berangkat sesuai pilihan, misalnya "16.30".
String departureClock(DateTime now, Horizon horizon) =>
    formatClock(now.add(Duration(minutes: horizon.minutes))).replaceAll(':', '.');

String departureLabel(DateTime now, Horizon horizon) =>
    horizon == Horizon.now ? 'Berangkat sekarang' : 'Berangkat ${horizon.label} • ${departureClock(now, horizon)}';

/// Tombol pemilih jam berangkat. Prediksi kemacetan mengikuti jam ini.
class DepartureButton extends StatelessWidget {
  const DepartureButton({super.key, required this.horizon, required this.onTap});
  final Horizon horizon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.schedule_rounded, color: AppColors.maroon, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(departureLabel(DateTime.now(), horizon), style: AppText.bodyStrong),
                    const SizedBox(height: 2),
                    Text(
                      horizon == Horizon.now
                          ? 'Ketuk untuk melihat prediksi hingga 6 jam ke depan'
                          : 'Kemacetan diprediksi untuk jam berangkat ini',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Daftar jam berangkat sampai 6 jam ke depan, masing-masing dengan ETA dan
/// kepadatan rute terbaiknya supaya perbedaannya langsung terlihat.
Future<Horizon?> showDepartureSheet(
  BuildContext context, {
  required Horizon current,
  required List<RouteOption>? routes,
  required VehicleMode mode,
}) {
  final now = DateTime.now();
  final best = {
    if (routes != null && routes.isNotEmpty)
      for (final h in Horizon.values) h: rankRoutes(routes, h, mode).first,
  };
  final fastest = best.isEmpty
      ? null
      : Horizon.values.reduce((a, b) => best[b]!.minutes(b, mode) < best[a]!.minutes(a, mode) ? b : a);

  return showModalBottomSheet<Horizon>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.82),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kapan Anda berangkat?', style: AppText.sectionTitle),
                  SizedBox(height: 4),
                  Text('AI memprediksi kemacetan hingga 6 jam ke depan.', style: AppText.caption),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  for (final h in Horizon.values)
                    _DepartureRow(
                      horizon: h,
                      clock: departureClock(now, h),
                      selected: h == current,
                      fastest: h == fastest,
                      minutes: best[h]?.minutes(h, mode),
                      level: best[h]?.level(h),
                      onTap: () => Navigator.of(context).pop(h),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DepartureRow extends StatelessWidget {
  const _DepartureRow({
    required this.horizon,
    required this.clock,
    required this.selected,
    required this.fastest,
    required this.minutes,
    required this.level,
    required this.onTap,
  });

  final Horizon horizon;
  final String clock;
  final bool selected;
  final bool fastest;
  final int? minutes;
  final TrafficLevel? level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: selected ? AppColors.maroon.withValues(alpha: 0.05) : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              color: selected ? AppColors.maroon : AppColors.border,
              size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(horizon.label, style: AppText.bodyStrong),
                      if (fastest) ...[const SizedBox(width: 8), const AiBadge(label: 'Tercepat')],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('Berangkat $clock', style: AppText.caption),
                ],
              ),
            ),
            if (minutes != null) ...[
              Text('$minutes mnt', style: AppText.bodyStrong.copyWith(fontSize: 15)),
              const SizedBox(width: 10),
              SizedBox(
                width: 92,
                child: Align(alignment: Alignment.centerRight, child: StatusBadge(level!)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
