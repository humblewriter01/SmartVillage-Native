import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../services/weather_service.dart';
import '../state/app_state.dart';
import '../widgets/section_card.dart';
import '../widgets/speak_button.dart';

/// Weather / Yanayi — 7-day forecast with an offline cache.
/// Port of `WeatherScreen.tsx`.
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final WeatherService _service = WeatherService();
  String _locationName = 'Kano';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final hausa = state.isHausa;
    final forecast = state.forecast;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: <Widget>[
        SectionCard(
          title: state.t('weatherTitle'),
          subtitle: '${forecast.locationName} · '
              '${forecast.isCached ? state.t('cached') : state.t('online')}',
          accent: AppColors.water,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.faint(AppColors.water, 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.cloud_outlined,
                color: AppColors.water, size: 18),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SpeakButton(
                compact: true,
                color: AppColors.water,
                textBuilder: () => forecast.days.isEmpty
                    ? state.t('noWeather')
                    : forecast.days
                        .take(3)
                        .map((day) =>
                            '${WeatherService.weekdayLabel(day.date, hausa)}: '
                            '${day.max.round()} to ${day.min.round()} degrees, '
                            '${day.rain.toStringAsFixed(1)} mm rain')
                        .join('. '),
              ),
              IconButton(
                onPressed: state.weatherLoading
                    ? null
                    : () async {
                        final selected = _service.locations.firstWhere(
                          (location) => location.name == _locationName,
                          orElse: () => _service.locations.first,
                        );
                        await state.reloadWeather(
                          latitude: selected.lat,
                          longitude: selected.lon,
                        );
                      },
                icon: state.weatherLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                tooltip: state.t('refresh'),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              DropdownButtonFormField<String>(
                value: _locationName,
                isExpanded: true,
                items: _service.locations
                    .map(
                      (location) => DropdownMenuItem<String>(
                        value: location.name,
                        child: Text(
                          '${location.name} · ${location.state}',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() => _locationName = value);
                  await _service.savePreferredLocation(value);
                  final selected = _service.locations
                      .firstWhere((location) => location.name == value);
                  await state.reloadWeather(
                    latitude: selected.lat,
                    longitude: selected.lon,
                  );
                },
                decoration: InputDecoration(
                  labelText: state.t('selectLocation'),
                ),
              ),
              if (forecast.days.isEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  state.t('noWeather'),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (forecast.days.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          ...forecast.days.map(
            (day) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 52,
                    child: Text(
                      WeatherService.weekdayLabel(day.date, hausa),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(day.date, style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  )),
                  const Spacer(),
                  Pill(
                    label: '${day.max.round()}°',
                    color: AppColors.danger,
                    icon: Icons.arrow_upward,
                  ),
                  const SizedBox(width: 5),
                  Pill(
                    label: '${day.min.round()}°',
                    color: AppColors.info,
                    icon: Icons.arrow_downward,
                  ),
                  const SizedBox(width: 5),
                  Pill(
                    label: '${day.rain.toStringAsFixed(1)}mm',
                    color: AppColors.water,
                    icon: Icons.water_drop_outlined,
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          state.pick(
            'Forecast data: Open-Meteo. The last successful download is cached so the app keeps working offline.',
            'Bayanan yanayi daga Open-Meteo. Ana adana na ƙarshe domin aiki ba tare da intanet ba.',
          ),
          style: const TextStyle(
            fontSize: 10,
            height: 1.4,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
