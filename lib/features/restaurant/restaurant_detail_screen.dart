import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/external_navigation_service.dart';
import '../../data/models/restaurant.dart';
import '../../data/models/restaurant_photo.dart';
import '../../data/models/restaurant_review.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/contribution_providers.dart';
import '../../data/providers/moderation_providers.dart';
import '../../data/providers/restaurant_providers.dart';
import '../../data/repositories/contribution_repository.dart';
import 'duplicate_restaurant_sheet.dart';
import 'favorite_button.dart';
import 'photo_upload_button.dart';
import 'restaurant_image.dart';
import 'restaurant_moderation_sheets.dart';
import 'review_form_sheet.dart';

class RestaurantDetailScreen extends ConsumerStatefulWidget {
  const RestaurantDetailScreen({
    super.key,
    required this.restaurantId,
    this.showPhotoUploadFailureNotice = false,
    this.openEditSheet = false,
  });

  final String restaurantId;
  final bool showPhotoUploadFailureNotice;
  final bool openEditSheet;

  @override
  ConsumerState<RestaurantDetailScreen> createState() =>
      _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState
    extends ConsumerState<RestaurantDetailScreen> {
  bool _editSheetOpened = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(restaurantProvider(widget.restaurantId), (previous, next) {
      next.whenData((restaurant) {
        final targetId = restaurant?.mergedIntoRestaurantId;
        if (restaurant?.isMerged == true && targetId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            context.go('/restaurants/$targetId');
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('這家店已合併，已前往保留中的店家。')));
          });
        }
      });
    });

    final restaurantState = ref.watch(restaurantProvider(widget.restaurantId));
    final restaurant = restaurantState.asData?.value;
    return Scaffold(
      body: restaurantState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorBody(
          onRetry: () =>
              ref.invalidate(restaurantProvider(widget.restaurantId)),
        ),
        data: (restaurant) {
          if (restaurant == null) {
            return const _MissingRestaurantBody();
          }
          if (restaurant.isMerged) {
            return const Center(child: CircularProgressIndicator());
          }
          if (widget.openEditSheet && !_editSheetOpened) {
            _editSheetOpened = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                showRestaurantEditSheet(context, ref, restaurant);
              }
            });
          }
          return _RestaurantDetailBody(
            restaurant: restaurant,
            showPhotoUploadFailureNotice: widget.showPhotoUploadFailureNotice,
          );
        },
      ),
      floatingActionButton: restaurant == null
          ? null
          : _MoreActionsButton(restaurant: restaurant),
    );
  }
}

class _RestaurantDetailBody extends ConsumerWidget {
  const _RestaurantDetailBody({
    required this.restaurant,
    required this.showPhotoUploadFailureNotice,
  });

