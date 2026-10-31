import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

final propertyProvider = FutureProvider.autoDispose.family<Property, String>((ref, id) async =>
    Property.fromJson(await ref.watch(apiProvider).get<Map<String, dynamic>>('/properties/$id')));

final reviewsProvider = FutureProvider.autoDispose.family<({double? average, int count, List<PublicReview> items}), String>((ref, id) async {
  final j = await ref.watch(apiProvider).get<Map<String, dynamic>>('/properties/$id/reviews');
  return (
    average: (j['average'] as num?)?.toDouble(),
    count: (j['count'] as num?)?.toInt() ?? 0,
    items: [for (final r in (j['items'] as List? ?? const []).whereType<Map>()) PublicReview.fromJson(r.cast<String, dynamic>())],
  );
});

class PropertyScreen extends ConsumerWidget {
  const PropertyScreen({super.key, required this.propertyId, this.initial = const {}});
  final String propertyId;
  final Map<String, String> initial; // date, time, nights, guests carried from the search

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final property = ref.watch(propertyProvider(propertyId));
    return property.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: ListView(padding: const EdgeInsets.all(20), children: const [
          AspectRatio(aspectRatio: 4 / 3, child: Skeleton(radius: 18)),
          SizedBox(height: 20),
          Skeleton(height: 26, width: 240, radius: 6),
          SizedBox(height: 10),
          Skeleton(height: 16, width: 160, radius: 6),
        ]),
      ),
      error: (e, _) => Scaffold(appBar: AppBar(), body: ErrorView(error: e, onRetry: () => ref.invalidate(propertyProvider(propertyId)))),
      data: (p) => _PropertyView(property: p, initial: initial),
    );
  }
}

class _PropertyView extends ConsumerWidget {
  const _PropertyView({required this.property, required this.initial});
  final Property property;
  final Map<String, String> initial;

  void _choose(BuildContext context, Unit unit) {
    final q = {...initial, 'property': property.id, 'unit': unit.id};
    context.push(Uri(path: '/book', queryParameters: q).toString());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = property;
    final t = Theme.of(context).textTheme;
    final cheapest = p.units.isEmpty ? null : p.units.reduce((a, b) => a.pricePer24h <= b.pricePer24h ? a : b);
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: MediaQuery.sizeOf(context).width * 0.8,
          pinned: true,
          backgroundColor: Colors.white,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: CircleAvatar(backgroundColor: Colors.white, child: BackButton(color: Brand.ink, onPressed: () => context.pop())),
          ),
          flexibleSpace: FlexibleSpaceBar(background: _Gallery(photos: [...p.photos, for (final u in p.units) ...u.photos])),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          sliver: SliverList.list(children: [
            Text(p.name, style: t.headlineMedium?.copyWith(fontSize: 26)),
            const SizedBox(height: 6),
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, children: [
              if (p.typeName != null) Text(p.typeName!, style: const TextStyle(color: Brand.slate600)),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.place_outlined, size: 16, color: Brand.slate600),
                Text(p.place, style: const TextStyle(color: Brand.slate600)),
              ]),
              if (p.rating != null) RatingBadge(average: p.rating!.average, count: p.rating!.count),
            ]),
            const SizedBox(height: 18),
            Row(children: [
              CircleAvatar(backgroundColor: Brand.b100, child: Text(p.hostFirstName.isEmpty ? 'H' : p.hostFirstName[0], style: const TextStyle(color: Brand.b800, fontWeight: FontWeight.w700))),
              const SizedBox(width: 12),
              Expanded(child: Text('Hosted by ${p.hostFirstName.isEmpty ? 'your host' : p.hostFirstName}', style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
            if (p.latitude != null && p.longitude != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('See the area on a map'),
                  onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=${p.latitude},${p.longitude}'),
                      mode: LaunchMode.externalApplication),
                ),
              ),
            ],
            const Divider(height: 36),
            if (p.description.isNotEmpty) ...[
              _ExpandableText(p.description),
              const Divider(height: 36),
            ],
            Text(p.units.length == 1 ? 'The place' : 'Choose a room', style: t.titleLarge),
            const SizedBox(height: 14),
            for (final u in p.units) ...[
              _UnitCard(unit: u, onChoose: () => _choose(context, u)),
              const SizedBox(height: 16),
            ],
            if (p.rules.isNotEmpty) ...[
              const Divider(height: 36),
              Text('House rules', style: t.titleLarge),
              const SizedBox(height: 10),
              Text(p.rules, style: const TextStyle(height: 1.5)),
            ],
            if (p.cancellationName != null) ...[
              const Divider(height: 36),
              Text('Cancellation', style: t.titleLarge),
              const SizedBox(height: 10),
              Text(p.cancellationName!, style: const TextStyle(fontWeight: FontWeight.w600)),
              if ((p.cancellationDescription ?? '').isNotEmpty) Text(p.cancellationDescription!, style: const TextStyle(color: Brand.slate600)),
              const SizedBox(height: 8),
              for (final tier in p.cancellationTiers)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• ${tier.refundPct}% back if you cancel ${tier.hoursBefore >= 24 ? plural(tier.hoursBefore ~/ 24, 'day') : plural(tier.hoursBefore, 'hour')} or more before check-in'),
                ),
            ],
            const Divider(height: 36),
            _Reviews(propertyId: p.id),
            const SizedBox(height: 120),
          ]),
        ),
      ]),
      bottomNavigationBar: cheapest == null
          ? null
          : _BottomBar(
              price: money(cheapest.pricePer24h, cheapest.currency),
              label: p.units.length == 1 ? 'Choose dates' : 'Choose a room',
              onTap: p.units.length == 1 ? () => _choose(context, p.units.first) : null, // several rooms: each card has its own button
            ),
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.photos});
  final List<Photo> photos;
  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) return const NetImage(null);
    return Stack(fit: StackFit.expand, children: [
      PageView.builder(
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _FullScreenPhotos(photos: widget.photos, start: i))),
          child: NetImage(widget.photos[i].url),
        ),
      ),
      Positioned(
        right: 16,
        bottom: 16,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
          child: Text('${_index + 1} / ${widget.photos.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ),
    ]);
  }
}

