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
    unawaited(initialize());
  }

  final SpeechService _speechService;
  final EntriesRepository _entriesRepository;
  final Uuid _uuid;

  Timer? _recordingTimer;
  Future<void> _lifecycleLock = Future<void>.value();

  String? _activeSessionId;
  String? _stopRequestedSessionId;
  bool _sessionCommitted = false;
  bool _sessionFinalized = false;

  String _committedTranscript = '';
  String _sessionTranscript = '';

  Future<void> initialize() async {
    final availability = await _speechService.initialize();
    if (!mounted) {
      return;
    }

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

  Future<void> beginNewCapture() {
    return _serialize(() async {
      await _cancelActiveRecognition();
      _resetTranscriptBuffers();

      state = state.copyWith(
        status: VoiceCaptureStatus.idle,
        liveTranscript: '',
        editableTranscript: '',
        elapsed: Duration.zero,
        errorMessage: null,
      );

      await _startFreshRecordingLocked();
    });
  }

  Future<void> toggleRecording() {
    return _serialize(() async {
      if (state.status == VoiceCaptureStatus.recording ||
          state.status == VoiceCaptureStatus.paused) {
        await _completeCurrentRecordingLocked();
        return;
      }

      await _startFreshRecordingLocked();
    });
  }

  Future<void> startRecording() {
    return _serialize(_startFreshRecordingLocked);
  }

  Future<void> stopRecording() {
    return _serialize(_completeCurrentRecordingLocked);
  }

  Future<void> cancelRecording() {
    return _serialize(() async {
      await _cancelActiveRecognition();
      _resetTranscriptBuffers();

      state = state.copyWith(
        status: VoiceCaptureStatus.idle,
        liveTranscript: '',
        editableTranscript: '',
        elapsed: Duration.zero,
        errorMessage: null,
      );
    });
  }

  void updateEditableTranscript(String value) {
    if (value == state.editableTranscript) {
      return;
    }

    state = state.copyWith(editableTranscript: value);
  }

  void clearResult() {
    _resetTranscriptBuffers();

    state = state.copyWith(
      status: VoiceCaptureStatus.idle,
      liveTranscript: '',
      editableTranscript: '',
      elapsed: Duration.zero,
      errorMessage: null,
    );
  }

  Future<void> continueRecording() {
    return _serialize(() async {
      if (state.status != VoiceCaptureStatus.paused) {
        return;
      }

      await _startSessionLocked(
        preserveEditableTranscript: true,
        errorMessage: null,
      );
    });
  }

  Future<void> continueFromReview() {
    return _serialize(() async {
      if (state.status != VoiceCaptureStatus.result) {
        return;
      }

      _committedTranscript = _normalizeWhitespace(state.editableTranscript);
      _sessionTranscript = '';

      await _startSessionLocked(
        preserveEditableTranscript: true,
        errorMessage: null,
      );
    });
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
    _committedTranscript = _normalizeWhitespace(entry.transcriptText);
    _sessionTranscript = '';
    _activeSessionId = null;
    _stopRequestedSessionId = null;
    _sessionCommitted = false;
    _sessionFinalized = false;

    state = state.copyWith(
      status: VoiceCaptureStatus.result,
      liveTranscript: _committedTranscript,
      editableTranscript: _committedTranscript,
      errorMessage: null,
    );
  }

  Future<void> _startFreshRecordingLocked() async {
    state = state.copyWith(
      status: VoiceCaptureStatus.requestingPermission,
      liveTranscript: _committedTranscript,
      editableTranscript: state.editableTranscript,
      errorMessage: null,
      elapsed: state.status == VoiceCaptureStatus.paused
          ? state.elapsed
          : Duration.zero,
    );

    final permission = await _speechService.ensureMicrophonePermission();
    if (permission != SpeechPermissionState.granted) {
      _stopTimer();
      state = state.copyWith(
        status: VoiceCaptureStatus.permissionDenied,
        permissionState: permission,
        errorMessage: 'Microphone permission was denied.',
      );
      return;
    }

    final available = await _speechService.checkAvailability();
    if (!available) {
      _stopTimer();
      state = state.copyWith(
        status: VoiceCaptureStatus.unavailable,
        permissionState: permission,
        errorMessage: 'Speech recognition is unavailable on this device.',
      );
      return;
    }

    if (state.status != VoiceCaptureStatus.paused) {
      _resetTranscriptBuffers();
      state = state.copyWith(elapsed: Duration.zero);
    }

    await _startSessionLocked(
      preserveEditableTranscript: true,
      permissionState: permission,
      errorMessage: null,
    );
  }

  Future<void> _startSessionLocked({
    required bool preserveEditableTranscript,
    SpeechPermissionState? permissionState,
    String? errorMessage,
  }) async {
    await _cancelActiveRecognition();

    final sessionId = _uuid.v4();
    _activeSessionId = sessionId;
    _stopRequestedSessionId = null;
    _sessionCommitted = false;
    _sessionFinalized = false;
    _sessionTranscript = '';

    state = state.copyWith(
      status: VoiceCaptureStatus.recording,
      liveTranscript: _buildVisibleTranscript(),
      editableTranscript: preserveEditableTranscript
          ? state.editableTranscript
          : _committedTranscript,
      permissionState: permissionState ?? state.permissionState,
      activeLocaleLabel: _speechService.activeLocale?.name,
      errorMessage: errorMessage,
    );

    _startTimer();

    try {
      await _speechService.startListening(
        onResult: (words, isFinal) {
          _handleSpeechResult(
            sessionId: sessionId,
            words: words,
            isFinal: isFinal,
          );
        },
        onStatus: (status) {
          _handleSpeechStatus(sessionId: sessionId, status: status);
        },
        onError: (errorMessage, permanent) {
          _handleSpeechError(
            sessionId: sessionId,
            errorMessage: errorMessage,
            permanent: permanent,
          );
        },
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      if (_activeSessionId == sessionId) {
        _activeSessionId = null;
      }
      _stopTimer();
      state = state.copyWith(
        status: VoiceCaptureStatus.error,
        errorMessage: 'Unable to start speech recognition.',
      );
    }
  }

  void _handleSpeechResult({
    required String sessionId,
    required String words,
    required bool isFinal,
  }) {
    if (_activeSessionId != sessionId || _sessionFinalized) {
      return;
    }

    final nextSessionTranscript = _normalizeWhitespace(words);
    if (nextSessionTranscript == _sessionTranscript && !isFinal) {
      return;
    }

    _sessionTranscript = nextSessionTranscript;

    final visibleTranscript = _buildVisibleTranscript();
    if (visibleTranscript != state.liveTranscript || state.errorMessage != null) {
      state = state.copyWith(
        liveTranscript: visibleTranscript,
        errorMessage: null,
      );
    }

    if (isFinal && _stopRequestedSessionId == sessionId) {
      _finalizeSession(
        sessionId,
        nextStatus: VoiceCaptureStatus.result,
      );
    }
  }

  void _handleSpeechStatus({
    required String sessionId,
    required String status,
  }) {
    if (_activeSessionId != sessionId || _sessionFinalized) {
      return;
    }

    if (status != 'done' && status != 'notListening') {
      return;
    }

    if (_stopRequestedSessionId == sessionId) {
      _finalizeSession(sessionId, nextStatus: VoiceCaptureStatus.result);
      return;
    }

    _pauseSession(sessionId);
  }

  void _handleSpeechError({
    required String sessionId,
    required String errorMessage,
    required bool permanent,
  }) {
    if (_activeSessionId != sessionId || _sessionFinalized) {
      return;
    }

    if (_stopRequestedSessionId == sessionId) {
      _finalizeSession(sessionId, nextStatus: VoiceCaptureStatus.result);
      return;
    }

    _pauseSession(
      sessionId,
      errorMessage: permanent ? errorMessage : null,
    );
  }

  Future<void> _completeCurrentRecordingLocked() async {
    final sessionId = _activeSessionId;
    if (sessionId == null) {
      _stopTimer();
      _enterResultState();
      return;
    }

    if (_sessionFinalized) {
      return;
    }

    _stopRequestedSessionId = sessionId;
    state = state.copyWith(
      status: VoiceCaptureStatus.processing,
      errorMessage: null,
    );

    if (_speechService.isListening) {
      await _speechService.stopListening();
    }

    _finalizeSession(sessionId, nextStatus: VoiceCaptureStatus.result);
  }

  void _pauseSession(String sessionId, {String? errorMessage}) {
    if (_activeSessionId != sessionId || _sessionFinalized) {
      return;
    }

    _commitSessionTranscript();
    _sessionFinalized = true;
    _activeSessionId = null;
    _stopRequestedSessionId = null;
    _stopTimer();

    state = state.copyWith(
      status: VoiceCaptureStatus.paused,
      liveTranscript: _buildVisibleTranscript(),
      errorMessage: errorMessage,
    );
  }

  void _finalizeSession(
    String sessionId, {
    required VoiceCaptureStatus nextStatus,
  }) {
    if (_activeSessionId != sessionId || _sessionFinalized) {
      return;
    }

    _commitSessionTranscript();
    _sessionFinalized = true;
    _activeSessionId = null;
    _stopRequestedSessionId = null;
    _stopTimer();

    if (nextStatus == VoiceCaptureStatus.result) {
      _enterResultState();
      return;
    }

    state = state.copyWith(
      status: nextStatus,
      liveTranscript: _buildVisibleTranscript(),
      errorMessage: null,
    );
  }

  void _commitSessionTranscript() {
    if (_sessionCommitted) {
      return;
    }

    final sessionTranscript = _normalizeWhitespace(_sessionTranscript);
    if (sessionTranscript.isNotEmpty) {
      _committedTranscript = _joinSegments(
        _committedTranscript,
        sessionTranscript,
      );
    }

    _sessionTranscript = '';
    _sessionCommitted = true;
  }

  void _enterResultState() {
    final transcript = _normalizeWhitespace(_committedTranscript);

    if (transcript.isEmpty) {
      state = state.copyWith(
        status: VoiceCaptureStatus.idle,
        liveTranscript: '',
        editableTranscript: '',
        errorMessage: 'No speech captured. Try again.',
      );
      return;
    }

    state = state.copyWith(
      status: VoiceCaptureStatus.result,
      liveTranscript: transcript,
      editableTranscript: transcript,
      errorMessage: null,
    );
  }

  Future<void> _cancelActiveRecognition() async {
    final hadActiveSession =
        _activeSessionId != null || _speechService.isListening;

    _activeSessionId = null;
    _stopRequestedSessionId = null;
    _sessionCommitted = false;
    _sessionFinalized = false;
    _sessionTranscript = '';
    _stopTimer();

    if (hadActiveSession) {
      await _speechService.cancelListening();
    }
  }

  void _resetTranscriptBuffers() {
    _committedTranscript = '';
    _sessionTranscript = '';
    _activeSessionId = null;
    _stopRequestedSessionId = null;
    _sessionCommitted = false;
    _sessionFinalized = false;
  }

  String _buildVisibleTranscript() {
    return _joinSegments(_committedTranscript, _sessionTranscript);
  }

  String _joinSegments(String leading, String trailing) {
    final left = _normalizeWhitespace(leading);
    final right = _normalizeWhitespace(trailing);

    if (left.isEmpty) {
      return right;
    }

    if (right.isEmpty) {
      return left;
    }

    return '$left $right';
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

  void _stopTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
  }

  Future<void> _serialize(Future<void> Function() action) {
    _lifecycleLock = _lifecycleLock
        .catchError((Object _) {})
        .then((_) => action());
    return _lifecycleLock;
  }

  @override
  void dispose() {
    _stopTimer();
    unawaited(_speechService.cancelListening());
    super.dispose();
  }
}
