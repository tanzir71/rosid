import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rosid/core/l10n/app_localizations.dart';
import 'package:rosid/core/routing/app_router.dart';
import 'package:rosid/core/settings/app_settings.dart';
import 'package:rosid/core/theme/app_theme.dart';
import 'package:rosid/data/repositories/startup_cleanup_repository.dart';
import 'package:rosid/features/safety/lock_screen.dart';
import 'package:rosid/safety/app_lock_service.dart';

class RosidApp extends ConsumerStatefulWidget {
  const RosidApp({super.key});

  @override
  ConsumerState<RosidApp> createState() => _RosidAppState();
}

class _RosidAppState extends ConsumerState<RosidApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = ref.read(appLockControllerProvider.notifier);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      lock.onAppBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      lock.onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(appSettingsProvider);
    final startupCleanup = ref.watch(startupCleanupProvider);
    final lockState = ref.watch(appLockControllerProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
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
          final c = RosidColors.of(context);
          return ColoredBox(
            color: c.bgCanvas,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final content = child ?? const SizedBox.shrink();
        if (lockState.isLocked) {
          return Stack(
            children: [
              Offstage(offstage: true, child: content),
              const AppLockScreen(),
            ],
          );
        }
        return content;
      },
    );
  }
}
