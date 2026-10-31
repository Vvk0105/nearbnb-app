import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'common.dart';

/// What a tab that needs an account shows to someone signed out (instead of throwing them to a login page).
class SignInPrompt extends StatelessWidget {
  const SignInPrompt({super.key, required this.icon, required this.title, required this.message, required this.from});
  final IconData icon;
  final String title;
  final String message;
  final String from;
  @override
  Widget build(BuildContext context) => EmptyState(
        icon: icon,
        title: title,
        message: message,
        action: SizedBox(
          width: 220,
          child: FilledButton(onPressed: () => context.push('/login?from=${Uri.encodeComponent(from)}'), child: const Text('Sign in')),
        ),
      );
}
