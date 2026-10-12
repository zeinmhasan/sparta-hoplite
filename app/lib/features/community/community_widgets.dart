import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../pulse/evidence_camera_screen.dart';

/// Warna penanda tiap jenis kejadian, di peta dan di kartu.
Color incidentColor(IncidentType type) => switch (type) {
  IncidentType.macet => AppColors.padat,
  IncidentType.kecelakaan => AppColors.emergency,
  IncidentType.banjir => const Color(0xFF1565C0),
  IncidentType.jalanDitutup => const Color(0xFF6A1B9A),
  IncidentType.lainnya => const Color(0xFFB07A00),
};

const _distance = Distance();

/// Jarak dari [from] ke laporan, mis. "1,2 km".
String distanceTo(LatLng from, LatLng to) {
  final meters = _distance.as(LengthUnit.Meter, from, to);
  if (meters < 1000) return '${(meters / 50).round() * 50} m';
  return '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// Foto bukti laporan warga: aset bawaan, atau file dari kamera pengguna.
class CitizenPhoto extends StatelessWidget {
  const CitizenPhoto({super.key, required this.report});
  final CitizenReport report;

  @override
  Widget build(BuildContext context) =>
      report.photoIsFile ? evidenceImage(report.photo) : Image.asset(report.photo, fit: BoxFit.cover);
}

/// Pil status laporan. [onPhoto] membuatnya terbaca di atas foto.
class CitizenStatusChip extends StatelessWidget {
  const CitizenStatusChip(this.status, {super.key, this.onPhoto = false});
  final CitizenStatus status;
  final bool onPhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: onPhoto ? Colors.white : status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 13, color: status.color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: status.color),
          ),
        ],
      ),
    );
  }
}

/// Pil jenis kejadian berwarna, mis. "Banjir".
class IncidentChip extends StatelessWidget {
  const IncidentChip(this.type, {super.key});
  final IncidentType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: incidentColor(type), borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            type.label,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// Inisial pelapor dalam lingkaran.
class ReporterAvatar extends StatelessWidget {
  const ReporterAvatar({super.key, required this.name, this.mine = false, this.size = 28});
  final String name;
  final bool mine;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: mine ? AppColors.maroon : AppColors.navy.withValues(alpha: 0.12),
      child: Text(
        name.characters.first,
        style: TextStyle(
          fontSize: size * 0.45,
          fontWeight: FontWeight.w700,
          color: mine ? Colors.white : AppColors.navy,
        ),
      ),
    );
  }
}
