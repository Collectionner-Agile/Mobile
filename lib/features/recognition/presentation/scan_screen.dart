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
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/kit.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/application/session_controller.dart';
import '../application/scan_controller.dart';

/// The Scan tab: open the camera (or pick a photo), check the shot, and send
/// it for identification with each step shown as it happens.
class ScanScreen extends ConsumerWidget {
  const ScanScreen({super.key});

  Future<void> _openCamera(BuildContext context, WidgetRef ref, {bool replace = false}) async {
    final path = await context.push<String>(Routes.camera);
    if (path == null) return;
    final controller = ref.read(scanControllerProvider.notifier);
    replace ? controller.replacePhoto(path) : controller.usePhoto(path);
  }

  Future<void> _pickGallery(BuildContext context, WidgetRef ref, {bool replace = false}) async {
    final l10n = context.l10n;
    try {
      final picked = await ImageSourcePicker().pick(ImageSource.gallery);
      if (picked == null) return;
      final controller = ref.read(scanControllerProvider.notifier);
      replace ? controller.replacePhoto(picked.path) : controller.usePhoto(picked.path);
    } on PickException {
      if (context.mounted) showToast(context, l10n.permissionGalleryDenied, error: true);
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
        onCamera: () => _openCamera(context, ref),
        onGallery: () => _pickGallery(context, ref),
      );
    } else {
      body = _Preview(
        key: const ValueKey('preview'),
        state: scan,
        onRetake: () => _openCamera(context, ref, replace: true),
        onReplace: () => _pickGallery(context, ref, replace: true),
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
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              PageTitle(
                title: l10n.navScan,
                subtitle: scan.imagePath == null ? l10n.scanSubtitle : l10n.scanPreviewTitle,
                actions: [
                  if (scan.imagePath != null && !scan.isBusy)
                    CircleIconButton(
                      icon: AppIcons.x,
                      tooltip: l10n.back,
                      onPressed: ref.read(scanControllerProvider.notifier).reset,
                    ),
                ],
              ),
              Expanded(child: FadeSwitch(child: body)),
            ],
          ),
        ),
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
      padding: EdgeInsets.fromLTRB(
        Space.gutter,
        Space.xs,
        Space.gutter,
        Space.xxl + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        ContentWidth(
          child: HeroPanel(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.asset(
                      'assets/images/lab/archive-worktable.webp',
                      fit: BoxFit.cover,
                      cacheWidth: 900,
                      semanticLabel: l10n.scanTitle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(Space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.scanSignInTitle,
                        style: Fonts.display(context.text.headlineSmall, weight: 660).copyWith(color: Brand.ivory),
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        l10n.scanSignInBody,
                        style: context.text.bodyMedium?.copyWith(color: const Color(0xB3F5F1E7)),
                      ),
                      const SizedBox(height: Space.lg),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Brand.gold,
                          foregroundColor: const Color(0xFF1A1305),
                          minimumSize: const Size.fromHeight(54),
                        ),
                        onPressed: () =>
                            context.push(Uri(path: Routes.login, queryParameters: {'from': Routes.scan}).toString()),
                        icon: const Icon(AppIcons.logIn, size: 18),
                        label: Text(l10n.signIn),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
    final enabled = ref.watch(recognitionEnabledProvider).value;
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
              Reveal(
                child: _Viewfinder(enabled: enabled, onCamera: onCamera, onGallery: onGallery),
              ),
              if (enabled == false) ...[
                const SizedBox(height: Space.md),
                _Banner(icon: AppIcons.wifiOff, text: l10n.scanUnavailable, color: brand.warning),
              ],
              const SizedBox(height: Space.xl),
              Text(l10n.scanTipsTitle, style: context.text.titleLarge),
              const SizedBox(height: Space.sm),
              for (final (index, (icon, tip)) in [
                (AppIcons.focus, l10n.scanTip1),
                (AppIcons.sun, l10n.scanTip2),
                (AppIcons.tag, l10n.scanTip3),
              ].indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: Reveal(
                    index: index + 1,
                    child: AppCard(
                      padding: const EdgeInsets.all(Space.md),
                      child: Row(
                        children: [
                          IconBadge(icon, color: brand.gold),
                          const SizedBox(width: Space.sm),
                          Expanded(child: Text(tip, style: context.text.bodyMedium)),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: Space.sm),
              _Banner(icon: AppIcons.shieldCheck, text: l10n.scanPrivacy, color: brand.info),
            ],
          ),
        ),
      ],
    );
  }
}

/// Midnight viewfinder card: a sample piece behind breathing brackets, the
/// service status, and the two ways in.
class _Viewfinder extends StatefulWidget {
  const _Viewfinder({required this.enabled, required this.onCamera, required this.onGallery});
  final bool? enabled;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  State<_Viewfinder> createState() => _ViewfinderState();
}

