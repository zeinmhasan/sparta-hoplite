import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/map_view.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/mock_data.dart' as mock;
import '../../data/models.dart';
import '../../data/state.dart';
import 'departure.dart';

String trafficSentence(TrafficLevel level) => 'Lalu lintas ${level.label.toLowerCase()}';

/// Jam tiba jika berangkat pada waktu berangkat terpilih.
String arrivalLabel(Departure departure, int minutes) =>
    'Tiba ${formatClock(departure.time.add(Duration(minutes: minutes)))}';

class RouteScreen extends ConsumerWidget {
  const RouteScreen({super.key});

  Future<void> _pickDestination(BuildContext context, WidgetRef ref) async {
    final place = await pickDestination(context);
    if (place != null) ref.read(destinationProvider.notifier).state = place;
  }

  Future<void> _pickDeparture(BuildContext context, WidgetRef ref) async {
    final picked = await showDepartureSheet(
      context,
      current: ref.read(departureProvider),
      routes: ref.read(tripRoutesProvider).value,
      mode: ref.read(vehicleModeProvider),
    );
    if (picked != null) ref.read(departureProvider.notifier).state = picked;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = ref.watch(destinationProvider);
    final swapped = ref.watch(swappedProvider);
    final departure = ref.watch(departureProvider);
    final mode = ref.watch(vehicleModeProvider);
    final routes = ref.watch(tripRoutesProvider);

    void pick() => _pickDestination(context, ref);
    void fixed() => toast(context, 'Lokasi Saya mengikuti posisi Anda saat ini');

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const ScreenHeader(title: 'Rute Terbaik'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                AppCard(
                  child: TripFields(
                    from: swapped ? destination.name : mock.origin.name,
                    to: swapped ? mock.origin.name : destination.name,
                    onTapFrom: swapped ? pick : fixed,
                    onTapTo: swapped ? fixed : pick,
                    trailing: Material(
                      color: AppColors.field,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Tukar asal dan tujuan',
                        icon: AnimatedRotation(
                          turns: swapped ? 0.5 : 0,
                          duration: const Duration(milliseconds: 250),
                          child: const Icon(Icons.swap_vert_rounded, color: AppColors.navy),
                        ),
                        onPressed: () => ref.read(swappedProvider.notifier).state = !swapped,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    for (final m in VehicleMode.values) ...[
                      _ModeChip(
                        mode: m,
                        selected: m == mode,
                        onTap: () => ref.read(vehicleModeProvider.notifier).state = m,
                      ),
                      const SizedBox(width: 10),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                DepartureButton(departure: departure, onTap: () => _pickDeparture(context, ref)),
                const SizedBox(height: 16),
                routes.when(
                  loading: () => const _RouteSkeleton(),
                  error: (error, _) => _RouteError(onRetry: () => ref.invalidate(routesProvider(destination))),
                  // Kunci baru tiap pilihan berubah, supaya kartu muncul ulang dengan animasi.
                  data: (list) => Column(
                    key: ValueKey('$departure-$mode-${destination.id}-$swapped'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _routeCards(context, rankRoutes(list, departure, mode), departure, mode),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _routeCards(BuildContext context, List<RouteOption> ranked, Departure departure, VehicleMode mode) {
    final best = ranked.first;
    final saved = ranked.length > 1 ? ranked[1].minutes(departure, mode) - best.minutes(departure, mode) : 0;
    void open(RouteOption route) => context.push('/route-detail/${route.index}');

    return [
      _RecommendedCard(
        route: best,
        minutes: best.minutes(departure, mode),
        arrival: arrivalLabel(departure, best.minutes(departure, mode)),
        level: best.level(departure),
        saved: saved,
        onTap: () => open(best),
      ),
      for (var i = 1; i < ranked.length; i++) ...[
        const SizedBox(height: 12),
        _AlternativeCard(
          title: 'Rute Alternatif $i',
          route: ranked[i],
          minutes: ranked[i].minutes(departure, mode),
          arrival: arrivalLabel(departure, ranked[i].minutes(departure, mode)),
          level: ranked[i].level(departure),
          extra: ranked[i].minutes(departure, mode) - best.minutes(departure, mode),
          onTap: () => open(ranked[i]),
        ),
      ],
      if (ranked.length > 1) ...[
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => _showComparison(context, ranked, departure, mode),
          icon: const Icon(Icons.compare_arrows_rounded, size: 20),
          label: const Text('Lihat Perbandingan Rute'),
          style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
        ),
      ],
    ].animate(interval: 50.ms).fadeIn(duration: 260.ms);
  }
}

class _RouteError extends StatelessWidget {
  const _RouteError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 36, color: AppColors.textSecondary),
          const SizedBox(height: 10),
          const Text(
            'Rute ke tempat ini belum bisa dihitung. Periksa koneksi internet, lalu coba lagi.',
            textAlign: TextAlign.center,
            style: AppText.body,
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.mode, required this.selected, required this.onTap});
  final VehicleMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.text;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.maroon : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? AppColors.maroon : AppColors.border),
        ),
        child: Row(
          children: [
            Icon(mode.icon, size: 18, color: fg),
            const SizedBox(width: 8),
            Text(
              mode.label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendedCard extends StatelessWidget {
  const _RecommendedCard({
    required this.route,
    required this.minutes,
    required this.arrival,
    required this.level,
    required this.saved,
    required this.onTap,
  });

  final RouteOption route;
  final int minutes;
  final String arrival;
  final TrafficLevel level;
  final int saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.maroon,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFFFFC55A)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'RUTE REKOMENDASI AI',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: Colors.white),
                ),
              ),
              if (saved > 0)
                Text('$saved menit lebih cepat', style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'ETA $minutes menit',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text('$arrival • ${route.kmLabel}', style: const TextStyle(fontSize: 14, color: Colors.white70)),
              ),
              StatusBadge(level, label: trafficSentence(level), onDark: true),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 150,
              child: IgnorePointer(
                child: AppMap(
                  fitPoints: route.points,
                  interactive: false,
                  padding: const EdgeInsets.all(26),
                  layers: [
                    plainLine(route.points),
                    MarkerLayer(
                      markers: [
                        dotMarker(route.points.first, AppColors.navy),
                        dotMarker(route.points.last, AppColors.emergency, size: 22),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'via ${route.via}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
              const Text(
                'Lihat detail',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlternativeCard extends StatelessWidget {
  const _AlternativeCard({
    required this.title,
    required this.route,
    required this.minutes,
    required this.arrival,
    required this.level,
    required this.extra,
    required this.onTap,
  });

  final String title;
  final RouteOption route;
  final int minutes;
  final String arrival;
  final TrafficLevel level;
  final int extra;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppText.bodyStrong.copyWith(fontSize: 13))),
              Text('+$extra menit', style: AppText.caption),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ETA $minutes menit',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
                    ),
                    const SizedBox(height: 2),
                    Text('$arrival • ${route.kmLabel}', style: AppText.caption.copyWith(fontSize: 13)),
                  ],
                ),
              ),
              StatusBadge(level),
            ],
          ),
          const SizedBox(height: 8),
          Text('via ${route.via}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
        ],
      ),
    );
  }
}

