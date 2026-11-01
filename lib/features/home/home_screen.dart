import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/external_navigation_service.dart';
import '../../core/widgets/ads/web_adsense_home_feed_ad.dart';
import '../../data/models/location_result.dart';
import '../../data/models/nearby_restaurant.dart';
import '../../data/models/restaurant.dart';
import '../../data/providers/location_providers.dart';
import '../../data/providers/restaurant_providers.dart';
import '../restaurant/restaurant_card.dart';
import '../search/load_more_restaurants_button.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _radiusOptionsKm = [5.0, 10.0, 20.0];
  double _radiusKm = 10;

  @override
  Widget build(BuildContext context) {
    // 在首頁背景同步目錄，讓搜尋分類切換不必再等待一次網路請求。
    ref.watch(searchCatalogProvider);
    final location = ref.watch(currentLocationProvider);
    return Scaffold(
      // 拿掉標題列讓店家有更多空間，內容仍需避開狀態列與瀏海。
      body: SafeArea(
        bottom: false,
        child: location.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _FallbackFeed(
            message: '無法取得目前位置，先顯示最新店家。',
            onRetry: () => ref.invalidate(currentLocationProvider),
          ),
          data: (result) {
            final coordinates = result.coordinates;
            if (coordinates == null) {
              final actionLabel = _locationActionLabel(result.failure);
              return _FallbackFeed(
                message: _locationFailureMessage(result.failure),
                actionLabel: actionLabel,
                // 沒有對應的設定頁時不傳 onAction，讓「重新嘗試」退回 onRetry 重新取得位置
                onAction: actionLabel == null
                    ? null
                    : () => _handleLocationAction(ref, result.failure),
                onRetry: () => ref.invalidate(currentLocationProvider),
              );
            }
            final query = NearbyRestaurantQuery(
              origin: coordinates,
              radiusKm: _radiusKm,
            );
            final nearbyRestaurants = ref.watch(
              nearbyRestaurantsProvider(query),
            );
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  children: [
                    _HomeIntro(
                      optionsKm: _radiusOptionsKm,
                      selectedRadiusKm: _radiusKm,
                      // 沒有附近店家時改顯示最新店家，此時不是依距離排序。
                      hasNearbyResults:
                          nearbyRestaurants
                              .asData
                              ?.value
                              .restaurants
                              .isNotEmpty ??
                          false,
                      onRadiusSelected: (radiusKm) {
                        setState(() => _radiusKm = radiusKm);
                      },
                    ),
                    Expanded(
                      child: nearbyRestaurants.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stackTrace) => _FallbackFeed(
                          message: '附近店家載入失敗，先顯示最新店家。',
                          onRetry: () =>
                              ref.invalidate(nearbyRestaurantsProvider(query)),
                        ),
                        data: (nearby) => nearby.restaurants.isEmpty
                            ? _FallbackFeed(
                                message:
                                    '${nearby.radiusKm.toInt()} 公里內沒有店家，先顯示最新店家。',
                                onRetry: () {
                                  ref.invalidate(currentLocationProvider);
                                  ref.invalidate(
                                    nearbyRestaurantsProvider(query),
                                  );
                                },
                              )
                            : _NearbyFeed(
                                key: ValueKey(query),
                                result: nearby,
                                onRefresh: () async {
                                  ref.invalidate(currentLocationProvider);
                                  ref.invalidate(
                                    nearbyRestaurantsProvider(query),
                                  );
                                  await ref.read(
                                    currentLocationProvider.future,
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleLocationAction(
    WidgetRef ref,
    LocationFailure? failure,
  ) async {
    final repository = ref.read(locationRepositoryProvider);
    if (failure == LocationFailure.serviceDisabled) {
      await repository.openLocationSettings();
    } else if (failure == LocationFailure.permissionDeniedForever) {
      await repository.openAppSettings();
    }
  }
}

class _HomeIntro extends StatelessWidget {
  const _HomeIntro({
    required this.optionsKm,
    required this.selectedRadiusKm,
    required this.hasNearbyResults,
    required this.onRadiusSelected,
  });

  final List<double> optionsKm;
  final double selectedRadiusKm;
  final bool hasNearbyResults;
  final ValueChanged<double> onRadiusSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          // 小螢幕放不下時等比縮小，維持在同一行。
          final intro = FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('今天想吃什麼？', style: textTheme.headlineSmall),
                const SizedBox(width: 8),
                Text('探索你身邊的好味道。', style: textTheme.bodyMedium),
              ],
            ),
          );
          final selector = _RadiusSelector(
            optionsKm: optionsKm,
            selectedRadiusKm: selectedRadiusKm,
            hasNearbyResults: hasNearbyResults,
            onSelected: onRadiusSelected,
          );

          return wide
              ? Row(
                  children: [
                    Expanded(child: intro),
                    const SizedBox(width: 24),
                    selector,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [intro, const SizedBox(height: 16), selector],
                );
        },
      ),
    );
  }
}

class _RadiusSelector extends StatelessWidget {
  const _RadiusSelector({
    required this.optionsKm,
    required this.selectedRadiusKm,
    required this.hasNearbyResults,
    required this.onSelected,
  });

  final List<double> optionsKm;
  final double selectedRadiusKm;
  final bool hasNearbyResults;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // 小螢幕放不下時等比縮小，維持在同一行。
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasNearbyResults) ...[
            Text('附近推薦', style: textTheme.titleMedium),
            const SizedBox(width: 12),
          ],
          Text('搜尋範圍', style: textTheme.labelLarge),
          const SizedBox(width: 12),
          DropdownButton<double>(
            value: selectedRadiusKm,
            isDense: true,
            underline: const SizedBox.shrink(),
            items: [
              for (final radiusKm in optionsKm)
                DropdownMenuItem(
                  value: radiusKm,
                  child: Text('${radiusKm.toInt()} 公里'),
                ),
            ],
            onChanged: (radiusKm) {
              if (radiusKm != null) onSelected(radiusKm);
            },
          ),
          if (hasNearbyResults) ...[
            const SizedBox(width: 12),
            Icon(
              Icons.near_me_outlined,
              size: 17,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text('依距離排序', style: textTheme.labelMedium),
          ],
        ],
      ),
    );
  }
}

