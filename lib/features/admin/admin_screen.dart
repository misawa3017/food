import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/moderation_request.dart';
import '../../data/models/restaurant.dart';
import '../../data/models/restaurant_photo.dart';
import '../../data/models/restaurant_review.dart';
import '../../data/providers/contribution_providers.dart';
import '../../data/providers/moderation_providers.dart';
import '../../data/providers/restaurant_providers.dart';
import '../../data/repositories/contribution_repository.dart';
import '../../data/repositories/restaurant_repository.dart';
import '../restaurant/restaurant_detail_screen.dart';
import '../restaurant/restaurant_image.dart';

class _EditControllers {
  const _EditControllers({
    required this.name,
    required this.address,
    required this.googleMapsUrl,
    required this.latitude,
    required this.longitude,
    required this.categories,
    required this.amenities,
    required this.dishes,
  });

  final TextEditingController name;
  final TextEditingController address;
  final TextEditingController googleMapsUrl;
  final TextEditingController latitude;
  final TextEditingController longitude;
  final TextEditingController categories;
  final TextEditingController amenities;
  final TextEditingController dishes;
}

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
                fields: _EditControllers(
                  name: name,
                  address: address,
                  googleMapsUrl: googleMapsUrl,
                  latitude: latitude,
                  longitude: longitude,
                  categories: categories,
                  amenities: amenities,
                  dishes: dishes,
                ),
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
    required _EditControllers fields,
  }) {
    final latitudeText = fields.latitude.text.trim();
    final longitudeText = fields.longitude.text.trim();
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
      'name': fields.name.text,
      'address': fields.address.text,
      'googleMapsUrl': fields.googleMapsUrl.text.trim().isEmpty
          ? null
          : fields.googleMapsUrl.text.trim(),
      'latitude': parsedLatitude,
      'longitude': parsedLongitude,
      'categories': _splitList(fields.categories.text),
      'amenities': _splitList(fields.amenities.text),
      'recommendedDishes': _splitList(fields.dishes.text),
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

  Future<void> _claimRestaurantRecommender(Restaurant restaurant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('設為我推薦'),
        content: Text(
          '要將「${restaurant.name}」標記為由你推薦嗎？\n之後更新公開推薦暱稱時，這家店也會一併更新。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確認'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(contributionRepositoryProvider)
          .claimRestaurantRecommender(restaurant.id);
      ref.invalidate(searchRestaurantsProvider(_query));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已設為你推薦的店家。')));
      }
    } on ContributionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<void> _claimImportedRestaurantRecommenders() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('認領匯入店家'),
        content: const Text(
          '系統會將你的匯入收藏中，能以 Google Maps 連結或店名加地址明確對應的既有店家設為你推薦。\n\n不會改動已屬於其他使用者的店家。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('開始認領'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final count = await ref
          .read(contributionRepositoryProvider)
          .claimImportedRestaurantRecommenders();
      ref.invalidate(searchRestaurantsProvider(_query));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已將 $count 家匯入店家設為你推薦。')));
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
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _claimImportedRestaurantRecommenders,
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: const Text('認領匯入店家'),
              ),
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
                              tooltip: '設為我推薦',
                              onPressed: () =>
                                  _claimRestaurantRecommender(restaurant),
                              icon: const Icon(Icons.person_add_alt_1_outlined),
                            ),
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
                    const Chip(
                      avatar: Icon(Icons.star, size: 16),
                      label: Text('目前封面'),
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
  final _photoController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    _photoController.dispose();
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
    final photoValue = int.tryParse(_photoController.text.trim());
    if (photoValue == null || photoValue < 1 || photoValue > 100) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('照片投稿上限必須是 1 到 100。')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(contributionRepositoryProvider)
          .updateContributionLimits(
            restaurantDailyLimit: value,
            photoDailyLimit: photoValue,
          );
      ref.invalidate(adminContributionLimitsProvider);
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
    final limit = ref.watch(adminContributionLimitsProvider);
    return limit.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          const Center(child: Text('無法讀取投稿限制，請稍後再試。')),
      data: (limits) {
        if (_controller.text.isEmpty && !_isSaving) {
          _controller.text = '${limits['restaurantDailyLimit']}';
          _photoController.text = '${limits['photoDailyLimit']}';
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
                      controller: _photoController,
                      enabled: !_isSaving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: '每日照片投稿上限',
                        helperText: '每位使用者 24 小時內可投稿的照片數量，範圍為 1 到 100。',
                        suffixText: '張',
                      ),
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
    if (approve && request.type == 'report') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(_approveActionLabel(request)),
          content: Text(_approveConfirmMessage(request)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_approveActionLabel(request)),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

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
        final message = request.type == 'report'
            ? (approve ? '已下架被檢舉的內容。' : '已保留內容並將檢舉結案。')
            : (approve ? '已核准。' : '已拒絕。');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
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
                return _ModerationRequestCard(
                  request: item,
                  canReject: canReject,
                  onReject: () => _review(context, ref, item, false),
                  onApprove: () => _review(context, ref, item, true),
                );
              },
            ),
    );
  }
}

