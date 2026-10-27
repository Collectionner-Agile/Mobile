import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/app_config.dart';
import '../../../app/preferences.dart';
import '../../../app/providers.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/password_field.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/application/session_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await confirmDialog(context, title: l10n.signOut, body: l10n.signOutConfirm, confirmLabel: l10n.signOut);
    if (!ok) return;
    await ref.read(sessionProvider.notifier).logout();
    if (context.mounted) context.go(Routes.home);
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final deleted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _DeleteAccountSheet(),
    );
    if (deleted == true && context.mounted) {
      showToast(context, context.l10n.accountDeleted);
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final brand = context.brand;
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: EdgeInsets.only(bottom: Space.xxl + MediaQuery.paddingOf(context).bottom),
        children: [
          ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(title: l10n.appearance),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: const Icon(Icons.brightness_auto_outlined),
                        label: Text(l10n.themeSystem),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: const Icon(Icons.light_mode_outlined),
                        label: Text(l10n.themeLight),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: const Icon(Icons.dark_mode_outlined),
                        label: Text(l10n.themeDark),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (value) => ref.read(themeModeProvider.notifier).set(value.first),
                  ),
                ),
                SectionHeader(title: l10n.language),
                RadioGroup<String>(
                  groupValue: locale?.languageCode ?? 'system',
                  onChanged: (value) =>
                      ref.read(localeProvider.notifier).set(value == null || value == 'system' ? null : Locale(value)),
                  child: _Group(
                    children: [
                      RadioListTile<String>(value: 'system', title: Text(l10n.languageSystem)),
                      const RadioListTile<String>(value: 'es', title: Text('Español')),
                      const RadioListTile<String>(value: 'en', title: Text('English')),
                    ],
                  ),
                ),
                if (user != null) ...[
                  SectionHeader(title: l10n.account),
                  _Group(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(user.name),
                        subtitle: Text(user.email ?? '@${user.username}'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.password),
                        title: Text(l10n.changePassword),
                        subtitle: user.hasLocalPassword ? null : Text(l10n.externalAccountPassword),
                        enabled: user.hasLocalPassword,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(Routes.changePassword),
                      ),
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: Text(l10n.signOut),
                        onTap: () => _signOut(context, ref),
                      ),
                      if (user.hasLocalPassword)
                        ListTile(
                          leading: Icon(Icons.delete_forever_outlined, color: brand.danger),
                          title: Text(l10n.deleteAccount, style: TextStyle(color: brand.danger)),
                          onTap: () => _deleteAccount(context, ref),
                        ),
                    ],
                  ),
                ] else ...[
                  SectionHeader(title: l10n.account),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                    child: BusyButton(
                      label: l10n.signIn,
                      icon: Icons.login,
                      onPressed: () => context.push(Routes.login),
                    ),
                  ),
                ],
                SectionHeader(title: l10n.about),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.privacySummary, style: context.text.bodyMedium?.copyWith(color: brand.muted)),
                      const SizedBox(height: Space.sm),
                      Text(l10n.versionLabel('1.0.0'), style: context.text.bodySmall?.copyWith(color: brand.muted)),
                      Text(
                        l10n.serverLabel(AppConfig.apiBaseUrl),
                        style: context.text.bodySmall?.copyWith(color: brand.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteAccountSheet extends ConsumerStatefulWidget {
  const _DeleteAccountSheet();

  @override
  ConsumerState<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<_DeleteAccountSheet> {
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).deleteAccount(_password.text);
      await ref.read(sessionProvider.notifier).signOutLocally();
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error, context.l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xl),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.deleteAccount, style: context.text.titleLarge?.copyWith(color: brand.danger)),
              const SizedBox(height: Space.xs),
              Text(l10n.deleteAccountBody, style: context.text.bodyMedium),
              const SizedBox(height: Space.md),
              PasswordField(
                controller: _password,
                label: l10n.currentPassword,
                validator: Validators(l10n).required,
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: Space.sm),
                Text(_error!, style: context.text.bodySmall?.copyWith(color: brand.danger)),
              ],
              const SizedBox(height: Space.lg),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: brand.danger, foregroundColor: Colors.white),
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l10n.deleteAccountConfirm),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).changePassword(_current.text, _next.text);
      // Same rule as the web: saving a new password ends this session.
      await ref.read(sessionProvider.notifier).signOutLocally();
      if (!mounted) return;
      showToast(context, l10n.passwordChanged);
      context.go(Routes.login);
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error, l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final validators = Validators(l10n);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.changePassword)),
      body: SafeArea(
        top: false,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, Space.xxl),
            children: [
              ContentWidth(
                maxWidth: 480,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.changePasswordIntro,
                      style: context.text.bodyMedium?.copyWith(color: context.brand.muted),
                    ),
                    const SizedBox(height: Space.lg),
                    PasswordField(
                      controller: _current,
                      label: l10n.currentPassword,
                      validator: validators.required,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: Space.md),
                    PasswordField(
                      controller: _next,
                      label: l10n.newPassword,
                      validator: validators.password,
                      autofillHints: const [AutofillHints.newPassword],
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: Space.md),
                    PasswordField(
                      controller: _confirm,
                      label: l10n.confirmPassword,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: (value) => validators.matches(value, _next.text),
                      onSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: Space.sm),
                      Text(_error!, style: context.text.bodyMedium?.copyWith(color: context.brand.danger)),
                    ],
                    const SizedBox(height: Space.lg),
                    BusyButton(label: l10n.save, busy: _busy, onPressed: _submit),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grouped settings rows on one card, separated by hairlines.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: brand.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: brand.line),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.md - 1),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                for (final (index, child) in children.indexed) ...[
                  if (index > 0) Divider(height: 1, indent: Space.md, endIndent: Space.md, color: brand.line),
                  child,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
