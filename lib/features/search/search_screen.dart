import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/food_categories.dart';
import '../../core/services/external_navigation_service.dart';
import '../../data/models/location_result.dart';
import '../../data/models/nearby_restaurant.dart';
import '../../data/models/restaurant.dart';
import '../../data/providers/location_providers.dart';
import '../../data/providers/restaurant_providers.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../restaurant/restaurant_card.dart';

enum _SearchMode { keyword, nearby }

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  static const _minimumNearbyRadiusKm = 1;
  static const _maximumNearbyRadiusKm = 50;

  final _searchController = TextEditingController();
  RestaurantSearchQuery _query = const RestaurantSearchQuery();
  _SearchMode _mode = _SearchMode.keyword;
  double _nearbyRadiusKm = 10;
  bool _hasKeywordSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    setState(() {
      _query = RestaurantSearchQuery(
        keyword: _searchController.text,
        category: _query.category,
      );
      _hasKeywordSearch =
          _searchController.text.trim().isNotEmpty || _query.category != null;
    });
  }

  void _selectCategory(String? category) {
    setState(() {
      _query = RestaurantSearchQuery(
        keyword: _searchController.text,
        category: category,
      );
      _hasKeywordSearch =
          _searchController.text.trim().isNotEmpty || category != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('搜尋')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SegmentedButton<_SearchMode>(
              segments: const [
                ButtonSegment(
                  value: _SearchMode.keyword,
                  icon: Icon(Icons.search),
                  label: Text('關鍵字'),
                ),
                ButtonSegment(
                  value: _SearchMode.nearby,
                  icon: Icon(Icons.near_me_outlined),
                  label: Text('附近'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) {
                setState(() => _mode = selection.first);
              },
            ),
          ),
          if (_mode == _SearchMode.keyword)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) => _search(),
                decoration: InputDecoration(
                  hintText: '輸入店家名稱',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: '搜尋',
                    onPressed: _search,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          if (_mode == _SearchMode.nearby)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _selectNearbyRadius,
                  icon: const Icon(Icons.tune_outlined),
                  label: Text('搜尋範圍：${_nearbyRadiusKm.toInt()} 公里'),
                ),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('全部'),
                  selected: _query.category == null,
                  onSelected: (selected) => _selectCategory(null),
                ),
                const SizedBox(width: 8),
                for (final category in FoodCategories.all) ...[
                  ChoiceChip(
                    label: Text(category),
                    selected: _query.category == category,
                    onSelected: (selected) {
                      _selectCategory(selected ? category : null);
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: _mode == _SearchMode.keyword
                ? _buildKeywordResults()
                : _buildNearbyResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildKeywordResults() {
    if (!_hasKeywordSearch) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.manage_search_outlined, size: 44),
            SizedBox(height: 12),
            Text('輸入店名開始搜尋'),
          ],
        ),
      );
    }

    final searchCatalog = ref.watch(searchCatalogProvider);
    return searchCatalog.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _SearchError(
        onRetry: () => ref.invalidate(searchCatalogProvider),
      ),
      data: (catalog) {
        final items = _query.filterCatalog(catalog);
        return items.isEmpty
          ? const Center(child: Text('找不到符合條件的店家。'))
          : _SearchResults(restaurants: items);
      },
    );
  }

  Widget _buildNearbyResults() {
    final location = ref.watch(currentLocationProvider);
    return location.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _LatestSearchFallback(
        message: '無法取得目前位置，先顯示最新店家。',
        onRetry: () => ref.invalidate(currentLocationProvider),
      ),
      data: (result) {
        final coordinates = result.coordinates;
        if (coordinates == null) {
          return _LatestSearchFallback(
            message: _locationFailureMessage(result.failure),
            actionLabel: _locationActionLabel(result.failure),
            onAction: () => _handleLocationAction(result.failure),
            onRetry: () => ref.invalidate(currentLocationProvider),
          );
        }
        final nearbyQuery = NearbyRestaurantQuery(
          origin: coordinates,
          category: _query.category,
          radiusKm: _nearbyRadiusKm,
        );
        final nearby = ref.watch(nearbyRestaurantsProvider(nearbyQuery));
        return nearby.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _SearchError(
            onRetry: () {
              ref.invalidate(nearbyRestaurantsProvider(nearbyQuery));
            },
          ),
          data: (result) => Column(
            children: [
              _SearchBanner(
                message: '依距離排序，搜尋範圍 ${result.radiusKm.toInt()} 公里。',
              ),
              Expanded(
                child: result.restaurants.isEmpty
                    ? const Center(child: Text('附近找不到符合條件的店家。'))
                    : _SearchResults(nearbyRestaurants: result.restaurants),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleLocationAction(LocationFailure? failure) async {
    final repository = ref.read(locationRepositoryProvider);
    if (failure == LocationFailure.serviceDisabled) {
      await repository.openLocationSettings();
    } else if (failure == LocationFailure.permissionDeniedForever) {
      await repository.openAppSettings();
    }
  }

  Future<void> _selectNearbyRadius() async {
    final controller = TextEditingController(
      text: _nearbyRadiusKm.toInt().toString(),
    );
    String? errorText;

    final selectedRadius = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('自訂附近搜尋範圍'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '範圍（公里）',
              helperText: '可設定 1 到 50 公里',
              errorText: errorText,
            ),
            onSubmitted: (_) => _submitNearbyRadius(
              context: context,
              controller: controller,
              onInvalid: () => setDialogState(
                () => errorText =
                    '請輸入 $_minimumNearbyRadiusKm 到 $_maximumNearbyRadiusKm 的整數',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => _submitNearbyRadius(
                context: context,
                controller: controller,
                onInvalid: () => setDialogState(
                  () => errorText =
                      '請輸入 $_minimumNearbyRadiusKm 到 $_maximumNearbyRadiusKm 的整數',
                ),
              ),
              child: const Text('套用'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();

    if (selectedRadius != null && mounted) {
      setState(() => _nearbyRadiusKm = selectedRadius);
    }
  }

  void _submitNearbyRadius({
    required BuildContext context,
    required TextEditingController controller,
    required VoidCallback onInvalid,
  }) {
    final radiusKm = int.tryParse(controller.text.trim());
    if (radiusKm == null ||
        radiusKm < _minimumNearbyRadiusKm ||
        radiusKm > _maximumNearbyRadiusKm) {
      onInvalid();
      return;
    }
    Navigator.of(context).pop(radiusKm.toDouble());
  }
}

class _LatestSearchFallback extends ConsumerWidget {
  const _LatestSearchFallback({
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
    final latest = ref.watch(latestRestaurantsProvider);
    return Column(
      children: [
        _SearchBanner(
          message: message,
          actionLabel: actionLabel ?? '重試定位',
          onAction: onAction ?? onRetry,
        ),
        Expanded(
          child: latest.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _SearchError(onRetry: onRetry),
            data: (items) => items.isEmpty
                ? const Center(child: Text('目前還沒有店家資料。'))
                : _SearchResults(restaurants: items),
          ),
        ),
      ],
    );
  }
}

class _SearchBanner extends StatelessWidget {
  const _SearchBanner({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    this.restaurants = const [],
    this.nearbyRestaurants = const [],
  });

  final List<Restaurant> restaurants;
  final List<NearbyRestaurant> nearbyRestaurants;

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
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columnCount = constraints.maxWidth >= 960
                ? 3
                : constraints.maxWidth >= 620
                ? 2
                : 1;
            const spacing = 16.0;
            final cardWidth =
                (constraints.maxWidth - 32 - (columnCount - 1) * spacing) /
                columnCount;

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnCount,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio: cardWidth / (cardWidth / 2 + 160),
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                return RestaurantCard(
                  restaurant: item.restaurant,
                  distanceMeters: item.distance,
                  onTap: () {
                    context.push('/restaurants/${item.restaurant.id}');
                  },
                  onDirections: () => _openDirections(context, item.restaurant),
                );
              },
            );
          },
        ),
      ),
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

class _SearchError extends StatelessWidget {
  const _SearchError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('搜尋失敗，請稍後再試。'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('重試')),
        ],
      ),
    );
  }
}

String _locationFailureMessage(LocationFailure? failure) {
  return switch (failure) {
    LocationFailure.serviceDisabled => '裝置定位尚未開啟，先顯示最新店家。',
    LocationFailure.permissionDenied => '未取得定位權限，先顯示最新店家。',
    LocationFailure.permissionDeniedForever => '定位權限已停用，先顯示最新店家。',
    _ => '無法取得目前位置，先顯示最新店家。',
  };
}

String? _locationActionLabel(LocationFailure? failure) {
  return switch (failure) {
    LocationFailure.serviceDisabled => '定位設定',
    LocationFailure.permissionDeniedForever => 'App 設定',
    _ => null,
  };
}
