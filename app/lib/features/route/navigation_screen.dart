import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/map_view.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/state.dart';
import '../voice/voice_widgets.dart';
import 'nav_sim.dart';
import 'nav_widgets.dart';
import 'trip_session.dart';

const _zoom = 17.0;

// Efek miring: peta ubin digambar lebih besar dari layar, lalu direbahkan ke
// belakang dengan perspektif. Sumbu rebahnya tepat di posisi kendaraan,
// sehingga panah tidak bergeser saat kemiringan berubah.
const _maxTilt = 52 * math.pi / 180;
const _perspective = 0.0006;

/// Tinggi peta (dp) yang digambar di depan dan di belakang kendaraan.
const _mapAhead = 1500.0;
const _mapBehind = 380.0;
const _haze = Color(0xFFE6ECF0);

/// Navigasi cadangan di atas peta ubin biasa: tanpa gedung dan kendaraan 3D,
/// tetapi tidak bergantung pada mesin peta vektor. Dipakai di web, dan bisa
/// dibuka dari navigasi 3D jika peta vektornya gagal dimuat.
class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key, required this.routeIndex});
  final int routeIndex;

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> with TickerProviderStateMixin {
  final _map = MapController();
  final _frame = ValueNotifier<NavFrame?>(null);
  late final Ticker _ticker = createTicker(_onTick);

  /// 1 = miring penuh (3D), 0 = tegak lurus dari atas (2D).
  late final _tilt = AnimationController(vsync: this, duration: const Duration(milliseconds: 450), value: 1);

  TripSession? _trip;
  Duration _lastTick = Duration.zero;

  /// False saat pengguna menggeser atau memutar peta sendiri.
  bool _following = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final routes = ref.read(tripRoutesProvider).value;
      if (routes == null) return context.pop();
      // Saat rute berganti atas saran co-pilot, layar dibangun ulang dengan rute baru.
      void rebuild() {
        if (mounted) setState(() {});
      }

      _trip = TripSession(ref, widget.routeIndex, onReroute: rebuild);
      rebuild();
      _ticker.start();
    });
  }

  @override
  void dispose() {
    _trip?.close();
    _ticker.dispose();
    _tilt.dispose();
    _frame.dispose();
    _map.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = math.min((elapsed - _lastTick).inMicroseconds / 1e6, 0.1);
    _lastTick = elapsed;
    final trip = _trip!;
    final frame = trip.step(dt, DateTime.now());
    if (trip.sim.arrived) {
      _ticker.stop();
      toast(context, 'Anda telah tiba di tujuan');
      return context.pop();
    }
    if (_following) {
      // Pusat kamera berada di depan kendaraan, sejauh selisih tinggi peta di depan dan belakang.
      final metersPerDp = 156543.03392 * math.cos(frame.position.latitude * math.pi / 180) / math.pow(2, _zoom);
      final ahead = (_mapAhead - _mapBehind) / 2 * metersPerDp;
      _map.moveAndRotate(const Distance().offset(frame.position, ahead, frame.bearing), _zoom, -frame.bearing);
    }
    _frame.value = frame;
  }

  Widget _buildMap(RouteOption route, Departure departure, DateTime now, double tilt) {
    // Marker ikut memipih saat peta direbahkan; tarik ke atas agar tetap terbaca.
    final stretch = 1 / math.cos(tilt);
    return AppMap(
      controller: _map,
      fitPoints: route.points,
      followZoom: _zoom,
      allowRotate: true,
      showAttribution: false,
      onPositionChanged: (camera, hasGesture) {
        if (mounted && hasGesture && _following) setState(() => _following = false);
      },
      layers: [
        // Garis rute hanya digambar dari posisi kendaraan sampai tujuan.
        ValueListenableBuilder(
          valueListenable: _frame,
          builder: (context, frame, _) =>
              trafficLine(route, departure, width: 13, from: (frame?.meters ?? 0) / route.sampler.totalMeters),
        ),
        MarkerLayer(
          markers: [
            iconMarker(route.points.last, Icons.flag_rounded, AppColors.emergency, size: 40, stretch: stretch),
            for (final x in route.intersections)
              iconMarker(
                route.sampler.at(x.fraction),
                Icons.traffic_rounded,
                x.stateAt(now).color,
                size: 38,
                stretch: stretch,
              ),
          ],
        ),
        ValueListenableBuilder(
          valueListenable: _frame,
          builder: (context, frame, _) {
            if (frame == null) return const SizedBox.shrink();
            // Panah menunjuk arah jalan walau peta sedang diputar pengguna.
            final heading = (frame.bearing + MapCamera.of(context).rotation) * math.pi / 180;
            return MarkerLayer(
              markers: [
                Marker(
                  point: frame.position,
                  width: 58,
                  height: 58,
                  rotate: true,
                  child: Transform.scale(
                    scaleY: stretch,
                    child: Transform.rotate(angle: heading, child: const _Puck()),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final routes = ref.watch(tripRoutesProvider).value;
    if (routes == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final trip = _trip;
    final route = trip?.route ?? routes.firstWhere((r) => r.index == widget.routeIndex);
    final departure = ref.watch(departureProvider);
    final minutes = route.minutes(departure, ref.watch(vehicleModeProvider));
    final now = ref.watch(nowProvider);
    final safe = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: _haze,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth, height = constraints.maxHeight;
          final anchorY = height * 0.66;
          final mapWidth = math.max(width * 2.2, 900.0);

          return Stack(
            children: [
              Positioned(
                left: (width - mapWidth) / 2,
                top: anchorY - _mapAhead,
                width: mapWidth,
                height: _mapAhead + _mapBehind,
                child: ListenableBuilder(
                  listenable: _tilt,
                  builder: (context, _) {
                    final tilt = _maxTilt * Curves.easeInOut.transform(_tilt.value);
                    return Transform(
                      alignment: Alignment.topLeft,
                      origin: Offset(mapWidth / 2, _mapAhead),
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, _perspective)
                        ..rotateX(-tilt),
                      child: _buildMap(route, departure, now, tilt),
                    );
                  },
                ),
              ),
              // Kabut di cakrawala, menutup tepi jauh peta.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: height * 0.3,
                child: const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_haze, _haze, Color(0x00E6ECF0)],
                        stops: [0, 0.35, 1],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: ValueListenableBuilder(
                    valueListenable: _frame,
                    builder: (context, frame, _) =>
                        frame == null ? const SizedBox.shrink() : GuidanceBanner(route: route, frame: frame, now: now),
                  ),
                ),
              ),
              Positioned(
                right: 14,
                bottom: 118 + safe.bottom,
                child: Column(
                  children: [
                    if (trip != null) ...[VoiceToggleButton(copilot: trip.copilot), const SizedBox(height: 10)],
                    ListenableBuilder(
                      listenable: _tilt,
                      builder: (context, _) => NavRoundButton(
                        label: _tilt.value > 0.5 ? '3D' : '2D',
                        onTap: () => _tilt.value > 0.5 ? _tilt.reverse() : _tilt.forward(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    NavRoundButton(
                      icon: Icons.traffic_rounded,
                      onTap: () => showLightsSheet(
                        context,
                        route: route,
                        minutes: minutes,
                        metersNow: () => _trip?.sim.meters ?? 0,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 14,
                bottom: 118 + safe.bottom,
                child: ValueListenableBuilder(
                  valueListenable: _frame,
                  builder: (context, frame, _) => Speedometer(kmh: frame?.kmh ?? 0),
                ),
              ),
              Positioned(right: 0, bottom: 92 + safe.bottom, child: const MapAttribution()),
              if (!_following)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 126 + safe.bottom,
                  child: Center(child: RecenterButton(onTap: () => setState(() => _following = true))),
                ),
              if (trip != null)
                Positioned(
                  left: 14,
                  right: 74,
                  bottom: 188 + safe.bottom,
                  child: VoiceDock(copilot: trip.copilot),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ValueListenableBuilder(
                  valueListenable: _frame,
                  builder: (context, frame, _) => NavBottomBar(
                    route: route,
                    minutes: minutes,
                    meters: frame?.meters ?? 0,
                    now: now,
                    onClose: () => context.pop(),
                    trailing: trip == null ? null : MicButton(copilot: trip.copilot, onTap: trip.trip.userReport),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Penanda posisi kendaraan: panah yang menghadap arah jalan.
class _Puck extends StatelessWidget {
  const _Puck();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navy,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.45), blurRadius: 14, spreadRadius: 3)],
      ),
      child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 32),
    );
  }
}
