import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum SpeechPermissionState { unknown, granted, denied }

class SpeechLocaleOption {
  const SpeechLocaleOption({
    required this.localeId,
    required this.name,
  });

  final String localeId;
  final String name;
}

class SpeechAvailability {
  const SpeechAvailability({
    required this.isAvailable,
    required this.activeLocale,
    required this.locales,
  });

  final bool isAvailable;
  final SpeechLocaleOption? activeLocale;
  final List<SpeechLocaleOption> locales;
}

abstract class SpeechService {
  Future<SpeechAvailability> initialize();

  Future<bool> checkAvailability();

  Future<SpeechPermissionState> ensureMicrophonePermission();

  Future<void> startListening({
    required void Function(String words, bool isFinal) onResult,
    required void Function(String status) onStatus,
    required void Function(String errorMessage, bool permanent) onError,
  });

  Future<void> stopListening();

  Future<void> cancelListening();

  bool get isListening;

  SpeechLocaleOption? get activeLocale;
}

class LocalSpeechService implements SpeechService {
  LocalSpeechService({SpeechToText? speechToText})
    : _speechToText = speechToText ?? SpeechToText();

  final SpeechToText _speechToText;
  bool _initialized = false;
  int _callbackGeneration = 0;
  SpeechLocaleOption? _activeLocale;
  List<SpeechLocaleOption> _locales = const [];
  void Function(String words, bool isFinal)? _resultCallback;
  void Function(String status)? _statusCallback;
  void Function(String errorMessage, bool permanent)? _errorCallback;

  @override
  SpeechLocaleOption? get activeLocale => _activeLocale;

  @override
  bool get isListening => _speechToText.isListening;

  @override
  Future<SpeechAvailability> initialize() async {
    final initialized = await _speechToText.initialize(
      onError: (error) {
        _errorCallback?.call(error.errorMsg, error.permanent);
      },
      onStatus: (status) {
        _statusCallback?.call(status);
      },
    );
    _initialized = initialized;

    if (initialized) {
      final locales = await _speechToText.locales();
      _locales = [
        for (final locale in locales)
          SpeechLocaleOption(localeId: locale.localeId, name: locale.name),
      ];
      _activeLocale = await _selectPreferredLocale();
    } else {
      _locales = const [];
      _activeLocale = null;
    }

    return SpeechAvailability(
      isAvailable: initialized,
      activeLocale: _activeLocale,
      locales: _locales,
    );
  }

  @override
  Future<bool> checkAvailability() async {
    if (!_initialized) {
      final availability = await initialize();
      return availability.isAvailable;
    }
    return _speechToText.isAvailable;
  }

  @override
  Future<SpeechPermissionState> ensureMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted || status.isLimited) {
      return SpeechPermissionState.granted;
    }
    return SpeechPermissionState.denied;
  }

  @override
  Future<void> startListening({
    required void Function(String words, bool isFinal) onResult,
    required void Function(String status) onStatus,
    required void Function(String errorMessage, bool permanent) onError,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    _resultCallback = onResult;
    _statusCallback = onStatus;
    _errorCallback = onError;
    final generation = ++_callbackGeneration;

    if (_speechToText.isListening) {
      await _speechToText.cancel();
    }

    await _speechToText.listen(
      onResult: (SpeechRecognitionResult result) {
        if (generation != _callbackGeneration) {
          return;
        }
        _resultCallback?.call(result.recognizedWords, result.finalResult);
      },
      // `pauseFor` controls how long we wait for more speech before the
      // underlying engine stops listening. Keep it high so brief pauses
      // don't end capture while the UI still indicates "recording".
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 20),
      localeId: _activeLocale?.localeId,
      onSoundLevelChange: (_) {},
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        onDevice: false,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  @override
  Future<void> stopListening() async {
    _clearCallbacks();
    await _speechToText.stop();
  }

  @override
  Future<void> cancelListening() async {
    _clearCallbacks();
    await _speechToText.cancel();
  }

  void _clearCallbacks() {
    _callbackGeneration++;
    _resultCallback = null;
    _statusCallback = null;
    _errorCallback = null;
  }

  Future<SpeechLocaleOption?> _selectPreferredLocale() async {
    final systemLocale = await _speechToText.systemLocale();
    if (systemLocale != null) {
      final systemMatch = _locales.where((item) {
        return item.localeId == systemLocale.localeId;
      }).cast<SpeechLocaleOption?>().fold<SpeechLocaleOption?>(
        null,
        (previousValue, element) => previousValue ?? element,
      );
      if (systemMatch != null) {
        return _preferMixedLanguageAround(systemMatch) ?? systemMatch;
      }
    }

    return _preferMixedLanguageAround(null) ??
        (_locales.isEmpty ? null : _locales.first);
  }

  SpeechLocaleOption? _preferMixedLanguageAround(SpeechLocaleOption? fallback) {
    const preferredTags = ['hi-IN', 'en-IN', 'hi', 'en'];
    for (final tag in preferredTags) {
      for (final locale in _locales) {
        if (locale.localeId.toLowerCase().contains(tag.toLowerCase())) {
          return locale;
        }
      }
    }
    return fallback;
  }
}
