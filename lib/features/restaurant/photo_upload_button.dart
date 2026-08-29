import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/providers/auth_providers.dart';
import '../../data/providers/contribution_providers.dart';
import '../../data/providers/restaurant_providers.dart';
import '../../data/repositories/contribution_repository.dart';

class PhotoUploadButton extends ConsumerStatefulWidget {
  const PhotoUploadButton({super.key, required this.restaurantId});

  final String restaurantId;

  @override
  ConsumerState<PhotoUploadButton> createState() => _PhotoUploadButtonState();
}

class _PhotoUploadButtonState extends ConsumerState<PhotoUploadButton> {
  bool _isUploading = false;
  double _progress = 0;

  Future<void> _selectAndUpload() async {
    final user = ref.read(authStateChangesProvider).asData?.value;
    if (user == null) {
      final from = GoRouterState.of(context).uri.toString();
      context.push('/login?from=${Uri.encodeComponent(from)}');
      return;
    }
    final photos = await ImagePicker().pickMultiImage(limit: 5);
    if (photos.isEmpty || !mounted) {
      return;
    }
    setState(() {
      _isUploading = true;
      _progress = 0;
    });
    try {
      await ref
          .read(contributionRepositoryProvider)
          .addPhotos(
            widget.restaurantId,
            photos,
            onProgress: (progress) {
              if (mounted) {
                setState(() => _progress = progress);
              }
            },
          );
      ref.invalidate(restaurantProvider(widget.restaurantId));
      ref.invalidate(restaurantPhotosProvider(widget.restaurantId));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('照片已新增。')));
      }
    } on ContributionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isUploading) {
      return SizedBox(
        width: 120,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: _progress == 0 ? null : _progress),
            const SizedBox(height: 4),
            Text('${(_progress * 100).round()}%'),
          ],
        ),
      );
    }
    return FilledButton.tonalIcon(
      onPressed: _selectAndUpload,
      icon: const Icon(Icons.add_photo_alternate_outlined),
      label: const Text('補上傳照片'),
    );
  }
}
