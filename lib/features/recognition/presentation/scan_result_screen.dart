import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/media/artwork.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/collectible_image.dart';
import '../../../core/widgets/kit.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/ui.dart';
import '../../catalog/presentation/publish_collectible_screen.dart';
import '../application/scan_controller.dart';
import '../domain/recognition_models.dart';

class ScanResultScreen extends ConsumerStatefulWidget {
  const ScanResultScreen({super.key});

  @override
  ConsumerState<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends ConsumerState<ScanResultScreen> {
  int? _chosen;

  void _newScan() {
    ref.read(scanControllerProvider.notifier).reset();
    context.pop();
  }

  void _retake() {
    // Back to the preview with the same photo, ready to crop or replace.
    ref.read(scanControllerProvider.notifier).cancel();
    context.pop();
  }

  void _openMatch(CatalogMatch match) {
    if (match.auctionOpen && match.auctionId != null) {
      context.go(Routes.auction(match.auctionId!));
    } else {
      context.go(Routes.collectible(match.collectibleId));
    }
  }

  void _register(RecognitionResult result) {
    final path = ref.read(scanControllerProvider).imagePath;
    context.push(
      Routes.publishCollectible,
      extra: PublishPrefill(
        name: result.productName,
        category: result.catalogCategory ?? result.category,
        photoPath: path,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final result = ref.watch(scanControllerProvider.select((state) => state.result));
    if (result == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(message: l10n.notDetected, actionLabel: l10n.newScan, onAction: _newScan),
      );
    }
    final matches = result.allMatches;
    final requiresChoice = result.suggestedAction == SuggestedAction.reviewMatches && matches.isNotEmpty;
    final selected = _chosen == null
        ? null
        : matches.firstWhere((m) => m.collectibleId == _chosen, orElse: () => matches.first);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.resultTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Space.gutter,
          Space.xs,
          Space.gutter,
          Space.xxl + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          ContentWidth(
            child: _Reveal(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    result.detected ? (result.productName ?? l10n.notDetected) : l10n.notDetected,
                    style: context.text.headlineSmall,
                  ),
                  const SizedBox(height: Space.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: StatusBadge(status: result.purchaseStatus),
                  ),
                  if (result.reason != null) ...[
                    const SizedBox(height: Space.sm),
                    Text(result.reason!, style: context.text.bodyMedium),
                  ],
                  if (result.confidence != null) ...[
                    const SizedBox(height: Space.lg),
                    _ConfidenceBar(value: result.confidence!),
                  ],
                  const SizedBox(height: Space.lg),
                  _Facts(result: result),
                  if (matches.isNotEmpty) ...[
                    const SizedBox(height: Space.xl),
                    Text(requiresChoice ? l10n.alternatives : l10n.catalogMatch, style: context.text.titleMedium),
                    if (requiresChoice) ...[
                      const SizedBox(height: Space.xxs),
                      Text(l10n.chooseMatchHint, style: context.text.bodySmall?.copyWith(color: brand.muted)),
                    ],
                    const SizedBox(height: Space.sm),
                    for (final match in matches) ...[
                      _MatchCard(
                        match: match,
                        selected: requiresChoice
                            ? _chosen == match.collectibleId
                            : identical(match, result.catalogMatch),
                        onTap: requiresChoice
                            ? () => setState(() => _chosen = match.collectibleId)
                            : () => _openMatch(match),
                      ),
                      const SizedBox(height: Space.sm),
                    ],
                  ],
                  const SizedBox(height: Space.lg),
                  ..._actions(context, result, requiresChoice, selected),
                  const SizedBox(height: Space.lg),
                  Text(l10n.resultDisclaimer, style: context.text.bodySmall?.copyWith(color: brand.muted)),
                  if (result.modelVersion != null) ...[
                    const SizedBox(height: Space.xxs),
                    Text(
                      l10n.modelUsed(result.modelVersion!),
                      style: context.text.bodySmall?.copyWith(color: brand.muted),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context, RecognitionResult result, bool requiresChoice, CatalogMatch? selected) {
    final l10n = context.l10n;
    final primary = switch (result.suggestedAction) {
      SuggestedAction.placeBid when result.catalogMatch != null => BusyButton(
        label: l10n.actionPlaceBid,
        icon: AppIcons.gavel,
        onPressed: () => _openMatch(result.catalogMatch!),
      ),
      SuggestedAction.viewRecord when result.catalogMatch != null => BusyButton(
        label: l10n.actionViewRecord,
        icon: AppIcons.package,
        onPressed: () => _openMatch(result.catalogMatch!),
      ),
      SuggestedAction.reviewMatches when requiresChoice => BusyButton(
        label: selected?.auctionOpen == true ? l10n.actionPlaceBid : l10n.actionViewRecord,
        icon: AppIcons.arrowRight,
        onPressed: selected == null ? null : () => _openMatch(selected),
      ),
      SuggestedAction.registerItem => BusyButton(
        label: l10n.actionRegister,
        icon: AppIcons.plus,
        onPressed: () => _register(result),
      ),
      _ => BusyButton(label: l10n.actionRetake, icon: AppIcons.camera, onPressed: _retake),
    };
    return [
      primary,
      const SizedBox(height: Space.xs),
      if (result.suggestedAction != SuggestedAction.retakePhoto)
        OutlinedButton.icon(onPressed: _retake, icon: const Icon(AppIcons.crop), label: Text(l10n.actionRetake)),
      TextButton.icon(onPressed: _newScan, icon: const Icon(AppIcons.refreshCw), label: Text(l10n.newScan)),
    ];
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});
  final PurchaseStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final (label, icon, color) = switch (status) {
      PurchaseStatus.available => (l10n.statusAvailable, AppIcons.gavel, brand.success),
      PurchaseStatus.unavailable => (l10n.statusUnavailable, AppIcons.package, brand.info),
      PurchaseStatus.notInCatalog => (l10n.statusNotInCatalog, AppIcons.scanSearch, brand.muted),
      PurchaseStatus.requiresVerification => (l10n.statusRequiresVerification, AppIcons.circleHelp, brand.warning),
      PurchaseStatus.unsupportedProduct => (l10n.statusUnsupported, AppIcons.circleX, brand.danger),
    };
    return Tag(label, icon: icon, color: color);
  }
}

class _ConfidenceBar extends StatelessWidget {
  const _ConfidenceBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final percent = (value * 100).round();
    final color = value >= 0.75
        ? brand.success
        : value >= 0.4
        ? brand.warning
        : brand.danger;
    return Semantics(
      label: '${l10n.confidenceLabel}: ${l10n.confidenceValue(percent)}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(l10n.confidenceLabel, style: context.text.labelLarge)),
                Text(l10n.confidenceValue(percent), style: context.text.labelLarge?.copyWith(color: color)),
              ],
            ),
            const SizedBox(height: Space.xs),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value),
              duration: Motion.of(context, const Duration(milliseconds: 600)),
              curve: Motion.enter,
              builder: (_, animated, _) => ClipRRect(
                borderRadius: BorderRadius.circular(Radii.pill),
                child: LinearProgressIndicator(
                  value: animated,
                  minHeight: 8,
                  color: color,
                  backgroundColor: brand.line,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.result});
  final RecognitionResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    Widget row(String label, String? value) => value == null
        ? const SizedBox.shrink()
        : Container(
            padding: const EdgeInsets.symmetric(vertical: Space.sm),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: brand.line)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(label, style: context.text.bodyMedium?.copyWith(color: brand.muted)),
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  flex: 3,
                  child: Text(value, style: context.text.bodyMedium, textAlign: TextAlign.end),
                ),
              ],
            ),
          );

    Widget chips(String title, List<String> values, {Color? color}) => values.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.labelLarge),
                const SizedBox(height: Space.xs),
                Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  children: [for (final value in values) InfoChip(label: value, color: color)],
                ),
              ],
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(l10n.category, result.catalogCategory ?? result.category),
        row(l10n.brand, result.brand),
        row(l10n.model, result.model),
        for (final entry in result.attributes.entries) row(entry.key, entry.value),
        chips(l10n.visibleText, result.visibleText),
        chips(l10n.ambiguities, result.ambiguities, color: brand.warning),
      ],
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.match, required this.selected, required this.onTap});
  final CatalogMatch match;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    return Pressable(
      onTap: onTap,
      semanticLabel: '${match.name}, ${l10n.matchScore((match.score * 100).round())}',
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.fast),
        decoration: BoxDecoration(
          color: brand.surfaceRaised,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: selected ? brand.gold : brand.line, width: selected ? 2 : 1),
        ),
        padding: const EdgeInsets.all(Space.sm),
        child: ExcludeSemantics(
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.sm),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: CollectibleImage(
                    artworkFor(name: match.name, category: match.category, url: match.imageUrl),
                    cacheWidth: 64,
                  ),
                ),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(match.name, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: Space.xxs),
                    Wrap(
                      spacing: Space.xs,
                      runSpacing: Space.xxs,
                      children: [
                        InfoChip(label: l10n.matchScore((match.score * 100).round())),
                        if (match.auctionOpen)
                          InfoChip(label: l10n.openAuctionTag, icon: AppIcons.gavel, color: brand.success),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(selected ? AppIcons.circleCheck : AppIcons.chevronRight, color: selected ? brand.gold : brand.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fade + slight upward slide on first build.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.of(context, Motion.slow),
      curve: Motion.enter,
      child: child,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 12 * (1 - value)), child: child),
      ),
    );
  }
}
