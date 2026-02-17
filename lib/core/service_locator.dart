import 'package:get_it/get_it.dart';
import '../logic/physics_engine.dart';
import '../services/logging_service.dart';

final getIt = GetIt.instance;

void setupServiceLocator() {
  // Services
  getIt.registerLazySingleton<LoggingService>(() => ConsoleLoggingService());

  // Logic
  // Registering as a factory because GraphScreen manages lifecycle (init/dispose)
  // and we might want a fresh instance if we re-enter the screen.
  getIt.registerFactory<PhysicsEngine>(() => PhysicsEngine());
}