  final Restaurant restaurant;
  final bool showPhotoUploadFailureNotice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(restaurantPhotosProvider(restaurant.id));
    final reviews = ref.watch(restaurantReviewsProvider(restaurant.id));
    final currentUid = ref.watch(authStateChangesProvider).asData?.value?.uid;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 330,
          pinned: true,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.of(context).maybePop(),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.arrow_back),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: _RestaurantHero(restaurant: restaurant),
          ),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showPhotoUploadFailureNotice) ...[
                      const _PhotoUploadFailureNotice(),
                      const SizedBox(height: 20),
                    ],
                    _OverviewCard(restaurant: restaurant),
                    const SizedBox(height: 20),
                    _ActionRow(restaurant: restaurant),
                    const SizedBox(height: 36),
                    const _SectionHeader(title: '推薦菜色'),
                    const SizedBox(height: 12),
                    _DishesPanel(dishes: restaurant.recommendedDishes),
                    const SizedBox(height: 36),
                    if (restaurant.amenities.isNotEmpty) ...[
                      const _SectionHeader(title: '店家設施'),
                      const SizedBox(height: 12),
                      _AmenitiesPanel(amenities: restaurant.amenities),
                      const SizedBox(height: 36),
                    ],
                    _SectionHeader(
                      title: '店家照片',
                      subtitle: '一起補足這家店的模樣',
                      action: PhotoUploadButton(restaurantId: restaurant.id),
                    ),
                    const SizedBox(height: 12),
                    photos.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, stackTrace) => const _SectionMessage(
                        icon: Icons.broken_image_outlined,
                        message: '照片載入失敗，請稍後再試。',
                      ),
                      data: (items) => items.isEmpty
                          ? const _SectionMessage(
                              icon: Icons.add_a_photo_outlined,
                              message: '還沒有照片，成為第一位分享的人吧。',
                            )
                          : _PhotoStrip(restaurant: restaurant, photos: items),
                    ),
                    const SizedBox(height: 36),
                    _SectionHeader(
                      title: '大家怎麼說',
                      subtitle: '留下你的用餐心得',
                      action: TextButton.icon(
                        onPressed: () =>
                            showReviewFormSheet(context, ref, restaurant.id),
                        icon: const Icon(Icons.rate_review_outlined),
                        label: const Text('寫評論'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    reviews.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, stackTrace) => const _SectionMessage(
                        icon: Icons.comment_outlined,
                        message: '評論載入失敗，請稍後再試。',
                      ),
                      data: (items) => items.isEmpty
                          ? const _SectionMessage(
                              icon: Icons.chat_bubble_outline,
                              message: '目前還沒有評論。',
                            )
                          : Column(
                              children: [
                                for (final review in items) ...[
                                  _ReviewTile(
                                    review: review,
                                    isOwner: review.id == currentUid,
                                    onEdit: () => showReviewFormSheet(
                                      context,
                                      ref,
                                      restaurant.id,
                                      review,
                                    ),
                                    onDelete: () => showDeleteReviewDialog(
                                      context,
                                      ref,
                                      restaurant.id,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RestaurantHero extends StatelessWidget {
  const _RestaurantHero({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RestaurantImage(imageUrl: restaurant.coverPhotoUrl),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.16),
                Colors.black.withValues(alpha: 0.70),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 28),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final category in restaurant.categories.take(3))
                          _HeroTag(label: category),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          fit: FlexFit.loose,
                          child: SelectableText(
                            restaurant.name,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: '複製店名',
                          color: Colors.white,
                          onPressed: () =>
                              _copyText(context, restaurant.name, '店名已複製。'),
                          icon: const Icon(Icons.content_copy_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFF1C84B),
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          restaurant.ratingCount == 0
                              ? '尚無評價'
                              : '${restaurant.averageRating.toStringAsFixed(1)} · ${restaurant.ratingCount} 則評論',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _copyText(
  BuildContext context,
  String value,
  String confirmationMessage,
) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(confirmationMessage)));
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final address = restaurant.address.isEmpty ? '尚未提供地址' : restaurant.address;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '店家地址',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      SelectableText(address),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Divider(height: 1),
            ),
            _OverviewStats(restaurant: restaurant),
          ],
        ),
      ),
    );
  }
}

