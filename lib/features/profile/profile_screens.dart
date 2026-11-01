import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api.dart';
import '../../core/config.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/sign_in_prompt.dart';
import '../auth/auth_screens.dart' show PasswordField, newPasswordProblem;

void _web(String path) => launchUrl(Uri.parse('${AppConfig.webOrigin}$path'), mode: LaunchMode.inAppBrowserView);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: ListView(children: [
          const SizedBox(height: 40),
          const SignInPrompt(icon: Icons.person_rounded, title: 'Welcome to NearBnB', message: 'Sign in or create an account to book stays.', from: '/profile'),
          const SizedBox(height: 24),
          _LegalLinks(),
        ]),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Row(children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Brand.b100,
              foregroundImage: user.photoUrl == null ? null : NetworkImage(AppConfig.media(user.photoUrl)!),
              child: Text(user.fullName.isEmpty ? '?' : user.fullName[0].toUpperCase(), style: const TextStyle(fontSize: 24, color: Brand.b800, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user.fullName, style: Theme.of(context).textTheme.titleLarge),
                Text(user.email, style: const TextStyle(color: Brand.slate600)),
              ]),
            ),
          ]),
        ),
        _group([
          _tile(Icons.badge_outlined, 'Personal details', 'Name, phone, date of birth, profile links', () => context.push('/profile/edit')),
          _tile(Icons.lock_outline_rounded, 'Change password', null, () => context.push('/profile/password')),
          _tile(Icons.luggage_outlined, 'My trips', null, () => context.go('/trips')),
        ]),
        _LegalLinks(),
        _group([
          _tile(Icons.logout_rounded, 'Sign out', null, () async {
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) context.go('/');
          }),
          _tile(Icons.delete_outline_rounded, 'Delete account', null, () => context.push('/profile/delete'), danger: true),
        ]),
      ]),
    );
  }
}

Widget _group(List<Widget> tiles) => Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Brand.line)),
      child: Column(children: [
        for (var i = 0; i < tiles.length; i++) ...[if (i > 0) const Divider(indent: 56), tiles[i]],
      ]),
    );

Widget _tile(IconData icon, String title, String? subtitle, VoidCallback onTap, {bool danger = false}) => ListTile(
      leading: Icon(icon, color: danger ? Brand.danger : Brand.slate600),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: danger ? Brand.danger : Brand.ink)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded, color: Brand.slate400),
      onTap: onTap,
    );

class _LegalLinks extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _group([
        _tile(Icons.description_outlined, 'Terms', null, () => _web('/legal/terms')),
        _tile(Icons.privacy_tip_outlined, 'Privacy Policy', null, () => _web('/legal/privacy')),
      ]);
}

// ---------- personal details ----------

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final User _user = ref.read(authProvider).valueOrNull!;
  late final _name = TextEditingController(text: _user.fullName);
  late final _phone = TextEditingController(text: _user.phone ?? '');
  late DateTime? _dob = DateTime.tryParse(_user.dob ?? '');
  final _link = TextEditingController();
  String? _error;
  String? _saved;

  Api get _api => ref.read(apiProvider);

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _error = null;
      _saved = null;
    });
    try {
      final me = await _api.patch<Map<String, dynamic>>('/me', body: {
        'full_name': _name.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'dob': _dob == null ? null : DateFormat('yyyy-MM-dd').format(_dob!),
      });
      ref.read(authProvider.notifier).setUser(User.fromJson(me));
      setState(() => _saved = 'Saved.');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _addLink() async {
    if (_link.text.trim().isEmpty) return;
    setState(() {
      _error = null;
      _saved = null;
    });
    try {
      final me = await _api.post<Map<String, dynamic>>('/me/social-links', body: {'url': _link.text.trim()});
      ref.read(authProvider.notifier).setUser(User.fromJson(me));
      _link.clear();
      setState(() {});
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _removeLink(String id) async {
    try {
      final me = await _api.delete<Map<String, dynamic>>('/me/social-links/$id');
      ref.read(authProvider.notifier).setUser(User.fromJson(me));
      setState(() {});
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30),
      firstDate: DateTime(now.year - 110),
      lastDate: DateTime(now.year - 16),
      initialEntryMode: DatePickerEntryMode.input,
      helpText: 'Date of birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  @override
  Widget build(BuildContext context) {
    final links = ref.watch(authProvider).valueOrNull?.socialLinks ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Personal details')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const Text('Hosts see your name, your age and your profile links when you request a stay. '
              'Your phone and email are shared only once a booking is confirmed.', style: TextStyle(color: Brand.slate600)),
          const SizedBox(height: 20),
          FormMessage(_error),
          FormMessage(_saved, success: true),
          TextFormField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) => requiredField(v, 'your name')),
          const SizedBox(height: 14),
          TextFormField(controller: _phone, keyboardType: TextInputType.phone, autofillHints: const [AutofillHints.telephoneNumber],
              decoration: const InputDecoration(labelText: 'Mobile number', hintText: '+61 400 000 000')),
          const SizedBox(height: 14),
          InkWell(
            onTap: _pickDob,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date of birth', suffixIcon: Icon(Icons.calendar_today_rounded)),
              child: Text(_dob == null ? 'Not set' : DateFormat('d MMMM yyyy').format(_dob!)),
            ),
          ),
          const SizedBox(height: 20),
          BusyButton(label: 'Save', onPressed: _save),
          const Divider(height: 48),
          Text('Profile links', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('Instagram, Facebook, LinkedIn or X. They help hosts know who is coming.', style: TextStyle(color: Brand.slate600)),
          const SizedBox(height: 12),
          for (final l in links)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link_rounded),
              title: Text(l.platform),
              subtitle: Text(l.url, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: IconButton(tooltip: 'Remove', icon: const Icon(Icons.close_rounded), onPressed: () => _removeLink(l.id)),
            ),
          Row(children: [
            Expanded(child: TextField(controller: _link, keyboardType: TextInputType.url, decoration: const InputDecoration(hintText: 'https://instagram.com/you'))),
            const SizedBox(width: 8),
            SizedBox(width: 90, child: OutlinedButton(onPressed: _addLink, child: const Text('Add'))),
          ]),
        ]),
      ),
    );
  }
}

