import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/property_card.dart';
import 'search_query.dart';
import 'search_sheet.dart';

final recentProvider = FutureProvider.autoDispose<SearchResult>((ref) async =>
    SearchResult.fromJson(await ref.watch(apiProvider).get<Map<String, dynamic>>('/search', query: {'sort': 'newest', 'page_size': 6})));

/// Opens the search sheet, then the results (or a property picked from the suggestions).
Future<void> startSearch(BuildContext context, SearchQuery current) async {
  final result = await openSearchSheet(context, current);
  if (!context.mounted || result == null) return;
  if (result is String && result.startsWith('property:')) {
    context.push('/property/${result.substring(9)}');
  } else if (result is SearchQuery) {
    context.push('/search?${result.toQueryString()}');
  }
}

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final recent = ref.watch(recentProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(recentProvider.future),
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _Hero(name: user?.firstName)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 4),
              child: Text('Recently added', style: Theme.of(context).textTheme.titleLarge),
            ),
          ),
          recent.when(
            loading: () => const SliverToBoxAdapter(child: SizedBox(height: 600, child: CardListSkeleton(count: 2))),
            error: (e, _) => SliverToBoxAdapter(child: ErrorView(error: e, onRetry: () => ref.invalidate(recentProvider))),
            data: (r) => r.items.isEmpty
                ? const SliverToBoxAdapter(child: EmptyState(icon: Icons.home_work_outlined, title: 'New places are on their way'))
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    sliver: SliverList.separated(
                      itemCount: r.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 28),
                      itemBuilder: (_, i) => PropertyCard(item: r.items[i], onTap: () => context.push('/property/${r.items[i].id}')),
                    ),
                  ),
          ),
          const SliverToBoxAdapter(child: _HowItWorks()),
        ]),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({this.name});
  final String? name;
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F172A), Brand.b900, Brand.b700]),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 16, 20, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Logo(size: 24, light: true),
          const SizedBox(height: 24),
          Text(name == null ? 'Find a place for exactly the time you need' : 'Where to next, $name?',
              style: const TextStyle(color: Colors.white, fontSize: 28, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
          const SizedBox(height: 8),
          const Text('Check in at any hour. Stay 24, 48, 72 hours or more.', style: TextStyle(color: Brand.b100, fontSize: 15)),
          const SizedBox(height: 22),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            elevation: 6,
            shadowColor: Colors.black26,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => startSearch(context, const SearchQuery()),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(children: [
                  Icon(Icons.search_rounded, color: Brand.b700),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Where to?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Text('Any place · Any day · Guests', style: TextStyle(color: Brand.slate600, fontSize: 13)),
                    ]),
                  ),
                  Icon(Icons.tune_rounded, color: Brand.slate400),
                ]),
              ),
            ),
          ),
        ]),
      );
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();
  static const _steps = [
    (Icons.search_rounded, 'Search by the hour', 'Pick the day, the hour you arrive and how many nights. Only places that are really free show up.'),
    (Icons.send_rounded, 'Send a request', 'The host replies within a set time. Your dates are held and you are not charged yet.'),
    (Icons.credit_card_rounded, 'Pay and stay', 'Once the host accepts, pay securely by card. The host\'s details are shared with you.'),
  ];
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Brand.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('How it works', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          for (final s in _steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Brand.b50, borderRadius: BorderRadius.circular(12)),
                  child: Icon(s.$1, color: Brand.b700, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.$2, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(s.$3, style: const TextStyle(color: Brand.slate600)),
                  ]),
                ),
              ]),
            ),
        ]),
      );
}
