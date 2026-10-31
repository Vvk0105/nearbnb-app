import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/price_breakdown.dart';
import '../../widgets/status_badge.dart';
import 'trips_screen.dart';

final tripProvider = FutureProvider.autoDispose.family<Booking, String>((ref, id) async =>
    Booking.fromJson(await ref.watch(apiProvider).get<Map<String, dynamic>>('/me/bookings/$id')));

/// One trip: where it stands, what it costs, and what the guest can do next (pay, withdraw, cancel, review, report a problem).
class TripScreen extends ConsumerWidget {
  const TripScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(tripProvider(bookingId));
    return Scaffold(
      appBar: AppBar(title: Text(trip.valueOrNull?.reference ?? 'Trip')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(tripProvider(bookingId).future),
        child: trip.when(
          loading: () => const CardListSkeleton(count: 1),
          error: (e, _) => ListView(children: [ErrorView(error: e, onRetry: () => ref.invalidate(tripProvider(bookingId)))]),
          data: (b) => _TripView(booking: b),
        ),
      ),
    );
  }
}

class _TripView extends ConsumerWidget {
  const _TripView({required this.booking});
  final Booking booking;

  void _refresh(WidgetRef ref) {
    ref.invalidate(tripProvider(booking.id));
    ref.invalidate(tripsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = booking;
    final t = Theme.of(context).textTheme;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
      InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/property/${b.propertyId}'),
        child: Row(children: [
          SizedBox(width: 72, height: 72, child: NetImage(b.coverUrl, radius: 14)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.propertyName, style: t.titleMedium),
              Text([b.unitName, b.place].where((s) => s.isNotEmpty).join(' · '), style: const TextStyle(color: Brand.slate600)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      _StatusCard(booking: b),
      const SizedBox(height: 16),
      _Section(title: 'Your stay', children: [
        _Row(Icons.login_rounded, 'Check in', b.checkInLabel),
        _Row(Icons.logout_rounded, 'Check out', b.checkOutLabel),
        _Row(Icons.people_outline_rounded, 'Guests', '${b.guests}'),
        _Row(Icons.confirmation_number_outlined, 'Reference', b.reference),
      ]),
      if (b.price != null) ...[
        const SizedBox(height: 16),
        _Section(title: 'Price', children: [PriceBreakdownView(price: b.price!, currency: b.currency)]),
      ],
      if (b.hostEmail != null || b.hostPhone != null || (b.checkinInstructions ?? '').isNotEmpty) ...[
        const SizedBox(height: 16),
        _Section(title: 'Your host', children: [
          if (b.hostName != null) _Row(Icons.person_outline_rounded, 'Name', b.hostName!),
          if (b.hostPhone != null)
            _Row(Icons.phone_outlined, 'Phone', b.hostPhone!, onTap: () => launchUrl(Uri.parse('tel:${b.hostPhone}'))),
          if (b.hostEmail != null)
            _Row(Icons.mail_outline_rounded, 'Email', b.hostEmail!, onTap: () => launchUrl(Uri.parse('mailto:${b.hostEmail}'))),
          if ((b.checkinInstructions ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Check-in instructions', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(b.checkinInstructions!, style: const TextStyle(height: 1.45)),
          ],
        ]),
      ],
      if (b.issues.isNotEmpty) ...[
        const SizedBox(height: 16),
        _Section(title: 'Problems you reported', children: [
          for (final i in b.issues)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${_issueLabel(i.category)} · ${i.status.replaceAll('_', ' ')}', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(i.body, maxLines: 3, overflow: TextOverflow.ellipsis),
                if (i.resolution != null) Text('Our reply: ${i.resolution}', style: const TextStyle(color: Brand.b800)),
              ]),
            ),
        ]),
      ],
      const SizedBox(height: 24),
      ..._actions(context, ref),
    ]);
  }

  List<Widget> _actions(BuildContext context, WidgetRef ref) {
    final b = booking;
    final out = <Widget>[];
    void add(Widget w) => out.addAll([w, const SizedBox(height: 10)]);
    if (b.canPay) add(BusyButton(label: 'Pay ${money(b.total, b.currency)}', onPressed: () => _pay(context, ref)));
    if (b.review?.canReview == true) add(BusyButton(label: 'Write a review', onPressed: () => _review(context, ref)));
    if (b.canWithdraw) add(BusyButton(label: 'Withdraw request', outlined: true, onPressed: () => _withdraw(context, ref)));
    if (b.status == 'confirmed') add(BusyButton(label: 'Cancel booking', outlined: true, onPressed: () => _cancel(context, ref)));
    if (b.canReportIssue) add(TextButton.icon(onPressed: () => _report(context, ref), icon: const Icon(Icons.flag_outlined), label: const Text('Report a problem')));
    return out;
  }

