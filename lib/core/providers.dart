import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'models.dart';
import 'token_store.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final apiProvider = Provider<Api>((ref) => Api(tokens: ref.watch(tokenStoreProvider)));

/// Booking rules from the admin settings (check-in interval, longest stay, how far ahead).
final bookingMetaProvider = FutureProvider<BookingMeta>((ref) async {
  try {
    return BookingMeta.fromJson(await ref.watch(apiProvider).get<Map<String, dynamic>>('/meta/booking'));
  } on ApiException {
    return BookingMeta.fallback;
  }
});

/// Things to do when someone signs in or out (push registration hooks in here, see push.dart).
typedef SessionHook = Future<void> Function();

class SessionHooks {
  final List<SessionHook> afterSignIn = [];
  final List<SessionHook> beforeSignOut = [];
}

final sessionHooksProvider = Provider<SessionHooks>((ref) => SessionHooks());

/// Who is signed in: null when signed out. Loading while the app checks the saved sign-in at start.
class AuthController extends AsyncNotifier<User?> {
  Api get _api => ref.read(apiProvider);
  TokenStore get _tokens => ref.read(tokenStoreProvider);

  @override
  Future<User?> build() async {
    _api.onSignedOut = () => state = const AsyncData(null);
    if (await _tokens.read() == null) return null;
    try {
      final me = User.fromJson(await _api.get<Map<String, dynamic>>('/me'));
      _runAfterSignIn();
      return me;
    } on ApiException catch (e) {
      if (e.isUnauthenticated) {
        await _tokens.clear();
        return null;
      }
      rethrow; // offline at start: the app shows a retry screen instead of signing the person out
    }
  }

  Future<void> _signedIn(Map<String, dynamic> body) async {
    final tokens = Tokens.fromJson(body['tokens'] as Map<String, dynamic>?);
    if (tokens == null) throw ApiException(500, 'NO_TOKENS', 'Sign-in failed. Please try again.');
    await _tokens.write(tokens);
    state = AsyncData(User.fromJson(body));
    _runAfterSignIn();
  }

  void _runAfterSignIn() {
    for (final hook in ref.read(sessionHooksProvider).afterSignIn) {
      hook().catchError((_) {}); // push registration must never block signing in
    }
  }

  Future<void> login(String email, String password) async {
    await _signedIn(await _api.post<Map<String, dynamic>>('/auth/login', body: {'email': email.trim(), 'password': password}));
  }

  /// Sends a 6-digit code to the email. The account exists once the code is confirmed.
  Future<void> register({required String name, required String email, required String password}) async {
    await _api.post('/auth/register', body: {'full_name': name.trim(), 'email': email.trim(), 'password': password, 'accept_terms': true});
  }

  Future<void> verifyEmail(String email, String code) async {
    await _signedIn(await _api.post<Map<String, dynamic>>('/auth/verify-email', body: {'email': email.trim(), 'code': code.trim()}));
  }

  Future<void> resendCode(String email) => _api.post('/auth/resend-otp', body: {'email': email.trim()});

  Future<void> forgotPassword(String email) => _api.post('/auth/forgot-password', body: {'email': email.trim()});

  Future<void> resetPassword(String email, String code, String newPassword) =>
      _api.post('/auth/reset-password', body: {'email': email.trim(), 'code': code.trim(), 'new_password': newPassword});

  Future<void> reload() async {
    state = AsyncData(User.fromJson(await _api.get<Map<String, dynamic>>('/me')));
  }

  void setUser(User user) => state = AsyncData(user);

  Future<void> logout() async {
    for (final hook in ref.read(sessionHooksProvider).beforeSignOut) {
      await hook().catchError((_) {});
    }
    final t = await _tokens.read();
    if (t != null) {
      try {
        await _api.post('/auth/logout', headers: {'X-Refresh-Token': t.refresh});
      } on ApiException {
        // signed out on this phone anyway
      }
    }
    await _tokens.clear();
    state = const AsyncData(null);
  }

  /// Erases the account (see the backend's /me/delete). Throws with a clear message when something blocks it.
  Future<void> deleteAccount(String password) async {
    await _api.post('/me/delete', body: {'password': password});
    await _tokens.clear();
    state = const AsyncData(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthController, User?>(AuthController.new);
