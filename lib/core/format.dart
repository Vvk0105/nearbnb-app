import 'package:intl/intl.dart';

/// Amounts come from the API in cents (25000 = $250.00).
String money(num? cents, [String currency = 'AUD']) {
  if (cents == null) return '';
  final whole = cents % 100 == 0;
  // Australian formatting, so AUD shows as "$250" like the website (not "A$250").
  final f = NumberFormat.simpleCurrency(locale: 'en_AU', name: currency, decimalDigits: whole ? 0 : 2);
  return f.format(cents / 100);
}

/// "2026-11-03T14:00" (local time at the property) -> "Tue 3 Nov, 2:00 pm".
String localLabel(String? local) {
  if (local == null || local.isEmpty) return '';
  final d = DateTime.tryParse(local);
  if (d == null) return local;
  return DateFormat('EEE d MMM, h:mm a').format(d).replaceAll('AM', 'am').replaceAll('PM', 'pm');
}

String dayLabel(DateTime d) => DateFormat('EEE d MMM').format(d);

/// "2026-11-03" for the API.
String isoDay(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// "14:00" -> "2:00 pm".
String timeLabel(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length < 2) return hhmm;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = parts[1];
  final suffix = h < 12 ? 'am' : 'pm';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:$m $suffix';
}

/// Check-in times a guest can pick: every `intervalMinutes` between the unit's window ("08:00" to "22:00"). Same as the website.
List<String> timeOptions(int intervalMinutes, [String from = '00:00', String to = '23:59']) {
  int toMin(String t) => (int.tryParse(t.substring(0, 2)) ?? 0) * 60 + (int.tryParse(t.substring(3, 5)) ?? 0);
  final step = intervalMinutes <= 0 ? 60 : intervalMinutes;
  final out = <String>[];
  for (var m = (toMin(from) / step).ceil() * step; m <= toMin(to); m += step) {
    out.add('${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}');
  }
  return out;
}

String plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';

/// Seconds left -> "2 h 15 min" / "8 min" / "under a minute".
String timeLeft(int? seconds) {
  if (seconds == null) return '';
  if (seconds < 60) return 'under a minute';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m min';
}
