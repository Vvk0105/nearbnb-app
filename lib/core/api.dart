import 'dart:async';

import 'package:dio/dio.dart';

import 'config.dart';
import 'token_store.dart';

/// An error the API sent back ({"error": {"code", "message"}}), or a network problem in the same shape,
/// so screens can always show `message` to the person.
class ApiException implements Exception {
  ApiException(this.status, this.code, this.message);
  final int status;
  final String code;
  final String message;

  bool get isNetwork => code == 'NETWORK';
  bool get isUnauthenticated => status == 401;

  @override
  String toString() => message;

  static ApiException from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] is Map) {
        final e = data['error'] as Map;
        return ApiException(error.response?.statusCode ?? 0, '${e['code'] ?? 'ERROR'}', '${e['message'] ?? 'Something went wrong.'}');
      }
      if (data is Map && data['detail'] is List) {
        // FastAPI validation errors: show the first one in plain words.
        final first = (data['detail'] as List).firstOrNull;
        final msg = first is Map ? '${first['msg'] ?? ''}' : '';
        return ApiException(error.response?.statusCode ?? 422, 'INVALID', msg.isEmpty ? 'Please check what you entered.' : msg);
      }
      if (error.response == null) {
        return ApiException(0, 'NETWORK', 'No connection. Check your internet and try again.');
      }
      return ApiException(error.response!.statusCode ?? 0, 'ERROR', 'Something went wrong. Please try again.');
    }
    return ApiException(0, 'ERROR', 'Something went wrong. Please try again.');
  }
}

/// The one HTTP client of the app.
///  * Says it is the mobile app (X-Client: mobile), so sign-in returns tokens instead of browser cookies.
///  * Adds "Authorization: Bearer <access>" to every request when signed in.
///  * When the access token has run out (401), swaps the refresh token for new ones once, then repeats the request.
///    If that fails too, the person is signed out (`onSignedOut`).
class Api {
  Api({required this.tokens, Dio? dio, this.onSignedOut}) : dio = dio ?? Dio() {
    this.dio.options
      ..baseUrl = AppConfig.apiBase
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 20)
      ..listFormat = ListFormat.multi // type_ids=a&type_ids=b, as the API expects
      ..headers['X-Client'] = 'mobile';
    this.dio.interceptors.add(InterceptorsWrapper(onRequest: _addToken, onError: _refreshOn401));
  }

  final Dio dio;
  final TokenStore tokens;
  void Function()? onSignedOut;
  Future<Tokens?>? _refreshing;

  static const _noRefresh = ['/auth/login', '/auth/refresh', '/auth/logout', '/auth/register', '/auth/verify-email'];

  Future<void> _addToken(RequestOptions options, RequestInterceptorHandler handler) async {
    final t = await tokens.read();
    if (t != null && !options.headers.containsKey('Authorization')) {
      options.headers['Authorization'] = 'Bearer ${t.access}';
    }
    handler.next(options);
  }

  Future<void> _refreshOn401(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final retried = options.extra['retried'] == true;
    if (err.response?.statusCode != 401 || retried || _noRefresh.any(options.path.endsWith)) {
      return handler.next(err);
    }
    final fresh = await (_refreshing ??= _refresh().whenComplete(() => _refreshing = null));
    if (fresh == null) return handler.next(err);
    try {
      options.extra['retried'] = true;
      options.headers['Authorization'] = 'Bearer ${fresh.access}';
      handler.resolve(await dio.fetch(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// Several requests can fail at once when the token runs out: they all wait for this one refresh.
  Future<Tokens?> _refresh() async {
    final current = await tokens.read();
    if (current == null) return null;
    try {
      // A bare client (same server, same connection) so the refresh call itself is never given the old access token or retried.
      final bare = Dio(dio.options.copyWith())..httpClientAdapter = dio.httpClientAdapter;
      final res = await bare.post('/auth/refresh', options: Options(headers: {'X-Refresh-Token': current.refresh}));
      final fresh = Tokens.fromJson((res.data as Map)['tokens'] as Map<String, dynamic>?);
      if (fresh == null) throw StateError('no tokens');
      await tokens.write(fresh);
      return fresh;
    } catch (_) {
      await tokens.clear();
      onSignedOut?.call();
      return null;
    }
  }

  // ---------- helpers that turn every failure into an ApiException ----------

  Future<T> get<T>(String path, {Map<String, dynamic>? query}) => _wrap(() => dio.get(path, queryParameters: query));
  Future<T> post<T>(String path, {Object? body, Map<String, dynamic>? headers}) =>
      _wrap(() => dio.post(path, data: body ?? {}, options: headers == null ? null : Options(headers: headers)));
  Future<T> patch<T>(String path, {Object? body}) => _wrap(() => dio.patch(path, data: body ?? {}));
  Future<T> delete<T>(String path) => _wrap(() => dio.delete(path));

  Future<T> _wrap<T>(Future<Response<dynamic>> Function() call) async {
    try {
      final res = await call();
      return res.data as T;
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}