class _OverviewStats extends StatelessWidget {
  const _OverviewStats({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatItem(
        icon: Icons.star_rounded,
        value: restaurant.ratingCount == 0
            ? '—'
            : restaurant.averageRating.toStringAsFixed(1),
        label: '${restaurant.ratingCount} 則評論',
      ),
      _StatItem(
        icon: Icons.favorite_border,
        value: '${restaurant.favoriteCount}',
        label: '收藏',
      ),
      _StatItem(
        icon: Icons.photo_library_outlined,
        value: '${restaurant.photoCount}',
        label: '照片',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 430
          ? _buildCompactStats(stats)
          : _buildWideStats(stats),
    );
  }

  Widget _buildCompactStats(List<Widget> stats) {
    return Column(
      children: [
        for (var index = 0; index < stats.length; index++) ...[
          stats[index],
          if (index != stats.length - 1) const Divider(height: 24),
        ],
      ],
    );
  }

  Widget _buildWideStats(List<Widget> stats) {
    return Row(
      children: [
        for (var index = 0; index < stats.length; index++) ...[
          Expanded(child: stats[index]),
          if (index != stats.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _openDirections(context),
            icon: const Icon(Icons.directions_outlined),
            label: const Text('帶我去'),
          ),
        ),
        const SizedBox(width: 12),
        FavoriteButton(restaurant: restaurant, filled: true),
      ],
    );
  }

  Future<void> _openDirections(BuildContext context) async {
    final opened = await const ExternalNavigationService().openDirections(
      restaurant,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('無法開啟外部導航。')));
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle, this.action});

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}

class _DishesPanel extends StatelessWidget {
  const _DishesPanel({required this.dishes});

  final List<String> dishes;

  @override
  Widget build(BuildContext context) {
    if (dishes.isEmpty) {
      return const _SectionMessage(
        icon: Icons.restaurant_menu_outlined,
        message: '尚未提供推薦菜色。',
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final dish in dishes)
              Chip(
                avatar: const Icon(Icons.restaurant_menu, size: 17),
                label: Text(dish),
              ),
          ],
        ),
      ),
    );
  }
}

class _AmenitiesPanel extends StatelessWidget {
  const _AmenitiesPanel({required this.amenities});

