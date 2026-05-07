enum LogEntryFlavor { voice, legacyStructured, legacySession }

extension LogEntryFlavorX on LogEntryFlavor {
  String get label => switch (this) {
    LogEntryFlavor.voice => 'Voice',
    LogEntryFlavor.legacyStructured => 'Legacy',
    LogEntryFlavor.legacySession => 'Session',
  };
}
