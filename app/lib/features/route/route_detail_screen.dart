import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/map_view.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/mock_data.dart' as mock;
import '../../data/state.dart';
import 'departure.dart';
import 'intersection_row.dart';
import 'route_screen.dart';

/// Ringkasan satu rute: peta, prediksi untuk jam berangkat terpilih, dan lampu
/// lalu lintas yang dilewati. Navigasinya dibuka sebagai layar penuh tersendiri.
class RouteDetailScreen extends ConsumerWidget {
  const RouteDetailScreen({super.key, required this.routeIndex});
  final int routeIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routes = ref.watch(tripRoutesProvider).value;
    if (routes == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final route = routes.firstWhere((r) => r.index == routeIndex);
    final goal = ref.watch(swappedProvider) ? mock.origin.name : ref.watch(destinationProvider).name;
    final horizon = ref.watch(horizonProvider);
    final mode = ref.watch(vehicleModeProvider);
    final now = ref.watch(nowProvider);
    final minutes = route.minutes(horizon, mode);
    final isBest = rankRoutes(routes, horizon, mode).first.index == route.index;

    return Scaffold(
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.42,
            child: Stack(
              children: [
                AppMap(
                  fitPoints: route.points,
                  padding: const EdgeInsets.fromLTRB(40, 96, 40, 44),
                  layers: [
                    trafficLine(route, horizon),
                    MarkerLayer(
                      markers: [
                        dotMarker(route.points.first, AppColors.navy),
                        iconMarker(route.points.last, Icons.flag_rounded, AppColors.emergency),
                        for (final x in route.intersections)
                          iconMarker(
                            route.sampler.at(x.fraction),
                            Icons.traffic_rounded,
                            x.stateAt(now).color,
                            size: 24,
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
                        _Pill(
                          icon: isBest ? Icons.auto_awesome_rounded : Icons.alt_route_rounded,
                          label: isBest ? 'Rute Rekomendasi AI' : 'Rute Alternatif',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                boxShadow: [BoxShadow(color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, -4))],
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ETA $minutes menit',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.text),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${arrivalLabel(now, horizon, minutes)} • ${route.kmLabel} • $goal',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption.copyWith(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(route.level(horizon)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const SectionLabel('Prediksi kemacetan'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.schedule_rounded, size: 18, color: AppColors.maroon),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(departureLabel(now, horizon), style: AppText.bodyStrong.copyWith(fontSize: 13)),
                              const SizedBox(height: 3),
                              Text(mock.routeNote(route, horizon), style: AppText.caption.copyWith(height: 1.4)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const SectionLabel(
                    'Lampu lalu lintas di rute ini',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LiveDot(),
                        SizedBox(width: 6),
                        Text(
                          'Tersinkron ATCS',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.lancar),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (route.intersections.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Tidak ada simpang berlampu di rute ini.', style: AppText.caption),
                    ),
                  for (var i = 0; i < route.intersections.length; i++)
                    IntersectionRow(
                      number: i + 1,
                      intersection: route.intersections[i],
                      now: now,
                      minutesAway: (route.intersections[i].fraction * minutes).round(),
                    ),
                ],
              ),
            ),
          ),
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SafeArea(
              top: false,
              child: FilledButton.icon(
                onPressed: () => context.push('/navigate/${route.index}'),
                icon: const Icon(Icons.navigation_rounded, size: 20),
                label: const Text('Mulai Navigasi'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.maroon,
        borderRadius: BorderRadius.circular(99),
        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFFFFC55A)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
