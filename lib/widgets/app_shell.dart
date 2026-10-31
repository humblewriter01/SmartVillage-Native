import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../screens/about_screen.dart';
import '../screens/crop_library_screen.dart';
import '../screens/crop_screen.dart';
import '../screens/farming_calendar_screen.dart';
import '../screens/health_screen.dart';
import '../screens/history_screen.dart';
import '../screens/home_screen.dart';
import '../screens/knowledge_screen.dart';
import '../screens/livestock_screen.dart';
import '../screens/offline_map_screen.dart';
import '../screens/soil_health_screen.dart';
import '../screens/water_quality_screen.dart';
import '../screens/weather_screen.dart';
import '../state/app_state.dart';
import '../utils/translations.dart';
import 'language_toggle.dart';
import 'voice_settings_sheet.dart';

/// The app frame: deep-green header, left drawer, bottom navigation and the
/// active screen — a 1:1 structural port of `App.tsx`.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const List<_NavItem> _bottomItems = <_NavItem>[
    _NavItem(TabId.home, 'home', '🏠', 'Home'),
    _NavItem(TabId.crop, 'crop', '🌾', 'Gona'),
    _NavItem(TabId.health, 'health', '🏥', 'Lafiya'),
    _NavItem(TabId.livestock, 'livestock', '🐄', 'Dabbobi'),
    _NavItem(TabId.map, 'map', '🗺️', 'Taswira'),
  ];

  static const List<_DrawerItem> _drawerItems = <_DrawerItem>[
    _DrawerItem(TabId.water, '💧', 'Water Quality', 'Ruwa', 'Drinking water safety',
        'Duba tsabtar ruwan sha'),
    _DrawerItem(TabId.calendar, '📅', 'Farming Calendar', 'Kalandar Noma',
        'Seasonal planting windows', 'Lokutan shuka da girbi'),
    _DrawerItem(TabId.soil, '🌱', 'Soil Health', 'Lafiyar Ƙasa',
        'Soil moisture & pH tracker', 'Auna laima da pH na gona'),
    _DrawerItem(TabId.knowledge, '📖', 'Knowledge', 'Ilimi',
        'Farming & health guides', 'Hanyoyin noma da kiwon lafiya'),
    _DrawerItem(TabId.history, '🕐', 'History', 'Tarihi', 'Past saved evaluations',
        'Bayanai da aka ajiye'),
    _DrawerItem(TabId.weather, '⛅', 'Weather', 'Yanayi',
        '7-day forecast', 'Hasashen ruwan sama na kwanaki 7'),
    _DrawerItem(TabId.library, '📚', 'Crop Disease Library', 'Laburaren Cututtuka',
        'Disease visual catalog', 'Hotunan cututtuka da magunguna'),
    _DrawerItem(TabId.about, 'ℹ️', 'About SmartVillage', 'Game da SmartVillage',
        'App info, creator & licensing', 'Bayanai da lasisi'),
  ];

  Widget _screenFor(int tab) {
    switch (tab) {
      case TabId.crop:
        return const CropScreen();
      case TabId.health:
        return const HealthScreen();
      case TabId.weather:
        return const WeatherScreen();
      case TabId.knowledge:
        return const KnowledgeScreen();
      case TabId.water:
        return const WaterQualityScreen();
      case TabId.livestock:
        return const LivestockScreen();
      case TabId.map:
        return const OfflineMapScreen();
      case TabId.calendar:
        return const FarmingCalendarScreen();
      case TabId.library:
        return const CropLibraryScreen();
      case TabId.history:
        return const HistoryScreen();
      case TabId.soil:
        return const SoilHealthScreen();
      case TabId.about:
        return const AboutScreen();
      case TabId.home:
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Scaffold(
      drawer: _AppDrawer(items: _drawerItems),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.primaryBorder),
              ),
              alignment: Alignment.center,
              child: const Text('🌿', style: TextStyle(fontSize: 16)),
            ),
            Text(
              state.t('appName'),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDeep,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppColors.primaryBorder),
              ),
              child: Text(
                state.pick('100% OFFLINE', 'BA INTANET'),
                style: const TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          _NetworkPill(online: state.isOnline, hausa: state.isHausa),
          const SizedBox(width: 4),
          const LanguageToggle(),
          IconButton(
            onPressed: () => showVoiceSettingsSheet(context),
            icon: const Icon(Icons.record_voice_over_outlined,
                color: AppColors.textSecondary, size: 22),
            tooltip: state.pick('Voice profile', 'Saitin murya'),
          ),
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.primaryBorder),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey<int>(state.tab),
            child: _screenFor(state.tab),
          ),
        ),
      ),
      bottomNavigationBar: _BottomNav(items: _bottomItems, currentTab: state.tab),
    );
  }
}

