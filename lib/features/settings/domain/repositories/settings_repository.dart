import '../app_settings.dart';

abstract class SettingsRepository {
  Future<AppSettings> fetchSettings();

  Future<void> saveSettings(AppSettings settings);
}
