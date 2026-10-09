import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/mock_data.dart' as mock;
import '../../data/models.dart';

/// Kartu teratas Home: cuaca Surabaya saat ini, prakiraan per 2 jam, dan
/// dampaknya ke perjalanan. Kondisi lalu lintas kota tampil sebagai lencana.
class WeatherCard extends StatelessWidget {
  const WeatherCard({super.key, required this.traffic});

  /// Kondisi lalu lintas kota saat ini.
  final TrafficLevel traffic;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final current = mock.weatherAt(now.hour);
    final forecast = [for (var i = 0; i < 5; i++) (now.hour + i * 2) % 24];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Cuaca Surabaya', style: AppText.bodyStrong)),
              Text('Diperbarui ${formatClock(now)}', style: AppText.caption.copyWith(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: current.sky.color.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Icon(current.sky.icon, color: current.sky.color, size: 32),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${current.temp}°C',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('${current.sky.label} • Terasa ${current.temp + 3}°C', style: AppText.caption),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Lalu lintas kota', style: AppText.caption),
                  const SizedBox(height: 6),
                  StatusBadge(traffic),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                for (var i = 0; i < forecast.length; i++)
                  Expanded(
                    child: _ForecastSlot(hour: forecast[i], isNow: i == 0),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.directions_car_filled_outlined, size: 16, color: AppColors.maroon),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mock.weatherImpact(now.hour),
                  style: AppText.caption.copyWith(color: AppColors.text, height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ForecastSlot extends StatelessWidget {
  const _ForecastSlot({required this.hour, required this.isNow});
  final int hour;
  final bool isNow;

  @override
  Widget build(BuildContext context) {
    final weather = mock.weatherAt(hour);
    return Column(
      children: [
        Text(
          isNow ? 'Kini' : '${hour.toString().padLeft(2, '0')}.00',
          style: TextStyle(
            fontSize: 11,
            fontWeight: isNow ? FontWeight.w700 : FontWeight.w500,
            color: isNow ? AppColors.maroon : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Icon(weather.sky.icon, size: 22, color: weather.sky.color),
        const SizedBox(height: 6),
        Text('${weather.temp}°', style: AppText.bodyStrong.copyWith(fontSize: 13)),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.water_drop_rounded, size: 9, color: Color(0xFF3B82C4)),
            const SizedBox(width: 2),
            Text('${weather.rainChance}%', style: const TextStyle(fontSize: 10, color: Color(0xFF3B82C4))),
          ],
        ),
      ],
    );
  }
}
