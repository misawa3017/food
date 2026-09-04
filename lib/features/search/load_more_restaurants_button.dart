import 'package:flutter/material.dart';

class LoadMoreRestaurantsButton extends StatelessWidget {
  const LoadMoreRestaurantsButton({
    super.key,
    this.isLoading = false,
    this.errorMessage,
    required this.onPressed,
  });

  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (errorMessage != null) ...[
            Text(
              errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
          ],
          FilledButton.tonalIcon(
            onPressed: onPressed,
            icon: const Icon(Icons.expand_more),
            label: const Text('載入更多店家'),
          ),
        ],
      ),
    );
  }
}
