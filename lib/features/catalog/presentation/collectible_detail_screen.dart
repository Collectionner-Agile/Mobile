import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/providers.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/media/image_pipeline.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/collectible_image.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/slab.dart';
import '../../../core/widgets/ui.dart';
import '../../auctions/application/auction_providers.dart';
import '../../auctions/presentation/create_auction_sheet.dart';
import '../../auth/application/session_controller.dart';
import '../application/catalog_providers.dart';
import '../domain/catalog_models.dart';
import 'widgets/collectible_card.dart';
import 'widgets/social_sections.dart';

class CollectibleDetailScreen extends ConsumerWidget {
  const CollectibleDetailScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(collectibleProvider(id));
    return Scaffold(
      body: AsyncSwitch(
        value: item,
        onRetry: () => ref.invalidate(collectibleProvider(id)),
        loading: const _DetailSkeleton(),
        data: (collectible) => _DetailBody(item: collectible),
      ),
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({required this.item});
  final Collectible item;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  final _page = PageController();
  int _index = 0;

  /// True once the gallery has scrolled under the toolbar; shows the name there.
  bool _collapsed = false;
  bool _uploading = false;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final l10n = context.l10n;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.scanCamera),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.scanGallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final picked = await ImageSourcePicker().pick(source);
      if (picked == null) return;
      final bytes = await prepareJpeg(picked.path);
      await ref.read(catalogRepositoryProvider).uploadPhoto(widget.item.id, bytes);
      ref
        ..invalidate(collectibleProvider(widget.item.id))
        ..invalidate(collectiblesProvider);
      if (mounted) showToast(context, l10n.photoUploaded);
    } on PickException catch (error) {
      if (mounted && error.reason == PickFailure.permissionDenied) {
        showToast(
          context,
          source == ImageSource.camera ? l10n.permissionCameraDenied : l10n.permissionGalleryDenied,
          error: true,
        );
      }
    } on ImageProcessingException catch (error) {
      if (!mounted) return;
      showToast(
        context,
        error.reason == ImageProcessingFailure.tooLarge ? l10n.imageTooLarge : l10n.imageUnreadable,
        error: true,
      );
    } catch (error) {
      if (mounted) showToast(context, describeError(error, l10n), error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l10n.deleteItem,
      body: l10n.deleteItemConfirm,
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(catalogRepositoryProvider).delete(widget.item.id);
      ref.invalidate(collectiblesProvider);
      if (!mounted) return;
      showToast(context, l10n.itemDeleted);
      context.pop();
    } catch (error) {
      if (mounted) showToast(context, describeError(error, l10n), error: true);
    }
  }

  Future<void> _startAuction() async {
    final created = await showCreateAuctionSheet(context, collectible: widget.item);
    if (created == null || !mounted) return;
    ref
      ..invalidate(collectibleProvider(widget.item.id))
      ..invalidate(collectiblesProvider)
      ..invalidate(auctionsProvider);
    showToast(context, context.l10n.auctionCreated);
    context.go(Routes.auction(created.id));
  }

  void _openGallery(List<String> urls, int initial) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullscreenGallery(urls: urls, initial: initial, heroTag: 'collectible-${widget.item.id}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final l10n = context.l10n;
    final brand = context.brand;
    final user = ref.watch(currentUserProvider);
    final isOwner = user != null && user.id == item.ownerId;
    final urls = item.galleryUrls;
    final width = MediaQuery.sizeOf(context).width;
    final galleryHeight = (width * 0.92).clamp(260.0, 520.0);

    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (notification) {
        if (notification.depth == 0) {
          final collapsed = notification.metrics.pixels > galleryHeight - kToolbarHeight - 24;
          if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            expandedHeight: galleryHeight,
            backgroundColor: brand.paper,
            title: AnimatedSwitcher(
              duration: Motion.of(context, Motion.fast),
              child: _collapsed
                  ? Text(item.name, key: const ValueKey('title'), maxLines: 1, overflow: TextOverflow.ellipsis)
                  : const SizedBox.shrink(),
            ),
            leading: Padding(
              padding: const EdgeInsets.all(6),
              child: BackButton(
                style: IconButton.styleFrom(
                  backgroundColor: brand.surface,
                  foregroundColor: brand.ink,
                  side: BorderSide(color: brand.line),
                ),
              ),
            ),
            actions: [
              if (isOwner)
                PopupMenuButton<String>(
                  onSelected: (value) => switch (value) {
                    'photo' => _addPhoto(),
                    'auction' => _startAuction(),
                    'delete' => _delete(),
                    _ => null,
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'photo',
                      child: ListTile(leading: const Icon(Icons.add_a_photo_outlined), title: Text(l10n.addPhoto)),
                    ),
                    if (!item.isLinkedToProcess && item.auctionId == null)
                      PopupMenuItem(
                        value: 'auction',
                        child: ListTile(leading: const Icon(Icons.gavel_outlined), title: Text(l10n.startAuction)),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline, color: brand.danger),
                        title: Text(l10n.deleteItem),
                      ),
                    ),
                  ],
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: brand.surfaceMuted),
                  if (urls.isEmpty)
                    Hero(
                      tag: 'collectible-${item.id}',
                      child: CollectibleImage(null, semanticLabel: item.name),
                    )
                  else
                    PageView.builder(
                      controller: _page,
                      itemCount: urls.length,
                      onPageChanged: (value) => setState(() => _index = value),
                      itemBuilder: (context, index) {
                        final image = GestureDetector(
                          onTap: () => _openGallery(urls, index),
                          child: CollectibleImage(
                            urls[index],
                            fit: BoxFit.cover,
                            semanticLabel: item.name,
                            cacheWidth: width,
                          ),
                        );
                        return index == 0 ? Hero(tag: 'collectible-${item.id}', child: image) : image;
                      },
                    ),
                  const IgnorePointer(
                    child: DecoratedBox(decoration: BoxDecoration(gradient: BrandColors.imageScrim)),
                  ),
                  // Name and category on frosted glass, price in a pill, page dots.
                  Positioned(
                    left: Space.md,
                    right: Space.md,
                    bottom: Space.md,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GlassPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  item.name,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.headlineSmall?.copyWith(color: Colors.white),
                                ),
                              ),
                              if (item.category != null) ...[
                                const SizedBox(height: Space.xxs),
                                Text(
                                  item.category!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.bodyMedium?.copyWith(color: const Color(0xCCFFFFFF)),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: Space.sm),
                        Row(
                          children: [
                            Flexible(child: PricePill(label: context.money(item.value))),
                            const Spacer(),
                            if (urls.length > 1)
                              Semantics(
                                label: l10n.photoCount(_index + 1, urls.length),
                                child: ExcludeSemantics(
                                  child: PageDots(count: urls.length, index: _index),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_uploading) const Positioned(left: 0, right: 0, bottom: 0, child: LinearProgressIndicator()),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: DecoratedBox(
              decoration: BoxDecoration(color: brand.paper),
              child: ContentWidth(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.auctionId != null || isOwner) ...[
                        Wrap(
                          spacing: Space.xs,
                          runSpacing: Space.xs,
                          children: [
                            if (item.auctionId != null) LiveBadge(label: l10n.inAuction),
                            if (isOwner) InfoChip(label: l10n.yourItem, icon: Icons.person_outline, color: brand.info),
                          ],
                        ),
                        const SizedBox(height: Space.sm),
                      ],
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: Space.md,
                        runSpacing: Space.xs,
                        children: [
                          if (item.reviewCount > 0)
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: Space.xs,
                              children: [
                                RatingStars(rating: item.rating),
                                Text(l10n.reviewsCount(item.reviewCount), style: context.text.bodySmall),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: Space.xxs),
                      Text('${l10n.declaredValue}. ${l10n.declaredValueNote}', style: context.text.bodySmall),
                      if (item.auctionId != null) ...[
                        const SizedBox(height: Space.lg),
                        _AuctionBanner(auctionId: item.auctionId!),
                      ],
                      const SizedBox(height: Space.lg),
                      _Particulars(
                        rows: [
                          if (item.eraYear != null) (l10n.year, '${item.eraYear}'),
                          if (item.ownerName != null) (l10n.owner, item.ownerName!),
                          if (item.category != null) (l10n.category, item.category!),
                          if (item.reviewCount > 0) (l10n.reviews, l10n.reviewsCount(item.reviewCount)),
                        ],
                      ),
                      const SizedBox(height: Space.xl),
                      Text(l10n.aboutObject, style: context.text.titleLarge),
                      const SizedBox(height: Space.xs),
                      Text(item.description, style: context.text.bodyLarge?.copyWith(color: brand.muted)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (item.category != null) SliverToBoxAdapter(child: _Related(item: item)),
          SliverToBoxAdapter(
            child: ContentWidth(
              child: ReviewsSection(collectibleId: item.id, ownerId: item.ownerId),
            ),
          ),
          SliverToBoxAdapter(
            child: ContentWidth(child: CommentsSection.collectible(collectibleId: item.id)),
          ),
          SliverToBoxAdapter(child: SizedBox(height: Space.xxl + MediaQuery.paddingOf(context).bottom)),
        ],
      ),
    );
  }
}

class _AuctionBanner extends StatelessWidget {
  const _AuctionBanner({required this.auctionId});
  final int auctionId;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final fg = heroForeground(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return HeroPanel(
      padding: const EdgeInsets.all(Space.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LiveBadge(label: context.l10n.liveNow),
                const SizedBox(height: Space.xs),
                Text(context.l10n.inAuction, style: context.text.titleMedium?.copyWith(color: fg)),
              ],
            ),
          ),
          const SizedBox(width: Space.sm),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: dark ? brand.ink : brand.paper,
              foregroundColor: dark ? brand.paper : brand.ink,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: Space.md),
            ),
            onPressed: () => context.go(Routes.auction(auctionId)),
            child: Text(context.l10n.viewAuction),
          ),
        ],
      ),
    );
  }
}

