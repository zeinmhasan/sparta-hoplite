import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/state.dart';
import 'intersection_row.dart';
import 'nav_sim.dart';

/// Banner atas navigasi: arah belok berikutnya, jaraknya, lampu simpang itu,
/// dan saran kecepatan agar tiba saat hijau.
class GuidanceBanner extends StatelessWidget {
  const GuidanceBanner({super.key, required this.route, required this.frame, required this.now});
  final RouteOption route;
  final NavFrame frame;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final total = route.sampler.totalMeters;
    final next = nextIntersection(route, frame.meters);
    final distance = (next == null ? total : next.fraction * total) - frame.meters;
    final light = next?.stateAt(now);
    final turn = next == null ? null : turnAt(route, next);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Row(
            children: [
              Icon(turn?.icon ?? Icons.flag_rounded, color: Colors.white, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      distanceLabel(distance),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      next == null ? 'Lurus sampai tujuan' : '${turn!.verb} Jl. ${next.roads.last}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (light != null) ...[const SizedBox(width: 10), LightCountdown(light, onDark: true)],
            ],
          ),
        ),
        // Tab kecil di bawah banner, seperti "Then" di aplikasi peta.
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 14, 9),
          decoration: const BoxDecoration(
            color: Color(0xFF123A8C),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
            boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sync_rounded, size: 15, color: Color(0xFFFFC55A)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  lightAdvice(route, frame, now),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tombol bulat putih di atas peta navigasi; berisi ikon atau label pendek.
class NavRoundButton extends StatelessWidget {
  const NavRoundButton({super.key, this.icon, this.label, required this.onTap});
  final IconData? icon;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: Colors.black38,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Center(
            child: icon != null
                ? Icon(icon, color: AppColors.maroon, size: 22)
                : Text(
                    label!,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.maroon),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Muncul saat pengguna menggeser peta sendiri; mengembalikan kamera ke kendaraan.
class RecenterButton extends StatelessWidget {
  const RecenterButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.navy,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 18),
      ),
      icon: const Icon(Icons.navigation_rounded, size: 18),
      label: const Text('Pusatkan', style: TextStyle(fontSize: 14)),
    );
  }
}

class Speedometer extends StatelessWidget {
  const Speedometer({super.key, required this.kmh});
  final int kmh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$kmh',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, height: 1, color: AppColors.text),
          ),
          const SizedBox(height: 2),
          const Text('km/jam', style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Bilah bawah navigasi: tombol keluar, sisa waktu, sisa jarak, dan jam tiba.
class NavBottomBar extends StatelessWidget {
  const NavBottomBar({
    super.key,
    required this.route,
    required this.minutes,
    required this.meters,
    required this.now,
    required this.onClose,
  });

  final RouteOption route;
  final int minutes;
  final double meters;
  final DateTime now;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final left = 1 - meters / route.sampler.totalMeters;
    final minutesLeft = math.max(1, (minutes * left).ceil());
    final kmLeft = (route.km * left).toStringAsFixed(1).replaceAll('.', ',');
    final arrival = formatClock(now.add(Duration(minutes: minutesLeft))).replaceAll(':', '.');

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Color(0x26000000), blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            children: [
              Material(
                color: AppColors.field,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Akhiri navigasi',
                  iconSize: 26,
                  padding: const EdgeInsets.all(12),
                  icon: const Icon(Icons.close_rounded, color: AppColors.text),
                  onPressed: onClose,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '$minutesLeft mnt',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: AppColors.lancar,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text('$kmLeft km • Tiba $arrival', style: AppText.caption.copyWith(fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 50),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lembar daftar semua lampu di rute. [metersNow] dibaca tiap detik untuk
/// menandai simpang yang sudah dilewati.
void showLightsSheet(
  BuildContext context, {
  required RouteOption route,
  required int minutes,
  required double Function() metersNow,
}) {
  final total = route.sampler.totalMeters;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Consumer(
        builder: (context, ref, _) {
          final now = ref.watch(nowProvider);
          final meters = metersNow();
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SheetHandle(),
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
                for (var i = 0; i < route.intersections.length; i++)
                  IntersectionRow(
                    number: i + 1,
                    intersection: route.intersections[i],
                    now: now,
                    minutesAway: math.max(0, ((route.intersections[i].fraction - meters / total) * minutes).round()),
                    passed: meters > route.intersections[i].fraction * total,
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
