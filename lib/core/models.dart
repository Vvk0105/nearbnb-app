// What the API returns, as Dart classes. Field names follow the API (see frontend/src/lib/types.ts in the nearbnb repo).
// Hand-written fromJson, no code generation: fewer build steps for the developer.

typedef Json = Map<String, dynamic>;

List<T> _list<T>(Object? raw, T Function(Json) f) => raw is List ? raw.whereType<Map>().map((e) => f(e.cast<String, dynamic>())).toList() : <T>[];
int _int(Object? v, [int fallback = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? fallback;
int? _intOrNull(Object? v) => v is num ? v.toInt() : (v == null ? null : int.tryParse('$v'));
String _str(Object? v) => v == null ? '' : '$v';
String? _strOrNull(Object? v) => v == null ? null : '$v';

class User {
  User({required this.id, required this.email, required this.fullName, this.phone, this.dob, this.photoUrl, required this.emailVerified,
      required this.pendingConsents, this.socialLinks = const []});
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? dob;
  final String? photoUrl;
  final bool emailVerified;
  final List<PendingConsent> pendingConsents;
  final List<({String id, String platform, String url})> socialLinks;

  String get firstName => fullName.split(' ').first;

  factory User.fromJson(Json j) => User(
        id: _str(j['id']),
        email: _str(j['email']),
        fullName: _str(j['full_name']),
        phone: _strOrNull(j['phone']),
        dob: _strOrNull(j['dob']),
        photoUrl: _strOrNull(j['photo_url']),
        emailVerified: j['email_verified'] == true,
        pendingConsents: _list(j['pending_consents'], PendingConsent.fromJson),
        socialLinks: [
          for (final l in (j['social_links'] as List? ?? const []).whereType<Map>()) (id: _str(l['id']), platform: _str(l['platform']), url: _str(l['url']))
        ],
      );
}

class PendingConsent {
  PendingConsent(this.docType, this.version, this.title);
  final String docType;
  final int version;
  final String title;
  factory PendingConsent.fromJson(Json j) => PendingConsent(_str(j['doc_type']), _int(j['version']), _str(j['title']));
}

class Rating {
  Rating(this.average, this.count);
  final double average;
  final int count;
  static Rating? fromJson(Object? j) => j is Map ? Rating((j['average'] as num?)?.toDouble() ?? 0, _int(j['count'])) : null;
}

class Photo {
  Photo(this.url, this.thumbUrl);
  final String url;
  final String thumbUrl;
  factory Photo.fromJson(Json j) => Photo(_str(j['url']), _str(j['thumb_url'] ?? j['url']));
}

// ---------- search ----------

class SearchItem {
  SearchItem({required this.id, required this.name, this.typeName, required this.suburb, required this.state, this.coverUrl, this.thumbUrl,
      required this.currency, required this.minPrice, this.distanceKm, this.rating, required this.fixedTiming});
  final String id;
  final String name;
  final String? typeName;
  final String suburb;
  final String state;
  final String? coverUrl;
  final String? thumbUrl;
  final String currency;
  final int minPrice;
  final double? distanceKm;
  final Rating? rating;
  final bool fixedTiming;

  String get place => [suburb, state].where((s) => s.isNotEmpty).join(', ');

  factory SearchItem.fromJson(Json j) => SearchItem(
        id: _str(j['id']),
        name: _str(j['name']),
        typeName: _strOrNull(j['type_name']),
        suburb: _str(j['suburb']),
        state: _str(j['state']),
        coverUrl: _strOrNull(j['cover_url']),
        thumbUrl: _strOrNull(j['thumb_url']),
        currency: _str(j['currency']).isEmpty ? 'AUD' : _str(j['currency']),
        minPrice: _int(j['min_price']),
        distanceKm: (j['distance_km'] as num?)?.toDouble(),
        rating: Rating.fromJson(j['rating']),
        fixedTiming: (j['units'] is List) && (j['units'] as List).isNotEmpty && (j['units'] as List).every((u) => u is Map && u['stay_mode'] == 'fixed'),
      );
}

class SearchResult {
  SearchResult(this.total, this.page, this.pageSize, this.items, this.hint);
  final int total;
  final int page;
  final int pageSize;
  final List<SearchItem> items;
  final String? hint;
  bool get hasMore => page * pageSize < total;
  factory SearchResult.fromJson(Json j) =>
      SearchResult(_int(j['total']), _int(j['page'], 1), _int(j['page_size'], 12), _list(j['items'], SearchItem.fromJson), _strOrNull(j['hint']));
}

class Suggestions {
  Suggestions(this.places, this.properties);
  final List<({String text, int count})> places;
  final List<({String id, String name, String place, String? type})> properties;
  factory Suggestions.fromJson(Json j) => Suggestions(
        [for (final p in (j['places'] as List? ?? const []).whereType<Map>()) (text: _str(p['text']), count: _int(p['properties']))],
        [
          for (final p in (j['properties'] as List? ?? const []).whereType<Map>())
            (id: _str(p['id']), name: _str(p['name']), place: [p['suburb'], p['state']].where((s) => s != null && '$s'.isNotEmpty).join(', '), type: _strOrNull(p['type_name']))
        ],
      );
}

class BookingMeta {
  BookingMeta({required this.intervalMinutes, required this.stepHours, required this.maxStayHours, required this.minLeadHours, required this.maxAdvanceDays});
  final int intervalMinutes;
  final int stepHours;
  final int maxStayHours;
  final int minLeadHours;
  final int maxAdvanceDays;
  int get maxNights => (maxStayHours ~/ stepHours).clamp(1, 365);
  factory BookingMeta.fromJson(Json j) => BookingMeta(
        intervalMinutes: _int(j['interval_minutes'], 60),
        stepHours: _int(j['step_hours'], 24),
        maxStayHours: _int(j['max_stay_hours'], 168),
        minLeadHours: _int(j['min_lead_hours'], 2),
        maxAdvanceDays: _int(j['max_advance_days'], 180),
      );
  static final fallback = BookingMeta(intervalMinutes: 60, stepHours: 24, maxStayHours: 168, minLeadHours: 2, maxAdvanceDays: 180);
}

// ---------- a property ----------

class Unit {
  Unit({required this.id, required this.name, required this.description, required this.pricePer24h, required this.currency, required this.cleaningFee,
      required this.capacity, this.bedrooms, this.bathrooms, this.beds, required this.checkinFrom, required this.checkinTo, required this.stayMode,
      this.fixedCheckin, this.fixedCheckout, required this.amenities, required this.photos, required this.rules});
  final String id;
  final String name;
  final String description;
  final int pricePer24h;
  final String currency;
  final int cleaningFee;
  final int capacity;
  final int? bedrooms;
  final int? bathrooms;
  final int? beds;
  final String checkinFrom;
  final String checkinTo;
  final String stayMode; // flexible | fixed
  final String? fixedCheckin;
  final String? fixedCheckout;
  final List<String> amenities;
  final List<Photo> photos;
  final BookingMeta rules;

  bool get isFixed => stayMode == 'fixed';

  factory Unit.fromJson(Json j) => Unit(
        id: _str(j['id']),
        name: _str(j['name']),
        description: _str(j['description']),
        pricePer24h: _int(j['price_per_24h']),
        currency: _str(j['currency']).isEmpty ? 'AUD' : _str(j['currency']),
        cleaningFee: _int(j['cleaning_fee']),
        capacity: _int(j['capacity'], 1),
        bedrooms: _intOrNull(j['bedrooms']),
        bathrooms: _intOrNull(j['bathrooms']),
        beds: _intOrNull(j['beds']),
        checkinFrom: _str(j['checkin_from']).isEmpty ? '00:00' : _str(j['checkin_from']),
        checkinTo: _str(j['checkin_to']).isEmpty ? '23:00' : _str(j['checkin_to']),
        stayMode: _str(j['stay_mode']).isEmpty ? 'flexible' : _str(j['stay_mode']),
        fixedCheckin: _strOrNull(j['fixed_checkin_time']),
        fixedCheckout: _strOrNull(j['fixed_checkout_time']),
        amenities: [for (final a in (j['amenities'] as List? ?? const []).whereType<Map>()) _str(a['name'])],
        photos: _list(j['photos'], Photo.fromJson),
        rules: j['rules'] is Map ? BookingMeta.fromJson((j['rules'] as Map).cast<String, dynamic>()) : BookingMeta.fallback,
      );
}

class PolicyTier {
  PolicyTier(this.hoursBefore, this.refundPct);
  final int hoursBefore;
  final int refundPct;
  factory PolicyTier.fromJson(Json j) => PolicyTier(_int(j['hours_before']), _int(j['refund_pct']));
}

class Property {
  Property({required this.id, required this.name, required this.description, required this.rules, this.typeName, required this.suburb,
      required this.state, this.latitude, this.longitude, required this.timezone, required this.photos, required this.units, required this.hostFirstName,
      this.rating, this.cancellationName, this.cancellationDescription, required this.cancellationTiers});
  final String id;
  final String name;
  final String description;
  final String rules;
  final String? typeName;
  final String suburb;
  final String state;
  final double? latitude;
  final double? longitude;
  final String timezone;
  final List<Photo> photos;
  final List<Unit> units;
  final String hostFirstName;
  final Rating? rating;
  final String? cancellationName;
  final String? cancellationDescription;
  final List<PolicyTier> cancellationTiers;

  String get place => [suburb, state].where((s) => s.isNotEmpty).join(', ');

  factory Property.fromJson(Json j) {
    final c = j['cancellation'] is Map ? (j['cancellation'] as Map).cast<String, dynamic>() : null;
    return Property(
      id: _str(j['id']),
      name: _str(j['name']),
      description: _str(j['description']),
      rules: _str(j['rules']),
      typeName: _strOrNull(j['type_name']),
      suburb: _str(j['suburb']),
      state: _str(j['state']),
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      timezone: _str(j['timezone']),
      photos: _list(j['photos'], Photo.fromJson),
      units: _list(j['units'], Unit.fromJson),
      hostFirstName: _str(j['host_first_name']),
      rating: Rating.fromJson(j['rating']),
      cancellationName: c == null ? null : _strOrNull(c['name']),
      cancellationDescription: c == null ? null : _strOrNull(c['description']),
      cancellationTiers: c == null ? [] : _list(c['tiers'], PolicyTier.fromJson),
    );
  }
}

class PublicReview {
  PublicReview(this.rating, this.comment, this.author, this.month);
  final int rating;
  final String comment;
  final String author;
  final String? month;
  factory PublicReview.fromJson(Json j) => PublicReview(_int(j['rating']), _str(j['comment']), _str(j['author']), _strOrNull(j['month']));
}

// ---------- availability and price ----------

class CalendarMonth {
  CalendarMonth(this.days);
  final Map<String, String> days; // "2026-11-03" -> available | partial | unavailable | past | closed
  factory CalendarMonth.fromJson(Json j) =>
      CalendarMonth({for (final d in (j['days'] as List? ?? const []).whereType<Map>()) _str(d['date']): _str(d['status'])});
}

class PriceBreakdown {
  PriceBreakdown({required this.nights, required this.accommodation, required this.cleaningFee, required this.serviceFee, required this.tax,
      this.taxName, this.taxRatePercent = 0, required this.taxInclusive, required this.total});
  final int nights;
  final int accommodation;
  final int cleaningFee;
  final int serviceFee;
  final int tax;
  final String? taxName;
  final num taxRatePercent;
  final bool taxInclusive;
  final int total;
  factory PriceBreakdown.fromJson(Json j) => PriceBreakdown(
        nights: _int(j['nights']),
        accommodation: _int(j['accommodation']),
        cleaningFee: _int(j['cleaning_fee']),
        serviceFee: _int(j['service_fee']),
        tax: _int(j['tax']),
        taxName: _strOrNull(j['tax_name']),
        taxRatePercent: (j['tax_rate_percent'] as num?) ?? 0,
        taxInclusive: j['tax_inclusive'] == true,
        total: _int(j['total']),
      );
}

class Alternative {
  Alternative(this.checkinLocal, this.label);
  final String checkinLocal;
  final String label;
  factory Alternative.fromJson(Json j) => Alternative(_str(j['checkin_local']), _str(j['label']));
}

class Quote {
  Quote({required this.available, this.message, required this.alternatives, this.checkinLocal, this.checkinLabel, this.checkoutLabel, this.currency,
      this.price, this.responseMinutes, required this.hours});
  final bool available;
  final String? message;
  final List<Alternative> alternatives;
  final String? checkinLocal;
  final String? checkinLabel;
  final String? checkoutLabel;
  final String? currency;
  final PriceBreakdown? price;
  final int? responseMinutes;
  final int hours;
  factory Quote.fromJson(Json j) => Quote(
        available: j['available'] == true,
        message: _strOrNull(j['message']),
        alternatives: _list(j['alternatives'], Alternative.fromJson),
        checkinLocal: _strOrNull(j['checkin_local']),
        checkinLabel: _strOrNull(j['checkin_label']),
        checkoutLabel: _strOrNull(j['checkout_label']),
        currency: _strOrNull(j['currency']),
        price: j['price'] is Map ? PriceBreakdown.fromJson((j['price'] as Map).cast<String, dynamic>()) : null,
        responseMinutes: _intOrNull(j['response_minutes']),
        hours: _int(j['hours'], 24),
      );
}

/// What the guest must add to their profile before booking. The admin chooses the fields (full_name, dob, phone, social_url).
class Readiness {
  Readiness(this.ready, this.missing);
  final bool ready;
  final List<({String field, String label})> missing;
  factory Readiness.fromJson(Json j) => Readiness(
      j['ready'] == true, [for (final m in (j['missing'] as List? ?? const []).whereType<Map>()) (field: _str(m['field']), label: _str(m['label']))]);
}

// ---------- trips ----------

class ReviewInfo {
  ReviewInfo({required this.open, required this.canReview, this.closesAt, this.myRating, this.myComment, this.myStatus});
  final bool open;
  final bool canReview;
  final String? closesAt;
  final int? myRating;
  final String? myComment;
  final String? myStatus;
  static ReviewInfo? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final mine = raw['mine'] is Map ? raw['mine'] as Map : null;
    return ReviewInfo(
      open: raw['open'] == true,
      canReview: raw['can_review'] == true,
      closesAt: _strOrNull(raw['closes_at']),
      myRating: mine == null ? null : _intOrNull(mine['rating']),
      myComment: mine == null ? null : _strOrNull(mine['comment']),
      myStatus: mine == null ? null : _strOrNull(mine['status']),
    );
  }
}

class Booking {
  Booking({required this.id, required this.reference, required this.status, required this.hours, required this.guests, required this.currency,
      required this.checkInLabel, required this.checkOutLabel, this.secondsToRespond, this.secondsToPay, this.closedReason, required this.canWithdraw,
      required this.canPay, required this.propertyId, required this.propertyName, required this.place, this.coverUrl, required this.unitName,
      required this.total, this.price, this.hostName, this.hostPhone, this.hostEmail, this.checkinInstructions, this.paymentFailure, this.refundState,
      this.cancelledBy, this.review, required this.canReportIssue, required this.issues});
  final String id;
  final String reference;
  final String status;
  final int hours;
  final int guests;
  final String currency;
  final String checkInLabel;
  final String checkOutLabel;
  final int? secondsToRespond;
  final int? secondsToPay;
  final String? closedReason;
  final bool canWithdraw;
  final bool canPay;
  final String propertyId;
  final String propertyName;
  final String place;
  final String? coverUrl;
  final String unitName;
  final int total;
  final PriceBreakdown? price;
  final String? hostName;
  final String? hostPhone;
  final String? hostEmail;
  final String? checkinInstructions;
  final String? paymentFailure;
  final String? refundState;
  final String? cancelledBy;
  final ReviewInfo? review;
  final bool canReportIssue;
  final List<Issue> issues;

  int get nights => price?.nights ?? (hours / 24).ceil();

  factory Booking.fromJson(Json j) {
    final p = (j['property'] as Map?)?.cast<String, dynamic>() ?? const {};
    final price = (j['price'] as Map?)?.cast<String, dynamic>();
    final host = (j['host'] as Map?)?.cast<String, dynamic>();
    final payment = (j['payment'] as Map?)?.cast<String, dynamic>();
    return Booking(
      id: _str(j['id']),
      reference: _str(j['reference']),
      status: _str(j['status']),
      hours: _int(j['hours'], 24),
      guests: _int(j['guests'], 1),
      currency: _str(j['currency']).isEmpty ? 'AUD' : _str(j['currency']),
      checkInLabel: _str(j['check_in_label']),
      checkOutLabel: _str(j['check_out_label']),
      secondsToRespond: _intOrNull(j['seconds_to_respond']),
      secondsToPay: _intOrNull(j['seconds_to_pay']),
      closedReason: _strOrNull(j['closed_reason']),
      canWithdraw: j['can_withdraw'] == true,
      canPay: j['can_pay'] == true,
      propertyId: _str(p['id']),
      propertyName: _str(p['name']),
      place: [p['suburb'], p['state']].where((s) => s != null && '$s'.isNotEmpty).join(', '),
      coverUrl: _strOrNull(p['cover_url']),
      unitName: _str((j['unit'] as Map?)?['name']),
      total: _int(price?['total']),
      price: price != null && price.containsKey('accommodation') ? PriceBreakdown.fromJson(price) : null,
      hostName: _strOrNull(host?['name'] ?? host?['first_name']),
      hostPhone: _strOrNull(host?['phone']),
      hostEmail: _strOrNull(host?['email']),
      checkinInstructions: _strOrNull(j['checkin_instructions']),
      paymentFailure: _strOrNull(payment?['failure_message']),
      refundState: _strOrNull((j['refund'] as Map?)?['state']),
      cancelledBy: _strOrNull((j['cancelled'] as Map?)?['by']),
      review: ReviewInfo.fromJson(j['review']),
      canReportIssue: j['can_report_issue'] == true,
      issues: _list(j['issues'], Issue.fromJson),
    );
  }
}

class BookingList {
  BookingList(this.items, this.counts, this.total, this.page);
  final List<Booking> items;
  final Map<String, int> counts; // pending | awaiting_payment | upcoming | past
  final int total;
  final int page;
  factory BookingList.fromJson(Json j) => BookingList(
        _list(j['items'], Booking.fromJson),
        {for (final e in ((j['counts'] as Map?) ?? const {}).entries) '${e.key}': _int(e.value)},
        _int(j['total']),
        _int(j['page'], 1),
      );
}

class Issue {
  Issue(this.category, this.body, this.status, this.resolution);
  final String category;
  final String body;
  final String status;
  final String? resolution;
  factory Issue.fromJson(Json j) => Issue(_str(j['category']), _str(j['body']), _str(j['status']), _strOrNull(j['resolution']));
}

class CancelPreview {
  CancelPreview({required this.currency, required this.paid, required this.policyName, required this.refundPct, required this.refundTotal});
  final String currency;
  final int paid;
  final String policyName;
  final int refundPct;
  final int refundTotal;
  factory CancelPreview.fromJson(Json j) {
    final r = (j['refund'] as Map?)?.cast<String, dynamic>() ?? const {};
    return CancelPreview(
      currency: _str(j['currency']).isEmpty ? 'AUD' : _str(j['currency']),
      paid: _int(j['paid']),
      policyName: _str((j['policy'] as Map?)?['name']),
      refundPct: _int(r['refund_pct']),
      refundTotal: _int(r['total']),
    );
  }
}

class PayStart {
  PayStart({this.clientSecret, this.publishableKey, required this.amount, required this.currency, required this.fake});
  final String? clientSecret;
  final String? publishableKey;
  final int amount;
  final String currency;
  final bool fake; // the server runs without Stripe (development only)
  factory PayStart.fromJson(Json j) => PayStart(
        clientSecret: _strOrNull(j['client_secret']),
        publishableKey: _strOrNull(j['publishable_key']),
        amount: _int(j['amount']),
        currency: _str(j['currency']).isEmpty ? 'AUD' : _str(j['currency']),
        fake: j['fake'] == true,
      );
}

// ---------- notifications ----------

class Notice {
  Notice({required this.id, required this.kind, required this.title, required this.body, required this.link, required this.tone, required this.createdAt,
      required this.read});
  final String id;
  final String kind;
  final String title;
  final String body;
  final String link;
  final String tone; // news | action | problem
  final DateTime createdAt;
  final bool read;
  factory Notice.fromJson(Json j) => Notice(
        id: _str(j['id']),
        kind: _str(j['kind']),
        title: _str(j['title']),
        body: _str(j['body']),
        link: _str(j['link']),
        tone: _str(j['tone']).isEmpty ? 'news' : _str(j['tone']),
        createdAt: DateTime.tryParse(_str(j['created_at']))?.toLocal() ?? DateTime.now(),
        read: j['read'] == true,
      );
}

class NoticeList {
  NoticeList(this.items, this.unread, this.total, this.page);
  final List<Notice> items;
  final int unread;
  final int total;
  final int page;
  factory NoticeList.fromJson(Json j) => NoticeList(_list(j['items'], Notice.fromJson), _int(j['unread']), _int(j['total']), _int(j['page'], 1));
}
