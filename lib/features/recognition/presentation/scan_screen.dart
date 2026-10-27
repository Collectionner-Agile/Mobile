import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/media/image_pipeline.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/account_button.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/application/session_controller.dart';
import '../application/scan_controller.dart';

class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key});

  Future<void> _pick(BuildContext context, WidgetRef ref, ImageSource source, {bool replace = false}) async {
    final l10n = context.l10n;
    try {
      final picked = await ImageSourcePicker().pick(source);
      if (picked == null) return;
      final controller = ref.read(scanControllerProvider.notifier);
      replace ? controller.replacePhoto(picked.path) : controller.usePhoto(picked.path);
    } on PickException {
      if (context.mounted) {
        showToast(
          context,
          source == ImageSource.camera ? l10n.permissionCameraDenied : l10n.permissionGalleryDenied,
          error: true,
        );
      }
    } catch (_) {
      if (context.mounted) showToast(context, l10n.imageUnreadable, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(currentUserProvider);
    final scan = ref.watch(scanControllerProvider);

    ref.listen(scanControllerProvider.select((state) => state.stage), (previous, next) {
      if (next == ScanStage.done && previous != ScanStage.done) {
        HapticFeedback.lightImpact();
        context.push(Routes.scanResult);
      }
    });

    final Widget body;
    if (user == null) {
      body = const _SignInPrompt(key: ValueKey('signin'));
    } else if (scan.imagePath == null) {
      body = _Intro(
        key: const ValueKey('intro'),
        onCamera: () => _pick(context, ref, ImageSource.camera),
        onGallery: () => _pick(context, ref, ImageSource.gallery),
      );
    } else {
      body = _Preview(
        key: const ValueKey('preview'),
        state: scan,
        onReplace: () => _pick(context, ref, ImageSource.gallery, replace: true),
        onRetake: () => _pick(context, ref, ImageSource.camera, replace: true),
      );
    }

    return PopScope(
      canPop: !scan.isBusy && scan.imagePath == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final controller = ref.read(scanControllerProvider.notifier);
        scan.isBusy ? controller.cancel() : controller.reset();
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: Space.gutter,
          title: Text(l10n.scanTitle),
          leading: scan.imagePath != null && !scan.isBusy
              ? IconButton(
                  tooltip: l10n.back,
                  icon: const Icon(Icons.arrow_back),
                  onPressed: ref.read(scanControllerProvider.notifier).reset,
                )
              : null,
          actions: const [
            AccountButton(),
            SizedBox(width: Space.xxs),
          ],
        ),
        body: AnimatedSwitcher(duration: Motion.of(context, Motion.base), child: body),
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(Space.gutter),
      children: [
        ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Kicker(l10n.scanKicker),
              const SizedBox(height: Space.xs),
              Text(l10n.scanSignInTitle, style: context.text.headlineSmall),
              const SizedBox(height: Space.xs),
              Text(l10n.scanSignInBody, style: context.text.bodyMedium?.copyWith(color: context.brand.muted)),
              const SizedBox(height: Space.lg),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.md),
                child: AspectRatio(
                  aspectRatio: 3 / 2,
                  child: Image.asset(
                    'assets/images/lab/archive-worktable.webp',
                    fit: BoxFit.cover,
                    cacheWidth: 900,
                    semanticLabel: l10n.scanTitle,
                  ),
                ),
              ),
              const SizedBox(height: Space.lg),
              BusyButton(
                label: l10n.signIn,
                icon: Icons.login,
                onPressed: () =>
                    context.push(Uri(path: Routes.login, queryParameters: {'from': Routes.scan}).toString()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Intro extends ConsumerWidget {
  const _Intro({super.key, required this.onCamera, required this.onGallery});
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final brand = context.brand;
    final enabled = ref.watch(recognitionEnabledProvider);
    return ListView(
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
              Kicker(l10n.scanKicker),
              const SizedBox(height: Space.xs),
              Text(l10n.scanIntro, style: context.text.bodyLarge),
              if (enabled.value == false) ...[
                const SizedBox(height: Space.md),
                _Banner(icon: Icons.cloud_off_outlined, text: l10n.scanUnavailable, color: brand.warning),
              ],
              const SizedBox(height: Space.lg),
              Row(
                children: [
                  Expanded(
                    child: _BigAction(
                      icon: Icons.photo_camera_outlined,
                      label: l10n.scanCamera,
                      onTap: onCamera,
                      primary: true,
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: _BigAction(icon: Icons.photo_library_outlined, label: l10n.scanGallery, onTap: onGallery),
                  ),
                ],
              ),
              const SizedBox(height: Space.xl),
              Text(l10n.scanTipsTitle, style: context.text.titleMedium),
              const SizedBox(height: Space.xs),
              for (final (index, tip) in [l10n.scanTip1, l10n.scanTip2, l10n.scanTip3].indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.xxs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 32, child: Kicker('0${index + 1}')),
                      Expanded(child: Text(tip, style: context.text.bodyMedium)),
                    ],
                  ),
                ),
              const SizedBox(height: Space.lg),
              _Banner(icon: Icons.lock_outline, text: l10n.scanPrivacy, color: brand.info),
            ],
          ),
        ),
      ],
    );
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({required this.icon, required this.label, required this.onTap, this.primary = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final background = primary ? BrandColors.light.ink : brand.surfaceRaised;
    final foreground = primary ? BrandColors.light.paper : brand.ink;
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: primary ? Colors.transparent : brand.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 112),
          child: Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 32, color: primary ? const Color(0xFFF0A07F) : brand.rustStrong),
                const SizedBox(height: Space.xs),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: context.text.labelLarge?.copyWith(color: foreground),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Space.sm),
    decoration: BoxDecoration(
      color: Color.alphaBlend(color.withValues(alpha: 0.08), context.brand.surfaceRaised),
      borderRadius: BorderRadius.circular(Radii.sm),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: Space.sm),
        Expanded(child: Text(text, style: context.text.bodySmall)),
      ],
    ),
  );
}

