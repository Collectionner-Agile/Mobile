import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/providers.dart';
import '../../../app/router/app_router.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/media/image_pipeline.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_icons.dart';
import '../../../core/widgets/collectible_image.dart';
import '../../../core/widgets/kit.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/ui.dart';
import '../../auctions/application/auction_providers.dart';
import '../../auctions/presentation/create_auction_sheet.dart';
import '../../auth/application/session_controller.dart';
import '../../compare/compare_screen.dart';
import '../../favorites/favorites.dart';
import '../application/catalog_providers.dart';
import '../domain/catalog_models.dart';
import 'photo_viewer_screen.dart';
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
  bool _uploading = false;
  bool _expanded = false;

  Collectible get item => widget.item;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final l10n = context.l10n;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
          child: MenuGroup(
            children: [
              MenuTile(
                icon: AppIcons.camera,
                title: l10n.scanCamera,
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              MenuTile(
                icon: AppIcons.images,
                title: l10n.scanGallery,
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final picked = await ImageSourcePicker().pick(source);
      if (picked == null) return;
      final bytes = await prepareJpeg(picked.path);
      await ref.read(catalogRepositoryProvider).uploadPhoto(item.id, bytes);
      ref
        ..invalidate(collectibleProvider(item.id))
        ..invalidate(collectiblesProvider);
      if (mounted) showToast(context, l10n.photoUploaded, icon: AppIcons.image);
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
      await ref.read(catalogRepositoryProvider).delete(item.id);
      ref.invalidate(collectiblesProvider);
      if (!mounted) return;
      showToast(context, l10n.itemDeleted);
      context.pop();
    } catch (error) {
      if (mounted) showToast(context, describeError(error, l10n), error: true);
    }
  }

  Future<void> _startAuction() async {
    final created = await showCreateAuctionSheet(context, collectible: item);
    if (created == null || !mounted) return;
    ref
      ..invalidate(collectibleProvider(item.id))
      ..invalidate(collectiblesProvider)
      ..invalidate(auctionsProvider);
    showToast(context, context.l10n.auctionCreated, icon: AppIcons.gavel);
    context.go(Routes.auction(created.id));
  }

  Future<void> _ownerMenu() async {
    final l10n = context.l10n;
    final action = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
          child: MenuGroup(
            title: l10n.yourItem,
            children: [
              MenuTile(icon: AppIcons.imagePlus, title: l10n.addPhoto, onTap: () => Navigator.pop(context, 'photo')),
              if (item.auctionId == null)
                MenuTile(
                  icon: AppIcons.gavel,
                  title: l10n.startAuction,
                  color: context.brand.live,
                  onTap: () => Navigator.pop(context, 'auction'),
                ),
              MenuTile(
                icon: AppIcons.trash2,
                title: l10n.deleteItem,
                destructive: true,
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        ),
      ),
    );
    switch (action) {
      case 'photo':
        await _addPhoto();
      case 'auction':
        await _startAuction();
      case 'delete':
        await _delete();
    }
  }

  void _openGallery(List<String> urls, int initial) => PhotoViewerScreen.open(
    context,
    urls: urls,
    initial: initial,
    heroTag: initial == 0 ? 'collectible-${item.id}' : null,
    title: item.name,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    final user = ref.watch(currentUserProvider);
    final isOwner = user != null && user.id == item.ownerId;
    final urls = item.galleryUrls;
    final heroHeight = (MediaQuery.sizeOf(context).height * 0.5).clamp(260.0, 520.0);

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(collectibleProvider(item.id));
              await ref.read(collectibleProvider(item.id).future).catchError((Object _) => item);
            },
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  stretch: true,
                  expandedHeight: heroHeight,
                  backgroundColor: brand.paper,
                  automaticallyImplyLeading: false,
                  leadingWidth: 60,
                  leading: Padding(
                    padding: const EdgeInsets.all(Space.xxs),
                    child: CircleIconButton(
                      icon: AppIcons.arrowLeft,
                      tooltip: l10n.back,
                      onPhoto: true,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  actions: [
                    FavoriteButton(id: item.id, size: 44),
                    const SizedBox(width: Space.xs),
                    CircleIconButton(
                      icon: AppIcons.share2,
                      tooltip: l10n.share,
                      onPhoto: true,
                      onPressed: () => context.push(Routes.sharePiece(item.id)),
                    ),
                    if (isOwner) ...[
                      const SizedBox(width: Space.xs),
                      _uploading
                          ? const SizedBox.square(
                              dimension: 44,
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                            )
                          : CircleIconButton(
                              icon: AppIcons.ellipsis,
                              tooltip: l10n.yourItem,
                              onPhoto: true,
                              onPressed: _ownerMenu,
                            ),
                    ],
                    const SizedBox(width: Space.sm),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [StretchMode.zoomBackground],
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        PageView.builder(
                          controller: _page,
                          itemCount: urls.length,
                          onPageChanged: (index) => setState(() => _index = index),
                          itemBuilder: (context, index) {
                            final image = GestureDetector(
                              onTap: () => _openGallery(urls, index),
                              child: ColoredBox(
                                color: brand.surfaceMuted,
                                child: CollectibleImage(urls[index], cacheWidth: 900, semanticLabel: item.name),
                              ),
                            );
                            return index == 0 ? Hero(tag: 'collectible-${item.id}', child: image) : image;
                          },
                        ),
                        const IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: [0, 0.28, 0.8, 1],
                                colors: [Color(0x66000000), Color(0x00000000), Color(0x00000000), Color(0x33000000)],
                              ),
                            ),
                          ),
                        ),
                        if (urls.length > 1)
                          Positioned(
                            bottom: Space.md,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Semantics(
                                label: l10n.photoCount(_index + 1, urls.length),
                                child: DotsIndicator(count: urls.length, index: _index, onPhoto: true),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ContentWidth(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Reveal(
                            child: Wrap(
                              spacing: Space.xs,
                              runSpacing: Space.xs,
                              children: [
                                if (item.auctionId != null) LivePill(label: l10n.inAuction),
                                if (item.category != null) Tag(item.category!, icon: AppIcons.tag, color: brand.gold),
                                if (item.eraYear != null) Tag('${item.eraYear}', icon: AppIcons.calendar),
                                if (isOwner) Tag(l10n.yourItem, icon: AppIcons.badgeCheck, color: brand.info),
                              ],
                            ),
                          ),
                          const SizedBox(height: Space.sm),
                          Reveal(index: 1, child: Text(item.name, style: context.text.headlineMedium)),
                          const SizedBox(height: Space.md),
                          Reveal(
                            index: 2,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(l10n.declaredValue, style: context.text.bodySmall),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: PriceText(item.value, style: context.text.displaySmall),
                                      ),
                                    ],
                                  ),
                                ),
                                if (item.reviewCount > 0)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      RatingStars(rating: item.rating),
                                      Text(l10n.reviewsCount(item.reviewCount), style: context.text.bodySmall),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          if (item.auctionId != null) ...[
                            const SizedBox(height: Space.lg),
                            Reveal(index: 3, child: _AuctionBanner(auctionId: item.auctionId!)),
                          ],
                          if (item.ownerName != null) ...[
                            const SizedBox(height: Space.lg),
                            AppCard(
                              onTap: () => context.push(Routes.collector(item.ownerId, name: item.ownerName)),
                              padding: const EdgeInsets.all(Space.sm),
                              child: Row(
                                children: [
                                  UserAvatar(name: item.ownerName!, size: 40),
                                  const SizedBox(width: Space.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.ownerName!, style: context.text.titleSmall),
                                        Text(
                                          [
                                            l10n.owner,
                                            if (item.createdAt != null)
                                              formatDate(item.createdAt!, context.languageCode),
                                          ].join(' · '),
                                          style: context.text.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: Space.xl),
                          Text(l10n.aboutObject, style: context.text.titleLarge),
                          const SizedBox(height: Space.xs),
                          AnimatedSize(
                            duration: Motion.of(context, Motion.base),
                            curve: Motion.enter,
                            alignment: Alignment.topCenter,
                            child: Text(
                              item.description.isEmpty ? '—' : item.description,
                              maxLines: _expanded ? null : 4,
                              overflow: _expanded ? null : TextOverflow.fade,
                              style: context.text.bodyLarge?.copyWith(color: brand.ink.withValues(alpha: 0.86)),
                            ),
                          ),
                          if (item.description.length > 180)
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton(
                                onPressed: () => setState(() => _expanded = !_expanded),
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: brand.gold),
                                child: Text(_expanded ? l10n.readLess : l10n.readMore),
                              ),
                            ),
                          const SizedBox(height: Space.md),
                          Text('${l10n.declaredValue}. ${l10n.declaredValueNote}', style: context.text.bodySmall),
                        ],
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
                const SliverToBoxAdapter(child: SizedBox(height: Space.xxl)),
              ],
            ),
          ),
        ),
        BottomCta(
          child: item.auctionId != null
              ? BusyButton(
                  label: l10n.actionPlaceBid,
                  icon: AppIcons.gavel,
                  color: brand.live,
                  onPressed: () => context.go(Routes.auction(item.auctionId!)),
                )
              : isOwner
              ? BusyButton(label: l10n.startAuction, icon: AppIcons.gavel, onPressed: _startAuction)
              : Row(
                  children: [
                    Expanded(child: _SaveButton(id: item.id)),
                    const SizedBox(width: Space.sm),
                    Expanded(child: CompareButton(id: item.id)),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Primary action for visitors: keep the piece in favourites.
class _SaveButton extends ConsumerWidget {
  const _SaveButton({required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final saved = ref.watch(favoritesProvider).contains(id);
    return BusyButton(
      label: saved ? l10n.savedInFavorites : l10n.addFavorite,
      icon: saved ? AppIcons.check : AppIcons.heart,
      outlined: saved,
      onPressed: () {
        HapticFeedback.lightImpact();
        ref.read(favoritesProvider.notifier).toggle(id);
      },
    );
  }
}

class _AuctionBanner extends StatelessWidget {
  const _AuctionBanner({required this.auctionId});
  final int auctionId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final brand = context.brand;
    return AppCard(
      onTap: () => context.go(Routes.auction(auctionId)),
      color: brand.live.withValues(alpha: context.isDark ? 0.14 : 0.07),
      border: false,
      shadow: false,
      child: Row(
        children: [
          IconBadge(AppIcons.gavel, color: brand.live, solid: true),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.inAuction, style: context.text.titleSmall?.copyWith(color: brand.live)),
                Text(l10n.auctionBannerBody, style: context.text.bodySmall),
              ],
            ),
          ),
          Icon(AppIcons.chevronRight, color: brand.live, size: 20),
        ],
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.zero,
    children: const [
      Skeleton(height: 380, radius: 0),
      Padding(
        padding: EdgeInsets.all(Space.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(width: 140, height: 22, radius: Radii.pill),
            SizedBox(height: Space.md),
            Skeleton(height: 26),
            SizedBox(height: Space.sm),
            Skeleton(width: 180, height: 26),
            SizedBox(height: Space.lg),
            Skeleton(height: 72, radius: Radii.lg),
          ],
        ),
      ),
    ],
  );
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
