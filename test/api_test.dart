import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearbnb_app/core/api.dart';
import 'package:nearbnb_app/core/token_store.dart';

/// Pretends to be api.nearbnb.com. `handler` decides each answer; every request is recorded.
class FakeServer implements HttpClientAdapter {
  FakeServer(this.handler);
  final ResponseBody Function(RequestOptions) handler;
  final seen = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    seen.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody reply(int status, Object body) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

void main() {
  late MemoryTokenStore store;
  setUp(() => store = MemoryTokenStore()..tokens = const Tokens(access: 'old-access', refresh: 'old-refresh'));

  Api apiWith(FakeServer server, {void Function()? onSignedOut}) {
    final dio = Dio()..httpClientAdapter = server;
    return Api(tokens: store, dio: dio, onSignedOut: onSignedOut);
  }

  test('says it is the mobile app and sends the access token', () async {
    final server = FakeServer((_) => reply(200, {'ok': true}));
    await apiWith(server).get('/me');
    expect(server.seen.single.headers['X-Client'], 'mobile');
    expect(server.seen.single.headers['Authorization'], 'Bearer old-access');
  });

  test('an expired token is swapped once and the request repeated', () async {
    final server = FakeServer((o) {
      if (o.path.endsWith('/auth/refresh')) {
        expect(o.headers['X-Refresh-Token'], 'old-refresh');
        return reply(200, {'ok': true, 'tokens': {'access_token': 'new-access', 'refresh_token': 'new-refresh'}});
      }
      return o.headers['Authorization'] == 'Bearer new-access' ? reply(200, {'email': 'ann@example.com'}) : reply(401, {'error': {'code': 'NOT_AUTHENTICATED', 'message': 'Please log in'}});
    });
    final me = await apiWith(server).get<Map<String, dynamic>>('/me');
    expect(me['email'], 'ann@example.com');
    expect(store.tokens!.access, 'new-access');
    expect(store.tokens!.refresh, 'new-refresh');
    expect(server.seen.where((o) => o.path.endsWith('/auth/refresh')).length, 1);
  });

  test('several requests failing at once share one refresh', () async {
    var refreshes = 0;
    final server = FakeServer((o) {
      if (o.path.endsWith('/auth/refresh')) {
        refreshes++;
        return reply(200, {'tokens': {'access_token': 'new-access', 'refresh_token': 'new-refresh'}});
      }
      return o.headers['Authorization'] == 'Bearer new-access' ? reply(200, {'ok': true}) : reply(401, {'error': {'code': 'NOT_AUTHENTICATED', 'message': 'x'}});
    });
    final api = apiWith(server);
    await Future.wait([api.get('/me'), api.get('/me/bookings'), api.get('/me/notifications/unread-count')]);
    expect(refreshes, 1);
  });

  test('when the refresh token is dead too, the person is signed out', () async {
    var signedOut = false;
    final server = FakeServer((_) => reply(401, {'error': {'code': 'NOT_AUTHENTICATED', 'message': 'Session expired'}}));
    final api = apiWith(server, onSignedOut: () => signedOut = true);
    await expectLater(api.get('/me'), throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)));
    expect(signedOut, isTrue);
    expect(store.tokens, isNull);
  });

  test('a wrong password at sign-in is not mistaken for an expired token', () async {
    final server = FakeServer((_) => reply(401, {'error': {'code': 'INVALID_CREDENTIALS', 'message': 'Incorrect email or password'}}));
    await expectLater(
      apiWith(server).post('/auth/login', body: {'email': 'a@b.co', 'password': 'x'}),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Incorrect email or password')),
    );
    expect(server.seen.where((o) => o.path.endsWith('/auth/refresh')), isEmpty);
  });

  test("the API's own message reaches the screen, and so does a validation error", () async {
    final conflict = FakeServer((_) => reply(409, {'error': {'code': 'OPEN_BOOKINGS', 'message': 'You have bookings in progress.'}}));
    await expectLater(apiWith(conflict).post('/me/delete', body: {'password': 'x'}),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'OPEN_BOOKINGS').having((e) => e.message, 'message', 'You have bookings in progress.')));
    final invalid = FakeServer((_) => reply(422, {'detail': [{'msg': 'value is not a valid email address'}]}));
    await expectLater(apiWith(invalid).post('/auth/register'), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'value is not a valid email address')));
  });
}
