import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../state/app_state.dart';
import '../widgets/harvest_countdown_card.dart';
import '../widgets/reminder_card.dart';
import '../widgets/section_card.dart';
import '../widgets/sos_card.dart';
import '../widgets/speak_button.dart';

/// Home / Gida.
///
/// Port of `HomeScreen.tsx`: hero intro with read-aloud, the SOS distress card,
/// the harvest countdown, the eight primary action cards and a compact weather
/// strip.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final hausa = state.isHausa;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
      children: <Widget>[
        _HeroCard(hausa: hausa),
        const SizedBox(height: 14),
        const SosCard(),
        const SizedBox(height: 14),
        const HarvestCountdownCard(),
        const SizedBox(height: 14),
        const ReminderCard(),
        const SizedBox(height: 14),
        _WeatherStrip(hausa: hausa),
        const SizedBox(height: 18),
        SectionHeader(
          title: hausa ? 'Babban Aiki' : 'Quick Actions',
          subtitle: hausa
              ? 'Duk ayyukan suna aiki ba tare da intanet ba'
              : 'Everything works without internet',
          icon: Icons.grid_view_rounded,
        ),
        _ActionCard(
          title: state.t('checkCrop'),
          subtitle: state.t('cropSubtitle'),
          emoji: '🌾',
          color: AppColors.crop,
          onTap: () => state.goToTab(TabId.crop),
        ),
        _ActionCard(
          title: state.t('checkHealth'),
          subtitle: state.t('healthSubtitle'),
          emoji: '🏥',
          color: AppColors.health,
          onTap: () => state.goToTab(TabId.health),
        ),
        _ActionCard(
          title: state.t('checkWater'),
          subtitle: state.t('waterSubtitle'),
          emoji: '💧',
          color: AppColors.water,
          onTap: () => state.goToTab(TabId.water),
        ),
        _ActionCard(
          title: state.t('checkLivestock'),
          subtitle: state.t('livestockSubtitle'),
          emoji: '🐄',
          color: AppColors.livestock,
          onTap: () => state.goToTab(TabId.livestock),
        ),
        _ActionCard(
          title: state.t('checkMap'),
          subtitle: state.t('mapSubtitle'),
          emoji: '🗺️',
          color: AppColors.map,
          onTap: () => state.goToTab(TabId.map),
        ),
        _ActionCard(
          title: state.t('checkCalendar'),
          subtitle: state.t('calendarSubtitle'),
          emoji: '📅',
          color: AppColors.calendar,
          onTap: () => state.goToTab(TabId.calendar),
        ),
        _ActionCard(
          title: state.t('checkSoil'),
          subtitle: state.t('soilSubtitle'),
          emoji: '🌱',
          color: AppColors.soil,
          onTap: () => state.goToTab(TabId.soil),
        ),
        _ActionCard(
          title: hausa ? 'Laburaren Cututtuka' : 'Disease Reference Library',
          subtitle: hausa
              ? 'Hotunan cututtuka da magunguna'
              : 'Pictures, causes and treatments',
          emoji: '📚',
          color: AppColors.info,
          onTap: () => state.goToTab(TabId.library),
        ),
        const SizedBox(height: 12),
        Text(
          state.t('notMedical'),
          style: const TextStyle(
            fontSize: 10.5,
            height: 1.45,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.hausa});

  final bool hausa;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF1F7A4C), Color(0xFF155A36)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.faint(AppColors.primaryDark, 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  hausa ? '100% BA INTANET BA' : '100% OFFLINE-FIRST',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const Spacer(),
              SpeakButton(
                color: Colors.white,
                background: const Color(0x33FFFFFF),
                textBuilder: () => hausa
                    ? 'Taimako ba tare da intanet ba ga gonaki da iyalai masu lafiya. Danna ko yi magana da murya domin duba amfanin gona, lafiya, ruwa, dabbobi da yanayin noma.'
                    : 'Offline help for healthier farms and families. Tap or speak in English or Hausa for crop health, symptom triage, water purity, livestock checks and maps.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            state.t('tagline'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              height: 1.2,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hausa
                ? 'Danna ko yi magana da murya domin duba amfanin gona, lafiya, ruwa, dabbobi da yanayin noma.'
                : 'Tap or speak in English or Hausa for crop health, symptom triage, water purity, livestock checks & maps.',
            style: const TextStyle(
              color: Color(0xFFD1FAE5),
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => state.goToTab(TabId.crop),
                  icon: const Icon(Icons.camera_alt_outlined, size: 16),
                  label: Text(
                    hausa ? 'Duba Shuka' : 'Scan a crop',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0x66FFFFFF)),
                    minimumSize: const Size.fromHeight(42),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => state.goToTab(TabId.health),
                  icon: const Icon(Icons.medical_services_outlined, size: 16),
                  label: Text(
                    hausa ? 'Lafiya' : 'Health check',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryDark,
                    minimumSize: const Size.fromHeight(42),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeatherStrip extends StatelessWidget {
  const _WeatherStrip({required this.hausa});

  final bool hausa;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final forecast = state.forecast;
    final today = forecast.days.isEmpty ? null : forecast.days.first;

    return SectionCard(
      title: hausa ? 'Yanayi' : 'Weather',
      subtitle: today == null
          ? state.t('noWeather')
          : '${forecast.locationName} · '
              '${forecast.isCached ? state.t('cached') : state.t('online')}',
      accent: AppColors.water,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.faint(AppColors.water, 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.wb_sunny_outlined,
            color: AppColors.water, size: 18),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (state.weatherLoading)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              onPressed: () => state.reloadWeather(),
              icon: const Icon(Icons.refresh, size: 18),
              visualDensity: VisualDensity.compact,
              tooltip: state.t('refresh'),
            ),
          TextButton(
            onPressed: () => state.goToTab(TabId.weather),
            child: Text(
              hausa ? 'Duba' : 'Details',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
      child: today == null
          ? const Text(
              '—',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            )
          : Row(
              children: <Widget>[
                _WeatherMetric(
                  label: state.t('max'),
                  value: '${today.max.round()}°C',
                  color: AppColors.danger,
                ),
                const SizedBox(width: 8),
                _WeatherMetric(
                  label: state.t('min'),
                  value: '${today.min.round()}°C',
                  color: AppColors.info,
                ),
                const SizedBox(width: 8),
                _WeatherMetric(
                  label: state.t('rain'),
                  value: '${today.rain.toStringAsFixed(1)} mm',
                  color: AppColors.water,
                ),
              ],
            ),
    );
  }
}

class _WeatherMetric extends StatelessWidget {
  const _WeatherMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.faint(color, 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.faint(color, 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String emoji;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.faint(color, 0.28)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.faint(color, 0.8)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Test hook: the home screen must expose all primary destinations.
List<int> debugHomeDestinations() => const <int>[
      TabId.crop,
      TabId.health,
      TabId.water,
      TabId.livestock,
      TabId.map,
      TabId.calendar,
      TabId.soil,
      TabId.library,
    ];
