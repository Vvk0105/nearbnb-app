import '../../core/format.dart';

/// What the guest is looking for. Travels between screens as the same query string the website uses
/// (q, lat, lng, date, time, nights, guests), so a search carries on to the property page and the booking.
class SearchQuery {
  const SearchQuery({this.q = '', this.lat, this.lng, this.date, this.time = '14:00', this.nights = 1, this.guests = 2});
  final String q;
  final double? lat;
  final double? lng;
  final DateTime? date;
  final String time; // "14:00", local time at the property
  final int nights;
  final int guests;

  bool get hasDates => date != null;

  SearchQuery copyWith({String? q, double? lat, double? lng, bool clearLocation = false, DateTime? date, bool clearDate = false, String? time, int? nights, int? guests}) =>
      SearchQuery(
        q: q ?? this.q,
        lat: clearLocation ? null : (lat ?? this.lat),
        lng: clearLocation ? null : (lng ?? this.lng),
        date: clearDate ? null : (date ?? this.date),
        time: time ?? this.time,
        nights: nights ?? this.nights,
        guests: guests ?? this.guests,
      );

  factory SearchQuery.fromParams(Map<String, String> p) => SearchQuery(
        q: p['q'] ?? '',
        lat: double.tryParse(p['lat'] ?? ''),
        lng: double.tryParse(p['lng'] ?? ''),
        date: DateTime.tryParse(p['date'] ?? ''),
        time: p['time'] ?? '14:00',
        nights: int.tryParse(p['nights'] ?? '') ?? 1,
        guests: int.tryParse(p['guests'] ?? '') ?? 2,
      );

  /// For app addresses (/search?..., /property/x?...).
  Map<String, String> toParams() => {
        if (q.trim().isNotEmpty) 'q': q.trim(),
        if (lat != null && lng != null) ...{'lat': '$lat', 'lng': '$lng'},
        if (date != null) ...{'date': isoDay(date!), 'time': time, 'nights': '$nights'},
        'guests': '$guests',
      };

  String toQueryString() => Uri(queryParameters: toParams()).query;

  /// For GET /search.
  Map<String, dynamic> toApi() => {
        if (q.trim().isNotEmpty) 'q': q.trim(), // with a map point too: listings without coordinates still match by name
        if (lat != null && lng != null) ...{'lat': lat, 'lng': lng},
        if (date != null) ...{'checkin': '${isoDay(date!)}T$time', 'hours': nights * 24},
        'guests': guests,
      };

  /// "Bondi · Tue 3 Nov, 2:00 pm · 2 nights · 2 guests"
  String summary() {
    final parts = <String>[q.trim().isEmpty ? 'Anywhere' : q.trim()];
    if (date != null) parts.add('${dayLabel(date!)}, ${timeLabel(time)}');
    if (date != null) parts.add(plural(nights, 'night'));
    parts.add(plural(guests, 'guest'));
    return parts.join(' · ');
  }
}
