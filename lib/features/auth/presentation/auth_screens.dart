import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

/// Shared layout: a photographic header that fades into the page, then the
/// title, intro and form. Scrolls under the keyboard and caps width on large
/// screens; [header] is false for secondary screens (recovery).
class _AuthPage extends StatelessWidget {
  const _AuthPage({required this.title, required this.intro, required this.children, this.header = true});
  final String title;
  final String intro;
  final List<Widget> children;
  final bool header;

  static const _image = 'assets/images/collectibles/records/vintage-yellow-chronograph.webp';

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final width = MediaQuery.sizeOf(context).width;
    final heroHeight = (width * 0.78).clamp(220.0, 340.0);
    return Scaffold(
      extendBodyBehindAppBar: header,
      appBar: AppBar(
        backgroundColor: header ? Colors.transparent : null,
        leading: Navigator.of(context).canPop()
            ? Padding(
                padding: const EdgeInsets.all(6),
                child: BackButton(
                  style: IconButton.styleFrom(
                    backgroundColor: header ? brand.surface : null,
                    foregroundColor: brand.ink,
                  ),
                ),
              )
            : null,
      ),
      body: SafeArea(
        top: !header,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: Space.xxl),
          children: [
            if (header)
              SizedBox(
                height: heroHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ExcludeSemantics(
                      child: Image.asset(_image, fit: BoxFit.cover, cacheWidth: (width * 2).round()),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.45, 1],
                          colors: [brand.paper.withValues(alpha: 0), brand.paper],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ContentWidth(
              maxWidth: 480,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(title, style: context.text.headlineMedium),
                      const SizedBox(height: Space.xs),
                      Text(intro, style: context.text.bodyMedium?.copyWith(color: brand.muted)),
                      const SizedBox(height: Space.xl),
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Continue with Google" plus the divider above the password form. Checks
/// with the server first so an unconfigured provider is explained instead of
/// opening a browser on a dead route.
class _GoogleSignIn extends ConsumerStatefulWidget {
  const _GoogleSignIn({required this.from});
  final String? from;

  @override
  ConsumerState<_GoogleSignIn> createState() => _GoogleSignInState();
}

class _GoogleSignInState extends ConsumerState<_GoogleSignIn> {
  bool _busy = false;

  static const _logo =
      '<svg viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg">'
      '<path fill="#FFC107" d="M43.6 20.1H42V20H24v8h11.3C33.7 32.7 29.2 36 24 36c-6.6 0-12-5.4-12-12s5.4-12 12-12c3.1 0 5.8 1.2 8 3l5.7-5.7C34 6.1 29.3 4 24 4 13 4 4 13 4 24s9 20 20 20 20-9 20-20c0-1.3-.1-2.6-.4-3.9z"/>'
      '<path fill="#FF3D00" d="M6.3 14.7l6.6 4.8C14.7 15.1 19 12 24 12c3.1 0 5.8 1.2 8 3l5.7-5.7C34 6.1 29.3 4 24 4 16.3 4 9.7 8.3 6.3 14.7z"/>'
      '<path fill="#4CAF50" d="M24 44c5.2 0 9.9-2 13.4-5.2l-6.2-5.2C29.2 35.1 26.7 36 24 36c-5.2 0-9.6-3.3-11.3-7.9l-6.5 5C9.5 39.6 16.2 44 24 44z"/>'
      '<path fill="#1976D2" d="M43.6 20.1H42V20H24v8h11.3c-.8 2.2-2.2 4.2-4.1 5.6l6.2 5.2C37 39.2 44 34 44 24c0-1.3-.1-2.6-.4-3.9z"/>'
      '</svg>';

  Future<void> _start() async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final providers = await ref.read(oauthProvidersProvider.future);
      if (!mounted) return;
      if (!providers.contains('google')) {
        ref.invalidate(oauthProvidersProvider);
        showToast(context, l10n.googleUnavailable, error: true);
        return;
      }
      await ref.read(sessionProvider.notifier).signInWithGoogle();
      if (mounted) _leaveAuth(context, widget.from);
    } on OAuthSignInException catch (error) {
      if (mounted && !error.cancelled) showToast(context, l10n.googleFailed, error: true);
    } catch (error) {
      if (mounted) showToast(context, describeError(error, l10n), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: brand.surface,
            minimumSize: const Size.fromHeight(52),
            side: BorderSide(color: brand.line),
          ),
          onPressed: _busy ? null : _start,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_busy)
                const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2.2))
              else
                SvgPicture.string(_logo, width: 20, height: 20, excludeFromSemantics: true),
              const SizedBox(width: Space.sm),
              Flexible(child: Text(l10n.continueWithGoogle, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        Row(
          children: [
            Expanded(child: Divider(color: brand.line)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.sm),
              child: Text(l10n.orWithEmail, style: context.text.bodySmall?.copyWith(color: brand.muted)),
            ),
            Expanded(child: Divider(color: brand.line)),
          ],
        ),
        const SizedBox(height: Space.lg),
      ],
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
        _GoogleSignIn(from: widget.from),
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
        _GoogleSignIn(from: widget.from),
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
      header: false,
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
      header: false,
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
