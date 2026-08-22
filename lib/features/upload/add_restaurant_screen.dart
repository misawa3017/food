import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/food_categories.dart';
import '../../core/constants/restaurant_amenities.dart';
import '../../core/constants/taiwan_administrative_areas.dart';
import '../../data/models/contribution_models.dart';
import '../../data/models/imported_place.dart';
import '../../data/models/restaurant.dart';
import '../../data/providers/ad_providers.dart';
import '../../data/providers/contribution_providers.dart';
import '../../data/providers/location_providers.dart';
import '../../data/repositories/contribution_repository.dart';

class AddRestaurantScreen extends ConsumerStatefulWidget {
  const AddRestaurantScreen({super.key, this.importedPlace});

  final ImportedPlace? importedPlace;

  @override
  ConsumerState<AddRestaurantScreen> createState() =>
      _AddRestaurantScreenState();
}

class _AddRestaurantScreenState extends ConsumerState<AddRestaurantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _streetController = TextEditingController();
  final _dishesController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _categories = <String>{};
  final _amenities = <String>{};
  String? _city;
  String? _district;
  List<XFile> _photos = const [];
  GeoCoordinates? _location;
  bool _isLocating = false;
  bool _isSubmitting = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    final importedPlace = widget.importedPlace;
    if (importedPlace != null) {
      _nameController.text = importedPlace.sourceTitle;
      _initializeAddress(importedPlace.address);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _streetController.dispose();
    _dishesController.dispose();
    super.dispose();
  }

  void _initializeAddress(String address) {
    final normalizedAddress = address.replaceFirst('台', '臺');
    for (final entry in taiwanAdministrativeAreas.entries) {
      if (!normalizedAddress.startsWith(entry.key)) continue;
      _city = entry.key;
      final remainder = normalizedAddress.substring(entry.key.length);
      for (final district in entry.value) {
        if (!remainder.startsWith(district)) continue;
        _district = district;
        _streetController.text = remainder.substring(district.length).trim();
        return;
      }
    }
    _streetController.text = address;
  }

  List<String> get _districtOptions =>
      _city == null ? const [] : taiwanAdministrativeAreas[_city]!;

  String get _fullAddress =>
      '$_city$_district${_streetController.text.trim()}'.trim();

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    final result = await ref
        .read(locationRepositoryProvider)
        .getCurrentLocation();
    if (!mounted) return;
    setState(() {
      _isLocating = false;
      _location = result.coordinates;
    });
    if (result.coordinates == null) {
      _showMessage('無法取得目前位置，請檢查定位權限。');
    }
  }

  Future<void> _pickPhotos() async {
    final selected = await _imagePicker.pickMultiImage(limit: 5);
    if (mounted && selected.isNotEmpty) {
      setState(() => _photos = selected.take(5).toList(growable: false));
    }
  }

  Future<void> _openImportedGoogleMaps() async {
    final rawUrl = widget.importedPlace?.googleMapsUrl;
    final uri = rawUrl == null ? null : Uri.tryParse(rawUrl);
    if (uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }
    if (mounted) _showMessage('無法開啟 Google Maps 連結。');
  }

  Future<void> _submit({
    bool duplicateAcknowledged = false,
    String? idempotencyKey,
  }) async {
    if (!_canSubmit()) return;
    final draft = _buildDraft();
    setState(() {
      _isSubmitting = true;
      _progress = 0;
    });
    try {
      final submission = await _submitDraft(
        draft,
        duplicateAcknowledged: duplicateAcknowledged,
        idempotencyKey: idempotencyKey,
      );
      await _handleSubmissionSuccess(submission);
    } on ContributionException catch (error) {
      await _handleContributionError(error);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool _canSubmit() {
    if (!_formKey.currentState!.validate()) return false;
    if (_categories.isEmpty) {
      _showMessage('請至少選擇一個分類。');
      return false;
    }
    if (_location == null && _isLocating) {
      _showMessage('請先等待目前位置取得完成。');
      return false;
    }
    return true;
  }

  RestaurantContributionDraft _buildDraft() {
    return RestaurantContributionDraft(
      name: _nameController.text.trim(),
      address: _fullAddress,
      location: _location,
      googleMapsUrl: widget.importedPlace?.googleMapsUrl,
      categories: _categories.toList(growable: false),
      recommendedDishes: _dishesController.text
          .split(RegExp('[,，、\n]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .take(10)
          .toList(growable: false),
      amenities: _amenities.toList(growable: false),
      photos: _photos,
    );
  }

  Future<RestaurantSubmissionResult> _submitDraft(
    RestaurantContributionDraft draft, {
    required bool duplicateAcknowledged,
    required String? idempotencyKey,
  }) {
    return ref
        .read(contributionRepositoryProvider)
        .submitRestaurant(
          draft,
          duplicateAcknowledged: duplicateAcknowledged,
          idempotencyKey: idempotencyKey,
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
        );
  }

  Future<void> _handleSubmissionSuccess(
    RestaurantSubmissionResult submission,
  ) async {
    if (!mounted) return;
    _showMessage(
      submission.photoUploadFailed ? '店家已新增，但照片上傳失敗；可在店家頁重新上傳。' : '店家已新增。',
    );
    await ref.read(adServiceProvider).showInterstitial();
    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('店家新增完成'),
        content: Text(
          submission.photoUploadFailed
              ? '店家已新增，但照片上傳失敗；稍後仍可到店家頁重新上傳。'
              : '店家已成功新增。接下來要做什麼？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('home'),
            child: const Text('回首頁'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop('continue'),
            child: const Text('繼續新增下一個店家'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop('edit'),
            child: const Text('修改店家'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'home') {
      context.go('/');
      return;
    }
    if (action == 'continue') {
      _resetFormForNextRestaurant();
      return;
    }

    final queryParameters = <String, String>{'edit': '1'};
    if (submission.photoUploadFailed) {
      queryParameters['photoUploadFailed'] = '1';
    }
    context.go(
      Uri(
        path: '/restaurants/${submission.restaurantId}',
        queryParameters: queryParameters,
      ).toString(),
    );
  }

  void _resetFormForNextRestaurant() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _streetController.clear();
    _dishesController.clear();
    setState(() {
      _categories.clear();
      _amenities.clear();
      _city = null;
      _district = null;
      _photos = const [];
      _location = null;
      _progress = 0;
    });
    _showMessage('已清空表單，可以新增下一個店家。');
  }

  Future<void> _handleContributionError(ContributionException error) async {
    if (!mounted) return;
    if (error.candidates.isNotEmpty) {
      await _confirmDuplicate(error);
      return;
    }
    final retryText = error.retryAfterSeconds == null
        ? ''
        : ' 約 ${error.retryAfterSeconds} 秒後可再試。';
    _showMessage('${error.message}$retryText');
  }

  Future<void> _confirmDuplicate(ContributionException error) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('附近可能已有相同店家'),
        content: SizedBox(
          width: 480,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final candidate in error.candidates)
                ListTile(
                  title: Text(candidate.name),
                  subtitle: Text(
                    '${candidate.address}\n約 ${candidate.distanceMeters.round()} 公尺',
                  ),
                  onTap: () => Navigator.of(dialogContext).pop(candidate.id),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop('continue'),
            child: const Text('不是同一家，繼續新增'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'continue') {
      await _submit(
        duplicateAcknowledged: true,
        idempotencyKey: error.idempotencyKey,
      );
    } else {
      context.push('/restaurants/$action');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<Widget> _buildFormSections(BuildContext context) {
    return [
      const _FormIntroduction(),
      const SizedBox(height: 24),
      if (widget.importedPlace != null) ...[
        _ImportedPlaceNotice(
          showGoogleMapsLink: widget.importedPlace?.googleMapsUrl != null,
          onOpenGoogleMaps: _openImportedGoogleMaps,
        ),
        const SizedBox(height: 20),
      ],
      _buildBasicSection(),
      const SizedBox(height: 20),
      _buildLocationSection(),
      const SizedBox(height: 20),
      _buildCategorySection(),
      const SizedBox(height: 20),
      _buildAmenitySection(),
      const SizedBox(height: 20),
      _buildPhotoSection(),
      if (_isSubmitting) ...[
        const SizedBox(height: 24),
        _SubmissionProgress(progress: _progress),
      ],
      const SizedBox(height: 28),
      FilledButton.icon(
        onPressed: _isSubmitting ? null : _submit,
        icon: const Icon(Icons.publish_outlined),
        label: const Text('發布店家'),
      ),
      const SizedBox(height: 12),
      Text(
        '送出前會檢查同名且距離 200 公尺內的店家；若有候選，不會直接阻擋連鎖分店。',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }

  Widget _buildBasicSection() {
    return _FormSection(
      number: '01',
      title: '店家基本資料',
      subtitle: '地址為必填，讓其他人更容易找到這家店。',
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            enabled: !_isSubmitting,
            decoration: const InputDecoration(
              labelText: '店家名稱',
              hintText: '例如：管吃小館',
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
            validator: (value) =>
                (value?.trim().length ?? 0) < 2 ? '請輸入至少 2 個字的店家名稱' : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: ValueKey(_city),
            initialValue: _city,
            decoration: const InputDecoration(
              labelText: '縣市',
              prefixIcon: Icon(Icons.map_outlined),
            ),
            items: [
              for (final city in taiwanAdministrativeAreas.keys)
                DropdownMenuItem(value: city, child: Text(city)),
            ],
            onChanged: _isSubmitting
                ? null
                : (value) => setState(() {
                    _city = value;
                    _district = null;
                  }),
            validator: (value) => value == null ? '請選擇縣市' : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            key: ValueKey('${_city}_$_district'),
            initialValue: _district,
            decoration: const InputDecoration(
              labelText: '鄉鎮市區',
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
            items: [
              for (final district in _districtOptions)
                DropdownMenuItem(value: district, child: Text(district)),
            ],
            onChanged: _isSubmitting || _city == null
                ? null
                : (value) => setState(() => _district = value),
            validator: (value) => value == null ? '請選擇鄉鎮市區' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _streetController,
            enabled: !_isSubmitting,
            minLines: 1,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '路段與門牌',
              hintText: '例如：市府路 45 號',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            validator: (value) =>
                (value?.trim().length ?? 0) < 2 ? '請輸入路段與門牌' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return _FormSection(
      number: '02',
      title: '店家座標（選填）',
      subtitle: '不按也能新增，仍可透過搜尋與最新店家找到，但沒辦法出現在附近。',
      child: _LocationPicker(
        location: _location,
        isLocating: _isLocating,
        isSubmitting: _isSubmitting,
        onUseCurrentLocation: _useCurrentLocation,
      ),
    );
  }

  Widget _buildCategorySection() {
    return _FormSection(
      number: '03',
      title: '分類與推薦菜色',
      subtitle: '至少選一個分類，推薦菜色可以留白。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in FoodCategories.all)
                FilterChip(
                  label: Text(category),
                  selected: _categories.contains(category),
                  onSelected: _isSubmitting
                      ? null
                      : (selected) =>
                            _toggleValue(_categories, category, selected),
                ),
            ],
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _dishesController,
            enabled: !_isSubmitting,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '推薦菜色',
              hintText: '以逗號分隔，例如：牛肉麵、小菜',
              prefixIcon: Icon(Icons.restaurant_menu_outlined),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmenitySection() {
    return _FormSection(
      number: '04',
      title: '店家設施（選填）',
      subtitle: '勾選店家實際提供的設施，讓其他人更容易判斷是否適合前往。',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final amenity in RestaurantAmenities.all)
            FilterChip(
              label: Text(amenity),
              selected: _amenities.contains(amenity),
              onSelected: _isSubmitting
                  ? null
                  : (selected) => _toggleValue(_amenities, amenity, selected),
            ),
        ],
      ),
    );
  }

  void _toggleValue(Set<String> values, String value, bool selected) {
    setState(() {
      if (selected) {
        values.add(value);
      } else {
        values.remove(value);
      }
    });
  }

  Widget _buildPhotoSection() {
    return _FormSection(
      number: '05',
      title: '店家照片（選填）',
      subtitle: '最多 5 張，第一張會作為封面。',
      child: _PhotoPicker(
        photoCount: _photos.length,
        isSubmitting: _isSubmitting,
        onPickPhotos: _pickPhotos,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('分享一家好店')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: _buildFormSections(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormIntroduction extends StatelessWidget {
  const _FormIntroduction();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('把好味道分享出去。', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            '填寫基本資料後，就能讓更多人發現這家店。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ImportedPlaceNotice extends StatelessWidget {
  const _ImportedPlaceNotice({
    required this.showGoogleMapsLink,
    required this.onOpenGoogleMaps,
  });

  final bool showGoogleMapsLink;
  final VoidCallback onOpenGoogleMaps;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bookmark_added_outlined),
                const SizedBox(width: 8),
                Text(
                  '從 Google 地圖收藏匯入',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('請確認店名與地址後，再發布為公開店家。'),
            if (showGoogleMapsLink) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: onOpenGoogleMaps,
                icon: const Icon(Icons.open_in_new),
                label: const Text('開啟原始 Google Maps 連結'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String number;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    child: Text(
                      number,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _LocationPicker extends StatelessWidget {
  const _LocationPicker({
    required this.location,
    required this.isLocating,
    required this.isSubmitting,
    required this.onUseCurrentLocation,
  });

  final GeoCoordinates? location;
  final bool isLocating;
  final bool isSubmitting;
  final VoidCallback onUseCurrentLocation;

  @override
  Widget build(BuildContext context) {
    final hasLocation = location != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasLocation ? Icons.location_on : Icons.location_searching,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasLocation ? '已取得座標' : '尚未設定座標',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            if (hasLocation) ...[
              const SizedBox(height: 8),
              Text(
                '${location!.latitude.toStringAsFixed(5)}, ${location!.longitude.toStringAsFixed(5)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: isSubmitting || isLocating
                  ? null
                  : onUseCurrentLocation,
              icon: isLocating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(hasLocation ? '重新取得目前位置' : '使用目前位置'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photoCount,
    required this.isSubmitting,
    required this.onPickPhotos,
  });

  final int photoCount;
  final bool isSubmitting;
  final VoidCallback onPickPhotos;

  @override
  Widget build(BuildContext context) {
    final selected = photoCount > 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.photo_library_outlined
                  : Icons.add_photo_alternate_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selected ? '已選擇 $photoCount 張照片' : '還沒有選擇照片',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton(
              onPressed: isSubmitting ? null : onPickPhotos,
              child: Text(selected ? '重新選擇' : '選擇照片'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmissionProgress extends StatelessWidget {
  const _SubmissionProgress({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '投稿處理中 ${progress == 0 ? '' : '${(progress * 100).round()}%'}',
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progress == 0 ? null : progress),
          ],
        ),
      ),
    );
  }
}
