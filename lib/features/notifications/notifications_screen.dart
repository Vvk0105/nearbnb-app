import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/push.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/sign_in_prompt.dart';

/// The number on the Alerts tab. Checked every minute while the app is open, and at once when a push arrives.
final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final timer = Timer(const Duration(seconds: 60), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  if (ref.watch(authProvider).valueOrNull == null) return 0;
  final j = await ref.watch(apiProvider).get<Map<String, dynamic>>('/me/notifications/unread-count');
  return (j['unread'] as num?)?.toInt() ?? 0;
});

final noticesProvider = FutureProvider.autoDispose<NoticeList>((ref) async =>
    NoticeList.fromJson(await ref.watch(apiProvider).get<Map<String, dynamic>>('/me/notifications', query: {'page_size': 50})));

/// The same list as the bell on the website.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  Future<void> _open(WidgetRef ref, Notice n) async {
    if (!n.read) {
      await ref.read(apiProvider).post('/me/notifications/${n.id}/read').catchError((_) => <String, dynamic>{});
      ref.invalidate(noticesProvider);
      ref.invalidate(unreadCountProvider);
    }
    ref.read(pushProvider).open(n.link);
  }

  Future<void> _readAll(WidgetRef ref) async {
    await ref.read(apiProvider).post('/me/notifications/read-all').catchError((_) => <String, dynamic>{});
    ref.invalidate(noticesProvider);
    ref.invalidate(unreadCountProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authProvider).valueOrNull != null;
    if (!signedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Alerts')),
        body: const SignInPrompt(
          icon: Icons.notifications_rounded,
          title: 'Stay in the loop',
          message: 'Sign in to hear when a host replies, when to pay and when your stay is near.',
          from: '/notifications',
        ),
      );
    }
    final list = ref.watch(noticesProvider);
    final unread = list.valueOrNull?.unread ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [if (unread > 0) TextButton(onPressed: () => _readAll(ref), child: const Text('Mark all read'))],
      ),
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(unreadCountProvider);
          return ref.refresh(noticesProvider.future);
        },
        child: list.when(
          loading: () => ListView(children: [for (var i = 0; i < 6; i++) const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: Skeleton(height: 64, radius: 14))]),
          error: (e, _) => ListView(children: [ErrorView(error: e, onRetry: () => ref.invalidate(noticesProvider))]),
          data: (l) => l.items.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 60),
                  EmptyState(icon: Icons.notifications_none_rounded, title: 'Nothing yet', message: 'Updates about your requests and trips will appear here.'),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: l.items.length,
                  separatorBuilder: (_, __) => const Divider(indent: 72),
                  itemBuilder: (_, i) => _NoticeTile(notice: l.items[i], onTap: () => _open(ref, l.items[i])),
                ),
        ),
      ),
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({required this.notice, required this.onTap});
  final Notice notice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notice;
    final (icon, color) = switch (n.tone) {
      'action' => (Icons.priority_high_rounded, Brand.amber),
      'problem' => (Icons.error_outline_rounded, Brand.danger),
      _ => (Icons.notifications_none_rounded, Brand.b600),
    };
    return InkWell(
      onTap: onTap,
      child: Container(
        color: n.read ? null : Brand.b50.withValues(alpha: 0.6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 20, backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.w700)),
              if (n.body.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Brand.slate600))),
              const SizedBox(height: 4),
              Text(_when(n.createdAt), style: const TextStyle(color: Brand.slate400, fontSize: 12)),
            ]),
          ),
          if (!n.read) const Padding(padding: EdgeInsets.only(top: 6, left: 8), child: CircleAvatar(radius: 4, backgroundColor: Brand.b600)),
        ]),
      ),
    );
  }

  static String _when(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    if (d.inDays < 7) return '${d.inDays} d ago';
    return DateFormat('d MMM yyyy').format(t);
  }
}