class _ViewfinderState extends State<_Viewfinder> with SingleTickerProviderStateMixin {
  static const _sample = 'assets/images/collectibles/records/star-destroyer-model.webp';

  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _breath.stop();
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ready = widget.enabled == true;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.xl),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(child: Image.asset(_sample, fit: BoxFit.cover, cacheWidth: 900)),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99060A14), Color(0x40060A14), Color(0xF2060A14)],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 76, 36, 190),
              child: AnimatedBuilder(
                animation: _breath,
                builder: (context, _) => Transform.scale(
                  scale: 0.97 + 0.03 * Curves.easeInOut.transform(_breath.value),
                  child: const CustomPaint(painter: _BracketPainter()),
                ),
              ),
            ),
            Positioned(
              top: Space.md,
              left: Space.md,
              child: Tag(
                widget.enabled == null ? l10n.loadingShort : (ready ? l10n.scanAiReady : l10n.scanAiOff),
                icon: ready ? AppIcons.sparkles : AppIcons.circleAlert,
                onPhoto: true,
              ),
            ),
            Positioned(
              left: Space.lg,
              right: Space.lg,
              bottom: Space.lg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.scanFrameHint,
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(color: const Color(0xE6FFFFFF)),
                  ),
                  const SizedBox(height: Space.md),
                  TapScale(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Brand.gold,
                        foregroundColor: const Color(0xFF1A1305),
                        minimumSize: const Size.fromHeight(56),
                      ),
                      onPressed: widget.onCamera,
                      icon: const Icon(AppIcons.camera, size: 20),
                      label: Text(l10n.openCamera, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(height: Space.xs),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: widget.onGallery,
                    icon: const Icon(AppIcons.images, size: 18),
                    label: Text(l10n.scanGallery, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Brand.goldLight
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const arm = 30.0;
    const r = 18.0;
    final w = size.width;
    final h = size.height;
    for (final (x, y, dx, dy) in [(0.0, 0.0, 1.0, 1.0), (w, 0.0, -1.0, 1.0), (0.0, h, 1.0, -1.0), (w, h, -1.0, -1.0)]) {
      final path = Path()
        ..moveTo(x, y + arm * dy)
        ..lineTo(x, y + r * dy)
        ..quadraticBezierTo(x, y, x + r * dx, y)
        ..lineTo(x + arm * dx, y);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Space.md),
    decoration: BoxDecoration(
      color: color.withValues(alpha: context.isDark ? 0.14 : 0.07),
      borderRadius: BorderRadius.circular(Radii.md),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: Space.sm),
        Expanded(
          child: Text(text, style: context.text.bodySmall?.copyWith(color: context.brand.ink)),
        ),
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
      icon: AppIcons.scanSearch,
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
        final maxImageHeight = (constraints.maxHeight * 0.58).clamp(220.0, 640.0);
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
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxImageHeight),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.xl),
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
                  const SizedBox(height: Space.md),
                  if (!busy)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _Tool(icon: AppIcons.crop, label: l10n.scanCrop, onTap: () => _crop(context, ref)),
                        _Tool(icon: AppIcons.rotateCw, label: l10n.scanRotate, onTap: controller.rotate),
                        _Tool(icon: AppIcons.camera, label: l10n.retakePhoto, onTap: onRetake),
                        _Tool(icon: AppIcons.images, label: l10n.scanGalleryShort, onTap: onReplace),
                      ],
                    ),
                  const SizedBox(height: Space.lg),
                  if (busy)
                    _Progress(state: state, onCancel: controller.cancel)
                  else ...[
                    if (state.stage == ScanStage.failed && state.error != null) ...[
                      _Banner(
                        icon: AppIcons.circleAlert,
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
                      _Banner(icon: AppIcons.wifiOff, text: l10n.scanUnavailable, color: brand.warning),
                      const SizedBox(height: Space.md),
                    ],
                    BusyButton(
                      label: state.stage == ScanStage.failed ? l10n.retry : l10n.scanAnalyze,
                      icon: AppIcons.wandSparkles,
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

class _Tool extends StatelessWidget {
  const _Tool({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: TapScale(
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(Space.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.brand.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.brand.line),
                ),
                child: Icon(icon, size: 20, color: context.brand.ink),
              ),
              const SizedBox(height: Space.xxs),
              Text(label, style: context.text.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    ),
  );
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
      (ScanStage.preparing, l10n.scanPreparing, AppIcons.crop),
      (ScanStage.uploading, l10n.scanStepUpload, AppIcons.upload),
      (ScanStage.analyzing, '${l10n.scanStepIdentify} · ${l10n.scanStepMatch}', AppIcons.sparkles),
    ];
    final current = steps.indexWhere((step) => step.$1 == state.stage);
    return Semantics(
      liveRegion: true,
      label: steps[current < 0 ? 0 : current].$2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              children: [
                for (final (index, (_, label, icon)) in steps.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.xs),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: AnimatedSwitcher(
                            duration: Motion.of(context, Motion.base),
                            child: index < current
                                ? Icon(
                                    AppIcons.circleCheck,
                                    key: const ValueKey('done'),
                                    color: brand.success,
                                    size: 24,
                                  )
                                : index == current
                                ? Stack(
                                    key: const ValueKey('now'),
                                    alignment: Alignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: brand.gold,
                                        value: state.stage == ScanStage.uploading && state.uploadProgress > 0
                                            ? state.uploadProgress
                                            : null,
                                      ),
                                      Icon(icon, size: 15, color: brand.gold),
                                    ],
                                  )
                                : Icon(icon, key: const ValueKey('next'), color: brand.line, size: 20),
                          ),
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
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(AppIcons.x, size: 18),
            label: Text(l10n.scanCancelAnalysis),
          ),
        ],
      ),
    );
  }
}

/// Gold beam sweeping over the photo while the analysis runs, with a soft
/// glow trailing it. A static tint when the system asks to reduce motion.
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
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: ColoredBox(
          color: const Color(0x40060A14),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Align(
              alignment: Alignment(0, -1 + 2 * Curves.easeInOut.transform(_controller.value)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Brand.gold.withValues(alpha: 0), Brand.gold.withValues(alpha: 0.35)],
                      ),
                    ),
                  ),
                  Container(
                    height: 2.5,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0x00F3DCA2), Brand.goldLight, Color(0x00F3DCA2)]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
