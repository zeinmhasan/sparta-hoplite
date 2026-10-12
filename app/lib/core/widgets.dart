import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import 'theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Lencana status kepadatan berbentuk pil.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.level, {super.key, this.label, this.onDark = false});

  final TrafficLevel level;
  final String? label;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.16) : level.tint,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: onDark ? Colors.white24 : level.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: level.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label ?? level.label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: onDark ? Colors.white : level.onTint),
          ),
        ],
      ),
    );
  }
}

/// Label kecil berwarna emas yang menandai konten hasil AI.
class AiBadge extends StatelessWidget {
  const AiBadge({super.key, this.label = 'AI'});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 12, color: AppColors.gold),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9A5F00)),
          ),
        ],
      ),
    );
  }
}

/// Judul layar dengan tombol kembali, seperti di referensi.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.maroon),
            onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          ),
          const SizedBox(width: 4),
          Expanded(child: Text(title, style: AppText.screenTitle)),
          trailing ??
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.text),
                onPressed: () => toast(context, 'Pengaturan segera hadir'),
              ),
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(text.toUpperCase(), style: AppText.overline)),
        ?trailing,
      ],
    );
  }
}

/// Lampu lalu lintas kecil dengan hitung mundur detik.
class LightCountdown extends StatelessWidget {
  const LightCountdown(this.state, {super.key, this.onDark = false});
  final LightState state;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.14) : state.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: state.color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: state.color.withValues(alpha: 0.6), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${state.remaining} dtk',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: onDark ? Colors.white : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

/// Titik hijau berdenyut untuk menandai data yang diperbarui terus.
class LiveDot extends StatefulWidget {
  const LiveDot({super.key, this.color = AppColors.lancar});
  final Color color;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
}

/// Waktu relatif singkat, mis. "5 menit lalu".
String timeAgo(DateTime time, DateTime now) {
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return 'Baru saja';
  if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
  if (diff.inDays < 1) return '${diff.inHours} jam lalu';
  return '${diff.inDays} hari lalu';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

/// Tanggal dan jam, mis. "13 Okt 2026, 14.30".
String dateTimeLabel(DateTime time) =>
    '${time.day} ${_months[time.month - 1]} ${time.year}, '
    '${time.hour.toString().padLeft(2, '0')}.${time.minute.toString().padLeft(2, '0')}';

/// Notifikasi saldo masuk: ikon dompet, judul, dan nominal.
void rewardToast(ScaffoldMessengerState messenger, String title, int amount, {VoidCallback? onOpen}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.text,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(color: Color(0xFFFFC55A), shape: BoxShape.circle),
              child: const Icon(Icons.account_balance_wallet_rounded, size: 18, color: AppColors.text),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  Text(
                    'Saldo Pulse +${rupiah(amount)}',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFFFFC55A), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        action: onOpen == null ? null : SnackBarAction(label: 'Lihat', textColor: Colors.white, onPressed: onOpen),
      ),
    );
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 14),
        decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(99)),
      ),
    );
  }
}

/// Membuka layar pencarian tujuan; mengembalikan tempat yang dipilih.
Future<Place?> pickDestination(BuildContext context) => context.push<Place>('/search');

/// Kartu asal dan tujuan yang dipakai Smart Route dan Transit.
class TripFields extends StatelessWidget {
  const TripFields({super.key, required this.from, required this.to, this.onTapFrom, this.onTapTo, this.trailing});

  final String from;
  final String to;
  final VoidCallback? onTapFrom;
  final VoidCallback? onTapTo;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    Widget field(String text, VoidCallback? onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(10)),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          layoutBuilder: (current, previous) =>
              Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
          child: Text(
            text,
            key: ValueKey(text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );

    return Row(
      children: [
        Column(
          children: [
            const Icon(Icons.circle, size: 9, color: AppColors.navy),
            for (var i = 0; i < 4; i++)
              Container(width: 2, height: 4, margin: const EdgeInsets.symmetric(vertical: 2), color: AppColors.border),
            const Icon(Icons.circle, size: 9, color: AppColors.emergency),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(children: [field(from, onTapFrom), const SizedBox(height: 10), field(to, onTapTo)])),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}
