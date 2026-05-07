import 'package:flutter/material.dart';

class TranscriptEditor extends StatelessWidget {
  const TranscriptEditor({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      minLines: 5,
      maxLines: 9,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        hintText: 'Transcript appears here',
      ),
    );
  }
}
