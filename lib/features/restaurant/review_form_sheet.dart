import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/restaurant_review.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/contribution_providers.dart';
import '../../data/providers/restaurant_providers.dart';
import '../../data/repositories/contribution_repository.dart';

Future<void> showReviewFormSheet(
  BuildContext context,
  WidgetRef ref,
  String restaurantId, [
  RestaurantReview? review,
]) async {
  if (ref.read(authStateChangesProvider).asData?.value == null) {
    final from = GoRouterState.of(context).uri.toString();
    context.push('/login?from=${Uri.encodeComponent(from)}');
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _ReviewForm(restaurantId: restaurantId, review: review),
  );
}

Future<void> showDeleteReviewDialog(
  BuildContext context,
  WidgetRef ref,
  String restaurantId,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('刪除評論'),
      content: const Text('確定要刪除你的評分與評論嗎？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('刪除'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await ref.read(contributionRepositoryProvider).deleteReview(restaurantId);
    ref.invalidate(restaurantProvider(restaurantId));
    ref.invalidate(restaurantReviewsProvider(restaurantId));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('評論已刪除。')));
    }
  } on ContributionException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _ReviewForm extends ConsumerStatefulWidget {
  const _ReviewForm({required this.restaurantId, this.review});

  final String restaurantId;
  final RestaurantReview? review;

  @override
  ConsumerState<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<_ReviewForm> {
  late final TextEditingController _textController;
  late int _rating;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.review?.text ?? '');
    _rating = widget.review?.rating ?? 5;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(contributionRepositoryProvider)
          .submitReview(
            restaurantId: widget.restaurantId,
            rating: _rating,
            text: _textController.text,
          );
      ref.invalidate(restaurantProvider(widget.restaurantId));
      ref.invalidate(restaurantReviewsProvider(widget.restaurantId));
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('評論已送出。')));
      }
    } on ContributionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.review == null ? '留下評分與評論' : '編輯評分與評論',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var value = 1; value <= 5; value += 1)
                IconButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() => _rating = value),
                  icon: Icon(
                    value <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: Colors.amber,
                  ),
                ),
            ],
          ),
          TextField(
            controller: _textController,
            enabled: !_isSubmitting,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: '留言（選填）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: Text(
                _isSubmitting
                    ? '送出中…'
                    : widget.review == null
                    ? '送出評論'
                    : '儲存評論',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
