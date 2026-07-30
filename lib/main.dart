import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
          builder: (context, language, _) => MaterialApp(
            title: AppStrings.translate('workshop'),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            locale: language == 'am' ? const Locale('am') : const Locale('en'),
            supportedLocales: const [Locale('en'), Locale('am')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: BlocBuilder<AuthBloc, AuthState>(
              builder: (ctx, state) {
                if (state is AuthAuthenticated) {
                  return BlocProvider(
                    create: (_) => sl<TaskBloc>()..add(const LoadTasks()),
                    child: const TaskListPage(),
                  );
                }
                return const LoginPage();
              },
            ),
          ),
        ),
      ),
    );
  }
}
