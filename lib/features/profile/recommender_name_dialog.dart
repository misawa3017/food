import 'package:flutter/material.dart';

/// 顯示公開推薦暱稱輸入視窗，取消時回傳 null。
Future<String?> showRecommenderNameDialog(
  BuildContext context, {
  String? currentName,
  String? message,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        _RecommenderNameDialog(currentName: currentName, message: message),
  );
}

class _RecommenderNameDialog extends StatefulWidget {
  const _RecommenderNameDialog({this.currentName, this.message});

  final String? currentName;
  final String? message;

  @override
  State<_RecommenderNameDialog> createState() => _RecommenderNameDialogState();
}

class _RecommenderNameDialogState extends State<_RecommenderNameDialog> {
  // 由視窗持有，關閉動畫結束才釋放，避免動畫期間使用到已釋放的控制器。
  late final _controller = TextEditingController(
    text: widget.currentName ?? '',
  );
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.length < 2) {
      setState(() => _errorText = '請輸入至少 2 個字元。');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    return AlertDialog(
      title: const Text('公開推薦暱稱'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message != null) ...[Text(message), const SizedBox(height: 12)],
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 24,
              decoration: InputDecoration(
                hintText: '例如：Jason 的美食筆記',
                helperText: '2 至 24 個字元，會公開顯示在你推薦的店家上。',
                errorText: _errorText,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('儲存')),
      ],
    );
  }
}
