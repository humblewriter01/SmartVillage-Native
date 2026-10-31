import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_theme.dart';
import 'state/app_state.dart';
import 'widgets/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge with a dark status bar to match the deep-green branding.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  final state = AppState();
  await state.init();

  runApp(SmartVillageApp(state: state));
}

/// SmartVillage — native Flutter rewrite of the React/Capacitor app.
class SmartVillageApp extends StatelessWidget {
  const SmartVillageApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'SmartVillage',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AppShell(),
        builder: (context, child) {
          // Keep text scaling in a sane band: farmers often enlarge system
          // fonts, but the cards are dense.
          final media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(
                minScaleFactor: 0.9,
                maxScaleFactor: 1.25,
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