String _requestTypeLabel(ModerationRequest request) {
  if (request.type == 'report') {
    switch (request.targetType) {
      case 'review':
        return '評論檢舉';
      case 'photo':
        return '照片檢舉';
      case 'restaurant':
        return '店家檢舉';
      default:
        return '內容檢舉';
    }
  }
  if (request.type == 'edit') return '資料修正';
  if (request.type == 'merge') return '重複店家合併';
  return request.type;
}

String _rejectActionLabel(ModerationRequest request) {
  if (request.type == 'report') return '保留內容（駁回檢舉）';
  return '拒絕修正';
}

String _approveActionLabel(ModerationRequest request) {
  if (request.type == 'report') {
    switch (request.targetType) {
      case 'review':
        return '下架此評論';
      case 'photo':
        return '下架此照片';
      case 'restaurant':
        return '下架此店家';
      default:
        return '下架被檢舉內容';
    }
  }
  if (request.type == 'edit') return '核准並套用修正';
  if (request.type == 'merge') return '核准並合併店家';
  return '核准';
}

String _approveConfirmMessage(ModerationRequest request) {
  switch (request.targetType) {
    case 'review':
      return '核准此檢舉後，該則評論將從店家頁面移除，並重新計算店家評分。確定要下架此評論嗎？';
    case 'photo':
      return '核准此檢舉後，該張照片將從店家頁面移除。確定要下架此照片嗎？';
    case 'restaurant':
      return '核准此檢舉後，整間店家將從公開搜尋與附近列表下架。確定要下架此店家嗎？';
    default:
      return '核准此檢舉後，被檢舉的內容將會下架移除。確定要繼續嗎？';
  }
}

class _ModerationRequestCard extends ConsumerWidget {
  const _ModerationRequestCard({
    required this.request,
    required this.canReject,
    required this.onReject,
    required this.onApprove,
  });

  final ModerationRequest request;
  final bool canReject;
  final VoidCallback onReject;
  final VoidCallback onApprove;

