import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/month_calendar.dart';
import '../../widgets/price_breakdown.dart';
import '../explore/search_sheet.dart' show CountStepper;
import '../trips/trips_screen.dart' show tripsProvider;
import 'property_screen.dart';

/// Choose a check-in day, time, nights and guests for one room, see the price straight away, then send a request.
/// Nothing is charged here: the host replies first, payment comes after (see the trip screen).
class BookScreen extends ConsumerWidget {
  const BookScreen({super.key, required this.params});
  final Map<String, String> params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertyId = params['property'] ?? '';
    final property = ref.watch(propertyProvider(propertyId));
    return property.when(
      loading: () => Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: ErrorView(error: e, onRetry: () => ref.invalidate(propertyProvider(propertyId)))),
      data: (p) {
        final unit = p.units.where((u) => u.id == params['unit']).firstOrNull ?? p.units.firstOrNull;
        if (unit == null) return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.event_busy_rounded, title: 'This place is not taking bookings'));
        return _Booker(property: p, unit: unit, params: params);
      },
    );
  }
}

class _Booker extends ConsumerStatefulWidget {
  const _Booker({required this.property, required this.unit, required this.params});
  final Property property;
  final Unit unit;
  final Map<String, String> params;
  @override
  ConsumerState<_Booker> createState() => _BookerState();
}

class _BookerState extends ConsumerState<_Booker> {
  late DateTime? _date = DateTime.tryParse(widget.params['date'] ?? '');
  late DateTime _month = DateTime((_date ?? DateTime.now()).year, (_date ?? DateTime.now()).month);
  late String _time = widget.params['time'] ?? '14:00';
  late int _nights = int.tryParse(widget.params['nights'] ?? '') ?? 1;
  late int _guests = (int.tryParse(widget.params['guests'] ?? '') ?? 2).clamp(1, widget.unit.capacity);

  Map<String, String> _days = {};
  bool _calendarLoading = false;
  Quote? _quote;
  bool _quoting = false;
  String? _error;
  int _quoteSeq = 0;

  Unit get u => widget.unit;
  bool get _fixed => u.isFixed && u.fixedCheckin != null && u.fixedCheckout != null;
  List<String> get _times => _fixed ? [u.fixedCheckin!] : timeOptions(u.rules.intervalMinutes, u.checkinFrom, u.checkinTo);
  String get _effectiveTime => _times.contains(_time) ? _time : (_times.firstOrNull ?? '14:00');
  Api get _api => ref.read(apiProvider);

  @override
  void initState() {
    super.initState();
    _loadMonth();
    _requote();
  }