class _Preview extends ConsumerWidget {
  const _Preview({super.key, required this.state, required this.onReplace, required this.onRetake});
  final ScanState state;
  final VoidCallback onReplace;
  final VoidCallback onRetake;

  Future<void> _crop(BuildContext context, WidgetRef ref) async {
    final cropped = await cropImage(context, state.imagePath!, title: context.l10n.scanCrop);
    if (cropped != null) ref.read(scanControllerProvider.notifier).replacePhoto(cropped);
  }

  Future<void> _analyze(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l10n.scanAnalyze,
      body: l10n.scanConfirmSend,
      confirmLabel: l10n.send,
    );
    if (ok) await ref.read(scanControllerProvider.notifier).analyze();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final brand = context.brand;
    final busy = state.isBusy;
    final controller = ref.read(scanControllerProvider.notifier);
    final enabled = ref.watch(recognitionEnabledProvider).value ?? true;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxImageHeight = (constraints.maxHeight * 0.55).clamp(220.0, 640.0);
        return ListView(
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
                  Text(l10n.scanPreviewTitle, style: context.text.titleMedium),
                  const SizedBox(height: Space.sm),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxImageHeight),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.md),
                      child: ColoredBox(
                        color: Colors.black,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Center(
                              child: AnimatedRotation(
                                turns: state.quarterTurns / 4,
                                duration: Motion.of(context, Motion.base),
                                curve: Motion.standard,
                                child: Image.file(
                                  File(state.imagePath!),
                                  fit: BoxFit.contain,
                                  cacheWidth: 1080,
                                  semanticLabel: l10n.scanPreviewTitle,
                                  errorBuilder: (_, _, _) => Padding(
                                    padding: const EdgeInsets.all(Space.xl),
                                    child: Text(l10n.imageUnreadable, style: const TextStyle(color: Colors.white)),
                                  ),
                                ),
                              ),
                            ),
                            if (busy) const Positioned.fill(child: _ScanningOverlay()),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  if (!busy)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: Space.xs,
                      runSpacing: Space.xs,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _crop(context, ref),
                          icon: const Icon(Icons.crop),
                          label: Text(l10n.scanCrop),
                        ),
                        OutlinedButton.icon(
                          onPressed: controller.rotate,
                          icon: const Icon(Icons.rotate_90_degrees_cw_outlined),
                          label: Text(l10n.scanRotate),
                        ),
                        OutlinedButton.icon(
                          onPressed: onRetake,
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: Text(l10n.scanCamera),
                        ),
                        OutlinedButton.icon(
                          onPressed: onReplace,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text(l10n.scanRetake),
                        ),
                      ],
                    ),
                  const SizedBox(height: Space.lg),
                  if (busy)
                    _Progress(state: state, onCancel: controller.cancel)
                  else ...[
                    if (state.stage == ScanStage.failed && state.error != null) ...[
                      _Banner(
                        icon: Icons.error_outline,
                        color: brand.danger,
                        text: state.error is ImageProcessingException
                            ? ((state.error! as ImageProcessingException).reason == ImageProcessingFailure.tooLarge
                                  ? l10n.imageTooLarge
                                  : l10n.imageUnreadable)
                            : describeError(state.error!, l10n),
                      ),
                      const SizedBox(height: Space.md),
                    ],
                    if (!enabled) ...[
                      _Banner(icon: Icons.cloud_off_outlined, text: l10n.scanUnavailable, color: brand.warning),
                      const SizedBox(height: Space.md),
                    ],
                    BusyButton(
                      label: state.stage == ScanStage.failed ? l10n.retry : l10n.scanAnalyze,
                      icon: Icons.auto_awesome_outlined,
                      onPressed: enabled ? () => _analyze(context, ref) : null,
                    ),
                    const SizedBox(height: Space.sm),
                    Text(
                      l10n.scanPrivacy,
                      style: context.text.bodySmall?.copyWith(color: brand.muted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.state, required this.onCancel});
  final ScanState state;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final steps = [
      (ScanStage.preparing, l10n.scanPreparing),
      (ScanStage.uploading, l10n.scanStepUpload),
      (ScanStage.analyzing, '${l10n.scanStepIdentify} · ${l10n.scanStepMatch}'),
    ];
    final current = steps.indexWhere((step) => step.$1 == state.stage);
    return Semantics(
      liveRegion: true,
      label: steps[current < 0 ? 0 : current].$2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, (_, label)) in steps.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xxs),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: index < current
                        ? Icon(Icons.check_circle, color: brand.success, size: 22)
                        : index == current
                        ? CircularProgressIndicator(
                            strokeWidth: 2.4,
                            value: state.stage == ScanStage.uploading && state.uploadProgress > 0
                                ? state.uploadProgress
                                : null,
                          )
                        : Icon(Icons.radio_button_unchecked, color: brand.line, size: 22),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      label,
                      style: context.text.bodyMedium?.copyWith(
                        color: index <= current ? brand.ink : brand.muted,
                        fontWeight: index == current ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Space.md),
          OutlinedButton.icon(onPressed: onCancel, icon: const Icon(Icons.close), label: Text(l10n.scanCancelAnalysis)),
        ],
      ),
    );
  }
}

/// Sweeping scan line over the photo while the analysis runs. Replaced by a
/// static tint when the system asks to reduce motion.
class _ScanningOverlay extends StatefulWidget {
  const _ScanningOverlay();

  @override
  State<_ScanningOverlay> createState() => _ScanningOverlayState();
}

class _ScanningOverlayState extends State<_ScanningOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const rust = Color(0xFFE2805C);
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.25),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Align(
              alignment: Alignment(0, -1 + 2 * Curves.easeInOut.transform(_controller.value)),
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: rust,
                  boxShadow: [BoxShadow(color: rust.withValues(alpha: 0.6), blurRadius: 16, spreadRadius: 2)],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