// ---------- password ----------

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  String? _error;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _error = null);
    try {
      final t = await ref.read(tokenStoreProvider).read();
      // Sending this phone's refresh token keeps it signed in; every other device is signed out.
      await ref.read(apiProvider).post('/auth/change-password',
          body: {'current_password': _current.text, 'new_password': _next.text}, headers: {if (t != null) 'X-Refresh-Token': t.refresh});
      if (!mounted) return;
      showMessage(context, 'Password changed. Other devices have been signed out.');
      context.pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Change password')),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            FormMessage(_error),
            PasswordField(controller: _current, label: 'Current password', autofill: const [AutofillHints.password]),
            const SizedBox(height: 14),
            PasswordField(controller: _next, label: 'New password', validator: newPasswordProblem, autofill: const [AutofillHints.newPassword]),
            const SizedBox(height: 24),
            BusyButton(label: 'Change password', onPressed: _save),
          ]),
        ),
      );
}

// ---------- delete account (Google Play requires this in the app) ----------

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});
  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();
  String? _error;

  Future<void> _delete() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter your password to confirm.');
      return;
    }
    setState(() => _error = null);
    try {
      await ref.read(authProvider.notifier).deleteAccount(_password.text);
      if (!mounted) return;
      context.go('/');
      showMessage(context, 'Your account has been deleted.');
    } on ApiException catch (e) {
      setState(() => _error = e.message); // e.g. a booking in progress, or a wrong password
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Delete account')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text('This cannot be undone', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          const Text(
            'Your name, email, phone, date of birth, photo and profile links are erased, and you are signed out everywhere.\n\n'
            'Past bookings and payments are kept without your details, as the law requires. '
            'Bookings in progress must be finished or cancelled first.',
            style: TextStyle(height: 1.5),
          ),
          TextButton(onPressed: () => _web('/delete-account'), child: const Text('More about deleting your account')),
          const SizedBox(height: 12),
          FormMessage(_error),
          PasswordField(controller: _password, label: 'Confirm with your password'),
          const SizedBox(height: 24),
          BusyButton(label: 'Delete my account', danger: true, onPressed: _delete),
        ]),
      );
}

// ---------- updated Terms or Privacy Policy ----------

/// When the Terms or Privacy Policy change, the person agrees again before carrying on (as on the website).
class ConsentGate extends ConsumerWidget {
  const ConsentGate({super.key, required this.user});
  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const SizedBox(height: 24),
            const Icon(Icons.policy_outlined, size: 48, color: Brand.b600),
            const SizedBox(height: 16),
            Text('We have updated our policies', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 24)),
            const SizedBox(height: 10),
            const Text('Please read and accept them to keep using NearBnB.', style: TextStyle(color: Brand.slate600)),
            const SizedBox(height: 20),
            for (final c in user.pendingConsents)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined),
                title: Text(c.title),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () => _web('/legal/${c.docType}'),
              ),
            const SizedBox(height: 20),
            BusyButton(
              label: 'I accept',
              onPressed: () async {
                try {
                  for (final c in user.pendingConsents) {
                    await ref.read(apiProvider).post('/me/consents', body: {'doc_type': c.docType});
                  }
                  await ref.read(authProvider.notifier).reload();
                } on ApiException catch (e) {
                  if (context.mounted) showMessage(context, e.message);
                }
              },
            ),
            TextButton(onPressed: () => ref.read(authProvider.notifier).logout(), child: const Text('Sign out')),
          ]),
        ),
      );
}
