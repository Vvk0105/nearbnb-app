import 'package:flutter_test/flutter_test.dart';
import 'package:nearbnb_app/core/models.dart';

void main() {
  test('a search result reads the API fields and spots fixed check-in times', () {
    final item = SearchItem.fromJson({
      'id': 'p1', 'name': 'Beach House', 'type_name': 'Entire place', 'suburb': 'Bondi', 'state': 'NSW', 'cover_url': '/api/v1/media/x.webp',
      'thumb_url': null, 'currency': 'AUD', 'min_price': 25000, 'distance_km': 2.4, 'rating': {'average': 4.5, 'count': 2},
      'units': [{'id': 'u1', 'stay_mode': 'fixed'}],
    });
    expect(item.place, 'Bondi, NSW');
    expect(item.minPrice, 25000);
    expect(item.rating!.average, 4.5);
    expect(item.fixedTiming, isTrue);
  });

  test('a unit without rules or timing falls back to safe defaults', () {
    final u = Unit.fromJson({'id': 'u1', 'name': 'Room', 'price_per_24h': 10000, 'capacity': 2});
    expect(u.isFixed, isFalse);
    expect(u.rules.stepHours, 24);
    expect(u.checkinFrom, '00:00');
  });

  test('a trip as the guest sees it, with host details once confirmed', () {
    final b = Booking.fromJson({
      'id': 'b1', 'reference': 'NB-ABC123', 'status': 'confirmed', 'hours': 48, 'guests': 2, 'currency': 'AUD',
      'check_in_label': 'Tue 3 Nov, 2:00 pm', 'check_out_label': 'Thu 5 Nov, 2:00 pm', 'can_withdraw': false, 'can_pay': false,
      'property': {'id': 'p1', 'name': 'Beach House', 'suburb': 'Bondi', 'state': 'NSW', 'cover_url': null},
      'unit': {'id': 'u1', 'name': 'Entire house'},
      'price': {'nights': 2, 'hours': 48, 'accommodation': 50000, 'cleaning_fee': 2000, 'service_fee': 3000, 'tax': 0, 'tax_name': null, 'tax_inclusive': true, 'total': 55000},
      'host': {'first_name': 'Hannah', 'name': 'Hannah Host', 'email': 'h@example.com', 'phone': '+61 400 000 000'},
      'review': {'open': false, 'can_review': false, 'closes_at': null, 'mine': null, 'theirs': null},
    });
    expect(b.nights, 2);
    expect(b.total, 55000);
    expect(b.hostName, 'Hannah Host');
    expect(b.place, 'Bondi, NSW');
    expect(b.review!.canReview, isFalse);
  });

  test('readiness lists what the guest still has to add', () {
    final r = Readiness.fromJson({'email_verified': true, 'ready': false, 'missing': [{'field': 'phone', 'label': 'Phone number'}]});
    expect(r.ready, isFalse);
    expect(r.missing.single.label, 'Phone number');
  });

  test('a user keeps their social links and pending consents', () {
    final u = User.fromJson({
      'id': '1', 'email': 'ann@example.com', 'full_name': 'Ann Guest', 'email_verified': true,
      'social_links': [{'id': 's1', 'platform': 'Instagram', 'url': 'https://instagram.com/ann'}],
      'pending_consents': [{'doc_type': 'terms', 'version': 2, 'title': 'Terms of Service'}],
    });
    expect(u.firstName, 'Ann');
    expect(u.socialLinks.single.platform, 'Instagram');
    expect(u.pendingConsents.single.docType, 'terms');
  });
}
