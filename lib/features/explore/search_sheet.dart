import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import 'search_query.dart';

/// Full-screen search: where (with suggestions), check-in day and time, nights, guests.
/// Returns the new SearchQuery, or a property id to open straight away (`property:<id>`).
Future<Object?> openSearchSheet(BuildContext context, SearchQuery current) => Navigator.of(context, rootNavigator: true).push<Object?>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => SearchSheet(initial: current)),
    );

class SearchSheet extends ConsumerStatefulWidget {
  const SearchSheet({super.key, required this.initial});
  final SearchQuery initial;
  @override
  ConsumerState<SearchSheet> createState() => _SearchSheetState();
}

typedef _GooglePlace = ({String placeId, String main, String secondary, String text});

class _SearchSheetState extends ConsumerState<SearchSheet> {
  late SearchQuery _q = widget.initial;
  late final _where = TextEditingController(text: widget.initial.q);
  Timer? _debounce;
  Suggestions? _ours;
  List<_GooglePlace> _google = [];
  bool _picked = false; // the box holds a picked suggestion: do not search again for it
  String _token = _newToken();

  static String _newToken() => List.generate(24, (_) => Random.secure().nextInt(16).toRadixString(16)).join();

  Api get _api => ref.read(apiProvider);

  @override
  void dispose() {
    _debounce?.cancel();
    _where.dispose();
    super.dispose();
  }

