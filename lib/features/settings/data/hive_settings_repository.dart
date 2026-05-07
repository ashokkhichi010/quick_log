import 'package:hive/hive.dart';

import '../../../core/constants/hive_boxes.dart';
import '../domain/app_settings.dart';
import '../domain/repositories/settings_repository.dart';

class HiveSettingsRepository implements SettingsRepository {
  const HiveSettingsRepository(this._box);

  final Box<AppSettings> _box;

  @override
  Future<AppSettings> fetchSettings() async {
    return _box.get(HiveBoxes.settingsKey) ?? const AppSettings.defaults();
  }

  Future<void> ensureSettings() async {
    if (!_box.containsKey(HiveBoxes.settingsKey)) {
      await saveSettings(const AppSettings.defaults());
    }
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    await _box.put(HiveBoxes.settingsKey, settings);
  }
}
