import 'package:flutter/material.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/widgets/collectible_image.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../../core/widgets/ui.dart';
import '../../domain/community_models.dart';

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
      semanticLabel: community.name,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CommunityAvatar(community: community, size: 48),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(community.name, style: context.text.titleSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      community.description,
                      style: context.text.bodySmall?.copyWith(color: brand.muted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: Space.xs),
                    Wrap(
                      spacing: Space.xs,
                      runSpacing: Space.xxs,
                      children: [
                        InfoChip(label: l10n.membersCount(community.memberCount), icon: Icons.people_outline),
                        if (community.isJoined) InfoChip(label: l10n.joined, icon: Icons.check, color: brand.success),
                      ],
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

class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar({super.key, required this.community, this.size = 48});
  final Community community;
  final double size;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final initial = community.name.isEmpty ? '?' : String.fromCharCode(community.name.runes.first).toUpperCase();
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.sm),
      child: SizedBox(
        width: size,
        height: size,
        child: community.imageUrl != null
            ? CollectibleImage(community.imageUrl, cacheWidth: size)
            : ColoredBox(
                color: brand.ink,
                child: Center(
                  child: Text(
                    initial,
                    style: context.text.titleMedium?.copyWith(color: brand.paper, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
      ),
    );
  }
}