class _RouteSkeleton extends StatelessWidget {
  const _RouteSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double height) => Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: const Color(0xFFEDEAE8), borderRadius: BorderRadius.circular(16)),
    );
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 10),
              Text('AI menghitung rute terbaik...', style: AppText.caption),
            ],
          ),
        ),
        block(280),
        block(96),
        block(96),
      ],
    ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.55, end: 1, duration: 700.ms);
  }
}

void _showComparison(BuildContext context, List<RouteOption> ranked, Departure departure, VehicleMode mode) {
  Widget cell(String text, {bool head = false, bool strong = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
    child: Text(
      text,
      style: head ? AppText.caption : AppText.body.copyWith(fontWeight: strong ? FontWeight.w700 : FontWeight.w400),
    ),
  );

  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const Text('Perbandingan Rute', style: AppText.sectionTitle),
            const SizedBox(height: 4),
            Text(departureLabel(departure), style: AppText.caption),
            const SizedBox(height: 10),
            Table(
              columnWidths: const {0: FlexColumnWidth(1.5), 4: FlexColumnWidth(1.3)},
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: const TableBorder(horizontalInside: BorderSide(color: AppColors.border)),
              children: [
                TableRow(
                  children: [
                    cell('Rute', head: true),
                    cell('Waktu', head: true),
                    cell('Jarak', head: true),
                    cell('Simpang', head: true),
                    cell('Kepadatan', head: true),
                  ],
                ),
                for (var i = 0; i < ranked.length; i++)
                  TableRow(
                    children: [
                      cell(i == 0 ? 'Rekomendasi AI' : 'Alternatif $i', strong: i == 0),
                      cell('${ranked[i].minutes(departure, mode)} mnt', strong: i == 0),
                      cell(ranked[i].kmLabel),
                      cell('${ranked[i].intersections.length} lampu'),
                      Align(alignment: Alignment.centerLeft, child: StatusBadge(ranked[i].level(departure))),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
