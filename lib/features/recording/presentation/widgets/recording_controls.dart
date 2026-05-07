import 'package:flutter/material.dart';

class RecordingControls extends StatelessWidget {
  const RecordingControls({
    super.key,
    required this.recording,
    required this.processing,
    required this.onMicPressed,
    required this.onStopPressed,
    required this.pulse,
    required this.statusLabel,
    required this.elapsedLabel,
  });

  final bool recording;
  final bool processing;
  final VoidCallback onMicPressed;
  final VoidCallback onStopPressed;
  final Animation<double> pulse;
  final String statusLabel;
  final String elapsedLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        AnimatedBuilder(
          animation: pulse,
          builder: (context, child) {
            final scale = 1 + (pulse.value * 0.12);
            return Transform.scale(scale: scale, child: child);
          },
          child: InkWell(
            onTap: processing ? null : onMicPressed,
            borderRadius: BorderRadius.circular(60),
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: recording
                    ? theme.colorScheme.primary.withValues(alpha: 0.18)
                    : theme.colorScheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                recording ? Icons.stop_rounded : Icons.mic_rounded,
                size: 46,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(statusLabel, style: theme.textTheme.titleMedium),
        if (elapsedLabel.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(elapsedLabel, style: theme.textTheme.bodyMedium),
        ],
        if (recording) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onStopPressed,
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Stop'),
          ),
        ],
      ],
    );
  }
}