  void _openRestaurant(BuildContext context, String restaurantId) {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push('/restaurants/$restaurantId');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RestaurantDetailScreen(restaurantId: restaurantId),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurantAsync = request.restaurantId.isEmpty
        ? const AsyncValue<Restaurant?>.data(null)
        : ref.watch(restaurantProvider(request.restaurantId));
    final restaurant = restaurantAsync.asData?.value;
    final titleName = restaurant?.name ?? request.restaurantId;
    final theme = Theme.of(context);
    final isReport = request.type == 'report';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_requestTypeLabel(request)} · $titleName',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        restaurant != null
                            ? '店家 ID：${request.restaurantId} · ${restaurant.address}'
                            : '店家 ID：${request.restaurantId}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (request.restaurantId.isNotEmpty)
                  TextButton.icon(
                    onPressed: () =>
                        _openRestaurant(context, request.restaurantId),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('查看店家'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '原因：${request.reason.isEmpty ? '（未提供原因）' : request.reason}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _buildTargetDetails(context, restaurant),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (canReject)
                  OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(_rejectActionLabel(request)),
                  ),
                FilledButton.icon(
                  style: isReport
                      ? FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                        )
                      : null,
                  onPressed: onApprove,
                  icon: Icon(
                    isReport ? Icons.delete_outline : Icons.check,
                    size: 18,
                  ),
                  label: Text(_approveActionLabel(request)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetDetails(BuildContext context, Restaurant? restaurant) {
    if (request.type == 'report') {
      switch (request.targetType) {
        case 'review':
          return _ReportedReviewPreview(
            restaurantId: request.restaurantId,
            reviewId: request.contentId,
          );
        case 'photo':
          return _ReportedPhotoPreview(
            restaurantId: request.restaurantId,
            photoId: request.contentId,
          );
        case 'restaurant':
          return _ReportedRestaurantPreview(restaurant: restaurant);
      }
    }
    if (request.type == 'edit') {
      return _EditChangesPreview(changes: request.changes);
    }
    if (request.type == 'merge') {
      return _MergeTargetPreview(
        sourceRestaurant: restaurant,
        sourceRestaurantId: request.restaurantId,
        targetRestaurantId: request.targetRestaurantId,
      );
    }
    return const SizedBox.shrink();
  }
}

/// 顯示被檢舉的評論內容（作者、評分、文字），讓管理員能直接判斷是否違規。
class _ReportedReviewPreview extends ConsumerWidget {
  const _ReportedReviewPreview({
    required this.restaurantId,
    required this.reviewId,
  });

  final String restaurantId;
  final String? reviewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (restaurantId.isEmpty || reviewId == null) {
      return const _PreviewBox(
        title: '被檢舉的評論',
        child: Text('缺少評論識別碼，請點選「查看店家」檢查評論列表。'),
      );
    }

    final reviewsAsync = ref.watch(restaurantReviewsProvider(restaurantId));
    return _PreviewBox(
      title: '被檢舉的評論',
      child: reviewsAsync.when(
        loading: () => const Text('正在載入評論內容…'),
        error: (error, stackTrace) => Text('無法讀取評論（評論 ID：$reviewId）。'),
        data: (reviews) {
          RestaurantReview? target;
          for (final item in reviews) {
            if (item.id == reviewId) {
              target = item;
              break;
            }
          }
          if (target == null) {
            return Text(
              '找不到這則評論（可能已被作者自行刪除或已下架，評論 ID：$reviewId）。\n'
              '若已不存在，可直接點選「保留內容（駁回檢舉）」將此單結案。',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '作者：${target.authorName} · 評分：${'★' * target.rating}（${target.rating}/5）',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                target.text.trim().isEmpty ? '（此評論僅給星等，沒有填寫文字內容）' : target.text,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 顯示被檢舉的照片縮圖，讓管理員能直接檢視照片是否有不當內容。
class _ReportedPhotoPreview extends ConsumerWidget {
  const _ReportedPhotoPreview({
    required this.restaurantId,
    required this.photoId,
  });

  final String restaurantId;
  final String? photoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (restaurantId.isEmpty || photoId == null) {
      return const _PreviewBox(
        title: '被檢舉的照片',
        child: Text('缺少照片識別碼，請點選「查看店家」檢查照片列表。'),
      );
    }

    final photosAsync = ref.watch(restaurantPhotosProvider(restaurantId));
    return _PreviewBox(
      title: '被檢舉的照片',
      child: photosAsync.when(
        loading: () => const Text('正在載入照片…'),
        error: (error, stackTrace) => Text('無法讀取照片（照片 ID：$photoId）。'),
        data: (photos) {
          RestaurantPhoto? target;
          for (final item in photos) {
            if (item.id == photoId) {
              target = item;
              break;
            }
          }
          if (target == null) {
            return Text(
              '找不到這張照片（可能已被刪除或已下架，照片 ID：$photoId）。\n'
              '若已不存在，可直接點選「保留內容（駁回檢舉）」將此單結案。',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 180,
                  height: 135,
                  child: RestaurantImage(imageUrl: target.url),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '照片 ID：${target.id}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 顯示被檢舉的店家摘要資訊。
class _ReportedRestaurantPreview extends StatelessWidget {
  const _ReportedRestaurantPreview({required this.restaurant});

  final Restaurant? restaurant;

  @override
  Widget build(BuildContext context) {
    final target = restaurant;
    if (target == null) {
      return const _PreviewBox(
        title: '被檢舉的店家',
        child: Text('正在載入店家資訊，或該店家已下架。'),
      );
    }
    return _PreviewBox(
      title: '被檢舉的店家資訊',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('店名：${target.name}（推薦人：${target.recommenderName}）'),
          const SizedBox(height: 4),
          Text('地址：${target.address}'),
          if (target.categories.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('分類：${target.categories.join('、')}'),
          ],
          if (target.recommendedDishes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('推薦菜色：${target.recommendedDishes.join('、')}'),
          ],
        ],
      ),
    );
  }
}

/// 顯示資料修正申請的欄位變更內容。
class _EditChangesPreview extends StatelessWidget {
  const _EditChangesPreview({required this.changes});

  final Map<String, dynamic> changes;

  @override
  Widget build(BuildContext context) {
    if (changes.isEmpty) {
      return const SizedBox.shrink();
    }
    final lines = <String>[];
    if (changes.containsKey('name')) {
      lines.add('店家名稱 → ${changes['name']}');
    }
    if (changes.containsKey('address')) {
      lines.add('地址 → ${changes['address']}');
    }
    if (changes['categories'] is Iterable) {
      lines.add('分類 → ${(changes['categories'] as Iterable).join('、')}');
    }
    if (changes['recommendedDishes'] is Iterable) {
      lines.add(
        '推薦菜色 → ${(changes['recommendedDishes'] as Iterable).join('、')}',
      );
    }
    if (changes['amenities'] is Iterable) {
      lines.add('店家設施 → ${(changes['amenities'] as Iterable).join('、')}');
    }
    if (changes.containsKey('googleMapsUrl')) {
      lines.add('Google Maps 連結 → ${changes['googleMapsUrl']}');
    }
    return _PreviewBox(
      title: '建議修改內容',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(line),
            ),
        ],
      ),
    );
  }
}

/// 顯示重複店家合併申請的來源與目標店家。
class _MergeTargetPreview extends ConsumerWidget {
  const _MergeTargetPreview({
    required this.sourceRestaurant,
    required this.sourceRestaurantId,
    required this.targetRestaurantId,
  });

  final Restaurant? sourceRestaurant;
  final String sourceRestaurantId;
  final String? targetRestaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetId = targetRestaurantId;
    final targetRestaurant = targetId == null
        ? null
        : ref.watch(restaurantProvider(targetId)).asData?.value;
    return _PreviewBox(
      title: '合併店家資訊',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('將被合併下架：${sourceRestaurant?.name ?? sourceRestaurantId}'),
          const SizedBox(height: 4),
          Text('保留目標店家：${targetRestaurant?.name ?? targetId ?? '未知'}'),
        ],
      ),
    );
  }
}

class _PreviewBox extends StatelessWidget {
  const _PreviewBox({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
