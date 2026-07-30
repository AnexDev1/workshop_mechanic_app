import 'package:get_it/get_it.dart';
import '../network/odoo_client.dart';
import '../network/offline_queue_service.dart';
import '../sync/sync_manager.dart';
import '../../features/tasks/data/task_repository.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/tasks/bloc/task_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/hive_task_cache.dart';

final sl = GetIt.instance;

Future<void> setupServiceLocator() async {
  final prefs = await SharedPreferences.getInstance();
  final taskCache = HiveTaskCache();
  await taskCache.initialize();
  final savedUrl =
      prefs.getString('odoo_server_url') ?? 'http://localhost:8064';

  // Core
  final odooClient = OdooClient(baseUrl: savedUrl);
  sl.registerSingleton<OdooClient>(odooClient);
  sl.registerSingleton<HiveTaskCache>(taskCache);

  // Init SyncManager
  await SyncManager().initialize(odooClient);

  sl.registerSingleton<OfflineQueueService>(
      OfflineQueueService(sl<OdooClient>()));

  // Repositories
  sl.registerLazySingleton<TaskRepository>(
    () => TaskRepository(
      client: sl<OdooClient>(),
      taskCache: sl<HiveTaskCache>(),
    ),
  );

  // BLoCs (factories so each registration gets fresh instance)
  sl.registerFactory<AuthBloc>(() => AuthBloc(client: sl<OdooClient>()));
  sl.registerFactory<TaskBloc>(() => TaskBloc(repo: sl<TaskRepository>()));
}
