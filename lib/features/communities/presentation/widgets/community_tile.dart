import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/media/artwork.dart';
import '../../../../core/widgets/app_icons.dart';
import '../../../../core/widgets/collectible_image.dart';
import '../../../../core/widgets/kit.dart';
import '../../../../core/widgets/ui.dart';
import '../../domain/community_models.dart';

/// Cover for a community: its own image, else the curated artwork that
/// matches its name or description (a retro-gaming group gets the console).
String communityCover(Community community) => community.imageUrl != null && community.imageUrl!.trim().isNotEmpty
    ? community.imageUrl!
    : artworkFor(
        name: '${community.name} ${community.description}',
        category: '${community.name} ${community.description}',
      );

/// Compact row card: cover thumbnail, name, one line of description and the
/// member count, readable at a glance.
class CommunityTile extends StatelessWidget {
  const CommunityTile({super.key, required this.community, required this.onTap});
  final Community community;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final l10n = context.l10n;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Space.sm),
      semanticLabel: '${community.name}, ${l10n.membersCount(community.memberCount)}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            CommunityAvatar(community: community, size: 76),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(community.name, style: context.text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (community.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      community.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall,
                    ),
                  ],
                  const SizedBox(height: Space.xs),
                  Wrap(
                    spacing: Space.xs,
                    runSpacing: Space.xxs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Tag(l10n.membersCount(community.memberCount), icon: AppIcons.users, color: brand.muted),
                      if (community.isJoined) Tag(l10n.joined, icon: AppIcons.check, color: brand.success),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.xs),
            Icon(AppIcons.chevronRight, color: brand.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Cover card for horizontal rails ("my communities"): photo, scrim, name.
class CommunityCoverCard extends StatelessWidget {
  const CommunityCoverCard({super.key, required this.community, required this.onTap, this.width = 210});
  final Community community;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      width: width,
      child: AppCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        radius: Radii.lg,
        semanticLabel: community.name,
        child: ExcludeSemantics(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: context.brand.surfaceMuted,
                child: CollectibleImage(communityCover(community), fit: BoxFit.cover, cacheWidth: 440),
              ),
              const DecoratedBox(decoration: BoxDecoration(gradient: BrandColors.imageScrim)),
              Positioned(
                left: Space.sm,
                right: Space.sm,
                bottom: Space.sm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      community.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Fonts.display(context.text.titleMedium, weight: 680).copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.membersCount(community.memberCount),
                      maxLines: 1,
                      style: context.text.bodySmall?.copyWith(color: const Color(0xD9FFFFFF)),
                    ),
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

/// Rounded-square thumbnail of the community cover.
class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar({super.key, required this.community, this.size = 48});
  final Community community;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.26),
    child: SizedBox.square(
      dimension: size,
      child: ColoredBox(
        color: context.brand.surfaceMuted,
        child: CollectibleImage(communityCover(community), fit: BoxFit.cover, cacheWidth: size * 2),
      ),
    ),
  );
}