class _FullScreenPhotos extends StatelessWidget {
  const _FullScreenPhotos({required this.photos, required this.start});
  final List<Photo> photos;
  final int start;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
        body: PageView.builder(
          controller: PageController(initialPage: start),
          itemCount: photos.length,
          itemBuilder: (_, i) => InteractiveViewer(child: Center(child: NetImage(photos[i].url, fit: BoxFit.contain))),
        ),
      );
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({required this.unit, required this.onChoose});
  final Unit unit;
  final VoidCallback onChoose;
  @override
  Widget build(BuildContext context) {
    final u = unit;
    final facts = [
      plural(u.capacity, 'guest'),
      if (u.bedrooms != null) plural(u.bedrooms!, 'bedroom'),
      if (u.beds != null) plural(u.beds!, 'bed'),
      if (u.bathrooms != null) plural(u.bathrooms!, 'bathroom'),
    ];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (u.photos.isNotEmpty) AspectRatio(aspectRatio: 16 / 9, child: NetImage(u.photos.first.url)),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(facts.join(' · '), style: const TextStyle(color: Brand.slate600)),
            const SizedBox(height: 10),
            _TimingNote(unit: u),
            if (u.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(u.description, style: const TextStyle(height: 1.45)),
            ],
            if (u.amenities.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final a in u.amenities.take(8))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Brand.canvas, borderRadius: BorderRadius.circular(999), border: Border.all(color: Brand.line)),
                    child: Text(a, style: const TextStyle(fontSize: 12.5)),
                  ),
                if (u.amenities.length > 8) Text('+${u.amenities.length - 8} more', style: const TextStyle(fontSize: 12.5, color: Brand.slate600)),
              ]),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: money(u.pricePer24h, u.currency), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const TextSpan(text: ' / night', style: TextStyle(color: Brand.slate600)),
                  if (u.cleaningFee > 0) TextSpan(text: '\n+ ${money(u.cleaningFee, u.currency)} cleaning', style: const TextStyle(color: Brand.slate600, fontSize: 12.5)),
                ])),
              ),
              SizedBox(width: 150, child: FilledButton(onPressed: onChoose, child: const Text('Choose dates'))),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _TimingNote extends StatelessWidget {
  const _TimingNote({required this.unit});
  final Unit unit;
  @override
  Widget build(BuildContext context) {
    final fixed = unit.isFixed && unit.fixedCheckin != null && unit.fixedCheckout != null;
    final text = fixed
        ? 'Check in ${timeLabel(unit.fixedCheckin!)} · Check out ${timeLabel(unit.fixedCheckout!)}'
        : 'Check in any time ${timeLabel(unit.checkinFrom)} to ${timeLabel(unit.checkinTo)} · stays in 24-hour blocks';
    return Row(children: [
      const Icon(Icons.schedule_rounded, size: 16, color: Brand.b700),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: const TextStyle(color: Brand.b800, fontSize: 13, fontWeight: FontWeight.w500))),
    ]);
  }
}

class _ExpandableText extends StatefulWidget {
  const _ExpandableText(this.text);
  final String text;
  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _open = false;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.text, maxLines: _open ? null : 5, overflow: _open ? null : TextOverflow.fade, style: const TextStyle(height: 1.5)),
        if (widget.text.length > 240)
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: () => setState(() => _open = !_open),
            child: Text(_open ? 'Show less' : 'Read more'),
          ),
      ]);
}

class _Reviews extends ConsumerWidget {
  const _Reviews({required this.propertyId});
  final String propertyId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews = ref.watch(reviewsProvider(propertyId));
    return reviews.when(
      loading: () => const Skeleton(height: 80, radius: 12),
      error: (_, __) => const SizedBox.shrink(),
      data: (r) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Reviews', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(width: 10),
          if (r.average != null) RatingBadge(average: r.average!, count: r.count),
        ]),
        const SizedBox(height: 12),
        if (r.items.isEmpty) const Text('No reviews yet.', style: TextStyle(color: Brand.slate600)),
        for (final review in r.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(review.author, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                if (review.month != null) Text(review.month!, style: const TextStyle(color: Brand.slate600, fontSize: 13)),
                const Spacer(),
                for (var i = 0; i < 5; i++) Icon(i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 16, color: Brand.amber),
              ]),
              if (review.comment.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(review.comment)),
            ]),
          ),
      ]),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.price, required this.label, required this.onTap});
  final String price;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Brand.line))),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
        child: Row(children: [
          Expanded(
            child: Text.rich(TextSpan(children: [
              const TextSpan(text: 'From ', style: TextStyle(color: Brand.slate600)),
              TextSpan(text: price, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const TextSpan(text: ' / night', style: TextStyle(color: Brand.slate600)),
            ])),
          ),
          if (onTap != null) SizedBox(width: 160, child: FilledButton(onPressed: onTap, child: Text(label))),
        ]),
      );
}
