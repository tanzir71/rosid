import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rosid/core/l10n/app_localizations.dart';
import 'package:rosid/core/routing/app_router.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/data/repositories/startup_cleanup_repository.dart';

class RosidApp extends ConsumerWidget {
  const RosidApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(appSettingsProvider);
    final startupCleanup = ref.watch(startupCleanupProvider);
    return MaterialApp.router(
      title: 'Rosid',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) {
        if (startupCleanup.isLoading) {
          return const ColoredBox(
            color: Color(0xFFF7F4EC),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
