import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/state.dart';
import 'nav_models3d.dart';
import 'nav_sim.dart';
import 'nav_widgets.dart';

/// Gaya peta vektor OpenFreeMap: tanpa API key, dan punya data tinggi gedung.
const _style = 'https://tiles.openfreemap.org/styles/liberty';
const _tiles = 'openmaptiles';

const _startZoom = 17.0;
const _minZoom = 15.0;
const _maxZoom = 19.5;
const _tilt3d = 58.0;

/// Gedung mulai tumbuh menjadi 3D pada zoom ini dan penuh pada [_buildingsFull].
const _buildingsFrom = 17.0;
const _buildingsFull = 17.7;

/// Garis rute dipotong ulang setiap kendaraan maju sejauh ini (meter).
const _routeTrimStep = 2.0;

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

ml.LatLng _ml(LatLng p) => ml.LatLng(p.latitude, p.longitude);

/// Navigasi layar penuh di atas peta vektor: kamera miring mengikuti kendaraan,
/// gedung menjadi 3D saat diperbesar, dan kendaraan serta lampu lalu lintas
/// digambar sebagai model 3D.
class Navigation3dScreen extends ConsumerStatefulWidget {
  const Navigation3dScreen({super.key, required this.routeIndex});
  final int routeIndex;

  @override
  ConsumerState<Navigation3dScreen> createState() => _Navigation3dScreenState();
}

class _Navigation3dScreenState extends ConsumerState<Navigation3dScreen> with SingleTickerProviderStateMixin {
  final _frame = ValueNotifier<NavFrame?>(null);
  late final Ticker _ticker = createTicker(_onTick);
  ml.MapLibreMapController? _map;
  Timer? _loadTimeout;

  late final NavSimulator _sim;
  late final VehicleMode _vehicle;
  late final Horizon _horizon;
  Duration _lastTick = Duration.zero;

  bool _ready = false;
  bool _slow = false;

  /// False saat pengguna menggeser, memutar, atau memiringkan peta sendiri.
  bool _following = true;

  // Kamera bergerak halus menuju nilai target ini.
  double _zoom = _startZoom, _zoomTarget = _startZoom;
  double _tilt = _tilt3d, _tiltTarget = _tilt3d;

  /// Jarak tempuh (meter) saat garis rute terakhir dipotong.
  double _routeTrimmed = 0;

  // Lampu digambar ulang hanya saat detiknya atau skalanya berubah.
  int _lightsSecond = -1;
  double _lightsScale = 0;

