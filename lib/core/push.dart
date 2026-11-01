import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/router.dart';
import '../features/notifications/notifications_screen.dart';
import 'config.dart';
import 'providers.dart';

/// Set in main(): false when the Firebase file is missing, so push is skipped and nothing crashes.
final firebaseReadyProvider = Provider<bool>((ref) => false);

final pushProvider = Provider<PushService>((ref) => PushService(ref));

/// What the phone says about notifications, shown in Profile so a problem is visible instead of silent.
final pushStatusProvider = StateProvider<String>((ref) => 'Not set up yet. Sign in to turn them on.');

/// Push notifications (Firebase Cloud Messaging).
///  * After sign-in: asks permission (Android 13+ and iOS ask the person), then gives the server this phone's token.
///  * Before sign-out: takes the token back, so the next person on this phone does not get the previous one's pushes.
///  * While the app is open: shows the push as a banner and refreshes the bell.
///  * Tapped: opens the matching screen (a trip, the bell), or the website for pages the app does not have.
/// The server sends the same moments that appear in the bell (see backend/app/modules/notifications/push.py).
class PushService {
  PushService(this.ref);
  final Ref ref;
  final _local = FlutterLocalNotificationsPlugin();
  static const _channel = AndroidNotificationChannel('updates', 'Booking updates',
      description: 'Requests, payments, reminders and replies about your trips.', importance: Importance.high);

  bool get _ready => ref.read(firebaseReadyProvider);

  void start() {
    final hooks = ref.read(sessionHooksProvider);
    hooks.afterSignIn.add(_register);
    hooks.beforeSignOut.add(_unregister);
    if (!_ready) return;
    _setUpLocal();
    FirebaseMessaging.onMessage.listen(_onForeground);
    FirebaseMessaging.onMessageOpenedApp.listen((m) => open(m.data['link'] as String?));
    FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m != null) open(m.data['link'] as String?);
    });
    FirebaseMessaging.instance.onTokenRefresh.listen((_) => _register());
  }

  Future<void> _setUpLocal() async {
    await _local.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'), iOS: DarwinInitializationSettings()),
      onDidReceiveNotificationResponse: (r) => open(r.payload),
    );
    await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_channel);
  }

  /// Called from Profile ("Push notifications") to try again and see the result.
  Future<void> registerNow() => _register();

  /// iPhone only: Apple hands the app its notification address a moment after permission is given. Asking for the
  /// Firebase token before that fails ("apns-token-not-set"), so wait up to ~10 seconds for it.
  Future<void> _waitForApnsToken() async {
    for (var i = 0; i < 20; i++) {
      if (await FirebaseMessaging.instance.getAPNSToken() != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  Future<void> _register() async {
    final status = ref.read(pushStatusProvider.notifier);
    if (!_ready) {
      status.state = 'Unavailable: Firebase did not start on this phone.';
      return;
    }
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        status.state = 'Off. Allow notifications for NearBnB in the phone settings, then tap here.';
        return;
      }
      if (Platform.isIOS) await _waitForApnsToken();
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        status.state = 'Unavailable: this phone gave no notification address. Tap to retry.';
        return;
      }
      if (ref.read(authProvider).valueOrNull == null) return;
      await ref.read(apiProvider).post('/me/notifications/devices', body: {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'});
      status.state = 'On. You will get updates about your bookings.';
    } catch (e) {
      final why = e.toString().replaceAll(RegExp(r'\s+'), ' ');
      status.state = 'Unavailable: ${why.length > 140 ? '${why.substring(0, 140)}...' : why}';
    }
  }

  Future<void> _unregister() async {
    if (!_ready) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await ref.read(apiProvider).post('/me/notifications/devices/remove', body: {'token': token});
  }

  void _onForeground(RemoteMessage m) {
    ref.invalidate(unreadCountProvider);
    ref.invalidate(noticesProvider);
    final n = m.notification;
    if (n == null) return;
    _local.show(
      m.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(_channel.id, _channel.name, channelDescription: _channel.description, importance: Importance.high, priority: Priority.high),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: m.data['link'] as String?,
    );
  }

  /// Opens what a notification points to.
  void open(String? link) {
    if (link == null || link.isEmpty) return;
    final route = appRouteFor(link);
    if (route != null) {
      ref.read(routerProvider).push(route);
    } else {
      launchUrl(Uri.parse('${AppConfig.webOrigin}$link'), mode: LaunchMode.externalApplication);
    }
    if (kDebugMode) debugPrint('push opened $link -> ${route ?? 'website'}');
  }
}