class _NetworkPill extends StatelessWidget {
  const _NetworkPill({required this.online, required this.hausa});

  final bool online;
  final bool hausa;

  @override
  Widget build(BuildContext context) {
    final color = online ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.faint(color, 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.faint(color, 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(online ? Icons.wifi : Icons.wifi_off, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            online
                ? (hausa ? 'Intanet' : 'Online')
                : (hausa ? 'Babu intanet' : 'Offline'),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.items, required this.currentTab});

  final List<_NavItem> items;
  final int currentTab;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: items.map((item) {
              final active = currentTab == item.tabId;
              return Expanded(
                child: InkWell(
                  onTap: () => state.goToTab(item.tabId),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.faint(AppColors.primary, 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item.emoji,
                          style: TextStyle(
                            fontSize: active ? 21 : 19,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.t(item.labelKey),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight:
                              active ? FontWeight.w900 : FontWeight.w600,
                          color: active
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({required this.items});

  final List<_DrawerItem> items;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final hausa = state.isHausa;

    return Drawer(
      backgroundColor: AppColors.surface,
      child: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 48, 18, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Text('🌿', style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          state.t('appName'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          hausa ? 'Noma da lafiya ba intanet' : 'Offline farm & health aid',
                          style: const TextStyle(
                            color: Color(0xFFD1FAE5),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  state.t('tagline'),
                  style: const TextStyle(
                    color: Color(0xFFECFDF5),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: items.map((item) {
                final active = state.tab == item.tabId;
                return ListTile(
                  dense: true,
                  selected: active,
                  selectedTileColor: AppColors.primarySoft,
                  leading: Text(item.emoji, style: const TextStyle(fontSize: 18)),
                  title: Text(
                    hausa ? item.labelHa : item.labelEn,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color: active ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    hausa ? item.subtitleHa : item.subtitleEn,
                    style: const TextStyle(fontSize: 10.5),
                  ),
                  onTap: () {
                    state.goToTab(item.tabId);
                    Navigator.of(context).pop();
                  },
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  hausa ? 'Zaɓi Harshe (Language):' : 'Select Language:',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _LanguageButton(
                        label: 'English 🇬🇧',
                        selected: !hausa,
                        onTap: () => state.setLanguage(AppLanguage.english),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _LanguageButton(
                        label: 'Hausa 🇳🇬',
                        selected: hausa,
                        onTap: () => state.setLanguage(AppLanguage.hausa),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text(
                      'SmartVillage v2.0',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      hausa ? 'A shirye ba intanet' : '100% Offline Ready',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
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

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primaryDark : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.tabId, this.labelKey, this.emoji, this.debugLabel);

  final int tabId;
  final String labelKey;
  final String emoji;
  final String debugLabel;
}

class _DrawerItem {
  const _DrawerItem(
    this.tabId,
    this.emoji,
    this.labelEn,
    this.labelHa,
    this.subtitleEn,
    this.subtitleHa,
  );

  final int tabId;
  final String emoji;
  final String labelEn;
  final String labelHa;
  final String subtitleEn;
  final String subtitleHa;
}
