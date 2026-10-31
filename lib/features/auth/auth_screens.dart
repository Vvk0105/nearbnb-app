import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

/// Where to go after signing in: back to what the person was doing (e.g. the booking they started), or Explore.
String _next(GoRouterState state) => state.uri.queryParameters['from'] ?? '/';

class PasswordField extends StatefulWidget {
  const PasswordField({super.key, required this.controller, this.label = 'Password', this.validator, this.autofill, this.onSubmitted});
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final Iterable<String>? autofill;
  final ValueChanged<String>? onSubmitted;
  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;
  @override
  Widget build(BuildContext context) => TextFormField(
        controller: widget.controller,
        obscureText: _hidden,
        autofillHints: widget.autofill,
        onFieldSubmitted: widget.onSubmitted,
        validator: widget.validator ?? (v) => (v ?? '').isEmpty ? 'Enter your password' : null,
        decoration: InputDecoration(
          labelText: widget.label,
          suffixIcon: IconButton(
            tooltip: _hidden ? 'Show password' : 'Hide password',
            icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _hidden = !_hidden),
          ),
        ),
      );
}

/// The same rules as the server (backend/app/core/security.py), so most mistakes show before sending.
String? newPasswordProblem(String? v) {
  final p = v ?? '';
  if (p.length < 10) return 'At least 10 characters';
  if (!(RegExp('[a-z]').hasMatch(p) && RegExp('[A-Z]').hasMatch(p) && RegExp('[0-9]').hasMatch(p))) {
    return 'Use a lowercase letter, an uppercase letter and a number';
  }
  return null;
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, this.subtitle, required this.children});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle!, style: const TextStyle(color: Brand.slate600, fontSize: 15)),
              ],
              const SizedBox(height: 28),
              ...children,
            ],
          ),
        ),
      );
}

// ---------- sign in ----------

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, required this.state});
  final GoRouterState state;
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _error = null);
    try {
      await ref.read(authProvider.notifier).login(_email.text, _password.text);
      if (mounted) context.go(_next(widget.state));
    } on ApiException catch (e) {
      if (e.code == 'EMAIL_NOT_VERIFIED' && mounted) {
        await ref.read(authProvider.notifier).resendCode(_email.text).catchError((_) {});
        if (mounted) context.push('/verify?email=${Uri.encodeComponent(_email.text.trim())}&from=${Uri.encodeComponent(_next(widget.state))}');
        return;
      }
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        title: 'Welcome back',
        subtitle: 'Sign in to book, pay and see your trips.',
        children: [
          Form(
            key: _form,
            child: AutofillGroup(
              child: Column(children: [
                FormMessage(_error),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: validateEmail,
                ),
                const SizedBox(height: 14),
                PasswordField(controller: _password, autofill: const [AutofillHints.password], onSubmitted: (_) => _submit()),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: () => context.push('/forgot-password'), child: const Text('Forgot password?')),
                ),
                const SizedBox(height: 8),
                BusyButton(label: 'Sign in', onPressed: _submit),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('New to NearBnB?', style: TextStyle(color: Brand.slate600)),
            TextButton(
              onPressed: () => context.push('/register?from=${Uri.encodeComponent(_next(widget.state))}'),
              child: const Text('Create an account'),
            ),
          ]),
        ],
      );
}

