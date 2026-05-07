import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_providers.dart';
import '../../../../core/widgets/soft_ui.dart';
import '../../../speech/presentation/controllers/voice_capture_controller.dart';
import '../../presentation/widgets/live_transcript_view.dart';
import '../../presentation/widgets/recording_controls.dart';
import '../../presentation/widgets/transcript_editor.dart';

Future<void> showRecordingBottomSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (context) => const RecordingBottomSheet(),
  );
}

class RecordingBottomSheet extends ConsumerStatefulWidget {
  const RecordingBottomSheet({super.key});

  @override
  ConsumerState<RecordingBottomSheet> createState() =>
      _RecordingBottomSheetState();
}

class _RecordingBottomSheetState extends ConsumerState<RecordingBottomSheet>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _transcriptController;
  late final FocusNode _transcriptFocusNode;
  late final ScrollController _scrollController;
  late final AnimationController _pulseController;
  late final VoiceCaptureController _voiceCaptureController;
  late final ProviderSubscription<VoiceCaptureState> _voiceSubscription;

  bool _syncingTranscriptField = false;

  @override
  void initState() {
    super.initState();
    _transcriptController = TextEditingController();
    _transcriptFocusNode = FocusNode();
    _scrollController = ScrollController();
    _voiceCaptureController = ref.read(voiceCaptureControllerProvider.notifier);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _voiceSubscription = ref.listenManual<VoiceCaptureState>(
      voiceCaptureControllerProvider,
      _handleVoiceStateChanged,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_voiceCaptureController.beginNewCapture());
    });
  }

  @override
  void dispose() {
    _pulseController.stop();
    _voiceSubscription.close();
    _transcriptController.dispose();
    _transcriptFocusNode.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceCaptureControllerProvider);
    _syncTranscriptEditorIfNeeded(voiceState);

    final isRecording = voiceState.status == VoiceCaptureStatus.recording;
    final isPaused = voiceState.status == VoiceCaptureStatus.paused;
    final isProcessing = voiceState.status == VoiceCaptureStatus.processing;
    final showingResult = voiceState.status == VoiceCaptureStatus.result;

    if (isRecording) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else if (_pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0;
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        top: 12,
      ),
      child: SoftSurface(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Quick record',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => _cancelAndClose(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
              voiceState.activeLocaleLabel ?? 'Preparing microphone',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            if (isProcessing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(strokeWidth: 2.8),
                ),
              )
            else if (showingResult)
              _ResultState(
                controller: _transcriptController,
                focusNode: _transcriptFocusNode,
                onChanged: _voiceCaptureController.updateEditableTranscript,
                onCancel: () => _cancelAndClose(context),
                onContinueRecording: _voiceCaptureController.continueFromReview,
                onSave: () => _saveAndClose(context),
              )
            else ...[
              RecordingControls(
                recording: isRecording,
                processing: isProcessing,
                paused: isPaused,
                onMicPressed: _voiceCaptureController.toggleRecording,
                onContinuePressed: _voiceCaptureController.continueRecording,
                onCompletePressed: _voiceCaptureController.stopRecording,
                onStopPressed: _voiceCaptureController.stopRecording,
                pulse: _pulseController,
                statusLabel: _statusLabel(voiceState),
                elapsedLabel: (isRecording || isPaused)
                    ? _formatDuration(voiceState.elapsed)
                    : '',
              ),
              const SizedBox(height: 16),
              LiveTranscriptView(
                text: voiceState.liveTranscript,
                scrollController: _scrollController,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _cancelAndClose(BuildContext context) async {
    final navigator = Navigator.of(context);
    final voiceState = ref.read(voiceCaptureControllerProvider);
    final hasTranscript = voiceState.editableTranscript.trim().isNotEmpty;
    if (hasTranscript) {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Discard recording?'),
            content: const Text(
              'You have an unsaved transcript. Closing now will discard it.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Discard'),
              ),
            ],
          );
        },
      );
      if (shouldDiscard != true) {
        return;
      }
    }

    await _voiceCaptureController.cancelRecording();
    if (!mounted) {
      return;
    }
    navigator.pop();
  }

  void _handleVoiceStateChanged(
    VoiceCaptureState? previous,
    VoiceCaptureState next,
  ) {
    if (!mounted) {
      return;
    }

    if (next.errorMessage != null &&
        next.errorMessage != previous?.errorMessage) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
    }

    if (next.liveTranscript != previous?.liveTranscript) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) {
          return;
        }

        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _syncTranscriptEditorIfNeeded(VoiceCaptureState voiceState) {
    final showingResult = voiceState.status == VoiceCaptureStatus.result;
    if (!showingResult) {
      return;
    }

    if (_transcriptFocusNode.hasFocus &&
        !_syncingTranscriptField &&
        _transcriptController.text == voiceState.editableTranscript) {
      return;
    }

    if (_transcriptFocusNode.hasFocus &&
        _transcriptController.text != voiceState.editableTranscript) {
      return;
    }

    if (_transcriptController.text == voiceState.editableTranscript) {
      return;
    }

    _syncingTranscriptField = true;
    _transcriptController.value = TextEditingValue(
      text: voiceState.editableTranscript,
      selection: TextSelection.collapsed(
        offset: voiceState.editableTranscript.length,
      ),
    );
    _syncingTranscriptField = false;
  }

  Future<void> _saveAndClose(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final entry = await _voiceCaptureController.saveTranscript();
    if (entry == null) {
      return;
    }

    await ref.read(entriesControllerProvider.notifier).loadEntries();
    if (!mounted) {
      return;
    }

    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Log saved.')));
  }

  String _statusLabel(VoiceCaptureState state) {
    return switch (state.status) {
      VoiceCaptureStatus.recording => 'Recording...',
      VoiceCaptureStatus.paused => 'Recording paused. Continue to keep adding.',
      VoiceCaptureStatus.permissionDenied => 'Microphone permission needed',
      VoiceCaptureStatus.unavailable => 'Speech recognition unavailable',
      VoiceCaptureStatus.requestingPermission => 'Preparing microphone...',
      _ => 'Listening for your next update',
    };
  }

  static String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _ResultState extends StatelessWidget {
  const _ResultState({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onCancel,
    required this.onContinueRecording,
    required this.onSave,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onCancel;
  final VoidCallback onContinueRecording;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Review transcript',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        TranscriptEditor(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onContinueRecording,
                icon: const Icon(Icons.mic_rounded),
                label: const Text('Continue'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(onPressed: onSave, child: const Text('Save')),
            ),
          ],
        ),
      ],
    );
  }
}
