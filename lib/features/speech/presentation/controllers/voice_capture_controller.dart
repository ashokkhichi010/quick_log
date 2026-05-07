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
  paused,
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
  bool _startingListening = false;
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
    _startingListening = false;
    state = state.copyWith(
      status: VoiceCaptureStatus.recording,
      permissionState: permission,
      activeLocaleLabel: _speechService.activeLocale?.name,
    );
    _startTimer();

    await _beginListeningSession();
  }

  Future<void> stopRecording() async {
    if (state.status != VoiceCaptureStatus.recording &&
        state.status != VoiceCaptureStatus.paused) {
      return;
    }
    _manualStopRequested = true;
    state = state.copyWith(status: VoiceCaptureStatus.processing);
    if (_speechService.isListening) {
      await _speechService.stopListening();
    }
    _completeRecognition();
  }

  Future<void> cancelRecording() async {
    _stopTimer();
    _finishing = false;
    _manualStopRequested = true;
    _startingListening = false;
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

  Future<void> continueRecording() async {
    if (state.status != VoiceCaptureStatus.paused) {
      return;
    }

    _manualStopRequested = false;
    state = state.copyWith(status: VoiceCaptureStatus.recording, errorMessage: null);
    _startTimer();
    await _beginListeningSession();
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
    _startingListening = false;

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
    final committed = _committedTranscript.trim();
    if (committed.isEmpty) {
      _committedTranscript = segment;
    } else {
      // Some recognizers resend previously captured text after pause/resume.
      // Append only the delta to avoid duplicate transcript chunks.
      final normalizedCommitted = _normalizeWhitespace(committed);
      final normalizedSegment = _normalizeWhitespace(segment);

      if (normalizedSegment == normalizedCommitted ||
          normalizedCommitted.endsWith(normalizedSegment)) {
        _currentSegment = '';
        return;
      }

      if (normalizedSegment.startsWith(normalizedCommitted)) {
        final delta = normalizedSegment.substring(normalizedCommitted.length).trim();
        if (delta.isNotEmpty) {
          _committedTranscript = '$committed $delta'.trim();
        }
      } else {
        _committedTranscript = '$committed $segment'.trim();
      }
    }

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

  String _normalizeWhitespace(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void _startTimer() {
    final baseElapsed = state.elapsed;
    _stopTimer();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state = state.copyWith(
        elapsed: baseElapsed + Duration(seconds: timer.tick),
      );
    });
  }

  Future<void> _beginListeningSession() async {
    if (_startingListening || _manualStopRequested) {
      return;
    }
    _startingListening = true;
    try {
      await _speechService.startListening(
        onResult: (words, isFinal) {
          _updateLiveTranscript(words);
          if (isFinal && _manualStopRequested) {
            _commitCurrentSegment();
            _completeRecognition();
          }
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (_manualStopRequested) {
              _commitCurrentSegment();
              _completeRecognition();
              return;
            }
            _pauseAfterEngineStopped();
          }
        },
        onError: (errorMessage, permanent) {
          if (_manualStopRequested) {
            _completeRecognition();
            return;
          }
          _pauseAfterEngineStopped(errorMessage: errorMessage);
        },
      );
    } finally {
      _startingListening = false;
    }
  }

  void _pauseAfterEngineStopped({String? errorMessage}) {
    if (state.status != VoiceCaptureStatus.recording) {
      return;
    }
    _commitCurrentSegment();
    _stopTimer();
    state = state.copyWith(
      status: VoiceCaptureStatus.paused,
      errorMessage: errorMessage,
      liveTranscript: _buildFullTranscript(),
      editableTranscript: _buildFullTranscript(),
    );
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