  final List<String> amenities;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final amenity in amenities)
              Chip(
                avatar: const Icon(Icons.check_circle_outline, size: 17),
                label: Text(amenity),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoStrip extends ConsumerWidget {
  const _PhotoStrip({required this.restaurant, required this.photos});

  final Restaurant restaurant;
  final List<RestaurantPhoto> photos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = ref.watch(authStateChangesProvider).asData?.value?.uid;
    final isAdmin = ref.watch(adminStatusProvider).asData?.value ?? false;
    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final photo = photos[index];
          final isCover = photo.url == restaurant.coverPhotoUrl;
          final canManagePhoto =
              currentUid != null && (isAdmin || photo.uploadedBy == currentUid);
          return SizedBox(
            width: 244,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: GestureDetector(
                    onTap: () => _showPhotoViewer(context, photos, index),
                    child: RestaurantImage(imageUrl: photo.url),
                  ),
                ),
                if (isCover)
                  const Positioned(
                    left: 10,
                    bottom: 10,
                    child: _CoverPhotoBadge(),
                  ),
                if (canManagePhoto)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Row(
                      children: [
                        if (!isCover) ...[
                          _PhotoActionButton(
                            tooltip: '設為封面',
                            icon: Icons.star_outline,
                            onPressed: () =>
                                _setCoverPhoto(context, ref, photo),
                          ),
                          const SizedBox(width: 6),
                        ],
                        _PhotoActionButton(
                          tooltip: '刪除照片',
                          icon: Icons.delete_outline,
                          onPressed: () => _removePhoto(context, ref, photo),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showPhotoViewer(
    BuildContext context,
    List<RestaurantPhoto> photos,
    int initialIndex,
  ) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) =>
          _PhotoViewerDialog(photos: photos, initialIndex: initialIndex),
    );
  }

  Future<void> _setCoverPhoto(
    BuildContext context,
    WidgetRef ref,
    RestaurantPhoto photo,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('設為封面照片'),
        content: const Text('要將這張照片設為店家的封面嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('設為封面'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(contributionRepositoryProvider)
          .setRestaurantCoverPhoto(
            restaurantId: restaurant.id,
            photoId: photo.id,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已更新店家封面照片。')));
      }
    } on ContributionException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _removePhoto(
    BuildContext context,
    WidgetRef ref,
    RestaurantPhoto photo,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除照片'),
        content: const Text('這張照片會從店家頁面與儲存空間永久移除，無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(contributionRepositoryProvider)
          .removeRestaurantPhoto(
            restaurantId: restaurant.id,
            photoId: photo.id,
          );
      ref.invalidate(restaurantProvider(restaurant.id));
      ref.invalidate(restaurantPhotosProvider(restaurant.id));
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('照片已刪除。')));
      }
    } on ContributionException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

class _PhotoViewerDialog extends StatefulWidget {
  const _PhotoViewerDialog({required this.photos, required this.initialIndex});

  final List<RestaurantPhoto> photos;
  final int initialIndex;

  @override
  State<_PhotoViewerDialog> createState() => _PhotoViewerDialogState();
}

class _PhotoViewerDialogState extends State<_PhotoViewerDialog> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.photos.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: SizedBox.expand(
                    child: RestaurantImage(
                      imageUrl: widget.photos[index].url,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white24,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close),
              ),
            ),
            if (widget.photos.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: Center(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${widget.photos.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoActionButton extends StatelessWidget {
  const _PhotoActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(99),
      child: IconButton(
        tooltip: tooltip,
        color: Colors.white,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

class _CoverPhotoBadge extends StatelessWidget {
  const _CoverPhotoBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, color: Color(0xFFF1C84B), size: 16),
            SizedBox(width: 4),
            Text('封面', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _SectionMessage extends StatelessWidget {
  const _SectionMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _PhotoUploadFailureNotice extends StatelessWidget {
  const _PhotoUploadFailureNotice();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline),
            SizedBox(width: 10),
            Expanded(child: Text('店家已新增，但照片尚未上傳成功。請在「店家照片」區塊重新上傳。')),
          ],
        ),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.review,
    required this.isOwner,
    required this.onEdit,
    required this.onDelete,
  });

  final RestaurantReview review;
  final bool isOwner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              foregroundImage: review.authorPhotoUrl == null
                  ? null
                  : NetworkImage(review.authorPhotoUrl!),
              child: review.authorPhotoUrl == null
                  ? const Icon(Icons.person_outline)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          review.authorName,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      if (isOwner)
                        PopupMenuButton<String>(
                          tooltip: '評論操作',
                          onSelected: (value) {
                            if (value == 'edit') onEdit();
                            if (value == 'delete') onDelete();
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('編輯評論')),
                            PopupMenuItem(value: 'delete', child: Text('刪除評論')),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(
                      5,
                      (index) => Icon(
                        index < review.rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: const Color(0xFFF1C84B),
                        size: 18,
                      ),
                    ),
                  ),
                  if (review.text.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(review.text),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreActionsButton extends ConsumerWidget {
  const _MoreActionsButton({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.small(
      tooltip: '更多操作',
      onPressed: () async {
        final action = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('建議修改資料'),
                    onTap: () => Navigator.pop(context, 'edit'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.storefront_outlined),
                    title: const Text('回報停業'),
                    onTap: () => Navigator.pop(context, 'closed'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.copy_all_outlined),
                    title: const Text('回報重複店家'),
                    onTap: () => Navigator.pop(context, 'duplicate'),
                  ),
                ],
              ),
            ),
          ),
        );
        if (!context.mounted) return;
        switch (action) {
          case 'edit':
            showRestaurantEditSheet(context, ref, restaurant);
          case 'closed':
            showRestaurantReportDialog(context, ref, restaurant);
          case 'duplicate':
            showDuplicateRestaurantSheet(context, ref, restaurant);
        }
      },
      child: const Icon(Icons.more_horiz),
    );
  }
}

class _MissingRestaurantBody extends StatelessWidget {
  const _MissingRestaurantBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: _SectionMessage(
          icon: Icons.storefront_outlined,
          message: '找不到這家店，可能已被移除。',
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48),
          const SizedBox(height: 12),
          const Text('無法載入店家資料。'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('重試')),
        ],
      ),
    );
  }
}
