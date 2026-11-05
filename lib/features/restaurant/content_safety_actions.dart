import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/auth_providers.dart';
import '../../data/providers/block_providers.dart';
import '../../data/providers/contribution_providers.dart';
import '../../data/repositories/block_repository.dart';
import '../../data/repositories/contribution_repository.dart';

/// 可以檢舉的內容類型，對應後端 submitReport 的 targetType。
enum ReportTarget {
  restaurant('restaurant', '店家'),
  photo('photo', '照片'),
  review('review', '評論');

  const ReportTarget(this.value, this.label);

  final String value;
  final String label;
}

/// 檢舉不當內容。restaurant 以外的類型需要 [contentId]。
Future<void> showContentReportDialog(
  BuildContext context,
  WidgetRef ref, {
  required ReportTarget target,
  required String restaurantId,
  String? contentId,
}) async {
  if (!_requireSignIn(context, ref, '檢舉')) return;
  final reason = await showDialog<String>(
    context: context,
    builder: (context) => _ReportReasonDialog(target: target),
  );
  if (reason == null || !context.mounted) return;

  try {
    await ref
        .read(contributionRepositoryProvider)
        .submitReport(
          targetType: target.value,
          restaurantId: restaurantId,
          contentId: contentId,
          reason: reason,
        );
    if (context.mounted) {
      _showMessage(context, '檢舉已送出，管理員會在 24 小時內處理。');
    }
  } on ContributionException catch (error) {
    if (context.mounted) _showMessage(context, error.message);
  }
}

/// 封鎖使用者：立即隱藏對方的內容，並把觸發封鎖的內容送交管理員檢查。
Future<void> confirmBlockUser(
  BuildContext context,
  WidgetRef ref, {
  required String blockedUid,
  required String displayName,
  required ReportTarget target,
  required String restaurantId,
  String? contentId,
}) async {
  if (!_requireSignIn(context, ref, '封鎖使用者')) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('封鎖「$displayName」？'),
      content: const Text(
        '封鎖後，你將不會再看到這位使用者新增的店家、照片與評論，'
        '我們也會通知管理員檢查這則內容。你可以在「我的 → 封鎖名單」解除封鎖。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('封鎖'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await ref
        .read(blockRepositoryProvider)
        .blockUser(blockedUid: blockedUid, displayName: displayName);
  } on BlockException catch (error) {
    if (context.mounted) _showMessage(context, error.message);
    return;
  } catch (_) {
    if (context.mounted) _showMessage(context, '封鎖失敗，請稍後再試。');
    return;
  }
  if (context.mounted) _showMessage(context, '已封鎖「$displayName」。');

  // 封鎖已生效；通知管理員失敗（例如同一內容已有待處理檢舉）不影響封鎖結果。
  try {
    await ref
        .read(contributionRepositoryProvider)
        .submitReport(
          targetType: target.value,
          restaurantId: restaurantId,
          contentId: contentId,
          reason: '使用者封鎖了這則${target.label}的作者，請檢查是否有不當內容。',
        );
  } on ContributionException {
    // 忽略。
  }
}

bool _requireSignIn(BuildContext context, WidgetRef ref, String action) {
  final user = ref.read(authStateChangesProvider).asData?.value;
  if (user != null) return true;
  _showMessage(context, '請先登入後再$action。');
  return false;
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _ReportReasonDialog extends StatefulWidget {
  const _ReportReasonDialog({required this.target});

  final ReportTarget target;

  @override
  State<_ReportReasonDialog> createState() => _ReportReasonDialogState();
}

class _ReportReasonDialogState extends State<_ReportReasonDialog> {
  static const _reasons = ['色情或暴力內容', '仇恨、騷擾或霸凌', '垃圾訊息或廣告', '不實或誤導資訊'];

  // 由視窗持有，關閉動畫結束才釋放，避免動畫期間使用到已釋放的控制器。
  final _details = TextEditingController();
  String? _selected;
  String? _errorText;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  void _submit() {
    final details = _details.text.trim();
    final selected = _selected;
    if (selected == null && details.length < 5) {
      setState(() => _errorText = '請選擇原因，或輸入至少 5 個字的說明。');
      return;
    }
    final reason = [?selected, if (details.isNotEmpty) details].join('：');
    // 後端要求至少 5 個字。
    Navigator.pop(context, reason.length < 5 ? '$reason（使用者檢舉）' : reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('檢舉${widget.target.label}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RadioGroup<String>(
              groupValue: _selected,
              onChanged: (value) => setState(() {
                _selected = value;
                _errorText = null;
              }),
              child: Column(
                children: [
                  for (final reason in _reasons)
                    RadioListTile<String>(
                      value: reason,
                      title: Text(reason),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _details,
              maxLines: 3,
              maxLength: 400,
              decoration: InputDecoration(
                labelText: '補充說明（選填）',
                border: const OutlineInputBorder(),
                errorText: _errorText,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('送出檢舉')),
      ],
    );
  }
}
