import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'core/widgets.dart';
import 'data/models.dart';
import 'data/state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
  );
  runApp(const ProviderScope(child: HopliteApp()));
}

class HopliteApp extends ConsumerWidget {
  const HopliteApp({super.key});

  static final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Laporan suara pengguna yang baru terverifikasi langsung menambah saldo.
    ref.listen(verifiedOwnReportsProvider, (previous, next) {
      final messenger = _messenger.currentState;
      if (previous == null || messenger == null || next.length <= previous.length) return;
      rewardToast(
        messenger,
        'Laporan ${next.first.title.toLowerCase()} terverifikasi',
        rewardPerReport,
        onOpen: () => router.push('/rewards'),
      );
    });

    return MaterialApp.router(
      title: 'SPARTA Hoplite',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      scaffoldMessengerKey: _messenger,
      routerConfig: router,
    );
  }
}
