class ReminderIntervalOption {
  const ReminderIntervalOption({required this.minutes, required this.label});

  final int minutes;
  final String label;
}

const reminderIntervalOptions = <ReminderIntervalOption>[
  ReminderIntervalOption(minutes: 15, label: 'Every 15 min'),
  ReminderIntervalOption(minutes: 30, label: 'Every 30 min'),
  ReminderIntervalOption(minutes: 60, label: 'Every 1 hour'),
  ReminderIntervalOption(minutes: 120, label: 'Every 2 hours'),
];