  // ---------- paying ----------

  Future<void> _pay(BuildContext context, WidgetRef ref) async {
    final api = ref.read(apiProvider);
    try {
      final start = PayStart.fromJson(await api.post<Map<String, dynamic>>('/me/bookings/${booking.id}/pay'));
      if (start.fake) {
        // The server runs without Stripe (development only): pretend the card went through.
        if (!context.mounted) return;
        final ok = await _confirm(context, 'Test payment', 'This server has no Stripe keys, so no card is needed. Mark the booking as paid?', 'Mark as paid');
        if (!ok) return;
        await api.post('/me/bookings/${booking.id}/pay/dev-complete');
      } else {
        if (start.publishableKey == null || start.clientSecret == null) throw ApiException(500, 'NO_PAYMENT', 'Payments are not set up yet. Please try later.');
        Stripe.publishableKey = start.publishableKey!;
        await Stripe.instance.applySettings();
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: start.clientSecret,
            merchantDisplayName: 'NearBnB',
            style: ThemeMode.light,
            appearance: const PaymentSheetAppearance(colors: PaymentSheetAppearanceColors(primary: Brand.b600)),
          ),
        );
        await Stripe.instance.presentPaymentSheet();
        // Stripe has the card. Ask our server, which asks Stripe, so the booking is confirmed straight away (the webhook also does it).
        await api.post('/me/bookings/${booking.id}/pay/sync');
      }
      if (context.mounted) showMessage(context, 'Payment received. Your booking is confirmed.');
    } on StripeException catch (e) {
      if (e.error.code != FailureCode.Canceled && context.mounted) {
        showMessage(context, e.error.localizedMessage ?? 'The payment did not go through. Please try another card.');
      }
      await api.post('/me/bookings/${booking.id}/pay/sync').catchError((_) => <String, dynamic>{});
    } on ApiException catch (e) {
      if (context.mounted) showMessage(context, e.message);
    } finally {
      _refresh(ref);
    }
  }

  // ---------- withdrawing and cancelling ----------

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    if (!await _confirm(context, 'Withdraw this request?', 'The host will be told, and the dates are released. Nothing has been charged.', 'Withdraw')) return;
    try {
      await ref.read(apiProvider).post('/me/bookings/${booking.id}/withdraw');
      if (context.mounted) showMessage(context, 'Request withdrawn.');
    } on ApiException catch (e) {
      if (context.mounted) showMessage(context, e.message);
    }
    _refresh(ref);
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final api = ref.read(apiProvider);
    try {
      final preview = CancelPreview.fromJson(await api.get<Map<String, dynamic>>('/me/bookings/${booking.id}/cancel-preview'));
      if (!context.mounted) return;
      final refund = preview.refundTotal > 0
          ? 'You will get ${money(preview.refundTotal, preview.currency)} back (${preview.refundPct}% under the ${preview.policyName} policy). Refunds take a few days to reach your card.'
          : 'Under the ${preview.policyName} policy, no money is refunded if you cancel now.';
      if (!await _confirm(context, 'Cancel this booking?', refund, 'Cancel booking', danger: true)) return;
      await api.post('/me/bookings/${booking.id}/cancel', body: {'expected_refund': preview.refundTotal});
      if (context.mounted) showMessage(context, 'Booking cancelled.');
    } on ApiException catch (e) {
      if (context.mounted) showMessage(context, e.message); // e.g. the refund changed meanwhile: the guest sees the new amount next time
    }
    _refresh(ref);
  }

  // ---------- review and problems ----------

  Future<void> _review(BuildContext context, WidgetRef ref) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReviewSheet(bookingId: booking.id),
    );
    if (sent == true) {
      if (context.mounted) showMessage(context, 'Thanks! Reviews appear once both of you have written one, or when the review time ends.');
      _refresh(ref);
    }
  }

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _IssueSheet(bookingId: booking.id),
    );
    if (sent == true) {
      if (context.mounted) showMessage(context, 'Thanks for telling us. Our team will look into it and reply by email.');
      _refresh(ref);
    }
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.booking});
  final Booking booking;
  @override
  Widget build(BuildContext context) {
    final b = booking;
    final message = switch (b.status) {
      'requested' => 'The host has ${b.secondsToRespond != null ? timeLeft(b.secondsToRespond) : 'a short time'} to reply. You have not been charged.',
      'accepted' || 'payment_pending' when b.canPay =>
        'Good news: the host accepted. Pay ${b.secondsToPay != null ? 'within ${timeLeft(b.secondsToPay)}' : 'soon'} to confirm your stay.',
      'payment_pending' => 'We are checking your payment with the bank.',
      'confirmed' => 'You are all set. The host\'s details and check-in instructions are below.',
      'checked_in' => 'Enjoy your stay!',
      'completed' => b.review?.canReview == true ? 'How was it? Leave a review while the review time is open.' : 'Thanks for staying with NearBnB.',
      'rejected' => b.closedReason == null ? 'The host could not take this booking.' : 'The host said: ${b.closedReason}',
      'expired' => 'The host did not reply in time, so the request closed. You were not charged.',
      'payment_expired' => 'The time to pay ran out, so the dates were released.',
      'withdrawn' => 'You withdrew this request.',
      'cancelled' => switch (b.refundState) {
          'pending' => 'Cancelled. Your refund is on its way.',
          'refunded' => 'Cancelled. Your refund has been sent.',
          'failed' => 'Cancelled. There was a problem with the refund: our team has been told.',
          _ => b.cancelledBy == 'guest' ? 'You cancelled this booking.' : 'This booking was cancelled.${b.closedReason != null ? ' ${b.closedReason}' : ''}',
        },
      _ => '',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Brand.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        StatusBadge(b.status),
        if (message.isNotEmpty) ...[const SizedBox(height: 10), Text(message, style: const TextStyle(height: 1.45))],
        if (b.paymentFailure != null && b.canPay) ...[const SizedBox(height: 10), FormMessage('Last attempt: ${b.paymentFailure}')],
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Brand.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ...children,
        ]),
      );
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.label, this.value, {this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20, color: Brand.slate600),
            const SizedBox(width: 12),
            SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Brand.slate600))),
            Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.w500, color: onTap != null ? Brand.b700 : Brand.ink))),
          ]),
        ),
      );
}