class _NearbyFeed extends StatelessWidget {
  const _NearbyFeed({super.key, required this.result, required this.onRefresh});

  final NearbySearchResult result;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return _PagedNearbyRestaurantList(
      nearbyRestaurants: result.restaurants,
      onRefresh: onRefresh,
    );
  }
}

/// 附近結果已依距離排序，因此在本機按順序分批呈現，不會漏掉較近店家。
class _PagedNearbyRestaurantList extends StatefulWidget {
  const _PagedNearbyRestaurantList({
    required this.nearbyRestaurants,
    required this.onRefresh,
  });

  final List<NearbyRestaurant> nearbyRestaurants;
  final Future<void> Function() onRefresh;

  @override
  State<_PagedNearbyRestaurantList> createState() =>
      _PagedNearbyRestaurantListState();
}

class _PagedNearbyRestaurantListState
    extends State<_PagedNearbyRestaurantList> {
  static const _pageSize = 6;
  late String _resultKey;
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _resultKey = _buildResultKey(widget.nearbyRestaurants);
  }

  @override
  void didUpdateWidget(covariant _PagedNearbyRestaurantList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextResultKey = _buildResultKey(widget.nearbyRestaurants);
    if (nextResultKey != _resultKey) {
      _resultKey = nextResultKey;
      _visibleCount = _pageSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasMore = _visibleCount < widget.nearbyRestaurants.length;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: _RestaurantList(
              nearbyRestaurants: widget.nearbyRestaurants,
              visibleCount: _visibleCount,
            ),
          ),
        ),
        if (hasMore)
          LoadMoreRestaurantsButton(
            onPressed: () {
              setState(() => _visibleCount += _pageSize);
            },
          ),
      ],
    );
  }

  String _buildResultKey(List<NearbyRestaurant> restaurants) {
    return restaurants.map((nearby) => nearby.restaurant.id).join(',');
  }
}

