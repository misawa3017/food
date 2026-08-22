import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/moderation_request.dart';
import '../../data/models/restaurant.dart';
import '../../data/models/restaurant_photo.dart';
import '../../data/providers/contribution_providers.dart';
import '../../data/providers/moderation_providers.dart';
import '../../data/providers/restaurant_providers.dart';
import '../../data/repositories/contribution_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../restaurant/restaurant_image.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(adminStatusProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('後台管理')),
      body: isAdmin.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const Center(child: Text('無法驗證管理員身分。')),
        data: (allowed) => allowed
            ? const _AdminTabs()
            : const Center(child: Text('你沒有管理員權限。')),
      ),
    );
  }
}

class _AdminTabs extends ConsumerWidget {
  const _AdminTabs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: '檢舉'),
              Tab(text: '資料修正'),
              Tab(text: '重複店家'),
              Tab(text: '店家管理'),
              Tab(text: '投稿限制'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _RequestList(
                  requests: ref.watch(pendingReportsProvider),
                  functionName: 'reviewReport',
                  canReject: true,
                ),
                _RequestList(
                  requests: ref.watch(pendingEditRequestsProvider),
                  functionName: 'reviewRestaurantEdit',
                  canReject: true,
                ),
                _RequestList(
                  requests: ref.watch(pendingMergeRequestsProvider),
                  functionName: 'mergeRestaurants',
                ),
                const _RestaurantManagement(),
                const _ContributionLimitSettings(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantManagement extends ConsumerStatefulWidget {
  const _RestaurantManagement();

  @override
  ConsumerState<_RestaurantManagement> createState() =>
      _RestaurantManagementState();
}

class _RestaurantManagementState extends ConsumerState<_RestaurantManagement> {
  final _searchController = TextEditingController();
  RestaurantSearchQuery _query = const RestaurantSearchQuery();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    setState(
      () => _query = RestaurantSearchQuery(
        keyword: _searchController.text,
        limit: 50,
      ).normalized(),
    );
  }

  Future<void> _editRestaurant(Restaurant restaurant) async {
    final name = TextEditingController(text: restaurant.name);
    final address = TextEditingController(text: restaurant.address);
    final googleMapsUrl = TextEditingController(
      text: restaurant.googleMapsUrl ?? '',
    );
    final latitude = TextEditingController(
      text: restaurant.location?.latitude.toString() ?? '',
    );
    final longitude = TextEditingController(
      text: restaurant.location?.longitude.toString() ?? '',
    );
    final dishes = TextEditingController(
      text: restaurant.recommendedDishes.join('、'),
    );
    final categories = TextEditingController(
      text: restaurant.categories.join('、'),
    );
    final amenities = TextEditingController(
      text: restaurant.amenities.join('、'),
    );
    final changes = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('編輯 ${restaurant.name}'),
        content: SingleChildScrollView(
          child: Padding(
            // OutlineInputBorder 的浮動標籤會超出欄位頂端，需要保留空間避免被捲動容器裁切。
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: '店家名稱'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: address,
                  decoration: const InputDecoration(labelText: '地址'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: googleMapsUrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Google Maps 連結（選填）',
                    helperText: '「帶我去」會優先開啟此連結；留白可移除。',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: latitude,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '緯度（選填）',
                    helperText: '座標需與經度一起填寫；兩欄留白可移除座標。',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: longitude,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: '經度（選填）'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: categories,
                  decoration: const InputDecoration(labelText: '分類（以 、 分隔）'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amenities,
                  decoration: const InputDecoration(
                    labelText: '店家設施（以 、 分隔）',
                    helperText: '例如：停車場、可刷卡、外送',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: dishes,
                  decoration: const InputDecoration(labelText: '推薦菜色（以 、 分隔）'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final changes = _buildEditChanges(
                context,
                name: name,
                address: address,
                googleMapsUrl: googleMapsUrl,
                latitude: latitude,
                longitude: longitude,
                categories: categories,
                amenities: amenities,
                dishes: dishes,
              );
              if (changes != null) Navigator.pop(context, changes);
            },
            child: const Text('儲存'),
          ),
        ],
      ),
    );
    name.dispose();
    address.dispose();
    googleMapsUrl.dispose();
    latitude.dispose();
    longitude.dispose();
    dishes.dispose();
    categories.dispose();
    amenities.dispose();
    if (changes == null || !mounted) return;

    try {
      await ref
          .read(contributionRepositoryProvider)
          .adminUpdateRestaurant(restaurantId: restaurant.id, changes: changes);
      ref.invalidate(searchRestaurantsProvider(_query));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('店家資料已更新。')));
      }
    } on ContributionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Map<String, Object?>? _buildEditChanges(
    BuildContext context, {
    required TextEditingController name,
    required TextEditingController address,
    required TextEditingController googleMapsUrl,
    required TextEditingController latitude,
    required TextEditingController longitude,
    required TextEditingController categories,
    required TextEditingController amenities,
    required TextEditingController dishes,
  }) {
    final latitudeText = latitude.text.trim();
    final longitudeText = longitude.text.trim();
    final parsedLatitude = latitudeText.isEmpty
        ? null
        : double.tryParse(latitudeText);
    final parsedLongitude = longitudeText.isEmpty
        ? null
        : double.tryParse(longitudeText);
    if ((latitudeText.isNotEmpty && parsedLatitude == null) ||
        (longitudeText.isNotEmpty && parsedLongitude == null)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('座標必須是數字。')));
      return null;
    }
    if ((parsedLatitude == null) != (parsedLongitude == null)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('緯度與經度必須同時填寫或同時留白。')));
      return null;
    }
    return {
      'name': name.text,
      'address': address.text,
      'googleMapsUrl': googleMapsUrl.text.trim().isEmpty
          ? null
          : googleMapsUrl.text.trim(),
      'latitude': parsedLatitude,
      'longitude': parsedLongitude,
      'categories': _splitList(categories.text),
      'amenities': _splitList(amenities.text),
      'recommendedDishes': _splitList(dishes.text),
    };
  }

  Future<void> _removeRestaurant(Restaurant restaurant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('下架店家？'),
        content: Text(
          '「${restaurant.name}」將從公開搜尋與附近列表移除。店家、照片與紀錄仍會保留，之後可由資料庫恢復。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('下架'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(contributionRepositoryProvider)
          .adminRemoveRestaurant(restaurant.id);
      ref.invalidate(searchRestaurantsProvider(_query));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('店家已下架。')));
      }
    } on ContributionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _showPhotoManager(Restaurant restaurant) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, scrollController) => Consumer(
          builder: (context, modalRef, child) {
            final photos = modalRef.watch(
              restaurantPhotosProvider(restaurant.id),
            );
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '管理照片：${restaurant.name}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '可設定封面或刪除任一使用者上傳的照片。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: photos.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stackTrace) =>
                            const Center(child: Text('照片讀取失敗，請稍後再試。')),
                        data: (items) => items.isEmpty
                            ? const Center(child: Text('這間店目前沒有照片。'))
                            : ListView.separated(
                                controller: scrollController,
                                itemCount: items.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final photo = items[index];
                                  return _AdminPhotoTile(
                                    photo: photo,
                                    isCover:
                                        photo.url == restaurant.coverPhotoUrl,
                                    onSetCover: () =>
                                        _setCoverPhoto(restaurant, photo),
                                    onDelete: () =>
                                        _removePhoto(restaurant, photo),
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

  Future<void> _setCoverPhoto(
    Restaurant restaurant,
    RestaurantPhoto photo,
  ) async {
    try {
      await ref
          .read(contributionRepositoryProvider)
          .setRestaurantCoverPhoto(
            restaurantId: restaurant.id,
            photoId: photo.id,
          );
      ref.invalidate(restaurantProvider(restaurant.id));
      ref.invalidate(restaurantPhotosProvider(restaurant.id));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已更新店家封面照片。')));
      }
    } on ContributionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _removePhoto(
    Restaurant restaurant,
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
    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(contributionRepositoryProvider)
          .removeRestaurantPhoto(
            restaurantId: restaurant.id,
            photoId: photo.id,
          );
      ref.invalidate(restaurantProvider(restaurant.id));
      ref.invalidate(restaurantPhotosProvider(restaurant.id));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('照片已刪除。')));
      }
    } on ContributionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurants = ref.watch(searchRestaurantsProvider(_query));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: '搜尋店家名稱',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _search, child: const Text('搜尋')),
            ],
          ),
        ),
        Expanded(
          child: restaurants.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                const Center(child: Text('店家清單載入失敗。')),
            data: (items) => items.isEmpty
                ? const Center(child: Text('找不到符合的店家。'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final restaurant = items[index];
                      return ListTile(
                        title: Text(restaurant.name),
                        subtitle: Text(
                          '${restaurant.address}\n${restaurant.categories.join('、')}',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: '管理照片',
                              onPressed: () => _showPhotoManager(restaurant),
                              icon: const Icon(Icons.photo_library_outlined),
                            ),
                            IconButton(
                              tooltip: '編輯店家',
                              onPressed: () => _editRestaurant(restaurant),
                              icon: const Icon(Icons.edit),
                            ),
                            IconButton(
                              tooltip: '下架店家',
                              color: Theme.of(context).colorScheme.error,
                              onPressed: () => _removeRestaurant(restaurant),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _AdminPhotoTile extends StatelessWidget {
  const _AdminPhotoTile({
    required this.photo,
    required this.isCover,
    required this.onSetCover,
    required this.onDelete,
  });

  final RestaurantPhoto photo;
  final bool isCover;
  final VoidCallback onSetCover;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 108,
                height: 84,
                child: RestaurantImage(imageUrl: photo.url),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isCover)
                    Chip(
                      avatar: const Icon(Icons.star, size: 16),
                      label: const Text('目前封面'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: onSetCover,
                      icon: const Icon(Icons.star_outline),
                      label: const Text('設為封面'),
                    ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: onDelete,
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('刪除照片'),
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

List<String> _splitList(String value) {
  return value
      .split(RegExp('[,，、\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

class _ContributionLimitSettings extends ConsumerStatefulWidget {
  const _ContributionLimitSettings();

  @override
  ConsumerState<_ContributionLimitSettings> createState() =>
      _ContributionLimitSettingsState();
}

class _ContributionLimitSettingsState
    extends ConsumerState<_ContributionLimitSettings> {
  final _controller = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value < 1 || value > 100) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入 1 到 100 的整數。')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(contributionRepositoryProvider)
          .updateRestaurantDailyLimit(value);
      ref.invalidate(adminRestaurantDailyLimitProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('每日新增店家上限已更新為 $value。')));
      }
    } on ContributionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final limit = ref.watch(adminRestaurantDailyLimitProvider);
    return limit.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          const Center(child: Text('無法讀取投稿限制，請稍後再試。')),
      data: (currentLimit) {
        if (_controller.text.isEmpty && !_isSaving) {
          _controller.text = '$currentLimit';
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '每位使用者每日新增店家上限',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '此設定套用於所有帳號的 24 小時投稿額度。可設為 1 到 100；既有的照片、評論與檢舉限制不受影響。',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _controller,
                      enabled: !_isSaving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: '每日店家上限',
                        suffixText: '間',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('儲存'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RequestList extends ConsumerWidget {
  const _RequestList({
    required this.requests,
    required this.functionName,
    this.canReject = false,
  });

  final AsyncValue<List<ModerationRequest>> requests;
  final String functionName;
  final bool canReject;

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    ModerationRequest request,
    bool approve,
  ) async {
    try {
      if (functionName == 'mergeRestaurants') {
        await ref
            .read(contributionRepositoryProvider)
            .mergeRestaurants(request.id);
      } else {
        await ref
            .read(contributionRepositoryProvider)
            .reviewRequest(
              functionName,
              request.id,
              approve ? 'approved' : 'rejected',
            );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(approve ? '已核准。' : '已拒絕。')));
      }
    } on ContributionException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return requests.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => const Center(child: Text('審核清單載入失敗。')),
      data: (items) => items.isEmpty
          ? const Center(child: Text('目前沒有待處理項目。'))
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    title: Text('${item.type} · ${item.restaurantId}'),
                    subtitle: Text(
                      item.reason.isEmpty ? item.data.toString() : item.reason,
                    ),
                    trailing: Wrap(
                      children: [
                        if (canReject)
                          IconButton(
                            tooltip: '拒絕',
                            onPressed: () => _review(context, ref, item, false),
                            icon: const Icon(Icons.close),
                          ),
                        IconButton(
                          tooltip: '核准',
                          onPressed: () => _review(context, ref, item, true),
                          icon: const Icon(Icons.check),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
