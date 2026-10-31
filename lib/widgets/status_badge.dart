import 'package:flutter/material.dart';

/// Booking status in the guest's words, the same as the website (frontend/src/components/bookings.tsx).
const _labels = <String, (String, Color, Color)>{
  'requested': ('Waiting for host', Color(0xFFFEF3C7), Color(0xFF92400E)),
  'accepted': ('Accepted, payment due', Color(0xFFDBEAFE), Color(0xFF1E40AF)),
  'payment_pending': ('Payment processing', Color(0xFFDBEAFE), Color(0xFF1E40AF)),
  'confirmed': ('Confirmed', Color(0xFFDCFCE7), Color(0xFF166534)),
  'checked_in': ('Checked in', Color(0xFFDCFCE7), Color(0xFF166534)),
  'completed': ('Completed', Color(0xFFF1F5F9), Color(0xFF334155)),
  'rejected': ('Declined', Color(0xFFFEE2E2), Color(0xFF991B1B)),
  'expired': ('Expired', Color(0xFFE2E8F0), Color(0xFF334155)),
  'withdrawn': ('Withdrawn', Color(0xFFE2E8F0), Color(0xFF334155)),
  'payment_expired': ('Payment time ran out', Color(0xFFE2E8F0), Color(0xFF334155)),
  'cancelled': ('Cancelled', Color(0xFFE2E8F0), Color(0xFF334155)),
};

String statusLabel(String status) => _labels[status]?.$1 ?? status;

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final s = _labels[status] ?? (status, const Color(0xFFF1F5F9), const Color(0xFF334155));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: s.$2, borderRadius: BorderRadius.circular(999)),
      child: Text(s.$1, style: TextStyle(color: s.$3, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
