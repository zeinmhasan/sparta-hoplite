import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme.dart';
import '../../data/state.dart';
import '../voice/intent.dart';

/// Foto bukti dari [path]: file di perangkat, atau URL blob di web.
Widget evidenceImage(String path, {BoxFit fit = BoxFit.cover}) =>
    kIsWeb ? Image.network(path, fit: fit) : Image.file(File(path), fit: fit);

/// Kamera foto bukti, langkah wajib setelah laporan suara diklasifikasi.
/// Mengembalikan path foto, atau null jika ditutup tanpa memotret.
class EvidenceCameraScreen extends ConsumerStatefulWidget {
  const EvidenceCameraScreen({super.key, required this.report});
  final ClassifiedReport report;

  @override
  ConsumerState<EvidenceCameraScreen> createState() => _EvidenceCameraScreenState();
}

class _EvidenceCameraScreenState extends ConsumerState<EvidenceCameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  String? _error;
  bool _denied = false;
  bool _taking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  // Kamera dilepas saat aplikasi ke latar belakang dan dibuka lagi saat kembali.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.inactive && controller != null) {
      _controller = null;
      controller.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && controller == null && _error == null) {
      _open();
    }
  }

  Future<void> _open() async {
    setState(() {
      _error = null;
      _denied = false;
    });
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('NoCamera', 'Perangkat ini tidak punya kamera.');
      final back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
      final controller = CameraController(back, ResolutionPreset.high, enableAudio: false);
      await controller.initialize();
      if (!mounted) return controller.dispose();
      setState(() => _controller = controller);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        _denied = e.code.contains('AccessDenied') || e.code.contains('Restricted');
        _error = _denied
            ? 'Izin kamera ditolak. Foto bukti wajib, jadi izinkan kamera di pengaturan aplikasi.'
            : 'Kamera tidak bisa dibuka (${e.description ?? e.code}).';
      });
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _taking || controller.value.isTakingPicture) return;
    setState(() => _taking = true);
    try {
      final photo = await controller.takePicture();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (mounted) Navigator.of(context).pop(photo.path);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() => _taking = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memotret: ${e.description ?? e.code}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (ready) _Preview(controller: controller) else if (_error == null) const _Loading(),
          if (_error != null) _Failure(message: _error!, denied: _denied, onRetry: _open),
          if (_taking) Container(color: Colors.white).animate().fadeOut(duration: 260.ms, curve: Curves.easeOut),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      _RoundButton(icon: Icons.close_rounded, onTap: () => Navigator.of(context).pop()),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Foto bukti',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            Text(
                              'Wajib sebelum laporan dikirim',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ClassificationCard(report: widget.report),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  children: [
                    const _SpotChip(),
                    const SizedBox(height: 18),
                    _Shutter(enabled: ready && !_taking, onTap: _capture),
                    const SizedBox(height: 10),
                    const Text(
                      'Arahkan kamera ke kejadiannya',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pratinjau kamera memenuhi layar, dipotong di tepi tanpa merusak rasio.
class _Preview extends StatelessWidget {
  const _Preview({required this.controller});
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    // Rasio kamera dilaporkan dalam orientasi lanskap; layar ini selalu potret.
    var scale = screen.aspectRatio * controller.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;
    return ClipRect(
      child: Transform.scale(
        scale: scale,
        child: Center(child: CameraPreview(controller)),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: Colors.white),
        SizedBox(height: 14),
        Text('Membuka kamera…', style: TextStyle(color: Colors.white70)),
      ],
    ),
  );
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.denied, required this.onRetry});
  final String message;
  final bool denied;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, size: 48, color: Colors.white70),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.white),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: denied ? Geolocator.openAppSettings : onRetry,
              style: FilledButton.styleFrom(backgroundColor: AppColors.maroon),
              child: Text(denied ? 'Buka Pengaturan' : 'Coba Lagi'),
            ),
            if (denied) TextButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
}

/// Hasil klasifikasi AI dari ucapan pengguna, supaya jelas foto ini bukti untuk apa.
class _ClassificationCard extends StatelessWidget {
  const _ClassificationCard({required this.report});
  final ClassifiedReport report;

  @override
  Widget build(BuildContext context) {
    final intent = report.intent;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.maroon, borderRadius: BorderRadius.circular(12)),
            child: Icon(intent.type.icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${intent.type.label} • ${intent.severity.label}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                if (report.transcript.isNotEmpty)
                  Text(
                    '“${report.transcript}”',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AiConfidence(confidence: report.confidence, dark: true),
        ],
      ),
    );
  }
}

/// Lencana "AI 94%" untuk hasil klasifikasi.
class AiConfidence extends StatelessWidget {
  const AiConfidence({super.key, required this.confidence, this.dark = false});
  final double confidence;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = dark ? const Color(0xFFFFC55A) : AppColors.purple;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            'AI ${(confidence * 100).round()}%',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

/// Lokasi yang akan ikut terkirim, diisi otomatis dari GPS.
class _SpotChip extends ConsumerWidget {
  const _SpotChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spot = ref.watch(reportSpotProvider).value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(spot == null ? Icons.gps_not_fixed_rounded : Icons.gps_fixed_rounded, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              spot?.address ?? 'Mencari lokasi GPS…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _Shutter extends StatelessWidget {
  const _Shutter({required this.enabled, required this.onTap});
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ambil foto bukti',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: enabled ? 1 : 0.4,
          child: Container(
            width: 78,
            height: 78,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: const DecoratedBox(
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 42, height: 42, child: Icon(icon, color: Colors.white)),
      ),
    );
  }
}
