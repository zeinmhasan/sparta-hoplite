import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/state.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  void _open(BuildContext context, AppNotification item) {
    final route = item.route;
    if (route == null) return toast(context, 'Tidak ada tindak lanjut untuk notifikasi ini');
    // Tab kerangka dibuka dengan go; layar lain ditumpuk di atas notifikasi.
    route == '/route' ? context.go(route) : context.push(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'Notifikasi'),
            Expanded(
              child: items.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('Gagal memuat: $error', style: AppText.caption)),
                data: (list) => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    for (final item in list) ...[
                      AppCard(
                        onTap: () => _open(context, item),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: item.color.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(item.icon, color: item.color, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title, style: AppText.bodyStrong),
                                  const SizedBox(height: 4),
                                  Text(item.body, style: AppText.caption.copyWith(height: 1.4)),
                                  const SizedBox(height: 6),
                                  Text(item.time, style: AppText.caption.copyWith(fontSize: 11)),
                                ],
                              ),
                            ),
                            if (item.unread)
                              Container(
                                width: 9,
                                height: 9,
                                margin: const EdgeInsets.only(left: 8, top: 4),
                                decoration: const BoxDecoration(color: AppColors.emergency, shape: BoxShape.circle),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ].animate(interval: 50.ms).fadeIn(duration: 260.ms).slideY(begin: 0.06, end: 0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
