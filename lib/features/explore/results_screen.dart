import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/property_card.dart';
import 'explore_screen.dart';
import 'search_query.dart';

class Filters {
  const Filters({this.sort = 'relevance', this.minDollars, this.maxDollars, this.typeIds = const {}, this.amenityIds = const {}});
  final String sort;
  final int? minDollars;
  final int? maxDollars;
  final Set<String> typeIds;
  final Set<String> amenityIds;
  int get count => (minDollars != null ? 1 : 0) + (maxDollars != null ? 1 : 0) + typeIds.length + amenityIds.length;
  Map<String, dynamic> toApi() => {
        'sort': sort,
        if (minDollars != null) 'min_price': minDollars! * 100,
        if (maxDollars != null) 'max_price': maxDollars! * 100,
        if (typeIds.isNotEmpty) 'type_ids': typeIds.toList(),
        if (amenityIds.isNotEmpty) 'amenity_ids': amenityIds.toList(),
      };
}

final listingMetaProvider = FutureProvider<ListingMetaData>((ref) async =>
    ListingMetaData.fromJson(await ref.watch(apiProvider).get<Map<String, dynamic>>('/meta/listing')));

class ListingMetaData {
  ListingMetaData(this.types, this.amenities);
  final List<({String id, String name})> types;
  final List<({String id, String name})> amenities;
  factory ListingMetaData.fromJson(Map<String, dynamic> j) => ListingMetaData(
        [for (final t in (j['property_types'] as List? ?? const []).whereType<Map>()) (id: '${t['id']}', name: '${t['name']}')],
        [for (final a in (j['amenities'] as List? ?? const []).whereType<Map>()) (id: '${a['id']}', name: '${a['name']}')],
      );
}

/// Search results, nearest or best first, loading more as the person scrolls.
class SearchResultsScreen extends ConsumerStatefulWidget {
  const SearchResultsScreen({super.key, required this.params});
  final Map<String, String> params;
  @override
  ConsumerState<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  late final SearchQuery _query = SearchQuery.fromParams(widget.params);
  Filters _filters = const Filters();
  final _items = <SearchItem>[];
  int _page = 0;
  int _total = 0;
  bool _loading = false;
  bool _hasMore = true;
  String? _hint;
  Object? _error;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _items.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
    });
    await _load();
  }

  Future<void> _load() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final res = SearchResult.fromJson(await ref.read(apiProvider).get<Map<String, dynamic>>('/search', query: {
        ..._query.toApi(),
        ..._filters.toApi(),
        'page': _page + 1,
        'page_size': 12,
      }));
      setState(() {
        _items.addAll(res.items);
        _page = res.page;
        _total = res.total;
        _hasMore = res.hasMore;
        _hint = res.hint;
      });
    } on ApiException catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// "Book this place" carries the dates and guests to the property page.
  String get _carry => SearchQuery(date: _query.date, time: _query.time, nights: _query.nights, guests: _query.guests).toQueryString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => startSearch(context, _query),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: Brand.line)),
            child: Row(children: [
              const Icon(Icons.search_rounded, size: 20, color: Brand.b700),
              const SizedBox(width: 8),
              Expanded(child: Text(_query.summary(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            ]),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Filters',
            icon: Badge(isLabelVisible: _filters.count > 0, label: Text('${_filters.count}'), child: const Icon(Icons.tune_rounded)),
            onPressed: _openFilters,
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _reload, child: _body()),
    );
  }

  Widget _body() {
    if (_items.isEmpty && _loading) return const CardListSkeleton();
    if (_items.isEmpty && _error != null) return ErrorView(error: _error!, onRetry: _reload);
    if (_items.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 60),
        EmptyState(
          icon: Icons.travel_explore_rounded,
          title: 'Nothing matches yet',
          message: _hint ?? 'Try different dates, fewer filters, or a wider area.',
          action: OutlinedButton(onPressed: () => startSearch(context, _query), child: const Text('Change search')),
        ),
      ]);
    }
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: _items.length + 2,
      separatorBuilder: (_, i) => SizedBox(height: i == 0 ? 12 : 28),
      itemBuilder: (_, i) {
        if (i == 0) {
          return Row(children: [
            Expanded(child: Text(_total == 1 ? '1 place' : '$_total places', style: const TextStyle(fontWeight: FontWeight.w600))),
            _SortMenu(value: _filters.sort, nearest: _query.lat != null, onChanged: (s) {
              _filters = Filters(sort: s, minDollars: _filters.minDollars, maxDollars: _filters.maxDollars, typeIds: _filters.typeIds, amenityIds: _filters.amenityIds);
              _reload();
            }),
          ]);
        }
        if (i == _items.length + 1) {
          return _loading ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())) : const SizedBox.shrink();
        }
        final item = _items[i - 1];
        return PropertyCard(item: item, onTap: () => context.push('/property/${item.id}?$_carry'));
      },
    );
  }

  Future<void> _openFilters() async {
    final next = await showModalBottomSheet<Filters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FilterSheet(initial: _filters),
    );
    if (next != null) {
      _filters = next;
      _reload();
    }
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.value, required this.nearest, required this.onChanged});
  final String value;
  final bool nearest;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final labels = {'relevance': nearest ? 'Nearest' : 'Best match', 'price_asc': 'Lowest price', 'price_desc': 'Highest price', 'newest': 'Newest'};
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => [for (final e in labels.entries) PopupMenuItem(value: e.key, child: Text(e.value))],
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.swap_vert_rounded, size: 18, color: Brand.b700),
        const SizedBox(width: 4),
        Text(labels[value] ?? 'Sort', style: const TextStyle(color: Brand.b700, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.initial});
  final Filters initial;
  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late final _min = TextEditingController(text: widget.initial.minDollars?.toString() ?? '');
  late final _max = TextEditingController(text: widget.initial.maxDollars?.toString() ?? '');
  late final Set<String> _types = {...widget.initial.typeIds};
  late final Set<String> _amenities = {...widget.initial.amenityIds};

  @override
  Widget build(BuildContext context) {
    final meta = ref.watch(listingMetaProvider);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(children: [
        Expanded(
          child: ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
            Text('Filters', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            const Text('Price per night (AUD)', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: _min, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min', prefixText: '\$'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _max, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max', prefixText: '\$'))),
            ]),
            const SizedBox(height: 24),
            ...meta.when(
              loading: () => [const Center(child: CircularProgressIndicator())],
              error: (e, _) => [Text(ApiException.from(e).message)],
              data: (m) => [
                const Text('Type of place', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                _chips(m.types, _types),
                const SizedBox(height: 24),
                const Text('Amenities', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                _chips(m.amenities, _amenities),
              ],
            ),
          ]),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(children: [
              TextButton(
                onPressed: () => setState(() {
                  _min.clear();
                  _max.clear();
                  _types.clear();
                  _amenities.clear();
                }),
                child: const Text('Clear all'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    Filters(
                      sort: widget.initial.sort,
                      minDollars: int.tryParse(_min.text.trim()),
                      maxDollars: int.tryParse(_max.text.trim()),
                      typeIds: _types,
                      amenityIds: _amenities,
                    ),
                  ),
                  child: const Text('Show places'),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _chips(List<({String id, String name})> options, Set<String> selected) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in options)
          FilterChip(
            label: Text(o.name),
            selected: selected.contains(o.id),
            onSelected: (on) => setState(() => on ? selected.add(o.id) : selected.remove(o.id)),
          ),
      ]);
}
