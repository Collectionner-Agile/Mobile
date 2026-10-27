import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/password_field.dart';
import '../../../core/widgets/ui.dart';
import '../application/session_controller.dart';

/// Shared layout: title, intro, form and footer link; scrolls
/// under the keyboard and caps width on large screens.
class _AuthPage extends StatelessWidget {
  const _AuthPage({required this.title, required this.intro, required this.children});
  final String title;
  final String intro;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.xxl),
          children: [
            ContentWidth(
              maxWidth: 480,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title, style: context.text.headlineMedium),
                    const SizedBox(height: Space.xs),
                    Text(intro, style: context.text.bodyMedium?.copyWith(color: context.brand.muted)),
                    const SizedBox(height: Space.xl),
                    ...children,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormError extends StatelessWidget {
  const _FormError(this.message);
  final String? message;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: Motion.of(context, Motion.fast),
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: Space.md),
              padding: const EdgeInsets.all(Space.sm),
              decoration: BoxDecoration(
                color: Color.alphaBlend(context.brand.danger.withValues(alpha: 0.08), context.brand.surfaceRaised),
                borderRadius: BorderRadius.circular(Radii.sm),
                border: Border.all(color: context.brand.danger.withValues(alpha: 0.4)),
              ),
              child: Semantics(
                liveRegion: true,
                child: Text(message!, style: context.text.bodyMedium?.copyWith(color: context.brand.danger)),
              ),
            ),
    );
  }
}

void _leaveAuth(BuildContext context, String? from) {
  if (from != null && from.startsWith('/')) {
    context.go(from);
  } else if (context.canPop()) {
    context.pop();
  } else {
    context.go(Routes.home);
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.from});
  final String? from;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
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
      await ref.read(sessionProvider.notifier).login(_username.text, _password.text);
      TextInput.finishAutofillContext();
      if (mounted) _leaveAuth(context, widget.from);
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.kind == ApiErrorKind.unauthorized ? l10n.badCredentials : describeError(error, l10n),
        );
      }
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
    return _AuthPage(
      title: l10n.loginTitle,
      intro: l10n.loginIntro,
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _username,
                autofillHints: const [AutofillHints.username, AutofillHints.email],
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.usernameOrEmail,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: validators.required,
              ),
              const SizedBox(height: Space.md),
              PasswordField(
                controller: _password,
                label: l10n.password,
                validator: validators.required,
                onSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push(Routes.forgotPassword),
                  child: Text(l10n.forgotPassword),
                ),
              ),
              _FormError(_error),
              const SizedBox(height: Space.md),
              BusyButton(label: l10n.signIn, busy: _busy, onPressed: _submit),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l10n.noAccount, style: context.text.bodyMedium),
            TextButton(
              onPressed: () => context.pushReplacement(
                Uri(
                  path: Routes.register,
                  queryParameters: widget.from == null ? null : {'from': widget.from},
                ).toString(),
              ),
              child: Text(l10n.createAccount),
            ),
          ],
        ),
      ],
    );
  }
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.from});
  final String? from;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_name, _username, _email, _password, _confirm]) {
      controller.dispose();
    }
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
      await ref
          .read(sessionProvider.notifier)
          .register(username: _username.text, email: _email.text, password: _password.text, name: _name.text);
      TextInput.finishAutofillContext();
      if (mounted) _leaveAuth(context, widget.from);
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
    return _AuthPage(
      title: l10n.registerTitle,
      intro: l10n.registerIntro,
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                autofillHints: const [AutofillHints.name],
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.fullName),
                validator: (value) => validators.minLength(value, 2),
              ),
              const SizedBox(height: Space.md),
              TextFormField(
                controller: _username,
                autofillHints: const [AutofillHints.newUsername],
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.username, prefixText: '@'),
                validator: validators.username,
              ),
              const SizedBox(height: Space.md),
              TextFormField(
                controller: _email,
                autofillHints: const [AutofillHints.email],
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.email),
                validator: validators.email,
              ),
              const SizedBox(height: Space.md),
              PasswordField(
                controller: _password,
                label: l10n.password,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                validator: validators.password,
              ),
              const SizedBox(height: Space.md),
              PasswordField(
                controller: _confirm,
                label: l10n.confirmPassword,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) => validators.matches(value, _password.text),
                onSubmitted: (_) => _submit(),
              ),
              _FormError(_error),
              const SizedBox(height: Space.lg),
              BusyButton(label: l10n.createAccount, busy: _busy, onPressed: _submit),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l10n.haveAccount, style: context.text.bodyMedium),
            TextButton(
              onPressed: () => context.pushReplacement(
                Uri(path: Routes.login, queryParameters: widget.from == null ? null : {'from': widget.from}).toString(),
              ),
              child: Text(l10n.signIn),
            ),
          ],
        ),
      ],
    );
  }
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _result;

  @override
  void dispose() {
    _email.dispose();
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
      final message = await ref.read(authRepositoryProvider).forgotPassword(_email.text.trim());
      if (mounted) setState(() => _result = message ?? l10n.forgotSent);
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error, l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _AuthPage(
      title: l10n.forgotTitle,
      intro: l10n.forgotIntro,
      children: [
        Form(
          key: _form,
          child: TextFormField(
            controller: _email,
            autofillHints: const [AutofillHints.email],
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: l10n.email),
            validator: Validators(l10n).email,
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
        _FormError(_error),
        if (_result != null)
          Container(
            margin: const EdgeInsets.only(top: Space.md),
            padding: const EdgeInsets.all(Space.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.sm),
              border: Border.all(color: context.brand.success.withValues(alpha: 0.5)),
            ),
            child: Semantics(liveRegion: true, child: Text(_result!, style: context.text.bodyMedium)),
          ),
        const SizedBox(height: Space.lg),
        BusyButton(label: l10n.sendInstructions, busy: _busy, onPressed: _submit),
        const SizedBox(height: Space.sm),
        TextButton(onPressed: () => context.pushReplacement(Routes.resetPassword), child: Text(l10n.haveToken)),
      ],
    );
  }
}

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _token = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_username, _token, _password, _confirm]) {
      controller.dispose();
    }
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
      await ref
          .read(authRepositoryProvider)
          .resetPassword(username: _username.text.trim(), token: _token.text.trim(), newPassword: _password.text);
      if (!mounted) return;
      showToast(context, l10n.resetDone);
      context.pushReplacement(Routes.login);
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
    return _AuthPage(
      title: l10n.resetTitle,
      intro: l10n.forgotIntro,
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _username,
                autofillHints: const [AutofillHints.username],
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.username),
                validator: validators.required,
              ),
              const SizedBox(height: Space.md),
              TextFormField(
                controller: _token,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l10n.recoveryToken),
                validator: validators.required,
              ),
              const SizedBox(height: Space.md),
              PasswordField(
                controller: _password,
                label: l10n.newPassword,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                validator: validators.password,
              ),
              const SizedBox(height: Space.md),
              PasswordField(
                controller: _confirm,
                label: l10n.confirmPassword,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) => validators.matches(value, _password.text),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        _FormError(_error),
        const SizedBox(height: Space.lg),
        BusyButton(label: l10n.resetSubmit, busy: _busy, onPressed: _submit),
      ],
    );
  }
}
