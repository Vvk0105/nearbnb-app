import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/profile/profile_screens.dart' show ConsentGate;

/// The bottom tabs: Explore, Trips, Notifications (with the unread count), Profile. Each tab keeps its own scroll and history.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final signedIn = user != null;
    if (user != null && user.pendingConsents.isNotEmpty) return ConsentGate(user: user);
    final unread = signedIn ? ref.watch(unreadCountProvider).valueOrNull ?? 0 : 0;
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: [
            const NavigationDestination(icon: Icon(Icons.search_rounded), selectedIcon: Icon(Icons.travel_explore_rounded), label: 'Explore'),
            const NavigationDestination(icon: Icon(Icons.luggage_outlined), selectedIcon: Icon(Icons.luggage_rounded), label: 'Trips'),
            NavigationDestination(
              icon: Badge(isLabelVisible: unread > 0, label: Text(unread > 99 ? '99+' : '$unread'), child: const Icon(Icons.notifications_none_rounded)),
              selectedIcon: Badge(isLabelVisible: unread > 0, label: Text(unread > 99 ? '99+' : '$unread'), child: const Icon(Icons.notifications_rounded)),
              label: 'Alerts',
            ),
            const NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
