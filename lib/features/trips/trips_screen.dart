import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/sign_in_prompt.dart';
import '../../widgets/status_badge.dart';

/// Tabs, as on the website: all, waiting for host, awaiting payment, upcoming, past, cancelled.
const tripGroups = [
  ('all', 'All'),
  ('pending', 'Waiting for host'),
  ('awaiting_payment', 'To pay'),
  ('upcoming', 'Upcoming'),
  ('past', 'Past'),
  ('cancelled', 'Cancelled'),
];

final tripsProvider = FutureProvider.autoDispose.family<BookingList, String>((ref, group) async {
  final query = switch (group) {
    'all' => <String, dynamic>{},
    'cancelled' => {'status': 'cancelled'},
    _ => {'group': group},
  };
  return BookingList.fromJson(await ref.watch(apiProvider).get<Map<String, dynamic>>('/me/bookings', query: query));
});

class TripsScreen extends ConsumerStatefulWidget {
  const TripsScreen({super.key});
  @override
  ConsumerState<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends ConsumerState<TripsScreen> {
  String _group = 'all';

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(authProvider).valueOrNull != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Trips')),
      body: !signedIn
          ? const SignInPrompt(
              icon: Icons.luggage_rounded,
              title: 'Your trips live here',
              message: 'Sign in to see your requests, pay for accepted stays and find your check-in details.',
              from: '/trips',
            )
          : Column(children: [
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final g in tripGroups)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(g.$2),
                          selected: _group == g.$1,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _group = g.$1),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(child: _list()),
            ]),
    );
  }

  Widget _list() {
    final trips = ref.watch(tripsProvider(_group));
    return RefreshIndicator(
      onRefresh: () => ref.refresh(tripsProvider(_group).future),
      child: trips.when(
        loading: () => const CardListSkeleton(count: 2),
        error: (e, _) => ListView(children: [ErrorView(error: e, onRetry: () => ref.invalidate(tripsProvider(_group)))]),
        data: (list) => list.items.isEmpty
            ? ListView(children: [
                const SizedBox(height: 40),
                EmptyState(
                  icon: Icons.luggage_outlined,
                  title: 'No trips here yet',
                  message: 'When you request a stay, it shows up here.',
                  action: OutlinedButton(onPressed: () => context.go('/'), child: const Text('Find a place to stay')),
                ),
              ])
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: list.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => TripCard(booking: list.items[i]),
              ),
      ),
    );
  }
}

class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.booking});
  final Booking booking;
  @override
  Widget build(BuildContext context) {
    final b = booking;
    final nudge = switch (b.status) {
      'requested' when b.secondsToRespond != null => 'Host replies within ${timeLeft(b.secondsToRespond)}',
      'accepted' || 'payment_pending' when b.canPay => b.secondsToPay != null ? 'Pay within ${timeLeft(b.secondsToPay)}' : 'Payment due',
      _ => null,
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/trips/${b.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            SizedBox(width: 84, height: 84, child: NetImage(b.coverUrl, radius: 12)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                StatusBadge(b.status),
                const SizedBox(height: 6),
                Text(b.propertyName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                Text(b.checkInLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.slate600, fontSize: 13)),
                Text('${plural(b.nights, 'night')} · ${money(b.total, b.currency)}', style: const TextStyle(color: Brand.slate600, fontSize: 13)),
                if (nudge != null) ...[
                  const SizedBox(height: 4),
                  Text(nudge, style: const TextStyle(color: Color(0xFFB45309), fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: Brand.slate400),
          ]),
        ),
      ),
    );
  }
}
