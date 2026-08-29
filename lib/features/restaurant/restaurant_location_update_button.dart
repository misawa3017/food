import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/contribution_providers.dart';
import '../../data/providers/location_providers.dart';
import '../../data/providers/restaurant_providers.dart';
import '../../data/repositories/contribution_repository.dart';

class RestaurantLocationUpdateButton extends ConsumerStatefulWidget {
  const RestaurantLocationUpdateButton({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  ConsumerState<RestaurantLocationUpdateButton> createState() =>
      _RestaurantLocationUpdateButtonState();
}

class _RestaurantLocationUpdateButtonState
    extends ConsumerState<RestaurantLocationUpdateButton> {
  bool _isUpdating = false;

  Future<void> _updateFromCurrentLocation() async {
    setState(() => _isUpdating = true);
    try {
      final location = await ref
          .read(locationRepositoryProvider)
          .getCurrentLocation();
      final coordinates = location.coordinates;
      if (coordinates == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('無法取得目前位置，請確認定位服務與權限。')),
          );
        }
        return;
      }
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('更新店家座標？'),
          content: const Text('將使用你目前的位置更新店家座標，請確認你正位於店家。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('更新座標'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await ref
          .read(contributionRepositoryProvider)
          .updateRestaurantLocation(
            restaurantId: widget.restaurantId,
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
          );
      ref.invalidate(restaurantProvider(widget.restaurantId));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('店家座標已更新。')));
      }
    } on ContributionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _isUpdating ? null : _updateFromCurrentLocation,
      icon: _isUpdating
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.my_location_outlined),
      label: Text(_isUpdating ? '取得位置中' : '使用目前位置更新座標'),
    );
  }
}
