import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../core/api.dart';
import '../core/config.dart';
import '../core/theme.dart';

/// "NearBnB" in the website's style: Near in ink, BnB in brand teal.
class Logo extends StatelessWidget {
  const Logo({super.key, this.size = 26, this.light = false});
  final double size;
  final bool light;
  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          TextSpan(text: 'Near', style: TextStyle(color: light ? Colors.white : Brand.ink)),
          TextSpan(text: 'BnB', style: TextStyle(color: light ? Brand.b300 : Brand.b600)),
        ]),
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, letterSpacing: -0.8),
      );
}

/// A photo from the API, with a soft placeholder while it loads and a calm fallback when there is none.
class NetImage extends StatelessWidget {
  const NetImage(this.path, {super.key, this.fit = BoxFit.cover, this.radius = 0});
  final String? path;
  final BoxFit fit;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final url = AppConfig.media(path);
    final fallback = Container(
      color: Brand.b50,
      alignment: Alignment.center,
      child: const Icon(Icons.home_work_outlined, color: Brand.b300, size: 40),
    );
    final image = url == null
        ? fallback
        : CachedNetworkImage(
            imageUrl: url,
            fit: fit,
            fadeInDuration: const Duration(milliseconds: 200),
            placeholder: (_, __) => const Skeleton(),
            errorWidget: (_, __, ___) => fallback,
          );
    return radius == 0 ? image : ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
  }
}

/// A grey shimmering block shown while something loads.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.height, this.width, this.radius = 0});
  final double? height;
  final double? width;
  final double radius;
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: const Color(0xFFE9EEF3),
        highlightColor: const Color(0xFFF6F8FA),
        child: Container(
          height: height,
          width: width,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius)),
        ),
      );
}

/// Loading placeholder shaped like a list of property cards.
class CardListSkeleton extends StatelessWidget {
  const CardListSkeleton({super.key, this.count = 3});
  final int count;
  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 24),
        itemBuilder: (_, __) => const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(aspectRatio: 4 / 3, child: Skeleton(radius: 18)),
          SizedBox(height: 12),
          Skeleton(height: 16, width: 200, radius: 6),
          SizedBox(height: 8),
          Skeleton(height: 14, width: 140, radius: 6),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(color: Brand.b50, shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: Brand.b600),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, textAlign: TextAlign.center, style: const TextStyle(color: Brand.slate600)),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ]),
        ),
      );
}

/// Shown when loading failed: the API's own message, and a way to try again.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final e = ApiException.from(error);
    return EmptyState(
      icon: e.isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      title: e.isNetwork ? 'You are offline' : 'Something went wrong',
      message: e.message,
      action: onRetry == null ? null : OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
    );
  }
}

/// A full-width button that shows a spinner and ignores taps while its action runs.
class BusyButton extends StatefulWidget {
  const BusyButton({super.key, required this.label, required this.onPressed, this.outlined = false, this.danger = false});
  final String label;
  final Future<void> Function()? onPressed;
  final bool outlined;
  final bool danger;
  @override
  State<BusyButton> createState() => _BusyButtonState();
}

class _BusyButtonState extends State<BusyButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.onPressed == null || _busy ? null : _run;
    final child = _busy
        ? SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: widget.outlined ? Brand.b600 : Colors.white),
          )
        : Text(widget.label);
    if (widget.outlined) return OutlinedButton(onPressed: onTap, child: child);
    return FilledButton(
      onPressed: onTap,
      style: widget.danger ? FilledButton.styleFrom(backgroundColor: Brand.danger) : null,
      child: child,
    );
  }
}

/// A red box above a form with the API's message (kept near the button, like the website).
class FormMessage extends StatelessWidget {
  const FormMessage(this.message, {super.key, this.success = false});
  final String? message;
  final bool success;
  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    final color = success ? Brand.success : Brand.danger;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(success ? Icons.check_circle_outline : Icons.error_outline, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message!, style: TextStyle(color: color, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.average, required this.count, this.compact = false});
  final double average;
  final int count;
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.star_rounded, size: 18, color: Brand.amber),
        const SizedBox(width: 2),
        Text(average.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w600)),
        if (!compact) Text(' ($count)', style: const TextStyle(color: Brand.slate600)),
      ]);
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Simple email check: the server does the real validation.
String? validateEmail(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'Enter your email';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) return 'Enter a valid email';
  return null;
}

String? requiredField(String? v, String what) => (v ?? '').trim().isEmpty ? 'Enter $what' : null;