/// Catalogue particulars as label/value rows between hairlines.
class _Particulars extends StatelessWidget {
  const _Particulars({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Column(
      children: [
        for (final (label, value) in rows)
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: brand.line)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(label, style: Fonts.label(context.text.bodyMedium).copyWith(color: brand.muted)),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    flex: 3,
                    child: Text(value, textAlign: TextAlign.end, style: Fonts.figures(context.text.titleSmall)),
                  ),
                ],
              ),
            ),
          ),
        if (rows.isNotEmpty) Divider(height: 1, color: brand.line),
      ],
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        AspectRatio(aspectRatio: 1, child: Skeleton(radius: 0)),
        Padding(
          padding: EdgeInsets.all(Space.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeleton(width: 90, height: 10),
              SizedBox(height: Space.sm),
              Skeleton(height: 24),
              SizedBox(height: Space.sm),
              Skeleton(width: 140, height: 20),
              SizedBox(height: Space.xl),
              Skeleton(height: 12),
              SizedBox(height: Space.xs),
              Skeleton(height: 12),
              SizedBox(height: Space.xs),
              Skeleton(width: 200, height: 12),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FullscreenGallery extends StatefulWidget {
  const _FullscreenGallery({required this.urls, required this.initial, required this.heroTag});
  final List<String> urls;
  final int initial;
  final String heroTag;

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _controller = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(context.l10n.photoCount(_index + 1, widget.urls.length)),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.urls.length,
        onPageChanged: (value) => setState(() => _index = value),
        itemBuilder: (_, index) => InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(child: CollectibleImage(widget.urls[index], fit: BoxFit.contain)),
        ),
      ),
    );
  }
}

/// Other pieces of the same category, from the loaded catalogue.
class _Related extends ConsumerWidget {
  const _Related({required this.item});
  final Collectible item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final related = (ref.watch(collectiblesProvider).value ?? const <Collectible>[])
        .where((other) => other.category == item.category && other.id != item.id)
        .take(8)
        .toList();
    if (related.isEmpty) return const SizedBox.shrink();
    const width = 168.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: context.l10n.relatedIn(item.category!)),
        SizedBox(
          height: width + collectibleCardTextHeight(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            itemCount: related.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.md),
            itemBuilder: (context, index) => CollectibleCard(
              width: width,
              item: related[index],
              onTap: () => context.push(Routes.collectible(related[index].id)),
            ),
          ),
        ),
      ],
    );
  }
}
