import 'services/auth_service.dart';
import 'services/settings_service.dart';
import 'services/task_service.dart';

/// Единые экземпляры сервисов на всё приложение.
final AuthService auth = AuthService();
final SettingsService settings = SettingsService();
final TaskService tasks = TaskService();
