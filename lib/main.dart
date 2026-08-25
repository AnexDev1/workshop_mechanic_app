import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:geolocator/geolocator.dart';
import 'core/di/service_locator.dart';
import 'core/localization/app_locale.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/pages/login_page.dart';
import 'features/tasks/bloc/task_bloc.dart';
import 'features/tasks/pages/task_list_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLocaleController.instance.initialize();
  await appThemeController.initialize();
  await setupServiceLocator();
  runApp(const WorkshopMechanicApp());
}

class WorkshopMechanicApp extends StatelessWidget {
  const WorkshopMechanicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>(
      create: (_) => sl<AuthBloc>()..add(CheckAuthStatus()),
      child: AppLanguageScope(
        controller: AppLocaleController.instance,
        child: ValueListenableBuilder<String>(
          valueListenable: AppLocaleController.instance,
          builder: (context, language, _) => ValueListenableBuilder<ThemeMode>(
            valueListenable: appThemeController,
            builder: (context, themeMode, _) => MaterialApp(
              title: AppStrings.translate('workshop'),
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: themeMode,
              themeAnimationDuration: const Duration(milliseconds: 220),
              locale:
                  language == 'am' ? const Locale('am') : const Locale('en'),
              supportedLocales: const [Locale('en'), Locale('am')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: BlocBuilder<AuthBloc, AuthState>(
                builder: (ctx, state) {
                  if (state is AuthAuthenticated) {
                    return BlocProvider(
                      create: (_) => sl<TaskBloc>()..add(const LoadTasks()),
                      child: const LocationGate(child: TaskListPage()),
                    );
                  }
                  return const LoginPage();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LocationGate extends StatefulWidget {
  final Widget child;
  const LocationGate({super.key, required this.child});
  @override
  State<LocationGate> createState() => _LocationGateState();
}

class _LocationGateState extends State<LocationGate>
    with WidgetsBindingObserver {
  bool _ready = false;
  bool _checking = true;
  bool _openedSettingsAutomatically = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (!mounted) return;
    setState(() => _checking = true);
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied)
      permission = await Geolocator.requestPermission();
    final enabled = await Geolocator.isLocationServiceEnabled();
    final granted = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    final accuracy = granted ? await Geolocator.getLocationAccuracy() : null;
    if (mounted)
      setState(() {
        _ready =
            enabled && granted && accuracy != LocationAccuracyStatus.reduced;
        _checking = false;
      });

    // The OS owns these settings, so we cannot switch them on silently. Open
    // the exact system screen automatically once to guide non-technical users.
    if (!_ready && !_openedSettingsAutomatically) {
      _openedSettingsAutomatically = true;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (enabled && granted && accuracy == LocationAccuracyStatus.reduced) {
        await Geolocator.openAppSettings();
      } else if (!enabled) {
        await Geolocator.openLocationSettings();
      } else if (!granted) {
        await Geolocator.openAppSettings();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    return Scaffold(
        body: Center(
            child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.gps_fixed_rounded,
                      size: 56, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 18),
                  const Text('Precise location is required',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  const Text(
                      'Turn on Location and allow Precise location to use this app.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                      onPressed: _checking
                          ? null
                          : () async {
                              await Geolocator.openLocationSettings();
                              await _check();
                            },
                      icon: const Icon(Icons.settings_rounded),
                      label: const Text('Open location settings')),
                  TextButton(
                      onPressed: _check,
                      child: const Text('I turned it on — check again')),
                ]))));
  }
}
