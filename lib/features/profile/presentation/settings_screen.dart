import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/preferences.dart';
import '../../../app/providers.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/kit.dart';
import '../../../core/widgets/password_field.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/application/session_controller.dart';
import '../../launch/launch_scene.dart';

/// Settings as a few plain groups: how the app looks, your account, help and
/// about. Each row says what it does; destructive ones are red.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l10n.signOut,
      body: l10n.signOutConfirm,
      confirmLabel: l10n.signOut,
      icon: AppIcons.logOut,
    );
    if (!ok || !context.mounted) return;
    final router = ref.read(routerProvider);
    await ref.read(sessionProvider.notifier).logout();
    if (!context.mounted) return;
    await farewell(
      context,
      title: l10n.farewellTitle,
      message: l10n.farewellSignedOut,
      then: () => router.go(Routes.home),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final deleted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
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
    final user = ref.watch(currentUserProvider);
    final theme = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final themeName = switch (theme) {
      ThemeMode.light => l10n.themeLight,
      ThemeMode.dark => l10n.themeDark,
      ThemeMode.system => l10n.themeSystem,
    };
    final languageName = switch (locale?.languageCode) {
      'es' => 'Español',
      'en' => 'English',
      _ => l10n.languageSystem,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Space.gutter,
          Space.xs,
          Space.gutter,
          Space.xxl + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MenuGroup(
                  title: l10n.appearance,
                  children: [
                    MenuTile(
                      icon: AppIcons.palette,
                      title: l10n.appearance,
                      subtitle: '$themeName · $languageName',
                      color: brand.gold,
                      onTap: () => context.push(Routes.appearance),
                    ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                MenuGroup(
                  title: l10n.account,
                  children: [
                    if (user != null) ...[
                      MenuTile(
                        icon: AppIcons.squarePen,
                        title: l10n.editProfile,
                        onTap: () => context.push(Routes.editProfile),
                      ),
                      MenuTile(
                        icon: AppIcons.keyRound,
                        title: l10n.changePassword,
                        subtitle: user.hasLocalPassword ? null : l10n.externalAccountPassword,
                        onTap: user.hasLocalPassword ? () => context.push(Routes.changePassword) : null,
                      ),
                      MenuTile(icon: AppIcons.logOut, title: l10n.signOut, onTap: () => _signOut(context, ref)),
                      MenuTile(
                        icon: AppIcons.trash2,
                        title: l10n.deleteAccount,
                        destructive: true,
                        onTap: user.hasLocalPassword ? () => _deleteAccount(context) : null,
                      ),
                    ] else
                      MenuTile(icon: AppIcons.logIn, title: l10n.signIn, onTap: () => context.push(Routes.login)),
                  ],
                ),
                const SizedBox(height: Space.lg),
                MenuGroup(
                  title: l10n.helpTitle,
                  children: [
                    MenuTile(
                      icon: AppIcons.circleHelp,
                      title: l10n.helpTitle,
                      color: brand.info,
                      onTap: () => context.push(Routes.help),
                    ),
                    MenuTile(
                      icon: AppIcons.lightbulb,
                      title: l10n.howItWorksTitle,
                      color: brand.gold,
                      onTap: () => context.push(Routes.howItWorks),
                    ),
                    MenuTile(
                      icon: AppIcons.circlePlay,
                      title: l10n.replayIntro,
                      onTap: () => context.go(Routes.onboarding),
                    ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                MenuGroup(
                  title: l10n.about,
                  children: [
                    MenuTile(
                      icon: AppIcons.info,
                      title: l10n.aboutTitle,
                      subtitle: l10n.versionLabel(appVersion),
                      onTap: () => context.push(Routes.about),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown in About and Settings. Keep in step with pubspec.yaml.
const appVersion = '2.0.0';

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
              Center(child: IconBadge(AppIcons.triangleAlert, color: brand.danger, size: 56)),
              const SizedBox(height: Space.md),
              Text(l10n.deleteAccount, textAlign: TextAlign.center, style: context.text.titleLarge),
              const SizedBox(height: Space.xs),
              Text(
                l10n.deleteAccountBody,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(color: brand.muted),
              ),
              const SizedBox(height: Space.lg),
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
              BusyButton(
                label: l10n.deleteAccountConfirm,
                icon: AppIcons.trash2,
                busy: _busy,
                color: brand.danger,
                onPressed: _submit,
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
      showToast(context, l10n.passwordChanged, icon: AppIcons.shieldCheck);
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
    final brand = context.brand;
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
                    Center(child: IconBadge(AppIcons.keyRound, color: brand.gold, size: 56)),
                    const SizedBox(height: Space.md),
                    Text(
                      l10n.changePasswordIntro,
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(color: brand.muted),
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
                      Text(_error!, style: context.text.bodyMedium?.copyWith(color: brand.danger)),
                    ],
                    const SizedBox(height: Space.lg),
                    BusyButton(label: l10n.save, icon: AppIcons.check, busy: _busy, onPressed: _submit),
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
