import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';

/// "$250 × 2 nights ... Total", the same lines as the website.
class PriceBreakdownView extends StatelessWidget {
  const PriceBreakdownView({super.key, required this.price, required this.currency});
  final PriceBreakdown price;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final p = price;
    final perNight = p.nights > 0 ? p.accommodation / p.nights : 0;
    return Column(children: [
      _row('${money(perNight, currency)} × ${plural(p.nights, 'night')}', money(p.accommodation, currency)),
      if (p.cleaningFee > 0) _row('Cleaning fee', money(p.cleaningFee, currency)),
      if (p.serviceFee > 0) _row('Service fee', money(p.serviceFee, currency)),
      if (p.taxName != null && p.tax > 0) _row('${p.taxName} (${p.taxRatePercent}%)${p.taxInclusive ? ' included' : ''}', money(p.tax, currency)),
      const Divider(height: 20),
      _row('Total', money(p.total, currency), strong: true),
    ]);
  }

  Widget _row(String label, String value, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: strong ? Brand.ink : Brand.slate600, fontWeight: strong ? FontWeight.w700 : FontWeight.w400, fontSize: strong ? 16 : 14))),
          Text(value, style: TextStyle(fontWeight: strong ? FontWeight.w700 : FontWeight.w500, fontSize: strong ? 16 : 14)),
        ]),
      );
}