// ---------- sign up ----------

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, required this.state});
  final GoRouterState state;
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _accepted = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_accepted) {
      setState(() => _error = 'Please accept the Terms and the Privacy Policy.');
      return;
    }
    setState(() => _error = null);
    try {
      await ref.read(authProvider.notifier).register(name: _name.text, email: _email.text, password: _password.text);
      if (mounted) context.push('/verify?email=${Uri.encodeComponent(_email.text.trim())}&from=${Uri.encodeComponent(_next(widget.state))}');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final linkStyle = const TextStyle(color: Brand.b700, fontWeight: FontWeight.w600);
    return _AuthScaffold(
      title: 'Create your account',
      subtitle: 'We will email you a code to confirm it is you.',
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(children: [
              FormMessage(_error),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => requiredField(v, 'your name'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
                validator: validateEmail,
              ),
              const SizedBox(height: 14),
              PasswordField(controller: _password, autofill: const [AutofillHints.newPassword], validator: newPasswordProblem),
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('10+ characters with a lowercase letter, an uppercase letter and a number.',
                      style: TextStyle(color: Brand.slate600, fontSize: 12.5)),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _accepted,
                onChanged: (v) => setState(() => _accepted = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text.rich(TextSpan(style: const TextStyle(fontSize: 14), children: [
                  const TextSpan(text: 'I accept the '),
                  TextSpan(text: 'Terms', style: linkStyle, recognizer: TapGestureRecognizer()..onTap = () => _open('terms')),
                  const TextSpan(text: ' and the '),
                  TextSpan(text: 'Privacy Policy', style: linkStyle, recognizer: TapGestureRecognizer()..onTap = () => _open('privacy')),
                ])),
              ),
              const SizedBox(height: 12),
              BusyButton(label: 'Continue', onPressed: _submit),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('Already have an account?', style: TextStyle(color: Brand.slate600)),
          TextButton(onPressed: () => context.pop(), child: const Text('Sign in')),
        ]),
      ],
    );
  }

  void _open(String doc) => launchUrl(Uri.parse('${AppConfig.webOrigin}/legal/$doc'), mode: LaunchMode.inAppBrowserView);
}

// ---------- the emailed code ----------

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.state});
  final GoRouterState state;
  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _code = TextEditingController();
  String? _error;
  String? _info;
  String get _email => widget.state.uri.queryParameters['email'] ?? '';

  Future<void> _submit() async {
    if (_code.text.trim().length != 6) {
      setState(() => _error = 'Enter the 6-digit code from the email.');
      return;
    }
    setState(() {
      _error = null;
      _info = null;
    });
    try {
      await ref.read(authProvider.notifier).verifyEmail(_email, _code.text);
      if (mounted) context.go(_next(widget.state));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _resend() async {
    try {
      await ref.read(authProvider.notifier).resendCode(_email);
      setState(() {
        _error = null;
        _info = 'A new code is on its way.';
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        title: 'Check your email',
        subtitle: 'We sent a 6-digit code to $_email.',
        children: [
          FormMessage(_error),
          FormMessage(_info, success: true),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 28, letterSpacing: 12, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(counterText: '', hintText: '••••••'),
            onChanged: (v) {
              if (v.length == 6) _submit();
            },
          ),
          const SizedBox(height: 20),
          BusyButton(label: 'Confirm', onPressed: _submit),
          const SizedBox(height: 8),
          TextButton(onPressed: _resend, child: const Text('Send a new code')),
        ],
      );
}

// ---------- forgotten password ----------

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _sent = false;
  String? _error;

  Future<void> _send() async {
    if (validateEmail(_email.text) != null) {
      setState(() => _error = validateEmail(_email.text));
      return;
    }
    setState(() => _error = null);
    try {
      await ref.read(authProvider.notifier).forgotPassword(_email.text);
      setState(() => _sent = true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _reset() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _error = null);
    try {
      await ref.read(authProvider.notifier).resetPassword(_email.text, _code.text, _password.text);
      await ref.read(authProvider.notifier).login(_email.text, _password.text);
      if (mounted) context.go('/');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
        title: 'Reset your password',
        subtitle: _sent ? 'If an account uses ${_email.text.trim()}, a code is on its way.' : 'Enter your email and we will send you a code.',
        children: [
          FormMessage(_error),
          if (!_sent) ...[
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 20),
            BusyButton(label: 'Send code', onPressed: _send),
          ] else
            Form(
              key: _form,
              child: Column(children: [
                TextFormField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: '6-digit code', counterText: ''),
                  validator: (v) => (v ?? '').length == 6 ? null : 'Enter the 6-digit code',
                ),
                const SizedBox(height: 14),
                PasswordField(controller: _password, label: 'New password', validator: newPasswordProblem, autofill: const [AutofillHints.newPassword]),
                const SizedBox(height: 20),
                BusyButton(label: 'Save new password', onPressed: _reset),
                TextButton(onPressed: _send, child: const Text('Send a new code')),
              ]),
            ),
        ],
      );
}
