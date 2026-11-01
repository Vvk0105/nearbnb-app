import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'core/push.dart';
import 'core/theme.dart';

/// On iPhone the Firebase settings come from build variables (--dart-define, set in Codemagic), so no
/// GoogleService-Info.plist has to be in git. They are the API_KEY, GOOGLE_APP_ID, GCM_SENDER_ID and PROJECT_ID of that file.
/// On Android they come from android/app/google-services.json, so this returns null.
FirebaseOptions? _firebaseOptions() {
  if (!Platform.isIOS) return null;
  const apiKey = String.fromEnvironment('IOS_FIREBASE_API_KEY');
  const appId = String.fromEnvironment('IOS_FIREBASE_APP_ID');
  const senderId = String.fromEnvironment('IOS_FIREBASE_SENDER_ID');
  const projectId = String.fromEnvironment('IOS_FIREBASE_PROJECT_ID');
  if (apiKey.isEmpty || appId.isEmpty || senderId.isEmpty || projectId.isEmpty) return null;
  return const FirebaseOptions(apiKey: apiKey, appId: appId, messagingSenderId: senderId, projectId: projectId, iosBundleId: 'com.nearbnb.app');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(options: _firebaseOptions());
    firebaseReady = true;
  } catch (_) {
    // No Firebase file yet (a fresh checkout): the app works, just without push notifications.
  }
  runApp(ProviderScope(overrides: [firebaseReadyProvider.overrideWithValue(firebaseReady)], child: const NearBnBApp()));
}

class NearBnBApp extends ConsumerStatefulWidget {
  const NearBnBApp({super.key});
  @override
  ConsumerState<NearBnBApp> createState() => _NearBnBAppState();
}

class _NearBnBAppState extends ConsumerState<NearBnBApp> {
  @override
  void initState() {
    super.initState();
    ref.read(pushProvider).start(); // registers the phone after sign-in and opens the right screen when a push is tapped
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'NearBnB',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: ref.watch(routerProvider),
        locale: const Locale('en', 'AU'),
        supportedLocales: const [Locale('en', 'AU'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      );
}
