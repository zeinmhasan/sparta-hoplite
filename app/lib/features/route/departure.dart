import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/state.dart';

String departureLabel(Departure departure) => 'Berangkat ${departure.label}';

/// Tombol pemilih hari dan jam berangkat. Prediksi kemacetan mengikuti pilihan ini.
class DepartureButton extends StatelessWidget {
  const DepartureButton({super.key, required this.departure, required this.onTap});
  final Departure departure;
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
                    Text(departureLabel(departure), style: AppText.bodyStrong),
                    const SizedBox(height: 2),
                    Text(
                      departure.isNow
                          ? 'Ketuk untuk memilih hari dan jam berangkat'
                          : 'Kemacetan diprediksi untuk hari dan jam ini',
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

/// Jumlah hari yang bisa dipilih, mulai hari ini.
const _days = 7;

/// Jam berangkat yang bisa dipilih pada hari ke-[offset] dari hari ini. Hari ini
/// dimulai dari "Sekarang" lalu jam-jam berikutnya; hari lain 05.00 sampai 23.00.
List<Departure> _options(DateTime now, int offset) {
  if (offset == 0) {
    return [
      Departure.now,
      for (var h = now.hour + 1; h < 24; h++) Departure.at(DateTime(now.year, now.month, now.day, h)),
    ];
  }
  return [for (var h = 5; h < 24; h++) Departure.at(DateTime(now.year, now.month, now.day + offset, h))];
}

/// Pemilih hari lalu jam berangkat. Tiap jam menampilkan ETA dan kepadatan rute
/// terbaiknya supaya perbedaannya langsung terlihat.
Future<Departure?> showDepartureSheet(
  BuildContext context, {
  required Departure current,
  required List<RouteOption>? routes,
  required VehicleMode mode,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final picked = current.time;
  var day = DateTime(picked.year, picked.month, picked.day).difference(today).inDays.clamp(0, _days - 1);

  return showModalBottomSheet<Departure>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final options = _options(now, day);
        final best = {
          if (routes != null && routes.isNotEmpty)
            for (final d in options) d: rankRoutes(routes, d, mode).first,
        };
        final fastest = best.isEmpty
            ? null
            : options.reduce((a, b) => best[b]!.minutes(b, mode) < best[a]!.minutes(a, mode) ? b : a);

        return SafeArea(
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
                      Text(
                        'AI memprediksi kemacetan dari pola lalu lintas pada hari dan jam yang sama.',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _days,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => ChoiceChip(
                      label: Text(Departure.dayLabel(today.add(Duration(days: i)), now)),
                      selected: i == day,
                      showCheckmark: false,
                      selectedColor: AppColors.maroon,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: i == day ? Colors.white : AppColors.text,
                      ),
                      onSelected: (_) => setState(() => day = i),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: ListView(
                    key: ValueKey(day),
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 12),
                    children: [
                      for (final d in options)
                        _DepartureRow(
                          departure: d,
                          selected: d == current,
                          fastest: d == fastest,
                          minutes: best[d]?.minutes(d, mode),
                          level: best[d]?.level(d),
                          onTap: () => Navigator.of(context).pop(d),
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

class _DepartureRow extends StatelessWidget {
  const _DepartureRow({
    required this.departure,
    required this.selected,
    required this.fastest,
    required this.minutes,
    required this.level,
    required this.onTap,
  });

  final Departure departure;
  final bool selected;
  final bool fastest;
  final int? minutes;
  final TrafficLevel? level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final time = departure.time;
    final clock = formatClock(time).replaceAll(':', '.');
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
                      Text(departure.isNow ? 'Sekarang' : clock, style: AppText.bodyStrong),
                      if (fastest) ...[const SizedBox(width: 8), const AiBadge(label: 'Tercepat')],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    departure.isNow ? 'Berangkat $clock' : '${dayNames[time.weekday - 1]}, $clock',
                    style: AppText.caption,
                  ),
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
