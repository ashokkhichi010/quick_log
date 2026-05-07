import 'package:flutter/material.dart';

class LogsSectionHeader extends StatelessWidget {
  const LogsSectionHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(label, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
