import 'package:get_it/get_it.dart';
import '../logic/physics_engine.dart';
import '../services/logging_service.dart';
import '../services/graph_data_service.dart';
import '../services/selected_node_service.dart';
import '../services/camera_service.dart';
import '../services/debug_service.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  // Services
  getIt.registerLazySingleton<LoggingService>(() => ConsoleLoggingService());
  getIt.registerLazySingleton<GraphDataService>(() => GraphDataService());
  getIt.registerLazySingleton<SelectedNodeService>(() => SelectedNodeService());
  getIt.registerLazySingleton<CameraService>(() => CameraService());
  getIt.registerLazySingleton<DebugService>(() => DebugService());

  // Logic
  // Registering as a factory because GraphScreen manages lifecycle (init/dispose)
  // and we might want a fresh instance if we re-enter the screen.
  getIt.registerFactory<PhysicsEngine>(() => PhysicsEngine());
}
