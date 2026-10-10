import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'copilot.dart';

/// Tombol mikrofon besar: satu ketukan untuk mulai melapor dengan suara.
class MicButton extends StatelessWidget {
  const MicButton({super.key, required this.copilot, required this.onTap, this.size = 58});
  final VoiceCopilot copilot;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: copilot,
      builder: (context, _) {
        final listening = copilot.phase == VoicePhase.listening;
        final color = !copilot.enabled ? AppColors.field : (listening ? AppColors.emergency : AppColors.maroon);
        final button = Material(
          color: color,
          shape: const CircleBorder(),
          elevation: copilot.enabled ? 4 : 0,
          shadowColor: color,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () =>
                copilot.enabled ? onTap() : toast(context, 'Mode suara mati. Ketuk ikon speaker untuk menyalakannya.'),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                copilot.enabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                color: copilot.enabled ? Colors.white : AppColors.textSecondary,
                size: size * 0.46,
              ),
            ),
          ),
        );
        return Tooltip(
          message: 'Lapor dengan suara',
          child: listening
              ? button
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(begin: 1, end: 1.08, duration: 600.ms, curve: Curves.easeInOut)
              : button,
        );
      },
    );
  }
}

/// Keterangan apa yang sedang diucapkan atau didengar Hoplite. Hanya pelengkap:
/// semua isinya juga diucapkan, jadi tidak perlu dilihat saat berkendara.
/// Pilihan jawaban bisa diketuk di tempat bising atau saat mikrofon tidak ada.
class VoiceDock extends StatelessWidget {
  const VoiceDock({super.key, required this.copilot});
  final VoiceCopilot copilot;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: copilot,
      builder: (context, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: copilot.phase == VoicePhase.idle ? const SizedBox.shrink() : _panel(),
      ),
    );
  }

  Widget _panel() {
    final listening = copilot.phase == VoicePhase.listening;
    return Container(
      key: const ValueKey('panel'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(listening ? Icons.mic_rounded : Icons.volume_up_rounded, size: 16, color: const Color(0xFFFFC55A)),
              const SizedBox(width: 8),
              Text(
                listening ? 'MENDENGARKAN' : 'HOPLITE',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Colors.white70,
                ),
              ),
              if (listening) ...[const SizedBox(width: 8), const LiveDot(color: Color(0xFFFFC55A))],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            copilot.caption,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3, color: Colors.white),
          ),
          if (copilot.heard.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('“${copilot.heard}”', style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ],
          if (listening) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in copilot.options)
                  Material(
                    color: Colors.white.withValues(alpha: 0.14),
                    shape: const StadiumBorder(side: BorderSide(color: Colors.white24)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => copilot.answer(option),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        child: Text(
                          option,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Saklar darurat mode suara di layar navigasi.
class VoiceToggleButton extends StatelessWidget {
  const VoiceToggleButton({super.key, required this.copilot});
  final VoiceCopilot copilot;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: copilot,
      builder: (context, _) => Tooltip(
        message: copilot.enabled ? 'Matikan mode suara' : 'Nyalakan mode suara',
        child: Material(
          color: copilot.enabled ? Colors.white : AppColors.text,
          shape: const CircleBorder(),
          elevation: 3,
          shadowColor: Colors.black38,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              copilot.enabled = !copilot.enabled;
              toast(context, copilot.enabled ? 'Mode suara menyala' : 'Mode suara dimatikan');
            },
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(
                copilot.enabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                color: copilot.enabled ? AppColors.maroon : Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
