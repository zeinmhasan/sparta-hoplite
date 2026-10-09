import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) context.go('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 132,
            ).animate().fadeIn(duration: 500.ms).scaleXY(begin: 0.85, end: 1, curve: Curves.easeOutBack),
            const SizedBox(height: 20),
            const Text(
              'SPARTA Hoplite',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.maroon, letterSpacing: -0.5),
            ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
            const SizedBox(height: 6),
            const Text(
              'Asisten perjalanan warga Surabaya',
              style: AppText.caption,
            ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }
}
