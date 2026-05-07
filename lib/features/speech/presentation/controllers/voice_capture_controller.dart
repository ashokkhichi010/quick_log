import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../logs/domain/log_entry.dart';
import '../../../logs/domain/repositories/entries_repository.dart';
import '../../services/speech_service.dart';

enum VoiceCaptureStatus {
  idle,
  requestingPermission,
  unavailable,
  permissionDenied,
  recording,
  processing,
  result,
  error,
}

class VoiceCaptureState {
  const VoiceCaptureState({
    required this.status,
    required this.liveTranscript,
    required this.editableTranscript,
    required this.elapsed,
    required this.errorMessage,
    required this.permissionState,
    required this.activeLocaleLabel,
    required this.isInitialized,
  });

  const VoiceCaptureState.initial()
    : status = VoiceCaptureStatus.idle,
      liveTranscript = '',
      editableTranscript = '',
      elapsed = Duration.zero,
      errorMessage = null,
      permissionState = SpeechPermissionState.unknown,
      activeLocaleLabel = null,
      isInitialized = false;

  final VoiceCaptureStatus status;
  final String liveTranscript;
  final String editableTranscript;
  final Duration elapsed;
  final String? errorMessage;
  final SpeechPermissionState permissionState;
  final String? activeLocaleLabel;
  final bool isInitialized;

  bool get canStartRecording =>
      status != VoiceCaptureStatus.recording &&
      status != VoiceCaptureStatus.processing;

