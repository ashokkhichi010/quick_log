enum LogEntryType { manual, checkIn, checkOut }

extension LogEntryTypeX on LogEntryType {
  String get label => switch (this) {
    LogEntryType.manual => 'Manual',
    LogEntryType.checkIn => 'Check-in',
    LogEntryType.checkOut => 'Check-out',
  };
}
