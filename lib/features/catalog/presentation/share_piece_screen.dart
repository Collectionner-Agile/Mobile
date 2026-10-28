import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/collectible_image.dart';
import '../../../core/widgets/kit.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/ui.dart';
import '../application/catalog_providers.dart';
import '../domain/catalog_models.dart';

/// Deep link that opens a piece in the app.
String pieceLink(int id) => 'collectionner://app/catalog/item/$id';

/// Share a piece as a card: the piece cased in a slab (dark or light) to
/// send anywhere, its link, or a short text.
class SharePieceScreen extends ConsumerStatefulWidget {
  const SharePieceScreen({super.key, required this.id});
  final int id;

  @override
  ConsumerState<SharePieceScreen> createState() => _SharePieceScreenState();
}

class _SharePieceScreenState extends ConsumerState<SharePieceScreen> {
  final _card = GlobalKey();
  bool _dark = true;
  bool _busy = false;

  String _text(Collectible item) =>
      '${item.name} · ${context.money(item.value)}\n${context.l10n.shareFoundOn}\n${pieceLink(item.id)}';

  Future<void> _shareImage(Collectible item) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final boundary = _card.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (png == null || !mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(png.buffer.asUint8List(), mimeType: 'image/png', name: 'collectionner-${item.id}.png'),
          ],
          text: _text(item),
          subject: item.name,
        ),
      );
    } catch (_) {
      if (mounted) showToast(context, l10n.shareFailed, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareText(Collectible item) async {
    try {
      await SharePlus.instance.share(ShareParams(text: _text(item), subject: item.name));
    } catch (_) {
      if (mounted) showToast(context, context.l10n.shareFailed, error: true);
    }
  }

  Future<void> _copyLink(Collectible item) async {
    await Clipboard.setData(ClipboardData(text: pieceLink(item.id)));
    if (mounted) showToast(context, context.l10n.linkCopied, icon: Icons.link_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final item = ref.watch(collectibleProvider(widget.id));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.shareTitle)),
      body: AsyncSwitch(
        value: item,
        onRetry: () => ref.invalidate(collectibleProvider(widget.id)),
        data: (piece) => ListView(
          padding: EdgeInsets.fromLTRB(
            Space.gutter,
            Space.xs,
            Space.gutter,
            Space.xxl + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            ContentWidth(
              maxWidth: 460,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedTabs(
                    labels: [l10n.shareStyleDark, l10n.shareStyleLight],
                    icons: const [Icons.dark_mode_outlined, Icons.light_mode_outlined],
                    index: _dark ? 0 : 1,
                    onChanged: (index) => setState(() => _dark = index == 0),
                  ),
                  const SizedBox(height: Space.lg),
                  Reveal(
                    child: RepaintBoundary(
                      key: _card,
                      child: AnimatedSwitcher(
                        duration: Motion.of(context, Motion.base),
                        child: _ShareCard(key: ValueKey(_dark), item: piece, dark: _dark),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  BusyButton(
                    label: l10n.shareImage,
                    icon: Icons.share_outlined,
                    busy: _busy,
                    onPressed: () => _shareImage(piece),
                  ),
                  const SizedBox(height: Space.sm),
                  Row(
                    children: [
                      Expanded(
                        child: BusyButton(
                          label: l10n.copyLink,
                          icon: Icons.link_rounded,
                          outlined: true,
                          onPressed: () => _copyLink(piece),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: BusyButton(
                          label: l10n.shareText,
                          icon: Icons.chat_bubble_outline_rounded,
                          outlined: true,
                          onPressed: () => _shareText(piece),
                        ),
                      ),
                    ],
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

/// The card that gets shared: the piece cased like a graded collectible.
/// Fixed colours (not the app theme) so the image looks the same wherever it
/// lands.
class _ShareCard extends StatelessWidget {
  const _ShareCard({super.key, required this.item, required this.dark});
  final Collectible item;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = dark ? BrandColors.dark : BrandColors.light;
    final meta = [?item.category, if (item.eraYear != null) '${item.eraYear}'].join(' · ');
    final label = Fonts.label(const TextStyle(fontSize: 11.5), weight: 700);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.paper,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(Radii.xs),
                  child: Image.asset('assets/branding/site-icon-512.png', width: 26, height: 26, cacheWidth: 80),
                ),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: Text(
                    l10n.appName,
                    style: Fonts.display(const TextStyle(fontSize: 16), weight: 820).copyWith(color: c.ink),
                  ),
                ),
                if (item.auctionId != null) LivePill(label: l10n.inAuction),
              ],
            ),
            const SizedBox(height: Space.md),
            // The slab: label strip over the image well, one hairline frame.
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: c.line),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.md - 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: c.line)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.lotRef(item.id.toString().padLeft(4, '0')),
                              maxLines: 1,
                              style: Fonts.figures(label).copyWith(color: c.ink),
                            ),
                          ),
                          if (item.category != null)
                            Flexible(
                              child: Text(
                                item.category!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: label.copyWith(color: c.muted),
                              ),
                            ),
                        ],
                      ),
                    ),
                    AspectRatio(
                      aspectRatio: 1,
                      child: ColoredBox(color: c.surfaceMuted, child: CollectibleImage(item.artwork, cacheWidth: 900)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.md),
            Text(
              item.name,
              style: Fonts.display(const TextStyle(fontSize: 24, height: 1.15), weight: 760).copyWith(color: c.ink),
            ),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: Space.xxs),
              Text(meta, style: TextStyle(fontSize: 13, color: c.muted)),
            ],
            const SizedBox(height: Space.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.declaredValue.toUpperCase(),
                        style: Fonts.eyebrow(const TextStyle()).copyWith(color: c.muted, fontSize: 10),
                      ),
                      Text(
                        context.money(item.value),
                        style: Fonts.figures(Fonts.display(const TextStyle(fontSize: 26), weight: 760))
                            .copyWith(color: c.ink),
                      ),
                    ],
                  ),
                ),
                if (item.reviewCount > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 16, color: c.gold),
                      const SizedBox(width: 3),
                      Text(item.rating.toStringAsFixed(1), style: TextStyle(fontSize: 14, color: c.ink)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
