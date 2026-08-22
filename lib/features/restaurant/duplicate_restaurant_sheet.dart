import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/restaurant.dart';
import '../../data/providers/contribution_providers.dart';
import '../../data/providers/restaurant_providers.dart';
import '../../data/repositories/contribution_repository.dart';
import '../../data/repositories/restaurant_repository.dart';

Future<void> showDuplicateRestaurantSheet(
  BuildContext context,
  WidgetRef ref,
  Restaurant sourceRestaurant,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _DuplicateRestaurantSheet(sourceRestaurant: sourceRestaurant),
  );
}

class _DuplicateRestaurantSheet extends ConsumerStatefulWidget {
  const _DuplicateRestaurantSheet({required this.sourceRestaurant});

  final Restaurant sourceRestaurant;

  @override
  ConsumerState<_DuplicateRestaurantSheet> createState() =>
      _DuplicateRestaurantSheetState();
}

class _DuplicateRestaurantSheetState
    extends ConsumerState<_DuplicateRestaurantSheet> {
  final _searchController = TextEditingController();
  final _reasonController = TextEditingController();
  RestaurantSearchQuery _query = const RestaurantSearchQuery(limit: 10);
  Restaurant? _target;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _searchController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final target = _target;
    if (target == null || _reasonController.text.trim().length < 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請選擇保留店家，並填寫至少 5 個字的原因。')));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(contributionRepositoryProvider)
          .submitDuplicateRestaurant(
            sourceRestaurantId: widget.sourceRestaurant.id,
            targetRestaurantId: target.id,
            reason: _reasonController.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('重複店家申請已送出，等待管理員確認。')));
      }
    } on ContributionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchRestaurantsProvider(_query));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('回報重複店家', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('來源店家：${widget.sourceRestaurant.name}'),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: '搜尋要保留的店家',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _query = RestaurantSearchQuery(
                          keyword: _searchController.text,
                          limit: 10,
                        );
                      });
                    },
                    icon: const Icon(Icons.search),
                  ),
                ),
                onSubmitted: (value) {
                  setState(() {
                    _query = RestaurantSearchQuery(keyword: value, limit: 10);
                  });
                },
              ),
              const SizedBox(height: 8),
              Expanded(
                child: results.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) =>
                      const Center(child: Text('搜尋失敗。')),
                  data: (items) {
                    final candidates = items
                        .where((item) => item.id != widget.sourceRestaurant.id)
                        .toList(growable: false);
                    return RadioGroup<String>(
                      groupValue: _target?.id,
                      onChanged: _isSubmitting
                          ? (_) {}
                          : (value) {
                              setState(() {
                                _target = candidates.firstWhere(
                                  (restaurant) => restaurant.id == value,
                                );
                              });
                            },
                      child: ListView(
                        children: [
                          for (final restaurant in candidates)
                            RadioListTile<String>(
                              value: restaurant.id,
                              title: Text(restaurant.name),
                              subtitle: Text(restaurant.address),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              TextField(
                controller: _reasonController,
                enabled: !_isSubmitting,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '判斷為重複店家的原因',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(_isSubmitting ? '送出中…' : '送出申請'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