  @override
  void initState() {
    super.initState();
    final routes = ref.read(tripRoutesProvider).value!;
    _sim = NavSimulator(routes.firstWhere((r) => r.index == widget.routeIndex));
    _vehicle = ref.read(vehicleModeProvider);
    _horizon = ref.read(horizonProvider);
    _loadTimeout = Timer(const Duration(seconds: 12), () {
      if (mounted && !_ready) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _loadTimeout?.cancel();
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  /// Garis rute dari [meters] sampai tujuan, satu fitur per ruas kepadatan.
  Map<String, dynamic> _routeLine(double meters) {
    final route = _sim.route;
    return featureCollection([
      for (final (level, points) in route.remainingSlices(_horizon, from: meters / route.sampler.totalMeters))
        {
          'type': 'Feature',
          'properties': {'color': _hex(level.color)},
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              for (final p in points) [p.longitude, p.latitude],
            ],
          },
        },
    ]);
  }

  /// Menambahkan gedung 3D, garis rute, lampu, dan kendaraan ke gaya peta.
  Future<void> _onStyleLoaded() async {
    final map = _map;
    if (map == null) return;

    // Gedung bawaan gaya diganti versi yang tumbuh saat diperbesar dan cukup
    // transparan supaya garis rute di baliknya tetap terlihat.
    try {
      await map.removeLayer('building-3d');
    } catch (_) {
      // Gaya tanpa lapisan itu tidak perlu dibersihkan.
    }
    await map.addFillExtrusionLayer(
      _tiles,
      'sparta-buildings',
      const ml.FillExtrusionLayerProperties(
        fillExtrusionColor: '#C9BFB6',
        fillExtrusionOpacity: 0.5,
        fillExtrusionHeight: [
          'interpolate',
          ['linear'],
          ['zoom'],
          _buildingsFrom,
          0,
          _buildingsFull,
          [
            'coalesce',
            ['get', 'render_height'],
            6,
          ],
        ],
        fillExtrusionBase: [
          'interpolate',
          ['linear'],
          ['zoom'],
          _buildingsFrom,
          0,
          _buildingsFull,
          [
            'coalesce',
            ['get', 'render_min_height'],
            0,
          ],
        ],
      ),
      sourceLayer: 'building',
      minzoom: _buildingsFrom,
      enableInteraction: false,
    );

    // Rute, diwarnai per ruas menurut kepadatan pada jam berangkat terpilih.
    await map.addGeoJsonSource('sparta-route', _routeLine(0));
    // Lebar garis tumbuh bersama zoom. Tepi putihnya butuh ekspresi sendiri,
    // karena "zoom" hanya boleh berada di interpolate paling luar.
    const width = [
      'interpolate',
      ['exponential', 1.6],
      ['zoom'],
      14,
      5,
      17,
      14,
      20,
      48,
    ];
    const casing = [
      'interpolate',
      ['exponential', 1.6],
      ['zoom'],
      14,
      8,
      17,
      20,
      20,
      64,
    ];
    await map.addLineLayer(
      'sparta-route',
      'sparta-route-casing',
      const ml.LineLayerProperties(lineColor: '#FFFFFF', lineWidth: casing, lineCap: 'round', lineJoin: 'round'),
      belowLayerId: 'sparta-buildings',
      enableInteraction: false,
    );
    await map.addLineLayer(
      'sparta-route',
      'sparta-route-line',
      const ml.LineLayerProperties(lineColor: ['get', 'color'], lineWidth: width, lineCap: 'round', lineJoin: 'round'),
      belowLayerId: 'sparta-buildings',
      enableInteraction: false,
    );

    // Model 3D: lampu lalu lintas, bendera tujuan, dan kendaraan.
    const model = ml.FillExtrusionLayerProperties(
      fillExtrusionColor: ['get', 'color'],
      fillExtrusionHeight: ['get', 'h'],
      fillExtrusionBase: ['get', 'b'],
      fillExtrusionOpacity: 1,
      fillExtrusionVerticalGradient: true,
    );
    await map.addGeoJsonSource('sparta-lights', featureCollection(const []));
    await map.addFillExtrusionLayer('sparta-lights', 'sparta-lights', model, enableInteraction: false);
    await map.addGeoJsonSource('sparta-vehicle', featureCollection(const []));
    await map.addFillExtrusionLayer('sparta-vehicle', 'sparta-vehicle', model, enableInteraction: false);

    if (!mounted) return;
    _loadTimeout?.cancel();
    setState(() {
      _ready = true;
      _slow = false;
    });
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    final map = _map;
    if (map == null) return;
    final dt = math.min((elapsed - _lastTick).inMicroseconds / 1e6, 0.1);
    _lastTick = elapsed;
    final now = DateTime.now();
    final frame = _sim.step(dt, now);
    if (_sim.arrived) {
      _ticker.stop();
      toast(context, 'Anda telah tiba di tujuan');
      return context.pop();
    }

    final ease = math.min(1.0, dt * 5);
    _zoom += (_zoomTarget - _zoom) * ease;
    _tilt += (_tiltTarget - _tilt) * ease;

    // Saat pengguna melihat-lihat sendiri, ukuran model mengikuti zoom kamera mereka.
    final viewZoom = _following ? _zoom : (map.cameraPosition?.zoom ?? _zoom);
    final scale = modelScale(viewZoom, frame.position.latitude);

    if (_following) {
      // Kamera melihat sedikit ke depan supaya kendaraan berada di bawah tengah layar.
      final screen = MediaQuery.sizeOf(context).height;
      final ahead = (0.13 + 0.08 * _tilt / _tilt3d) * screen * metersPerDp(_zoom, frame.position.latitude);
      map.moveCamera(
        ml.CameraUpdate.newCameraPosition(
          ml.CameraPosition(
            target: _ml(const Distance().offset(frame.position, ahead, frame.bearing)),
            zoom: _zoom,
            tilt: _tilt,
            bearing: frame.bearing,
          ),
        ),
      );
    }
    map.setGeoJsonSource(
      'sparta-vehicle',
      featureCollection(vehicleModel(_vehicle, frame.position, frame.bearing, scale)),
    );
    // Garis yang sudah dilewati dibuang. Ujung potongannya tertutup kendaraan,
    // jadi cukup diperbarui tiap beberapa meter, bukan tiap frame.
    if (frame.meters - _routeTrimmed >= _routeTrimStep) {
      _routeTrimmed = frame.meters;
      map.setGeoJsonSource('sparta-route', _routeLine(frame.meters));
    }

    final second = now.millisecondsSinceEpoch ~/ 1000;
    if (second != _lightsSecond || (scale - _lightsScale).abs() > 0.05) {
      _lightsSecond = second;
      _lightsScale = scale;
      final route = _sim.route;
      final total = route.sampler.totalMeters;
      map.setGeoJsonSource(
        'sparta-lights',
        featureCollection([
          for (final x in route.intersections)
            ...trafficLightModel(
              route.sampler.at(x.fraction),
              route.sampler.bearingAt(x.fraction - 40 / total, spanMeters: 40),
              x.stateAt(now).green,
              scale,
            ),
          ...destinationModel(route.points.last, scale),
        ]),
      );
    }
    _frame.value = frame;
  }

  void _zoomBy(double delta) {
    if (_following) {
      _zoomTarget = (_zoomTarget + delta).clamp(_minZoom, _maxZoom);
    } else {
      _map?.animateCamera(ml.CameraUpdate.zoomBy(delta));
    }
  }

  void _toggleTilt() {
    setState(() => _tiltTarget = _tiltTarget > 1 ? 0 : _tilt3d);
    if (!_following) _map?.animateCamera(ml.CameraUpdate.tiltTo(_tiltTarget));
  }

  /// Kembali mengikuti kendaraan, mempertahankan zoom dan kemiringan pilihan pengguna.
  void _recenter() {
    final camera = _map?.cameraPosition;
    setState(() {
      if (camera != null) {
        _zoom = _zoomTarget = camera.zoom.clamp(_minZoom, _maxZoom);
        _tilt = _tiltTarget = camera.tilt;
      }
      _following = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final route = _sim.route;
    final minutes = route.minutes(_horizon, _vehicle);
    final now = ref.watch(nowProvider);
    final safe = MediaQuery.paddingOf(context);

    return Scaffold(
      body: Stack(
        children: [
          // Sentuhan di peta berarti pengguna ingin melihat-lihat sendiri.
          Listener(
            onPointerDown: (_) {
              if (_ready && _following) setState(() => _following = false);
            },
            child: ml.MapLibreMap(
              styleString: _style,
              initialCameraPosition: ml.CameraPosition(
                target: _ml(route.points.first),
                zoom: _startZoom,
                tilt: _tilt3d,
                bearing: route.sampler.bearingAt(0),
              ),
              minMaxZoomPreference: const ml.MinMaxZoomPreference(_minZoom, _maxZoom),
              trackCameraPosition: true,
              compassEnabled: false,
              attributionButtonMargins: math.Point(8, 100 + safe.bottom),
              onMapCreated: (controller) => _map = controller,
              onStyleLoadedCallback: _onStyleLoaded,
            ),
          ),
          if (!_ready)
            _LoadingCover(slow: _slow, onFallback: () => context.pushReplacement('/navigate-2d/${route.index}')),
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
          if (_ready)
            Positioned(
              right: 14,
              bottom: 118 + safe.bottom,
              child: Column(
                children: [
                  NavRoundButton(icon: Icons.add_rounded, onTap: () => _zoomBy(0.7)),
                  const SizedBox(height: 10),
                  NavRoundButton(icon: Icons.remove_rounded, onTap: () => _zoomBy(-0.7)),
                  const SizedBox(height: 10),
                  NavRoundButton(label: _tiltTarget > 1 ? '3D' : '2D', onTap: _toggleTilt),
                  const SizedBox(height: 10),
                  NavRoundButton(
                    icon: Icons.traffic_rounded,
                    onTap: () => showLightsSheet(context, route: route, minutes: minutes, metersNow: () => _sim.meters),
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
          if (_ready && !_following)
            Positioned(
              left: 0,
              right: 0,
              bottom: 126 + safe.bottom,
              child: Center(child: RecenterButton(onTap: _recenter)),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Menutup peta selama gaya dan ubin vektor dimuat. Jika terlalu lama,
/// menawarkan navigasi standar yang tidak butuh peta vektor.
class _LoadingCover extends StatelessWidget {
  const _LoadingCover({required this.slow, required this.onFallback});
  final bool slow;
  final VoidCallback onFallback;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.background,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 18),
                Text(
                  slow ? 'Peta 3D butuh waktu lebih lama dari biasanya.' : 'Menyiapkan peta 3D...',
                  textAlign: TextAlign.center,
                  style: AppText.body,
                ),
                if (slow) ...[
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: onFallback, child: const Text('Pakai Navigasi Standar')),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
