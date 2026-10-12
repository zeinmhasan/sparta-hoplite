import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/map_view.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/mock_data.dart' as mock;
import '../../data/models.dart';
import '../../data/state.dart';
import 'community_widgets.dart';

/// Titik acuan jarak: lokasi GPS pengguna jika berada di Surabaya, selain itu
/// lokasi rumah.
final userPointProvider = Provider<LatLng>((ref) {
  final spot = ref.watch(reportSpotProvider).value;
  if (spot == null || !spot.live) return mock.origin.point;
  final km = const Distance().as(LengthUnit.Kilometer, spot.point, mock.origin.point);
  return km < 30 ? spot.point : mock.origin.point;
});

/// Membuka detail laporan warga; laporan sendiri dibuka di halaman statusnya.
void openCitizenReport(BuildContext context, CitizenReport report) =>
    context.push(report.mine ? '/reports/${report.id}' : '/community/${report.id}');

/// Umpan Laporan Warga: peta sebaran, saringan jenis, dan kartu bergambar.
class CommunityFeed extends ConsumerStatefulWidget {
  const CommunityFeed({super.key});

  @override
  ConsumerState<CommunityFeed> createState() => _CommunityFeedState();
}

class _CommunityFeedState extends ConsumerState<CommunityFeed> {
  IncidentType? _filter;

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(citizenFeedProvider);
    final now = ref.watch(nowProvider);
    final user = ref.watch(userPointProvider);
    final shown = [
      for (final r in feed)
        if (_filter == null || r.type == _filter) r,
    ];
    final active = feed.where((r) => r.status != CitizenStatus.selesai).length;

    Widget chip(String label, IncidentType? type) {
      final selected = _filter == type;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => setState(() => _filter = type),
          selectedColor: AppColors.maroon,
          backgroundColor: Colors.white,
          side: BorderSide(color: selected ? AppColors.maroon : AppColors.border),
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.text,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          children: [
            const Expanded(child: Text('Kondisi jalan dari warga', style: AppText.sectionTitle)),
            const LiveDot(),
            const SizedBox(width: 6),
            Text('$active aktif', style: AppText.caption),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Laporan bergambar dari warga sekitarmu. Konfirmasi yang masih ada atau sudah aman.',
          style: AppText.body.copyWith(color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 14),
        _FeedMap(reports: shown, user: user),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [chip('Semua', null), for (final type in IncidentType.values) chip(type.label, type)]),
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text('Belum ada laporan jenis ini di sekitarmu.', textAlign: TextAlign.center),
          ),
        for (final report in shown) ...[CitizenCard(report: report, now: now, user: user), const SizedBox(height: 14)],
      ],
    );
  }
}

/// Peta kecil sebaran laporan; ketuk penanda untuk membuka laporannya.
class _FeedMap extends StatelessWidget {
  const _FeedMap({required this.reports, required this.user});
  final List<CitizenReport> reports;
  final LatLng user;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 190,
        child: AppMap(
          key: ValueKey(reports.length),
          fitPoints: [user, for (final r in reports) r.point],
          interactive: false,
          followZoom: reports.isEmpty ? 13 : null,
          padding: const EdgeInsets.all(28),
          layers: [
            MarkerLayer(
              markers: [
                dotMarker(user, AppColors.navy, size: 16),
                for (final r in reports)
                  Marker(
                    point: r.point,
                    width: 32,
                    height: 32,
                    child: GestureDetector(
                      onTap: () => openCitizenReport(context, r),
                      child: Container(
                        decoration: BoxDecoration(
                          color: incidentColor(r.type),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 6)],
                        ),
                        child: Icon(r.type.icon, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu laporan warga: foto, jenis, lokasi, pelapor, dan jumlah konfirmasi.
class CitizenCard extends StatelessWidget {
  const CitizenCard({super.key, required this.report, required this.now, required this.user});
  final CitizenReport report;
  final DateTime now;
  final LatLng user;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => openCitizenReport(context, report),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CitizenPhoto(report: report),
                Positioned(left: 10, top: 10, child: IncidentChip(report.type)),
                Positioned(right: 10, top: 10, child: CitizenStatusChip(report.status, onPhoto: true)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        report.road,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.cardTitle.copyWith(fontSize: 15),
                      ),
                    ),
                    Text(timeAgo(report.createdAt, now), style: AppText.caption),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${report.area} • ${distanceTo(user, report.point)} • ${report.severity.label}',
                  style: AppText.caption,
                ),
                if (report.note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '“${report.note}”',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(fontSize: 13.5, height: 1.35),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    ReporterAvatar(name: report.reporter, mine: report.mine, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${report.reporter} • ${report.reporterLevel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption.copyWith(color: AppColors.text),
                      ),
                    ),
                    const Icon(Icons.groups_2_outlined, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('${report.stillThere} konfirmasi', style: AppText.caption),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
