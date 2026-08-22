import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/auth_user.dart';
import '../../data/models/favorite_restaurant.dart';
import '../../data/models/imported_place.dart';
import '../../data/providers/account_providers.dart';
import '../../data/providers/ad_providers.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/favorite_providers.dart';
import '../../data/providers/imported_places_providers.dart';
import '../../data/providers/moderation_providers.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/favorite_repository.dart';

/// Profile tab. Sign-in state, own submissions, admin entry land in Phase 1/5.
class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateChangesProvider);
    final privacyOptionsRequired = ref.watch(adPrivacyOptionsRequiredProvider);

    Future<void> showPrivacyOptions() async {
      final message = await ref.read(adServiceProvider).showPrivacyOptions();
      ref.invalidate(adPrivacyOptionsRequiredProvider);
      if (message != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: authState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            const Center(child: Text('無法取得登入狀態，請稍後再試。')),
        data: (user) => user == null
            ? _SignedOutProfile(
                onSignIn: () => context.go('/login?from=/me'),
                privacyOptionsRequired: privacyOptionsRequired,
                onPrivacyOptions: showPrivacyOptions,
              )
            : _SignedInProfile(
                user: user,
                favorites: ref.watch(favoritesProvider),
                isAdmin: ref.watch(adminStatusProvider),
                privacyOptionsRequired: privacyOptionsRequired,
                onPrivacyOptions: showPrivacyOptions,
                onSignOut: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) {
                    context.go('/');
                  }
                },
                onDeleteAccount: () async {
                  await ref.read(accountRepositoryProvider).deleteAccount();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('帳號與個人資料已刪除。')),
                    );
                    context.go('/');
                  }
                },
              ),
      ),
    );
  }
}

class _SignedOutProfile extends StatelessWidget {
  const _SignedOutProfile({
    required this.onSignIn,
    required this.privacyOptionsRequired,
    required this.onPrivacyOptions,
  });

  final VoidCallback onSignIn;
  final AsyncValue<bool> privacyOptionsRequired;
  final VoidCallback onPrivacyOptions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_outline, size: 72),
            const SizedBox(height: 16),
            Text('尚未登入', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('登入後可查看收藏、投稿紀錄與帳號設定。'),
            const SizedBox(height: 24),
            FilledButton(onPressed: onSignIn, child: const Text('前往登入')),
            if (privacyOptionsRequired.asData?.value == true) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onPrivacyOptions,
                child: const Text('隱私權選項'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SignedInProfile extends StatefulWidget {
  const _SignedInProfile({
    required this.user,
    required this.favorites,
    required this.isAdmin,
    required this.privacyOptionsRequired,
    required this.onPrivacyOptions,
    required this.onSignOut,
    required this.onDeleteAccount,
  });

  final AuthUser user;
  final AsyncValue<List<FavoriteRestaurant>> favorites;
  final AsyncValue<bool> isAdmin;
  final AsyncValue<bool> privacyOptionsRequired;
  final VoidCallback onPrivacyOptions;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onDeleteAccount;

  @override
  State<_SignedInProfile> createState() => _SignedInProfileState();
}

class _SignedInProfileState extends State<_SignedInProfile> {
  bool _isSigningOut = false;
  bool _isDeletingAccount = false;

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await widget.onSignOut();
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  Future<void> _confirmAccountDeletion() async {
    final confirmationController = TextEditingController();
    var confirmation = '';
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('永久刪除帳號？'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('收藏、評論與照片會永久移除；餐廳與必要的防濫用紀錄會匿名化。此動作無法復原。'),
                    const SizedBox(height: 16),
                    const Text('請輸入「刪除」以繼續：'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmationController,
                      autofocus: true,
                      onChanged: (value) {
                        setDialogState(() => confirmation = value.trim());
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '刪除',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: confirmation == '刪除'
                      ? () => Navigator.of(dialogContext).pop(true)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('永久刪除'),
                ),
              ],
            );
          },
        );
      },
    );
    confirmationController.dispose();

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isDeletingAccount = true);
    try {
      await widget.onDeleteAccount();
    } on AccountDeletionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        CircleAvatar(
          radius: 40,
          foregroundImage: user.photoUrl == null
              ? null
              : NetworkImage(user.photoUrl!),
          child: user.photoUrl == null
              ? const Icon(Icons.person, size: 40)
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          user.displayName ?? '美食通使用者',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (user.email != null) ...[
          const SizedBox(height: 4),
          Text(user.email!, textAlign: TextAlign.center),
        ],
        const SizedBox(height: 32),
        _FavoriteSection(favorites: widget.favorites),
        const ListTile(
          leading: Icon(Icons.history),
          title: Text('投稿紀錄'),
          subtitle: Text('將在投稿功能階段啟用'),
        ),
        if (widget.isAdmin.asData?.value == true)
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text('後台管理'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/admin'),
          ),
        if (widget.isAdmin.asData?.value == true)
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('Google 地圖收藏匯入'),
            subtitle: const Text('匯入 Takeout「已儲存」CSV 到私人收藏'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/import-google-saved-places'),
          ),
        if (widget.privacyOptionsRequired.asData?.value == true)
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('隱私權選項'),
            subtitle: const Text('管理廣告與資料使用同意'),
            onTap: widget.onPrivacyOptions,
          ),
        const Divider(),
        ListTile(
          enabled: !_isSigningOut && !_isDeletingAccount,
          leading: const Icon(Icons.logout),
          title: Text(_isSigningOut ? '登出中…' : '登出'),
          onTap: _isSigningOut ? null : _signOut,
        ),
        ListTile(
          enabled: !_isSigningOut && !_isDeletingAccount,
          iconColor: Theme.of(context).colorScheme.error,
          textColor: Theme.of(context).colorScheme.error,
          leading: const Icon(Icons.delete_forever_outlined),
          title: Text(_isDeletingAccount ? '刪除處理中…' : '刪除帳號與資料'),
          subtitle: const Text('需要重新登入並二次確認'),
          onTap: _isSigningOut || _isDeletingAccount
              ? null
              : _confirmAccountDeletion,
        ),
        const _ImportedPlacesSection(),
      ],
    );
  }
}

