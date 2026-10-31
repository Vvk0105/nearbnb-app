import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import 'common.dart';

/// A search result: big photo, name, place, price per night. Tapping opens the property.
class PropertyCard extends StatelessWidget {
  const PropertyCard({super.key, required this.item, required this.onTap});
  final SearchItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: '${item.name}, ${item.place}, from ${money(item.minPrice, item.currency)} per night',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            AspectRatio(aspectRatio: 4 / 3, child: NetImage(item.coverUrl ?? item.thumbUrl, radius: 18)),
            if (item.distanceKm != null)
              Positioned(
                left: 12,
                top: 12,
                child: _Pill(icon: Icons.near_me_rounded, text: '${item.distanceKm!.toStringAsFixed(item.distanceKm! < 10 ? 1 : 0)} km away'),
              ),
            if (item.fixedTiming)
              const Positioned(right: 12, top: 12, child: _Pill(icon: Icons.schedule_rounded, text: 'Set check-in time')),
          ]),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleMedium)),
            if (item.rating != null) RatingBadge(average: item.rating!.average, count: item.rating!.count, compact: true),
          ]),
          const SizedBox(height: 2),
          Text([item.typeName, item.place].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.slate600)),
          const SizedBox(height: 6),
          Text.rich(TextSpan(children: [
            const TextSpan(text: 'From ', style: TextStyle(color: Brand.slate600)),
            TextSpan(text: money(item.minPrice, item.currency), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const TextSpan(text: ' / night', style: TextStyle(color: Brand.slate600)),
          ])),
        ]),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.94), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: Brand.b700),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
}
