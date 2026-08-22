import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/services/firebase_emulator_service.dart';

class RestaurantImage extends StatelessWidget {
  const RestaurantImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
  });

  final String? imageUrl;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final url = _platformImageUrl(imageUrl?.trim());
    if (url == null || url.isEmpty) {
      return const _ImageFallback();
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (context, url) => const ColoredBox(
        color: Color(0x14000000),
        child: Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => const _ImageFallback(),
    );
  }

  String? _platformImageUrl(String? value) {
    if (value == null ||
        !FirebaseEmulatorService.enabled ||
        (!value.contains('127.0.0.1:9199') &&
            !value.contains('localhost:9199'))) {
      return value;
    }
    final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : 'localhost';
    return value
        .replaceFirst('127.0.0.1:9199', '$host:9199')
        .replaceFirst('localhost:9199', '$host:9199');
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.16),
      child: Center(
        child: Icon(
          Icons.restaurant,
          size: 48,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }
}
