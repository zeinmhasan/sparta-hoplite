import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';

/// Satu simpang berlampu di daftar: nama, perkiraan tiba, dan hitung mundur lampunya.
class IntersectionRow extends StatelessWidget {
  const IntersectionRow({
    super.key,
    required this.number,
    required this.intersection,
    required this.now,
    required this.minutesAway,
    this.passed = false,
  });

  final int number;
  final Intersection intersection;
  final DateTime now;
  final int minutesAway;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    final onArrival = intersection.stateAt(now.add(Duration(minutes: minutesAway)));
    return Opacity(
      opacity: passed ? 0.45 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.field, shape: BoxShape.circle),
              child: passed
                  ? const Icon(Icons.check_rounded, size: 16, color: AppColors.lancar)
                  : Text('$number', style: AppText.bodyStrong.copyWith(fontSize: 12)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    intersection.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong.copyWith(fontSize: 13.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    passed ? 'Sudah dilewati' : '±$minutesAway mnt lagi • saat tiba: ${onArrival.label.toLowerCase()}',
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            LightCountdown(intersection.stateAt(now)),
          ],
        ),
      ),
    );
  }
}
