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
  ConsumerState<RecordingBottomSheet> createState() => _RecordingBottomSheetState();
}

class _RecordingBottomSheetState extends ConsumerState<RecordingBottomSheet>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _transcriptController;
  late final ScrollController _scrollController;
  late final AnimationController _pulseController;
  late final VoiceCaptureController _voiceCaptureController;

  @override
  void initState() {
    super.initState();
    _transcriptController = TextEditingController();
    _scrollController = ScrollController();
    _voiceCaptureController = ref.read(voiceCaptureControllerProvider.notifier);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _voiceCaptureController.clearResult();
      unawaited(_voiceCaptureController.startRecording());
    });
  }

  @override
  void dispose() {
    _pulseController.stop();
    _transcriptController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceCaptureControllerProvider);

    ref.listen<VoiceCaptureState>(voiceCaptureControllerProvider, (
      previous,
      next,
    ) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }

      if (next.liveTranscript != previous?.liveTranscript ||
          next.editableTranscript != previous?.editableTranscript) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });

    if (_transcriptController.text != voiceState.editableTranscript) {
      _transcriptController.value = TextEditingValue(
        text: voiceState.editableTranscript,
        selection: TextSelection.collapsed(
          offset: voiceState.editableTranscript.length,
        ),
      );
    }

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
                onChanged: _voiceCaptureController.updateEditableTranscript,
                onCancel: () => _cancelAndClose(context),
                onSave: () => _saveAndClose(context),
              )
            else ...[
              RecordingControls(
                recording: isRecording,
                processing: isProcessing,
                paused: isPaused,
                onMicPressed: _voiceCaptureController.toggleRecording,
                onContinuePressed: _voiceCaptureController.continueRecording,
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
    await _voiceCaptureController.cancelRecording();
    if (!mounted) {
      return;
    }
    navigator.pop();
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
    required this.onChanged,
    required this.onCancel,
    required this.onSave,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Review transcript', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TranscriptEditor(controller: controller, onChanged: onChanged),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onCancel,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: onSave,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