  void _typed(String text) {
    _picked = false;
    _q = _q.copyWith(q: text, clearLocation: true);
    _debounce?.cancel();
    if (text.trim().length < 2) {
      setState(() {
        _ours = null;
        _google = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () => _suggest(text.trim()));
  }

  Future<void> _suggest(String text) async {
    try {
      final ours = Suggestions.fromJson(await _api.get<Map<String, dynamic>>('/search/suggest', query: {'q': text}));
      if (!_picked && mounted) setState(() => _ours = ours);
    } on ApiException {
      // our own suggestions failing is never worth a message
    }
    if (text.length < 3) return;
    try {
      final res = await _api.get<Map<String, dynamic>>('/places/autocomplete', query: {'q': text, 'kind': 'region', 'token': _token});
      final list = [
        for (final s in (res['suggestions'] as List? ?? const []).whereType<Map>())
          (placeId: '${s['place_id']}', main: '${s['main']}', secondary: '${s['secondary']}', text: '${s['text']}')
      ];
      if (!_picked && mounted) setState(() => _google = list);
    } on ApiException {
      // Google off or down: typing a place name still works
    }
  }

  void _pickArea(String text, {double? lat, double? lng}) {
    _picked = true;
    _where.text = text;
    setState(() {
      _q = _q.copyWith(q: text, lat: lat, lng: lng, clearLocation: lat == null);
      _ours = null;
      _google = [];
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _pickGoogle(_GooglePlace p) async {
    _pickArea(p.text);
    try {
      final place = await _api.get<Map<String, dynamic>>('/places/details/${Uri.encodeComponent(p.placeId)}', query: {'token': _token});
      setState(() => _q = _q.copyWith(lat: (place['latitude'] as num?)?.toDouble(), lng: (place['longitude'] as num?)?.toDouble()));
    } on ApiException {
      // keep the name: the search still matches by text
    } finally {
      _token = _newToken(); // a Google billing session ends with each pick
    }
  }

  Future<void> _pickDate(BookingMeta meta) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _q.date ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(Duration(days: meta.maxAdvanceDays)),
      helpText: 'Check-in day',
    );
    if (picked != null) setState(() => _q = _q.copyWith(date: picked));
  }

  List<String> _times(BookingMeta meta) {
    final step = meta.intervalMinutes.clamp(15, 240);
    return [for (var m = 0; m < 24 * 60; m += step) '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}'];
  }

  @override
  Widget build(BuildContext context) {
    final meta = ref.watch(bookingMetaProvider).valueOrNull ?? BookingMeta.fallback;
    final hasSuggestions = (_ours?.places.isNotEmpty ?? false) || (_ours?.properties.isNotEmpty ?? false) || _google.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, title: const Text('Search'), leading: const CloseButton()),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 20), children: [
              TextField(
                controller: _where,
                autofocus: widget.initial.q.isEmpty,
                textInputAction: TextInputAction.search,
                onChanged: _typed,
                onSubmitted: (_) => Navigator.pop(context, _q),
                decoration: InputDecoration(
                  hintText: 'Suburb, city, postcode or place name',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _where.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _where.clear();
                            _typed('');
                          }),
                ),
              ),
              if (hasSuggestions) _suggestionList(),
              const SizedBox(height: 24),
              _label('Check-in'),
              Row(children: [
                Expanded(
                  child: _Box(
                    icon: Icons.calendar_today_rounded,
                    text: _q.date == null ? 'Any day' : dayLabel(_q.date!),
                    onTap: () => _pickDate(meta),
                    onClear: _q.date == null ? null : () => setState(() => _q = _q.copyWith(clearDate: true)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_q.time), // a new value from outside rebuilds the field (initialValue is read once)
                    initialValue: _times(meta).contains(_q.time) ? _q.time : null,
                    isExpanded: true,
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.schedule_rounded)),
                    items: [for (final t in _times(meta)) DropdownMenuItem(value: t, child: Text(timeLabel(t)))],
                    onChanged: (t) => setState(() => _q = _q.copyWith(time: t)),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              CountStepper(label: 'Nights', hint: '24 hours each', value: _q.nights, min: 1, max: meta.maxNights, onChanged: (v) => setState(() => _q = _q.copyWith(nights: v))),
              const Divider(height: 32),
              CountStepper(label: 'Guests', value: _q.guests, min: 1, max: 30, onChanged: (v) => setState(() => _q = _q.copyWith(guests: v))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context, _q),
              icon: const Icon(Icons.search_rounded),
              label: const Text('Search'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Brand.slate600)),
      );

  Widget _suggestionList() {
    final tiles = <Widget>[];
    final ours = _ours;
    if ((ours?.places.isNotEmpty ?? false) || _google.isNotEmpty) tiles.add(_header('Places'));
    for (final p in ours?.places ?? const <({String text, int count})>[]) {
      tiles.add(_tile(Icons.place_outlined, p.text, plural(p.count, 'place to stay', 'places to stay'), () => _pickArea(p.text)));
    }
    for (final g in _google) {
      tiles.add(_tile(Icons.location_on_outlined, g.main, g.secondary, () => _pickGoogle(g)));
    }
    if (ours?.properties.isNotEmpty ?? false) tiles.add(_header('Properties'));
    for (final p in ours?.properties ?? const <({String id, String name, String place, String? type})>[]) {
      tiles.add(_tile(Icons.home_outlined, p.name, [p.type, p.place].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
          () => Navigator.pop(context, 'property:${p.id}')));
    }
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(border: Border.all(color: Brand.line), borderRadius: BorderRadius.circular(14)),
      child: Column(children: tiles),
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Brand.slate400)),
        ),
      );

  Widget _tile(IconData icon, String title, String subtitle, VoidCallback onTap) => ListTile(
        dense: true,
        leading: Icon(icon, color: Brand.slate600),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: onTap,
      );
}

class _Box extends StatelessWidget {
  const _Box({required this.icon, required this.text, required this.onTap, this.onClear});
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: InputDecorator(
          decoration: InputDecoration(
            prefixIcon: Icon(icon),
            suffixIcon: onClear == null ? null : IconButton(tooltip: 'Any day', icon: const Icon(Icons.close_rounded, size: 18), onPressed: onClear),
          ),
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      );
}

class CountStepper extends StatelessWidget {
  const CountStepper({super.key, required this.label, this.hint, required this.value, required this.min, required this.max, required this.onChanged});
  final String label;
  final String? hint;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            if (hint != null) Text(hint!, style: const TextStyle(color: Brand.slate600, fontSize: 13)),
          ]),
        ),
        _round(Icons.remove_rounded, value > min ? () => onChanged(value - 1) : null, 'Fewer $label'.toLowerCase()),
        SizedBox(width: 44, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
        _round(Icons.add_rounded, value < max ? () => onChanged(value + 1) : null, 'More $label'.toLowerCase()),
      ]);

  Widget _round(IconData icon, VoidCallback? onTap, String tip) => IconButton.outlined(
        tooltip: tip,
        onPressed: onTap,
        icon: Icon(icon),
        style: IconButton.styleFrom(side: const BorderSide(color: Brand.line)),
      );
}
