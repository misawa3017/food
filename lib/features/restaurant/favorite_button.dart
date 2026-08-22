import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/restaurant.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/favorite_providers.dart';
import '../../data/repositories/favorite_repository.dart';

class FavoriteButton extends ConsumerStatefulWidget {
  const FavoriteButton({
    super.key,
    required this.restaurant,
    this.filled = false,
  });

  final Restaurant restaurant;
  final bool filled;

  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton> {
  bool _isSaving = false;

  Future<void> _toggle() async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) {
      final from = GoRouterState.of(context).uri.toString();
      context.push('/login?from=${Uri.encodeComponent(from)}');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(favoriteRepositoryProvider)
          .toggleFavorite(widget.restaurant);
    } on FavoriteException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('收藏更新失敗，請稍後再試。')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(favoriteStatusProvider(widget.restaurant.id));
    final isFavorite = status.asData?.value ?? false;
    final icon = _isSaving
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(isFavorite ? Icons.favorite : Icons.favorite_border);

    if (widget.filled) {
      return IconButton.filledTonal(
        tooltip: isFavorite ? '取消收藏' : '加入收藏',
        onPressed: _isSaving ? null : _toggle,
        icon: icon,
      );
    }
    return IconButton(
      tooltip: isFavorite ? '取消收藏' : '加入收藏',
      onPressed: _isSaving ? null : _toggle,
      icon: icon,
    );
  }
}
