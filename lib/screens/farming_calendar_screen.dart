import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/planting_calendar.dart';
import '../services/planting_calendar_service.dart';
import '../state/app_state.dart';
import '../widgets/section_card.dart';
import '../widgets/speak_button.dart';

/// Farming Calendar / Kalandar Noma.
/// Port of `PlantingCalendarScreen.tsx`.
class FarmingCalendarScreen extends StatefulWidget {
  const FarmingCalendarScreen({super.key});

  @override
  State<FarmingCalendarScreen> createState() => _FarmingCalendarScreenState();
}

class _FarmingCalendarScreenState extends State<FarmingCalendarScreen> {
  int _month = DateTime.now().month;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final hausa = state.isHausa;
    final season = PlantingCalendarService.currentSeason(_month);
    final recommendations = PlantingCalendarService.recommendationsFor(
      DateTime(DateTime.now().year, _month, 15),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: season.harmattanWarning
                  ? const <Color>[Color(0xFFB45309), Color(0xFF92400E)]
                  : const <Color>[Color(0xFFCA8A04), Color(0xFF854D0E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      PlantingCalendarService.monthName(_month, hausa),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  SpeakButton(
                    color: Colors.white,
                    background: const Color(0x33FFFFFF),
                    textBuilder: () =>
                        '${season.displayName(hausa)}. ${season.displayDescription(hausa)}',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                season.displayName(hausa),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                season.displayDescription(hausa),
                style: const TextStyle(
                  color: Color(0xFFFEF3C7),
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
              if (season.harmattanWarning) ...<Widget>[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    hausa
                        ? 'Kula da sanyi da kura: rufe shuke-shuke da yamma, kuma a shayar da safe.'
                        : 'Harmattan care: cover seedlings at night and irrigate in the early morning.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          title: hausa ? 'Zaɓi Wata' : 'Select month',
          accent: AppColors.calendar,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List<int>.generate(12, (i) => i + 1).map((month) {
              return ChoiceChip(
                selected: month == _month,
                label: Text(
                  PlantingCalendarService.monthName(month, hausa)
                      .substring(0, 3),
                  style: const TextStyle(fontSize: 10.5),
                ),
                onSelected: (_) => setState(() => _month = month),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        SectionHeader(
          title: hausa ? 'Shawarar Wannan Wata' : 'This month\'s plan',
          subtitle: hausa
              ? 'Lokutan shuka, girbi da kulawa'
              : 'Planting, harvest and care windows',
          icon: Icons.event_note,
          accent: AppColors.calendar,
        ),
        ...recommendations.take(8).map(
              (recommendation) => _RecommendationTile(
                recommendation: recommendation,
                hausa: hausa,
              ),
            ),
        const SizedBox(height: 8),
        SectionCard(
          title: hausa ? 'Dukkan Kalandar Amfanin Gona' : 'All crop calendars',
          subtitle: hausa
              ? 'Bude kowace shuka don ganin cikakken lokaci'
              : 'Open a crop for the full seasonal schedule',
          accent: AppColors.calendar,
          child: Column(
            children: PlantingCalendarService.crops
                .map(
                  (crop) => ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(bottom: 10),
                    title: Text(
                      crop.displayName(hausa),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      '${PlantingCalendarService.seasonTypeLabel(crop.seasonType, hausa)} · '
                      '${PlantingCalendarService.windowLabel(crop, hausa)}',
                      style: const TextStyle(fontSize: 10.5),
                    ),
                    children: <Widget>[
                      InfoRow(
                        label: hausa ? 'Ruwan sama' : 'Rainfall',
                        value: crop.idealRainfall,
                      ),
                      InfoRow(
                        label: hausa ? 'Zafin jiki' : 'Temperature',
                        value: crop.idealTemp,
                      ),
                      InfoRow(
                        label: hausa ? 'Girbi' : 'Harvest',
                        value:
                            '${PlantingCalendarService.monthName(crop.harvestStartMonth, hausa)}'
                            ' – ${PlantingCalendarService.monthName(crop.harvestEndMonth, hausa)}',
                      ),
                      InfoRow(
                        label: hausa ? 'Kula da ƙaramin shuka' : 'Baby plant care',
                        value: crop.localizedBabyCare(hausa),
                        valueColor: AppColors.soil,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        crop.localizedAdvice(hausa),
                        style: const TextStyle(fontSize: 11.5, height: 1.45),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  const _RecommendationTile({
    required this.recommendation,
    required this.hausa,
  });

  final PlantingRecommendation recommendation;
  final bool hausa;

  @override
  Widget build(BuildContext context) {
    Color color;
    String statusLabel;
    switch (recommendation.status) {
      case RecommendationStatus.optimal:
        color = AppColors.success;
        statusLabel = hausa ? 'Lokaci ya yi' : 'Plant now';
        break;
      case RecommendationStatus.careWindow:
        color = AppColors.calendar;
        statusLabel = hausa ? 'Lokacin girbi' : 'Harvest window';
        break;
      case RecommendationStatus.upcoming:
        color = AppColors.info;
        statusLabel = hausa ? 'Yana zuwa' : 'Upcoming';
        break;
      case RecommendationStatus.past:
        color = AppColors.textMuted;
        statusLabel = hausa ? 'Ya wuce' : 'Out of season';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        // `BoxDecoration` has a single `border` slot. `BorderDirectional` is a
        // `BoxBorder`, so it goes there and keeps the "thick leading edge,
        // hairline elsewhere" look without a second decoration.
        border: BorderDirectional(
          start: BorderSide(color: color, width: 3.5),
          top: BorderSide(color: AppColors.faint(color, 0.3)),
          end: BorderSide(color: AppColors.faint(color, 0.3)),
          bottom: BorderSide(color: AppColors.faint(color, 0.3)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  recommendation.displayTitle(hausa),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Pill(label: statusLabel, color: color),
              SpeakButton(
                compact: true,
                color: color,
                textBuilder: () =>
                    '${recommendation.displayTitle(hausa)}. ${recommendation.displayReason(hausa)}',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            recommendation.displayReason(hausa),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
