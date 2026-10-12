import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/community/community_detail_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/insights_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/panic/panic_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/pulse/evidence_camera_screen.dart';
import '../features/pulse/my_reports_screen.dart';
import '../features/pulse/pulse_screen.dart';
import '../features/rewards/rewards_screen.dart';
import '../features/rewards/voucher_screen.dart';
import '../features/route/navigation_3d_screen.dart';
import '../features/route/navigation_screen.dart';
import '../features/route/route_detail_screen.dart';
import '../features/route/route_screen.dart';
import '../features/search/search_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/transit/assistant_screen.dart';
import '../features/transit/bus_tracking_screen.dart';
import '../features/transit/transit_screen.dart';
import '../features/voice/intent.dart';
import 'shell.dart';

/// Tab di dalam kerangka berganti dengan fade singkat, bukan geser.
GoRoute _tab(String path, Widget screen) => GoRoute(
  path: path,
  pageBuilder: (context, state) => CustomTransitionPage(
    key: state.pageKey,
    child: screen,
    transitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
  ),
);

final router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    ShellRoute(
      builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
      routes: [
        _tab('/home', const HomeScreen()),
        _tab('/route', const RouteScreen()),
        _tab('/transit', const TransitScreen()),
        _tab('/profile', const ProfileScreen()),
        _tab('/pulse', const PulseScreen()),
        _tab('/panic', const PanicScreen()),
      ],
    ),
    GoRoute(
      path: '/route-detail/:index',
      builder: (context, state) => RouteDetailScreen(routeIndex: int.parse(state.pathParameters['index']!)),
    ),
    // Navigasi 3D memakai peta vektor; web dan cadangan memakai navigasi di atas peta ubin.
    GoRoute(
      path: '/navigate/:index',
      builder: (context, state) {
        final index = int.parse(state.pathParameters['index']!);
        return kIsWeb ? NavigationScreen(routeIndex: index) : Navigation3dScreen(routeIndex: index);
      },
    ),
    GoRoute(
      path: '/navigate-2d/:index',
      builder: (context, state) => NavigationScreen(routeIndex: int.parse(state.pathParameters['index']!)),
    ),
    GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
    GoRoute(path: '/bus', builder: (context, state) => const BusTrackingScreen()),
    GoRoute(path: '/assistant', builder: (context, state) => const AssistantScreen()),
    GoRoute(path: '/insights', builder: (context, state) => const InsightsScreen()),
    GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
    GoRoute(
      path: '/report-camera',
      builder: (context, state) => EvidenceCameraScreen(report: state.extra! as ClassifiedReport),
    ),
    GoRoute(
      path: '/community/:id',
      builder: (context, state) => CommunityDetailScreen(reportId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/rewards', builder: (context, state) => const RewardsScreen()),
    GoRoute(
      path: '/voucher/:id',
      builder: (context, state) => VoucherScreen(voucherId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/reports', builder: (context, state) => const MyReportsScreen()),
    GoRoute(
      path: '/reports/:id',
      builder: (context, state) => ReportDetailScreen(reportId: state.pathParameters['id']!),
    ),
  ],
);
