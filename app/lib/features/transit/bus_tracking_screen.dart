import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/map_view.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/mock_data.dart' as mock;
import '../../data/state.dart';

class BusTrackingScreen extends ConsumerWidget {
  const BusTrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    final buses = mock.busesAt(now);
    final tracked = mock.nextBusAt(now);
    final minutes = mock.nextBusMinutes(now);
    final occupancy = tracked.occupancy;
    final seatLabel = occupancy < 0.5 ? 'Banyak kursi kosong' : (occupancy < 0.75 ? 'Kursi tersedia' : 'Hampir penuh');
    final seatColor = occupancy < 0.5 ? AppColors.lancar : (occupancy < 0.75 ? AppColors.sedang : AppColors.padat);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                AppMap(
                  fitPoints: mock.busLine.points,
                  padding: const EdgeInsets.fromLTRB(36, 96, 36, 36),
                  layers: [
                    plainLine(mock.busLine.points, color: AppColors.teal),
                    MarkerLayer(
                      markers: [
                        for (final stop in mock.busStops)
                          stop.name == mock.boardingStop.name
                              ? iconMarker(
                                  mock.busLine.at(stop.fraction),
                                  Icons.person_pin_circle_rounded,
                                  AppColors.navy,
                                )
                              : dotMarker(mock.busLine.at(stop.fraction), AppColors.teal, size: 14),
                        for (final bus in buses)
                          iconMarker(
                            bus.position,
                            Icons.directions_bus_rounded,
                            bus.index == tracked.index ? AppColors.maroon : const Color(0xFF8A8A90),
                            size: bus.index == tracked.index ? 40 : 30,
                          ),
                      ],
                    ),
                  ],
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      children: [
                        MapButton(icon: Icons.arrow_back_rounded, onTap: () => context.pop()),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(99),
                            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2))],
                          ),
                          child: const Row(
                            children: [
                              LiveDot(),
                              SizedBox(width: 8),
                              Text('Posisi langsung', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 6,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                boxShadow: [BoxShadow(color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, -4))],
              ),
              child: SafeArea(
                top: false,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.maroon.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.directions_bus_rounded, color: AppColors.maroon),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Suroboyo Bus ${mock.busCorridor} • ${tracked.code}', style: AppText.cardTitle),
                              const SizedBox(height: 2),
                              const Text('Arah Keputih - Tunjungan', style: AppText.caption),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$minutes mnt',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.maroon,
                              ),
                            ),
                            Text('ke ${mock.boardingStop.name}', style: AppText.caption),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.event_seat_outlined, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          'Keterisian ${(occupancy * 100).round()}%',
                          style: AppText.bodyStrong.copyWith(fontSize: 13),
                        ),
                        const Spacer(),
                        Text(
                          seatLabel,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: seatColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: occupancy,
                        minHeight: 6,
                        backgroundColor: AppColors.field,
                        valueColor: AlwaysStoppedAnimation(seatColor),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SectionLabel('Halte di koridor ini'),
                    const SizedBox(height: 6),
                    for (final stop in mock.busStops)
                      _StopRow(
                        name: stop.name,
                        minutes: tracked.minutesTo(stop),
                        boarding: stop.name == mock.boardingStop.name,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  const _StopRow({required this.name, required this.minutes, required this.boarding});
  final String name;
  final int? minutes;
  final bool boarding;

  @override
  Widget build(BuildContext context) {
    final passed = minutes == null;
    return Opacity(
      opacity: passed ? 0.45 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(
              passed
                  ? Icons.check_circle_rounded
                  : (boarding ? Icons.person_pin_circle_rounded : Icons.circle_outlined),
              size: boarding && !passed ? 22 : 18,
              color: passed ? AppColors.lancar : (boarding ? AppColors.navy : AppColors.teal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                boarding ? '$name (halte naik Anda)' : name,
                style: boarding ? AppText.bodyStrong : AppText.body,
              ),
            ),
            Text(
              passed ? 'Terlewati' : (minutes == 0 ? 'Tiba' : '$minutes mnt'),
              style: AppText.bodyStrong.copyWith(
                fontSize: 13,
                color: boarding && !passed ? AppColors.maroon : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
