import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/media/artwork.dart';
import '../../../../core/widgets/collectible_image.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/pressable.dart';
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

/// Full-width cover card: photo banner with name and figures, description
/// underneath.
class CommunityTile extends StatelessWidget {
  const CommunityTile({super.key, required this.community, required this.onTap});
  final Community community;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final l10n = context.l10n;
    return Pressable(
      onTap: onTap,
      semanticLabel: '${community.name}, ${l10n.membersCount(community.memberCount)}',
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 2.3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: brand.surfaceMuted,
                      child: CollectibleImage(communityCover(community), fit: BoxFit.cover, cacheWidth: 720),
                    ),
                    const DecoratedBox(decoration: BoxDecoration(gradient: BrandColors.imageScrim)),
                    if (community.isJoined)
                      Positioned(
                        top: Space.sm,
                        right: Space.sm,
                        child: GlassPanel(
                          radius: Radii.pill,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                l10n.joined,
                                style: Fonts.label(context.text.labelMedium, weight: 680).copyWith(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      left: Space.md,
                      right: Space.md,
                      bottom: Space.sm,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            community.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Fonts.display(context.text.titleLarge, weight: 780).copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${l10n.membersCount(community.memberCount)} · ${l10n.postsCount(community.postCount)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall?.copyWith(color: const Color(0xD9FFFFFF)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (community.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          community.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyMedium?.copyWith(color: brand.muted),
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                      Icon(Icons.arrow_forward_rounded, color: brand.ink, size: 20),
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

/// Compact cover used in horizontal rails ("my communities").
class CommunityCoverCard extends StatelessWidget {
  const CommunityCoverCard({super.key, required this.community, required this.onTap, this.width = 220});
  final Community community;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      width: width,
      child: Pressable(
        onTap: onTap,
        semanticLabel: community.name,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.md),
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
                        style: Fonts.display(context.text.titleSmall, weight: 760).copyWith(color: Colors.white),
                      ),
                      Text(
                        l10n.membersCount(community.memberCount),
                        maxLines: 1,
                        style: context.text.bodySmall?.copyWith(color: const Color(0xCCFFFFFF)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Square thumbnail of the community cover.
class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar({super.key, required this.community, this.size = 48});
  final Community community;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(Radii.sm),
    child: SizedBox.square(
      dimension: size,
      child: ColoredBox(
        color: context.brand.surfaceMuted,
        child: CollectibleImage(communityCover(community), fit: BoxFit.cover, cacheWidth: size * 2),
      ),
    ),
  );
}
