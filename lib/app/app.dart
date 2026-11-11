import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_theme.dart';
import '../features/settings/application/appearance_controller.dart';
import 'app_router.dart';

class MwbApp extends ConsumerWidget {
  const MwbApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppThemeBuilder.build(appearance.themeId, Brightness.light),
      darkTheme: AppThemeBuilder.build(appearance.themeId, Brightness.dark),
      themeMode: appearance.themeMode,
      themeAnimationDuration: const Duration(milliseconds: 260),
      routerConfig: router,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        // Respect system text size while protecting layouts at extremes.
        maxScaleFactor: 1.6,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
