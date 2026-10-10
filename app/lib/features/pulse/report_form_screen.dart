import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/mock_data.dart' as mock;
import '../../data/models.dart';
import '../../data/state.dart';

/// Laporan lewat formulir, untuk kejadian yang butuh foto. Jalur utama melapor
/// adalah suara (lihat PulseScreen); layar ini juga menjadi pembanding jumlah
/// ketukan dan waktu per laporan.
class ReportFormScreen extends ConsumerStatefulWidget {
  const ReportFormScreen({super.key});

  @override
  ConsumerState<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends ConsumerState<ReportFormScreen> {
  final _description = TextEditingController();
  ReportCategory? _category;

  /// Foto di demo adalah kotak contoh; tiap angka menunjuk satu warna contoh.
  final _photos = <int>[];
  int _photoSerial = 0;
  String _location = mock.reportLocations.first;
  bool _sending = false;

  // Jumlah interaksi dan waktu mulai mengisi, untuk dibandingkan dengan laporan suara.
  int _taps = 0;
  DateTime? _startedAt;

  void _touch([int taps = 1]) {
    _startedAt ??= DateTime.now();
    _taps += taps;
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.maroon),
              title: const Text('Ambil foto', style: AppText.bodyStrong),
              onTap: () => Navigator.of(context).pop('kamera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.maroon),
              title: const Text('Pilih dari galeri', style: AppText.bodyStrong),
              onTap: () => Navigator.of(context).pop('galeri'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    _touch(2);
    if (source != null) setState(() => _photos.add(_photoSerial++));
  }

  Future<void> _editLocation() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            for (final location in mock.reportLocations)
              ListTile(
                leading: const Icon(Icons.location_on_outlined, color: AppColors.maroon),
                title: Text(location, style: AppText.bodyStrong),
                trailing: location == _location ? const Icon(Icons.check_rounded, color: AppColors.maroon) : null,
                onTap: () => Navigator.of(context).pop(location),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    _touch(2);
    if (picked != null) setState(() => _location = picked);
  }

  Future<void> _submit() async {
    if (_category == null) return toast(context, 'Pilih dulu jenis kejadian yang dilaporkan');
    if (_photos.isEmpty) return toast(context, 'Tambahkan minimal satu foto');

    _touch();
    final started = _startedAt ?? DateTime.now();
    setState(() => _sending = true);
    final report = await ref
        .read(repositoryProvider)
        .submitReport(
          category: _category!,
          description: _description.text.trim().isEmpty ? 'Tanpa deskripsi.' : _description.text.trim(),
          location: _location,
          photoCount: _photos.length,
          interactions: _taps,
          seconds: DateTime.now().difference(started).inSeconds,
        );
    if (!mounted) return;
    ref.read(reportsProvider.notifier).add(report);
    setState(() {
      _sending = false;
      _category = null;
      _photos.clear();
      _description.clear();
      _taps = 0;
      _startedAt = null;
    });

    final seeStatus = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => _SuccessDialog(report: report),
    );
    if (seeStatus == true && mounted) context.push('/reports/${report.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ScreenHeader(title: 'Lapor dengan Foto'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const Text('Apa yang ingin Anda laporkan?', style: AppText.sectionTitle),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.02,
                    children: [
                      for (final category in ReportCategory.values)
                        _CategoryTile(
                          category: category,
                          selected: category == _category,
                          onTap: () => setState(() {
                            _touch();
                            _category = category;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Text('TAMBAH FOTO', style: AppText.overline),
                      const Text(
                        '*',
                        style: TextStyle(color: AppColors.emergency, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 96,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      children: [
                        for (final photo in _photos)
                          _PhotoTile(
                            key: ValueKey(photo),
                            serial: photo,
                            onRemove: () => setState(() {
                              _touch();
                              _photos.remove(photo);
                            }),
                          ),
                        _AddPhotoTile(onTap: _addPhoto),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const SectionLabel('Deskripsi singkat'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _description,
                    onTap: _touch,
                    maxLines: 3,
                    maxLength: 160,
                    style: AppText.body,
                    decoration: InputDecoration(
                      hintText: 'Contoh: tabrakan dua motor, satu lajur tertutup',
                      hintStyle: AppText.body.copyWith(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const SectionLabel('Lokasi (otomatis)'),
                  const SizedBox(height: 10),
                  Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _editLocation,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.gps_fixed_rounded, color: AppColors.maroon),
                            const SizedBox(width: 12),
                            Expanded(child: Text(_location, style: AppText.body.copyWith(fontSize: 15))),
                            const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Lokasi terdeteksi menggunakan GPS perangkat Anda secara real-time.',
                    style: AppText.caption,
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _sending ? null : _submit,
                    style: FilledButton.styleFrom(disabledBackgroundColor: AppColors.maroon.withValues(alpha: 0.6)),
                    child: _sending
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                              ),
                              SizedBox(width: 12),
                              Text('Mengirim...', style: TextStyle(color: Colors.white)),
                            ],
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [Text('Kirim Laporan'), SizedBox(width: 10), Icon(Icons.send_outlined, size: 20)],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.selected, required this.onTap});
  final ReportCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? AppColors.maroon.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? AppColors.maroon : AppColors.border, width: selected ? 1.8 : 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(category.icon, color: AppColors.maroon, size: 30),
              const SizedBox(height: 8),
              Text(
                category.label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.25, color: AppColors.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({super.key, required this.serial, required this.onRemove});
  final int serial;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = mock.samplePhotoColors[serial % mock.samplePhotoColors.length];
    return Container(
      width: 96,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          const Center(child: Icon(Icons.image_outlined, color: Colors.white70, size: 30)),
          Positioned(
            left: 8,
            bottom: 6,
            child: Text('Foto ${serial + 1}', style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    ).animate().scaleXY(begin: 0.8, end: 1, duration: 200.ms, curve: Curves.easeOutBack).fadeIn();
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 96,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCFC9C5), width: 1.5),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: AppColors.maroon),
            SizedBox(height: 6),
            Text('Tambah', style: AppText.caption),
          ],
        ),
      ),
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog({required this.report});
  final Report report;

  @override
  Widget build(BuildContext context) {
    Widget check(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, size: 16, color: AppColors.lancar),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppText.caption.copyWith(color: AppColors.text)),
          ),
        ],
      ),
    );

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: AppColors.lancar.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: AppColors.lancar, size: 40),
            ).animate().scaleXY(begin: 0.4, end: 1, duration: 350.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 16),
            const Text('Laporan terkirim', style: AppText.sectionTitle),
            const SizedBox(height: 4),
            Text('Nomor laporan ${report.id}', style: AppText.caption),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const AiBadge(label: 'Verifikasi AI'),
                      const Spacer(),
                      Text('Prioritas ${report.priority}', style: AppText.bodyStrong.copyWith(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  check('Lokasi foto cocok dengan GPS'),
                  check('Foto tidak terdeteksi duplikat'),
                  check('Diteruskan ke operator SPARTA Ephor'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Lihat Status Laporan')),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Tutup', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}
