import 'package:intl/intl.dart';

/// "4:05", "1:02:30".
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// "32 min", "3 min read".
String formatMinutes(int seconds, {bool read = false}) {
  final m = (seconds / 60).ceil().clamp(1, 999);
  return read ? '$m min read' : '$m min';
}

/// "1.2K", "18K".
String formatCompact(int n) => NumberFormat.compact().format(n);

/// "Good morning" / "Good afternoon" / "Good evening".
String greetingFor(DateTime now) {
  final h = now.hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

/// "Tuesday, 10 November".
String formatLongDate(DateTime d) => DateFormat('EEEE, d MMMM').format(d);

/// "10 Nov 2026".
String formatShortDate(DateTime d) => DateFormat('d MMM y').format(d);

/// "Today", "Yesterday", "3 days ago", or a date.
String formatRelative(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return '$diff days ago';
  return formatShortDate(d);
}

/// "7:00 AM".
String formatTimeOfDay(int hour, int minute) => DateFormat.jm().format(DateTime(2000, 1, 1, hour, minute));