class _FavoriteSection extends ConsumerWidget {
  const _FavoriteSection({required this.favorites});

  final AsyncValue<List<FavoriteRestaurant>> favorites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExpansionTile(
      leading: const Icon(Icons.favorite_outline),
      title: const Text('我的最愛'),
      subtitle: _favoriteSubtitle(favorites),
      children: _favoriteChildren(context, ref, favorites),
    );
  }

  Widget _favoriteSubtitle(AsyncValue<List<FavoriteRestaurant>> value) {
    return value.when(
      loading: () => const Text('載入中…'),
      error: (error, stackTrace) => const Text('收藏載入失敗'),
      data: (items) => Text('${items.length} 家店'),
    );
  }

  List<Widget> _favoriteChildren(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<FavoriteRestaurant>> value,
  ) {
    return value.when(
      loading: () => const [LinearProgressIndicator()],
      error: (error, stackTrace) => const [
        ListTile(title: Text('無法載入收藏，請稍後再試。')),
      ],
      data: (items) => _favoriteItems(context, ref, items),
    );
  }

  List<Widget> _favoriteItems(
    BuildContext context,
    WidgetRef ref,
    List<FavoriteRestaurant> favorites,
  ) {
    if (favorites.isEmpty) {
      return const [ListTile(title: Text('尚未收藏店家。'))];
    }
    return favorites
        .map((favorite) => _favoriteTile(context, ref, favorite))
        .toList(growable: false);
  }

  Widget _favoriteTile(
    BuildContext context,
    WidgetRef ref,
    FavoriteRestaurant favorite,
  ) {
    return ListTile(
      leading: const Icon(Icons.restaurant_outlined),
      title: Text(favorite.name),
      subtitle: Text(favorite.categories.join('、')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openFavorite(context, ref, favorite),
    );
  }

  Future<void> _openFavorite(
    BuildContext context,
    WidgetRef ref,
    FavoriteRestaurant favorite,
  ) async {
    try {
      final targetId = await ref
          .read(favoriteRepositoryProvider)
          .resolveFavoriteTarget(favorite.restaurantId);
      if (context.mounted) context.push('/restaurants/$targetId');
    } on FavoriteException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

class _ImportedPlacesSection extends ConsumerWidget {
  const _ImportedPlacesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(importedPlacesProvider);
    return ExpansionTile(
      leading: const Icon(Icons.bookmark_outline),
      title: const Text('我的匯入收藏'),
      subtitle: places.when(
        loading: () => const Text('讀取中…'),
        error: (error, stackTrace) => const Text('讀取失敗'),
        data: (items) => Text('${items.length} 筆'),
      ),
      children: _buildPlaceChildren(context, places),
    );
  }

  List<Widget> _buildPlaceChildren(
    BuildContext context,
    AsyncValue<List<ImportedPlace>> places,
  ) {
    return places.when(
      loading: () => const [LinearProgressIndicator()],
      error: (error, stackTrace) => const [ListTile(title: Text('無法讀取匯入收藏。'))],
      data: (items) => _buildPlaceItems(context, items),
    );
  }

  List<Widget> _buildPlaceItems(
    BuildContext context,
    List<ImportedPlace> places,
  ) {
    if (places.isEmpty) {
      return const [ListTile(title: Text('尚未匯入 Google 地圖收藏。'))];
    }
    return places
        .map((place) {
          final subtitle = place.address.isEmpty
              ? 'Google Maps 收藏，請確認後建立公開店家'
              : place.address;
          return ListTile(
            leading: const Icon(Icons.restaurant_outlined),
            onTap: () => context.push('/upload', extra: place),
            title: Text(place.sourceTitle),
            subtitle: Text(subtitle),
            trailing: IconButton(
              tooltip: '在地圖開啟',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => _openMap(context, place),
            ),
          );
        })
        .toList(growable: false);
  }

  Future<void> _openMap(BuildContext context, ImportedPlace place) async {
    final uri = place.googleMapsUrl == null
        ? Uri.https('www.google.com', '/maps/search/', {
            'api': '1',
            'query': '${place.latitude},${place.longitude}',
          })
        : Uri.tryParse(place.googleMapsUrl!);
    if (uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('無法開啟地圖。')));
    }
  }
}
