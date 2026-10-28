import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/collectible_image.dart';
import '../../../core/widgets/kit.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/ui.dart';
import '../application/catalog_providers.dart';
import '../domain/catalog_models.dart';

/// Deep link that opens a piece in the app.
String pieceLink(int id) => 'collectionner://app/catalog/item/$id';

/// Share a piece as a card: a premium image of it (midnight or ivory) to
/// send anywhere, its link, or a short text.
class SharePieceScreen extends ConsumerStatefulWidget {
  const SharePieceScreen({super.key, required this.id});
  final int id;

  @override
  ConsumerState<SharePieceScreen> createState() => _SharePieceScreenState();
}

class _SharePieceScreenState extends ConsumerState<SharePieceScreen> {
  final _card = GlobalKey();
  bool _midnight = true;
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
    if (mounted) showToast(context, context.l10n.linkCopied, icon: AppIcons.link);
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
                    labels: [l10n.shareStyleMidnight, l10n.shareStyleIvory],
                    icons: const [AppIcons.moon, AppIcons.sun],
                    index: _midnight ? 0 : 1,
                    onChanged: (index) => setState(() => _midnight = index == 0),
                  ),
                  const SizedBox(height: Space.lg),
                  Reveal(
                    child: RepaintBoundary(
                      key: _card,
                      child: AnimatedSwitcher(
                        duration: Motion.of(context, Motion.base),
                        child: _ShareCard(key: ValueKey(_midnight), item: piece, midnight: _midnight),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  BusyButton(
                    label: l10n.shareImage,
                    icon: AppIcons.share2,
                    busy: _busy,
                    onPressed: () => _shareImage(piece),
                  ),
                  const SizedBox(height: Space.sm),
                  Row(
                    children: [
                      Expanded(
                        child: BusyButton(
                          label: l10n.copyLink,
                          icon: AppIcons.link,
                          outlined: true,
                          onPressed: () => _copyLink(piece),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(
                        child: BusyButton(
                          label: l10n.shareText,
                          icon: AppIcons.messageCircle,
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

/// The card that gets shared. Fixed colours (not the app theme) so the image
/// looks the same wherever it lands.
class _ShareCard extends StatelessWidget {
  const _ShareCard({super.key, required this.item, required this.midnight});
  final Collectible item;
  final bool midnight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ink = midnight ? Brand.ivory : const Color(0xFF121826);
    final muted = midnight ? const Color(0xB3F5F1E7) : const Color(0xFF686F80);
    final meta = [?item.category, if (item.eraYear != null) '${item.eraYear}'].join(' · ');
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.xl),
        gradient: midnight
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A2A4D), Brand.midnight, Color(0xFF070B15)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), Color(0xFFF5F3EE), Color(0xFFEDE6D6)],
              ),
        border: Border.all(color: midnight ? const Color(0x33DDB563) : const Color(0xFFE5E1D8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: Image.asset('assets/branding/site-icon-512.png', width: 26, height: 26, cacheWidth: 80),
                ),
                const SizedBox(width: Space.xs),
                Expanded(
                  child: Text(
                    l10n.appName,
                    style: Fonts.display(const TextStyle(fontSize: 16), weight: 660).copyWith(color: ink),
                  ),
                ),
                if (item.auctionId != null) LivePill(label: l10n.inAuction),
              ],
            ),
            const SizedBox(height: Space.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.lg),
              child: AspectRatio(
                aspectRatio: 1,
                child: ColoredBox(
                  color: midnight ? const Color(0xFF16203A) : const Color(0xFFECE9E2),
                  child: CollectibleImage(item.artwork, cacheWidth: 900),
                ),
              ),
            ),
            const SizedBox(height: Space.md),
            Text(
              item.name,
              style: Fonts.display(const TextStyle(fontSize: 24, height: 1.15), weight: 660).copyWith(color: ink),
            ),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: Space.xxs),
              Text(meta, style: TextStyle(fontSize: 13, color: muted)),
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
                        style: Fonts.eyebrow(const TextStyle()).copyWith(color: muted, fontSize: 10),
                      ),
                      Text(
                        context.money(item.value),
                        style: Fonts.figures(Fonts.display(const TextStyle(fontSize: 26), weight: 700))
                            .copyWith(color: midnight ? Brand.goldLight : const Color(0xFFB4842F)),
                      ),
                    ],
                  ),
                ),
                if (item.reviewCount > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(AppIcons.star, size: 15, color: Brand.gold),
                      const SizedBox(width: 3),
                      Text(item.rating.toStringAsFixed(1), style: TextStyle(fontSize: 14, color: ink)),
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
