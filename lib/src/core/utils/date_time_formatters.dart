import 'package:intl/intl.dart';

final _timeFormat = DateFormat('h:mm a');
final _hourHeaderFormat = DateFormat('h a');
final _fullDayHeaderFormat = DateFormat('EEE, d MMM • h a');

String formatEntryTime(DateTime value) => _timeFormat.format(value);

String formatTimelineHeader(DateTime value) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final targetDay = DateTime(value.year, value.month, value.day);

  if (targetDay == today) {
    return 'Today • ${_hourHeaderFormat.format(value)}';
  }

  if (targetDay == today.subtract(const Duration(days: 1))) {
    return 'Yesterday • ${_hourHeaderFormat.format(value)}';
  }

  return _fullDayHeaderFormat.format(value);
}

DateTime truncateToHour(DateTime value) {
  return DateTime(value.year, value.month, value.day, value.hour);
}