Future<bool> _confirm(BuildContext context, String title, String message, String action, {bool danger = false}) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('Keep it')),
          FilledButton(
            style: danger ? FilledButton.styleFrom(backgroundColor: Brand.danger, minimumSize: const Size(0, 44)) : FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

const _issueCategories = {
  'property_condition': 'Condition of the place',
  'not_as_described': 'Not as described',
  'host_behaviour': 'The host',
  'safety': 'Safety',
  'payment_or_refund': 'Payment or refund',
  'other': 'Something else',
};

String _issueLabel(String key) => _issueCategories[key] ?? key.replaceAll('_', ' ');

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({required this.bookingId});
  final String bookingId;
  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  int _rating = 0;
  final _comment = TextEditingController();
  String? _error;

  Future<void> _send() async {
    if (_rating == 0) {
      setState(() => _error = 'Tap the stars to choose a rating.');
      return;
    }
    try {
      await ref.read(apiProvider).post('/me/bookings/${widget.bookingId}/review', body: {'rating': _rating, 'comment': _comment.text.trim()});
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('How was your stay?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Reviews are blind: yours and the host\'s appear together.', style: TextStyle(color: Brand.slate600)),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                tooltip: '$i star${i == 1 ? '' : 's'}',
                iconSize: 40,
                onPressed: () => setState(() => _rating = i),
                icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, color: Brand.amber),
              ),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _comment, maxLines: 4, maxLength: 2000, decoration: const InputDecoration(hintText: 'What should other guests know? (optional)')),
          FormMessage(_error),
          BusyButton(label: 'Send review', onPressed: _send),
        ]),
      );
}

class _IssueSheet extends ConsumerStatefulWidget {
  const _IssueSheet({required this.bookingId});
  final String bookingId;
  @override
  ConsumerState<_IssueSheet> createState() => _IssueSheetState();
}

class _IssueSheetState extends ConsumerState<_IssueSheet> {
  String? _category;
  final _body = TextEditingController();
  String? _error;

  Future<void> _send() async {
    if (_category == null) {
      setState(() => _error = 'Choose what the problem is about.');
      return;
    }
    if (_body.text.trim().length < 10) {
      setState(() => _error = 'Please describe the problem in a sentence or two.');
      return;
    }
    try {
      await ref.read(apiProvider).post('/me/bookings/${widget.bookingId}/issues', body: {'category': _category, 'body': _body.text.trim()});
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Report a problem', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Our team reads every report and replies by email. In an emergency, call 000.', style: TextStyle(color: Brand.slate600)),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in _issueCategories.entries)
              ChoiceChip(label: Text(e.value), selected: _category == e.key, showCheckmark: false, onSelected: (_) => setState(() => _category = e.key)),
          ]),
          const SizedBox(height: 16),
          TextField(controller: _body, maxLines: 5, maxLength: 3000, decoration: const InputDecoration(hintText: 'What happened?')),
          FormMessage(_error),
          BusyButton(label: 'Send report', onPressed: _send),
        ]),
      );
}