class _FallbackFeed extends ConsumerWidget {
  const _FallbackFeed({
    required this.message,
    required this.onRetry,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final VoidCallback onRetry;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurants = ref.watch(latestRestaurantsProvider);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Column(
          children: [
            _InfoBanner(
              message: message,
              actionLabel: actionLabel ?? '重新嘗試',
              onAction: onAction ?? onRetry,
            ),
            Expanded(
              child: restaurants.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => _HomeError(onRetry: onRetry),
                data: (items) => items.isEmpty
                    ? const Center(child: Text('目前還沒有店家資料。'))
                    : RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(latestRestaurantsProvider);
                          await ref.read(latestRestaurantsProvider.future);
                        },
                        child: _RestaurantList(restaurants: items),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _RestaurantList extends StatelessWidget {
  const _RestaurantList({
    this.restaurants = const [],
    this.nearbyRestaurants = const [],
    this.visibleCount,
  });

  final List<Restaurant> restaurants;
  final List<NearbyRestaurant> nearbyRestaurants;
  final int? visibleCount;

  static const _adInsertionIndex = 3;

  @override
  Widget build(BuildContext context) {
    final items = nearbyRestaurants.isEmpty
        ? restaurants
              .map((restaurant) => (restaurant: restaurant, distance: null))
              .toList(growable: false)
        : nearbyRestaurants
              .map(
                (nearby) => (
                  restaurant: nearby.restaurant,
                  distance: nearby.distanceMeters,
                ),
              )
              .toList(growable: false);
    final visibleItems = visibleCount == null
        ? items
        : items.take(visibleCount!).toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final useGrid = constraints.maxWidth >= 760;
        final padding = const EdgeInsets.fromLTRB(20, 0, 20, 28);
        final includesAd = visibleItems.length > _adInsertionIndex;
        final itemCount = visibleItems.length + (includesAd ? 1 : 0);
        if (useGrid) {
          return GridView.builder(
            padding: padding,
            itemCount: itemCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.04,
            ),
            itemBuilder: (context, index) => _listItem(
              context,
              visibleItems,
              index,
              includesAd: includesAd,
              useGrid: true,
            ),
          );
        }
        return ListView.separated(
          padding: padding,
          itemCount: itemCount,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) => _listItem(
            context,
            visibleItems,
            index,
            includesAd: includesAd,
            useGrid: false,
          ),
        );
      },
    );
  }

  Widget _listItem(
    BuildContext context,
    List<({Restaurant restaurant, double? distance})> items,
    int index, {
    required bool includesAd,
    required bool useGrid,
  }) {
    if (includesAd && index == _adInsertionIndex) {
      final ad = const WebAdSenseHomeFeedAd();
      return useGrid ? ad : SizedBox(height: 150, child: ad);
    }

    final restaurantIndex = includesAd && index > _adInsertionIndex
        ? index - 1
        : index;
    final item = items[restaurantIndex];
    return _restaurantCard(context, item.restaurant, item.distance);
  }

  Widget _restaurantCard(
    BuildContext context,
    Restaurant restaurant,
    double? distance,
  ) {
    return RestaurantCard(
      restaurant: restaurant,
      distanceMeters: distance,
      onTap: () => context.push('/restaurants/${restaurant.id}'),
      onDirections: () => _openDirections(context, restaurant),
    );
  }

  Future<void> _openDirections(
    BuildContext context,
    Restaurant restaurant,
  ) async {
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

class _HomeError extends StatelessWidget {
  const _HomeError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          const Text('店家資料暫時無法載入。'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('重新嘗試')),
        ],
      ),
    );
  }
}

String _locationFailureMessage(LocationFailure? failure) {
  return switch (failure) {
    LocationFailure.serviceDisabled => '請開啟定位服務，才能顯示附近店家。',
    LocationFailure.permissionDenied => '允許定位權限後，即可顯示附近店家。',
    LocationFailure.permissionDeniedForever => '請到 App 設定開啟定位權限。',
    _ => '無法取得目前位置，先顯示最新店家。',
  };
}

String? _locationActionLabel(LocationFailure? failure) {
  return switch (failure) {
    LocationFailure.serviceDisabled => '開啟設定',
    LocationFailure.permissionDeniedForever => 'App 設定',
    _ => null,
  };
}
