import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'theme.dart';

/// Kerangka dengan navigasi bawah: Home, Route, tombol tengah (Pulse Report),
/// Transit, Profile.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Tombol kembali Android membawa ke Home dulu, baru keluar aplikasi.
      canPop: location == '/home',
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: Scaffold(
        body: child,
        bottomNavigationBar: _NavBar(location: location),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.location});
  final String location;

  @override
  Widget build(BuildContext context) {
    Widget item(String path, String label, IconData icon, IconData activeIcon) {
      final active = location == path;
      final color = active ? AppColors.maroon : AppColors.text;
      return Expanded(
        child: InkResponse(
          onTap: () => context.go(path),
          radius: 36,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(active ? activeIcon : icon, color: color, size: 24),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: color),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: SizedBox(
        height: 92,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 68,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [BoxShadow(color: Color(0x1F000000), blurRadius: 18, offset: Offset(0, 4))],
              ),
              child: Row(
                children: [
                  item('/home', 'Home', Icons.home_outlined, Icons.home_rounded),
                  item('/route', 'Route', Icons.alt_route_rounded, Icons.alt_route_rounded),
                  const SizedBox(width: 76),
                  item('/transit', 'Transit', Icons.directions_bus_outlined, Icons.directions_bus_rounded),
                  item('/profile', 'Profile', Icons.person_outline_rounded, Icons.person_rounded),
                ],
              ),
            ),
            Positioned(
              top: 0,
              child: Material(
                color: AppColors.maroon,
                shape: const CircleBorder(side: BorderSide(color: AppColors.background, width: 4)),
                elevation: location == '/pulse' ? 8 : 4,
                shadowColor: AppColors.maroon,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => context.go('/pulse'),
                  child: const SizedBox(
                    width: 68,
                    height: 68,
                    child: Icon(Icons.sensors_rounded, color: Colors.white, size: 30),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