  Future<void> _loadMonth() async {
    setState(() => _calendarLoading = true);
    final m = '${_month.year}-${_month.month.toString().padLeft(2, '0')}';
    try {
      final res = CalendarMonth.fromJson(await _api.get<Map<String, dynamic>>('/units/${u.id}/availability/calendar', query: {'month': m}));
      if (mounted) setState(() => _days = res.days);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _calendarLoading = false);
    }
  }

  /// Asks for the price and availability of the current choice. Only the newest answer is shown.
  Future<void> _requote() async {
    if (_date == null) return;
    final seq = ++_quoteSeq;
    setState(() {
      _quoting = true;
      _error = null;
    });
    try {
      final q = Quote.fromJson(await _api.post<Map<String, dynamic>>('/units/${u.id}/quote', body: {
        'checkin_local': '${isoDay(_date!)}T$_effectiveTime',
        'hours': _nights * u.rules.stepHours,
        'guests': _guests,
      }));
      if (seq == _quoteSeq && mounted) setState(() => _quote = q);
    } on ApiException catch (e) {
      if (seq == _quoteSeq && mounted) setState(() => _error = e.message);
    } finally {
      if (seq == _quoteSeq && mounted) setState(() => _quoting = false);
    }
  }

  void _change(VoidCallback f) {
    setState(f);
    _requote();
  }

  void _pickAlternative(Alternative a) {
    final d = DateTime.tryParse(a.checkinLocal);
    if (d == null) return;
    final otherMonth = d.month != _month.month || d.year != _month.year;
    _change(() {
      _date = DateTime(d.year, d.month, d.day);
      if (a.checkinLocal.length >= 16) _time = a.checkinLocal.substring(11, 16);
      if (otherMonth) _month = DateTime(d.year, d.month);
    });
    if (otherMonth) unawaited(_loadMonth());
  }

  String _selfLink() => Uri(path: '/book', queryParameters: {
        'property': widget.property.id,
        'unit': u.id,
        if (_date != null) 'date': isoDay(_date!),
        'time': _effectiveTime,
        'nights': '$_nights',
        'guests': '$_guests',
      }).toString();

  Future<void> _request() async {
    if (ref.read(authProvider).valueOrNull == null) {
      context.push('/login?from=${Uri.encodeComponent(_selfLink())}');
      return;
    }
    final booked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ConfirmSheet(property: widget.property, unit: u, quote: _quote!, date: _date!, time: _effectiveTime, nights: _nights, guests: _guests),
    );
    if (booked != null && mounted) {
      ref.invalidate(tripsProvider);
      context.go('/trips');
      context.push('/trips/$booked');
    } else if (mounted) {
      _loadMonth();
      _requote(); // the dates may have just been taken: show the fresh answer
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = u.rules;
    final now = DateTime.now();
    final q = _quote;
    final available = _date != null && q != null && q.available && !_quoting;
    return Scaffold(
      appBar: AppBar(title: Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
        Text(widget.property.name, style: const TextStyle(color: Brand.slate600)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: MonthCalendar(
              month: _month,
              days: _days,
              selected: _date,
              loading: _calendarLoading,
              canGoBack: _month.isAfter(DateTime(now.year, now.month)),
              onMonthChange: (m) {
                setState(() => _month = m);
                _loadMonth();
              },
              onSelect: (d) => _change(() => _date = d),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_fixed)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Brand.b50, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.schedule_rounded, color: Brand.b700),
              const SizedBox(width: 10),
              Expanded(child: Text('Check in ${timeLabel(u.fixedCheckin!)} · check out ${timeLabel(u.fixedCheckout!)}', style: const TextStyle(fontWeight: FontWeight.w600))),
            ]),
          )
        else
          DropdownButtonFormField<String>(
            key: ValueKey(_effectiveTime), // picking a suggested time from outside must show in the field
            initialValue: _effectiveTime,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Check-in time', prefixIcon: Icon(Icons.schedule_rounded)),
            items: [for (final t in _times) DropdownMenuItem(value: t, child: Text(timeLabel(t)))],
            onChanged: (t) => _change(() => _time = t ?? _time),
          ),
        const SizedBox(height: 20),
        CountStepper(
          label: _fixed ? 'Nights' : 'Stay',
          hint: _fixed ? null : '${_nights * meta.stepHours} hours',
          value: _nights,
          min: 1,
          max: meta.maxNights,
          onChanged: (v) => _change(() => _nights = v),
        ),
        const Divider(height: 32),
        CountStepper(label: 'Guests', hint: 'Up to ${u.capacity}', value: _guests, min: 1, max: u.capacity, onChanged: (v) => _change(() => _guests = v)),
        const SizedBox(height: 24),
        _answer(),
        const SizedBox(height: 8),
        Text('Times are local to the property (${widget.property.timezone.replaceAll('_', ' ')}).',
            style: const TextStyle(color: Brand.slate600, fontSize: 12.5)),
      ]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Brand.line))),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
        child: Row(children: [
          Expanded(
            child: available && q.price != null
                ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(money(q.price!.total, q.currency ?? u.currency), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Text('total · ${plural(_nights, 'night')}', style: const TextStyle(color: Brand.slate600, fontSize: 13)),
                  ])
                : Text(_date == null ? 'Choose a day' : (_quoting ? 'Checking…' : 'Not available'), style: const TextStyle(color: Brand.slate600)),
          ),
          SizedBox(width: 170, child: FilledButton(onPressed: available ? _request : null, child: const Text('Request to book'))),
        ]),
      ),
    );
  }

  Widget _answer() {
    final q = _quote;
    if (_error != null) return FormMessage(_error);
    if (_date == null) {
      return const Text('Choose a check-in day to see if it is free and what it costs.', style: TextStyle(color: Brand.slate600));
    }
    if (q == null) return const Skeleton(height: 120, radius: 14);
    final cur = q.currency ?? u.currency;
    return AnimatedOpacity(
      opacity: _quoting ? 0.5 : 1,
      duration: const Duration(milliseconds: 150),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: q.available
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.check_circle_rounded, color: Brand.success, size: 20),
                    SizedBox(width: 6),
                    Text('Available', style: TextStyle(color: Brand.success, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 8),
                  Text('Check in ${q.checkinLabel ?? ''}\nCheck out ${q.checkoutLabel ?? ''}', style: const TextStyle(height: 1.5)),
                  if (q.price != null) ...[const SizedBox(height: 12), PriceBreakdownView(price: q.price!, currency: cur)],
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.event_busy_rounded, color: Brand.danger, size: 20),
                    SizedBox(width: 6),
                    Text('Not available', style: TextStyle(color: Brand.danger, fontWeight: FontWeight.w700)),
                  ]),
                  if (q.message != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(q.message!)),
                  if (q.alternatives.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(_fixed ? 'Other dates that work:' : 'Other times that work:', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final a in q.alternatives)
                        ActionChip(
                          label: Text(a.label.isNotEmpty ? a.label : localLabel(a.checkinLocal)),
                          onPressed: () => _pickAlternative(a),
                        ),
                    ]),
                  ],
                ]),
        ),
      ),
    );
  }
}

