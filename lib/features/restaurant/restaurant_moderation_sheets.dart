import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/restaurant.dart';
import '../../data/providers/contribution_providers.dart';
import '../../data/repositories/contribution_repository.dart';

Future<void> showRestaurantEditSheet(
  BuildContext context,
  WidgetRef ref,
  Restaurant restaurant,
) async {
  final name = TextEditingController(text: restaurant.name);
  final address = TextEditingController(text: restaurant.address);
  final dishes = TextEditingController(
    text: restaurant.recommendedDishes.join('、'),
  );
  final reason = TextEditingController();
  final submitted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('建議修改資料'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: '店家名稱'),
            ),
            TextField(
              controller: address,
              decoration: const InputDecoration(labelText: '地址'),
            ),
            TextField(
              controller: dishes,
              decoration: const InputDecoration(labelText: '推薦菜色'),
            ),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: '修正原因'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('送出'),
        ),
      ],
    ),
  );
  if (submitted == true && context.mounted) {
    try {
      await ref
          .read(contributionRepositoryProvider)
          .submitRestaurantEdit(
            restaurantId: restaurant.id,
            changes: {
              'name': name.text,
              'address': address.text,
              'recommendedDishes': dishes.text
                  .split(RegExp('[,，、\n]'))
                  .map((item) => item.trim())
                  .where((item) => item.isNotEmpty)
                  .toList(),
            },
            reason: reason.text,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('資料修正申請已送出。')));
      }
    } on ContributionException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
  name.dispose();
  address.dispose();
  dishes.dispose();
  reason.dispose();
}

Future<void> showRestaurantReportDialog(
  BuildContext context,
  WidgetRef ref,
  Restaurant restaurant,
) async {
  final reason = TextEditingController();
  final submitted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('回報店家'),
      content: TextField(
        controller: reason,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: '請說明停業或不當內容原因',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('送出'),
        ),
      ],
    ),
  );
  if (submitted == true && context.mounted) {
    try {
      await ref
          .read(contributionRepositoryProvider)
          .submitReport(
            targetType: 'restaurant',
            restaurantId: restaurant.id,
            reason: reason.text,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('檢舉已送出，等待管理員處理。')));
      }
    } on ContributionException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
  reason.dispose();
}
