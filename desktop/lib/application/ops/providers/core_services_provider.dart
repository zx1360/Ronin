import 'package:northstar/infrastructure/ops/dependency_checker.dart';
import 'package:northstar/infrastructure/ops/ops_api_client.dart';
import 'package:northstar/infrastructure/ops/ops_persistence_repository.dart';
import 'package:northstar/infrastructure/ops/path_picker_service.dart';
import 'package:northstar/infrastructure/ops/windows_process_manager.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'core_services_provider.g.dart';

@Riverpod(keepAlive: true)
OpsPersistenceRepository opsPersistenceRepository(OpsPersistenceRepositoryRef ref) {
  return OpsPersistenceRepository();
}

@Riverpod(keepAlive: true)
OpsApiClient opsApiClient(OpsApiClientRef ref) {
  return OpsApiClient();
}

@Riverpod(keepAlive: true)
WindowsProcessManager windowsProcessManager(WindowsProcessManagerRef ref) {
  return WindowsProcessManager();
}

@Riverpod(keepAlive: true)
PathPickerService pathPickerService(PathPickerServiceRef ref) {
  return PathPickerService();
}

@Riverpod(keepAlive: true)
DependencyChecker dependencyChecker(DependencyCheckerRef ref) {
  return DependencyChecker();
}
