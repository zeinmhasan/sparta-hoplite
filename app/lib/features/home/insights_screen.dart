import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/mock_data.dart' as mock;
import '../../data/models.dart';
import '../../data/state.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(overviewProvider).value?.insights ?? mock.insights;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'AI Traffic Insight'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  const Text('Prediksi kepadatan dari model SPARTA untuk ruas utama Surabaya.', style: AppText.caption),
                  const SizedBox(height: 14),
                  for (final insight in insights) ...[
                    AppCard(
                      onTap: () => showInsightSheet(context, insight),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 52,
                            decoration: BoxDecoration(
                              color: insight.level.color,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(insight.road, style: AppText.cardTitle),
                                const SizedBox(height: 4),
                                Text(insight.when, style: AppText.caption),
                              ],
                            ),
                          ),
                          StatusBadge(insight.level),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ].animate(interval: 60.ms).fadeIn(duration: 280.ms).slideY(begin: 0.06, end: 0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showInsightSheet(BuildContext context, Insight insight) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            Row(
              children: [
                const AiBadge(label: 'Prediksi AI'),
                const Spacer(),
                StatusBadge(insight.level),
              ],
            ),
            const SizedBox(height: 12),
            Text(insight.road, style: AppText.sectionTitle),
            const SizedBox(height: 2),
            Text(insight.when, style: AppText.caption),
            const SizedBox(height: 14),
            Text(insight.detail, style: AppText.body.copyWith(height: 1.5)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, size: 18, color: AppColors.gold),
                  const SizedBox(width: 10),
                  Expanded(child: Text(insight.advice, style: AppText.body.copyWith(fontSize: 13, height: 1.45))),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text('Keyakinan model', style: AppText.caption),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: insight.confidence / 100,
                      minHeight: 6,
                      backgroundColor: AppColors.field,
                      valueColor: const AlwaysStoppedAnimation(AppColors.maroon),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${insight.confidence}%', style: AppText.bodyStrong),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                context.go('/route');
              },
              icon: const Icon(Icons.alt_route_rounded, size: 20),
              label: const Text('Cari Rute Alternatif'),
            ),
          ],
        ),
      ),
    ),
  );
}
