enum EntryResult { worked, notWorked, partial }

extension EntryResultX on EntryResult {
  String get label => switch (this) {
    EntryResult.worked => 'Worked',
    EntryResult.notWorked => 'Not Worked',
    EntryResult.partial => 'Partial',
  };
}
