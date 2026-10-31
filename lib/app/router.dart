import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_screens.dart';
import '../features/explore/explore_screen.dart';
import '../features/explore/results_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/profile/profile_screens.dart';
import '../features/property/book_screen.dart';
import '../features/property/property_screen.dart';
import '../features/trips/trip_screen.dart';
import '../features/trips/trips_screen.dart';
import 'shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Every screen and its address. Signed-out people can browse; tabs that need an account show a sign-in prompt instead of
/// redirecting, and screens that act for the person (booking, a trip) send them to sign in and back.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, __) => const ExploreScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/trips', builder: (_, __) => const TripsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen())]),
        ],
      ),
      GoRoute(path: '/search', parentNavigatorKey: rootNavigatorKey, builder: (_, s) => SearchResultsScreen(params: s.uri.queryParameters)),
      GoRoute(
        path: '/property/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => PropertyScreen(propertyId: s.pathParameters['id']!, initial: s.uri.queryParameters),
      ),
      GoRoute(path: '/book', parentNavigatorKey: rootNavigatorKey, builder: (_, s) => BookScreen(params: s.uri.queryParameters)),
      GoRoute(path: '/trips/:id', parentNavigatorKey: rootNavigatorKey, builder: (_, s) => TripScreen(bookingId: s.pathParameters['id']!)),
      GoRoute(path: '/profile/edit', parentNavigatorKey: rootNavigatorKey, builder: (_, __) => const EditProfileScreen()),
      GoRoute(path: '/profile/password', parentNavigatorKey: rootNavigatorKey, builder: (_, __) => const ChangePasswordScreen()),
      GoRoute(path: '/profile/delete', parentNavigatorKey: rootNavigatorKey, builder: (_, __) => const DeleteAccountScreen()),
      GoRoute(path: '/login', parentNavigatorKey: rootNavigatorKey, builder: (_, s) => LoginScreen(state: s)),
      GoRoute(path: '/register', parentNavigatorKey: rootNavigatorKey, builder: (_, s) => RegisterScreen(state: s)),
      GoRoute(path: '/verify', parentNavigatorKey: rootNavigatorKey, builder: (_, s) => VerifyEmailScreen(state: s)),
      GoRoute(path: '/forgot-password', parentNavigatorKey: rootNavigatorKey, builder: (_, __) => const ForgotPasswordScreen()),
    ],
  );
});

/// Notifications and pushes carry website links (`/account/trips/<id>/pay`). This turns them into app screens,
/// or returns null when the app has no such screen (host and admin pages): the caller then opens the website.
String? appRouteFor(String webLink) {
  final path = Uri.tryParse(webLink)?.path ?? webLink;
  final trip = RegExp(r'^/account/trips/([0-9a-fA-F-]{36})(/pay)?$').firstMatch(path);
  if (trip != null) return '/trips/${trip.group(1)}';
  if (path == '/account/trips') return '/trips';
  if (path == '/account' || path.startsWith('/account/')) return '/profile';
  if (path == '/notifications') return '/notifications';
  final property = RegExp(r'^/property/([0-9a-fA-F-]{36})$').firstMatch(path);
  if (property != null) return '/property/${property.group(1)}';
  if (path == '/' || path.isEmpty) return '/';
  return null;
}
