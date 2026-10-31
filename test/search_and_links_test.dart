import 'package:flutter_test/flutter_test.dart';
import 'package:nearbnb_app/app/router.dart';
import 'package:nearbnb_app/features/explore/search_query.dart';

void main() {
  group('a search', () {
    test('becomes the same API request as the website (checkin + hours)', () {
      final q = SearchQuery(q: 'Bondi', lat: -33.89, lng: 151.27, date: DateTime(2026, 11, 3), time: '15:00', nights: 2, guests: 3);
      expect(q.toApi(), {'q': 'Bondi', 'lat': -33.89, 'lng': 151.27, 'checkin': '2026-11-03T15:00', 'hours': 48, 'guests': 3});
    });

    test('without a day it asks for any day', () {
      expect(const SearchQuery(q: 'Manly').toApi(), {'q': 'Manly', 'guests': 2});
    });

    test('survives a trip through the address bar', () {
      final q = SearchQuery(q: 'Glass House Mountains', lat: -26.9, lng: 152.95, date: DateTime(2026, 12, 1), time: '10:00', nights: 4, guests: 2);
      final back = SearchQuery.fromParams(Uri.parse('/search?${q.toQueryString()}').queryParameters);
      expect(back.toApi(), q.toApi());
      expect(back.summary(), 'Glass House Mountains · Tue 1 Dec, 10:00 am · 4 nights · 2 guests');
    });

    test('typing a new place forgets the old map point', () {
      const q = SearchQuery(q: 'Bondi', lat: 1, lng: 2);
      expect(q.copyWith(q: 'Manly', clearLocation: true).toApi().containsKey('lat'), isFalse);
    });
  });

  group('links in notifications open app screens', () {
    const id = '3f2a1b4c-5d6e-4f70-8a9b-0c1d2e3f4a5b';
    test('trips and paying', () {
      expect(appRouteFor('/account/trips/$id'), '/trips/$id');
      expect(appRouteFor('/account/trips/$id/pay'), '/trips/$id');
      expect(appRouteFor('/account/trips'), '/trips');
    });
    test('account and properties', () {
      expect(appRouteFor('/account'), '/profile');
      expect(appRouteFor('/property/$id'), '/property/$id');
    });
    test('host and admin pages stay on the website', () {
      expect(appRouteFor('/host/requests'), isNull);
      expect(appRouteFor('/admin/refunds'), isNull);
    });
  });
}