/// "Send your request": what will happen, the profile check, and the button.
class _ConfirmSheet extends ConsumerStatefulWidget {
  const _ConfirmSheet({required this.property, required this.unit, required this.quote, required this.date, required this.time, required this.nights, required this.guests});
  final Property property;
  final Unit unit;
  final Quote quote;
  final DateTime date;
  final String time;
  final int nights;
  final int guests;
  @override
  ConsumerState<_ConfirmSheet> createState() => _ConfirmSheetState();
}

class _ConfirmSheetState extends ConsumerState<_ConfirmSheet> {
  Readiness? _ready;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final r = Readiness.fromJson(await ref.read(apiProvider).get<Map<String, dynamic>>('/me/booking-readiness'));
      if (mounted) setState(() => _ready = r);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _send() async {
    setState(() => _error = null);
    try {
      final booking = await ref.read(apiProvider).post<Map<String, dynamic>>('/units/${widget.unit.id}/book', body: {
        'checkin_local': '${isoDay(widget.date)}T${widget.time}',
        'hours': widget.nights * widget.unit.rules.stepHours,
        'guests': widget.guests,
      });
      if (mounted) Navigator.pop(context, '${booking['id']}');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quote;
    final r = _ready;
    final minutes = q.responseMinutes;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Send your request', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _line(Icons.home_outlined, '${widget.property.name} · ${widget.unit.name}'),
        _line(Icons.login_rounded, 'Check in ${q.checkinLabel ?? ''}'),
        _line(Icons.logout_rounded, 'Check out ${q.checkoutLabel ?? ''}'),
        _line(Icons.people_outline_rounded, plural(widget.guests, 'guest')),
        if (q.price != null) _line(Icons.receipt_long_outlined, 'Total ${money(q.price!.total, q.currency ?? widget.unit.currency)}'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Brand.b50, borderRadius: BorderRadius.circular(14)),
          child: Text(
            'You are not charged now. The host has ${minutes != null ? timeLeft(minutes * 60) : 'a short time'} to accept. '
            'If they accept, we will let you know and you will have a short time to pay.',
            style: const TextStyle(height: 1.45),
          ),
        ),
        const SizedBox(height: 16),
        FormMessage(_error),
        if (r == null && _error == null) const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
        if (r != null && !r.ready) ...[
          FormMessage('Before you can request a booking, please add: ${r.missing.map((m) => m.label).join(', ')}.'),
          OutlinedButton(
            onPressed: () async {
              await context.push('/profile/edit');
              setState(() => _ready = null);
              _check();
            },
            child: const Text('Complete my profile'),
          ),
        ],
        if (r != null && r.ready) BusyButton(label: 'Send request', onPressed: _send),
      ]),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 20, color: Brand.slate600),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ]),
      );
}
