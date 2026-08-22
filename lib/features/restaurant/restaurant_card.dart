import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/restaurant.dart';
import 'favorite_button.dart';
import 'restaurant_image.dart';

class RestaurantCard extends StatelessWidget {
  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.onTap,
    required this.onDirections,
    this.distanceMeters,
  });

  final Restaurant restaurant;
  final VoidCallback onTap;
  final VoidCallback onDirections;
  final double? distanceMeters;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 8,
                  child: RestaurantImage(imageUrl: restaurant.coverPhotoUrl),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                    ),
                    child: FavoriteButton(restaurant: restaurant, filled: true),
                  ),
                ),
                Positioned(
                  top: 62,
                  right: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      tooltip: '複製店名',
                      color: Theme.of(context).colorScheme.primary,
                      onPressed: () =>
                          _copyRestaurantName(context, restaurant.name),
                      icon: const Icon(Icons.content_copy_outlined),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _RatingLabel(restaurant: restaurant),
                      if (distanceMeters != null)
                        _DistanceLabel(distanceMeters: distanceMeters!),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    restaurant.address.isEmpty ? '尚未提供地址' : restaurant.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final category in restaurant.categories.take(
                              2,
                            ))
                              _CategoryLabel(label: category),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: onDirections,
                        icon: const Icon(Icons.near_me_outlined, size: 17),
                        label: const Text('帶我去'),
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

Future<void> _copyRestaurantName(BuildContext context, String name) async {
  await Clipboard.setData(ClipboardData(text: name));
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('店名已複製。')));
}

class _CategoryLabel extends StatelessWidget {
  const _CategoryLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DistanceLabel extends StatelessWidget {
  const _DistanceLabel({required this.distanceMeters});

  final double distanceMeters;

  @override
  Widget build(BuildContext context) {
    final label = distanceMeters < 1000
        ? '${distanceMeters.round()} 公尺'
        : '${(distanceMeters / 1000).toStringAsFixed(1)} 公里';
    return _MetadataLabel(icon: Icons.near_me_outlined, label: label);
  }
}

class _RatingLabel extends StatelessWidget {
  const _RatingLabel({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final label = restaurant.ratingCount == 0
        ? '尚無評價'
        : '${restaurant.averageRating.toStringAsFixed(1)} (${restaurant.ratingCount})';
    return _MetadataLabel(
      icon: Icons.star_rounded,
      iconColor: const Color(0xFFF0A531),
      label: label,
    );
  }
}

class _MetadataLabel extends StatelessWidget {
  const _MetadataLabel({
    required this.icon,
    required this.label,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 17,
          color: iconColor ?? Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
