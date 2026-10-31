import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'core/push.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
  var firebaseReady = false;
  try {
    await Firebase.initializeApp(); // reads android/app/google-services.json
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