  VoiceCaptureState copyWith({
    VoiceCaptureStatus? status,
    String? liveTranscript,
    String? editableTranscript,
    Duration? elapsed,
    Object? errorMessage = _unset,
    SpeechPermissionState? permissionState,
    Object? activeLocaleLabel = _unset,
    bool? isInitialized,
  }) {
    return VoiceCaptureState(
      status: status ?? this.status,
      liveTranscript: liveTranscript ?? this.liveTranscript,
      editableTranscript: editableTranscript ?? this.editableTranscript,
      elapsed: elapsed ?? this.elapsed,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      permissionState: permissionState ?? this.permissionState,
      activeLocaleLabel: identical(activeLocaleLabel, _unset)
          ? this.activeLocaleLabel
          : activeLocaleLabel as String?,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  static const _unset = Object();
}

class VoiceCaptureController extends StateNotifier<VoiceCaptureState> {
  VoiceCaptureController({
    required SpeechService speechService,
    required EntriesRepository entriesRepository,
    required Uuid uuid,
  }) : _speechService = speechService,
       _entriesRepository = entriesRepository,
       _uuid = uuid,
       super(const VoiceCaptureState.initial()) {
    initialize();
  }

  final SpeechService _speechService;
  final EntriesRepository _entriesRepository;
  final Uuid _uuid;

  Timer? _recordingTimer;
  bool _finishing = false;
  bool _manualStopRequested = false;
  bool _restartInProgress = false;
  bool _speechListeningEstablished = false;
  String _committedTranscript = '';
  String _currentSegment = '';

  Future<void> initialize() async {
    final availability = await _speechService.initialize();
    state = state.copyWith(
      isInitialized: true,
      activeLocaleLabel: availability.activeLocale?.name,
      status: availability.isAvailable
          ? VoiceCaptureStatus.idle
          : VoiceCaptureStatus.unavailable,
      errorMessage: availability.isAvailable
          ? null
          : 'Speech recognition is unavailable on this device.',
    );
  }

  Future<void> toggleRecording() async {
    if (state.status == VoiceCaptureStatus.recording) {
      await stopRecording();
      return;
    }
    await startRecording();
  }

  Future<void> startRecording() async {
    state = state.copyWith(
      status: VoiceCaptureStatus.requestingPermission,
      errorMessage: null,
      liveTranscript: '',
      editableTranscript: '',
      elapsed: Duration.zero,
    );
    _committedTranscript = '';
    _currentSegment = '';

    final permission = await _speechService.ensureMicrophonePermission();
    if (permission != SpeechPermissionState.granted) {
      state = state.copyWith(
        status: VoiceCaptureStatus.permissionDenied,
        permissionState: permission,
        errorMessage: 'Microphone permission was denied.',
      );
      return;
    }

    final available = await _speechService.checkAvailability();
    if (!available) {
      state = state.copyWith(
        status: VoiceCaptureStatus.unavailable,
        permissionState: permission,
        errorMessage: 'Speech recognition is unavailable on this device.',
      );
      return;
    }

    _finishing = false;
    _manualStopRequested = false;
    _restartInProgress = false;
    _speechListeningEstablished = false;
    state = state.copyWith(
      status: VoiceCaptureStatus.recording,
      permissionState: permission,
      activeLocaleLabel: _speechService.activeLocale?.name,
    );
    _startTimer();

    await _speechService.startListening(
      onResult: (words, isFinal) {
        _updateLiveTranscript(words);
        if (isFinal && _manualStopRequested) {
          _commitCurrentSegment();
          _completeRecognition();
        }
      },
      onStatus: (status) async {
        if (status == 'done' || status == 'notListening') {
          if (_manualStopRequested) {
            _commitCurrentSegment();
            _completeRecognition();
            return;
          }

          if (state.status == VoiceCaptureStatus.recording) {
            _commitCurrentSegment();
            await _restartListening();
          }
        }
      },
      onError: (errorMessage, permanent) {
        if (!_manualStopRequested && state.status == VoiceCaptureStatus.recording) {
          _commitCurrentSegment();
          unawaited(_restartListening());
          return;
        }

        if (state.liveTranscript.trim().isNotEmpty) {
          _completeRecognition();
          return;
        }
        state = state.copyWith(
          status: VoiceCaptureStatus.error,
          errorMessage: errorMessage,
        );
      },
    );

    _speechListeningEstablished = true;
  }

  Future<void> stopRecording() async {
    if (state.status != VoiceCaptureStatus.recording) {
      return;
    }
    _manualStopRequested = true;
    _speechListeningEstablished = false;
    state = state.copyWith(status: VoiceCaptureStatus.processing);
    await _speechService.stopListening();
    _completeRecognition();
  }

  Future<void> cancelRecording() async {
    _stopTimer();
    _finishing = false;
    _manualStopRequested = true;
    _speechListeningEstablished = false;
    await _speechService.cancelListening();
    state = state.copyWith(
      status: VoiceCaptureStatus.idle,
      liveTranscript: '',
      editableTranscript: '',
      elapsed: Duration.zero,
      errorMessage: null,
    );
    _committedTranscript = '';
    _currentSegment = '';
  }

  void updateEditableTranscript(String value) {
    state = state.copyWith(editableTranscript: value);
  }

  void clearResult() {
    state = state.copyWith(
      status: VoiceCaptureStatus.idle,
      liveTranscript: '',
      editableTranscript: '',
      elapsed: Duration.zero,
      errorMessage: null,
    );
    _committedTranscript = '';
    _currentSegment = '';
  }

  Future<LogEntry?> saveTranscript() async {
    final transcript = state.editableTranscript.trim();
    if (transcript.isEmpty) {
      state = state.copyWith(
        status: VoiceCaptureStatus.error,
        errorMessage: 'Transcript is empty. Record something first.',
      );
      return null;
    }

    final entry = LogEntry.voice(id: _uuid.v4(), transcript: transcript);
    await _entriesRepository.saveEntry(entry);
    clearResult();
    return entry;
  }

  void restoreForEditing(LogEntry entry) {
    state = state.copyWith(
      status: VoiceCaptureStatus.result,
      liveTranscript: entry.transcriptText,
      editableTranscript: entry.transcriptText,
      errorMessage: null,
    );
  }

  void _completeRecognition() {
    if (_finishing) {
      return;
    }
    _finishing = true;
    _stopTimer();
    _manualStopRequested = false;

    final transcript = state.editableTranscript.trim();
    if (transcript.isEmpty) {
      state = state.copyWith(
        status: VoiceCaptureStatus.idle,
        errorMessage: 'No speech captured. Try again.',
      );
    } else {
      state = state.copyWith(
        status: VoiceCaptureStatus.result,
        editableTranscript: transcript,
        liveTranscript: transcript,
        errorMessage: null,
      );
    }
    _finishing = false;
  }

  Future<void> _restartListening() async {
    if (_manualStopRequested || state.status != VoiceCaptureStatus.recording) {
      return;
    }

    if (_restartInProgress) return;
    _restartInProgress = true;
    _speechListeningEstablished = false;

    try {
      await _speechService.startListening(
        onResult: (words, isFinal) {
          _updateLiveTranscript(words);
          if (isFinal && _manualStopRequested) {
            _commitCurrentSegment();
            _completeRecognition();
          }
        },
        onStatus: (status) async {
          if (status == 'done' || status == 'notListening') {
            if (_manualStopRequested) {
              _commitCurrentSegment();
              _completeRecognition();
              return;
            }

            if (state.status == VoiceCaptureStatus.recording) {
              _commitCurrentSegment();
              await _restartListening();
            }
          }
        },
        onError: (errorMessage, permanent) {
          if (!_manualStopRequested &&
              state.status == VoiceCaptureStatus.recording) {
            _commitCurrentSegment();
            unawaited(_restartListening());
            return;
          }

          if (state.liveTranscript.trim().isNotEmpty) {
            _completeRecognition();
            return;
          }

          _stopTimer();
          state = state.copyWith(
            status: VoiceCaptureStatus.error,
            errorMessage: errorMessage,
          );
        },
      );

      _speechListeningEstablished = true;
    } finally {
      _restartInProgress = false;
    }
  }

  void _updateLiveTranscript(String segment) {
    _currentSegment = segment.trim();
    final fullTranscript = _buildFullTranscript();
    state = state.copyWith(
      liveTranscript: fullTranscript,
      editableTranscript: fullTranscript,
      errorMessage: null,
    );
  }

  void _commitCurrentSegment() {
    final segment = _currentSegment.trim();
    if (segment.isEmpty) {
      return;
    }
    _committedTranscript = _committedTranscript.trim().isEmpty
        ? segment
        : '${_committedTranscript.trim()} $segment';
    _currentSegment = '';
    final fullTranscript = _buildFullTranscript();
    state = state.copyWith(
      liveTranscript: fullTranscript,
      editableTranscript: fullTranscript,
      errorMessage: null,
    );
  }

  String _buildFullTranscript() {
    final committed = _committedTranscript.trim();
    final segment = _currentSegment.trim();
    if (committed.isEmpty) {
      return segment;
    }
    if (segment.isEmpty) {
      return committed;
    }
    return '$committed $segment';
  }

  void _startTimer() {
    _stopTimer();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state = state.copyWith(elapsed: Duration(seconds: timer.tick));

      // If the engine stops listening due to silence without emitting a
      // matching status event quickly enough, restart to keep capture
      // continuous while the UI stays in "recording".
      if (!_manualStopRequested &&
          state.status == VoiceCaptureStatus.recording &&
          _speechListeningEstablished &&
          !_speechService.isListening &&
          !_restartInProgress) {
        unawaited(_restartListening());
      }
    });
  }

  void _stopTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}
