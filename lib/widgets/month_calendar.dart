import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/format.dart';
import '../core/theme.dart';

/// A month of days coloured by availability (from /units/{id}/availability/calendar):
/// available = free, partial = some hours free, unavailable / past / closed = cannot start a stay.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({super.key, required this.month, required this.days, required this.selected, required this.onSelect, required this.onMonthChange,
      required this.canGoBack, this.loading = false});
  final DateTime month; // first day of the month
  final Map<String, String> days;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<DateTime> onMonthChange;
  final bool canGoBack;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1; // weeks start on Monday in Australia
    return Column(children: [
      Row(children: [
        IconButton(
          tooltip: 'Previous month',
          onPressed: canGoBack ? () => onMonthChange(DateTime(month.year, month.month - 1)) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(child: Text(DateFormat('MMMM yyyy').format(first), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
        IconButton(tooltip: 'Next month', onPressed: () => onMonthChange(DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right_rounded)),
      ]),
      const SizedBox(height: 4),
      Row(children: [
        for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
          Expanded(child: Text(d, textAlign: TextAlign.center, style: const TextStyle(color: Brand.slate400, fontSize: 12, fontWeight: FontWeight.w600))),
      ]),
      const SizedBox(height: 6),
      AnimatedOpacity(
        opacity: loading ? 0.5 : 1,
        duration: const Duration(milliseconds: 150),
        child: GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            for (var i = 0; i < leading; i++) const SizedBox.shrink(),
            for (var d = 1; d <= daysInMonth; d++) _day(DateTime(month.year, month.month, d)),
          ],
        ),
      ),
      const SizedBox(height: 10),
      const Wrap(spacing: 14, runSpacing: 6, children: [
        _Legend(color: Brand.b100, label: 'Free'),
        _Legend(color: Color(0xFFFEF3C7), label: 'Some hours free'),
        _Legend(color: Color(0xFFF1F5F9), label: 'Not available'),
      ]),
    ]);
  }

  Widget _day(DateTime day) {
    final status = days[isoDay(day)] ?? 'unavailable';
    final selectable = status == 'available' || status == 'partial';
    final isSelected = selected != null && isoDay(selected!) == isoDay(day);
    final bg = isSelected
        ? Brand.b600
        : switch (status) {
            'available' => Brand.b50,
            'partial' => const Color(0xFFFFFBEB),
            _ => Colors.transparent,
          };
    final fg = isSelected ? Colors.white : (selectable ? Brand.ink : Brand.slate400);
    return Semantics(
      button: selectable,
      selected: isSelected,
      label: '${dayLabel(day)}, ${status == 'partial' ? 'some hours free' : status}',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: selectable ? () => onSelect(day) : null,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Text('${day.day}',
              style: TextStyle(
                color: fg,
                fontWeight: isSelected || selectable ? FontWeight.w600 : FontWeight.w400,
                decoration: selectable || isSelected ? null : TextDecoration.lineThrough,
                decorationColor: Brand.slate400,
              )),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3), border: Border.all(color: Brand.line))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Brand.slate600)),
      ]);
}
