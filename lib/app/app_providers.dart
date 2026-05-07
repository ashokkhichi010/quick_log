import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/services/export_service.dart';
import '../core/services/notifications_service.dart';
import '../features/logs/domain/repositories/categories_repository.dart';
import '../features/logs/domain/repositories/entries_repository.dart';
import '../features/logs/presentation/controllers/entries_controller.dart';
import '../features/speech/presentation/controllers/voice_capture_controller.dart';
import '../features/speech/services/speech_service.dart';
import '../features/settings/domain/repositories/settings_repository.dart';
import '../features/settings/presentation/controllers/app_settings_controller.dart';
import '../features/settings/presentation/controllers/categories_controller.dart';

final entriesRepositoryProvider = Provider<EntriesRepository>(
  (ref) =>
      throw UnimplementedError('Entries repository has not been bootstrapped'),
);

final categoriesRepositoryProvider = Provider<CategoriesRepository>(
  (ref) => throw UnimplementedError(
    'Categories repository has not been bootstrapped',
  ),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) =>
      throw UnimplementedError('Settings repository has not been bootstrapped'),
);

final notificationsServiceProvider = Provider<NotificationsService>(
  (ref) => throw UnimplementedError(
    'Notifications service has not been bootstrapped',
  ),
);

final exportServiceProvider = Provider<ExportService>(
  (ref) => throw UnimplementedError('Export service has not been bootstrapped'),
);

final speechServiceProvider = Provider<SpeechService>(
  (ref) => throw UnimplementedError('Speech service has not been bootstrapped'),
);

final uuidProvider = Provider<Uuid>((ref) => const Uuid());

final entriesControllerProvider =
    StateNotifierProvider<EntriesController, EntriesState>(
      (ref) => EntriesController(
        repository: ref.read(entriesRepositoryProvider),
        uuid: ref.read(uuidProvider),
      ),
    );

final categoriesControllerProvider =
    StateNotifierProvider<CategoriesController, CategoriesState>(
      (ref) => CategoriesController(
        repository: ref.read(categoriesRepositoryProvider),
        entriesRepository: ref.read(entriesRepositoryProvider),
        uuid: ref.read(uuidProvider),
      ),
    );

final appSettingsControllerProvider =
    StateNotifierProvider<AppSettingsController, AppSettingsState>(
      (ref) => AppSettingsController(
        repository: ref.read(settingsRepositoryProvider),
        notificationsService: ref.read(notificationsServiceProvider),
      ),
    );

final voiceCaptureControllerProvider =
    StateNotifierProvider<VoiceCaptureController, VoiceCaptureState>(
      (ref) => VoiceCaptureController(
        speechService: ref.read(speechServiceProvider),
        entriesRepository: ref.read(entriesRepositoryProvider),
        uuid: ref.read(uuidProvider),
      ),
    );
