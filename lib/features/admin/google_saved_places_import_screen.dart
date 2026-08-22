import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/imported_place.dart';
import '../../data/providers/imported_places_providers.dart';
import '../../data/repositories/imported_places_repository.dart';
import 'google_saved_places_csv.dart';

class GoogleSavedPlacesImportScreen extends ConsumerStatefulWidget {
  const GoogleSavedPlacesImportScreen({super.key});

  @override
  ConsumerState<GoogleSavedPlacesImportScreen> createState() =>
      _GoogleSavedPlacesImportScreenState();
}

class _GoogleSavedPlacesImportScreenState
    extends ConsumerState<GoogleSavedPlacesImportScreen> {
  List<ImportedPlaceSource> _sourcePlaces = const [];
  List<ImportedPlaceMatch> _matches = const [];
  final Set<int> _selected = <int>{};
  final Map<int, int> _candidateSelections = <int, int>{};
  bool _isResolving = false;
  bool _isSaving = false;
  int _resolvedCount = 0;

  Future<void> _pickCsv() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
    if (file == null || !mounted) return;
    try {
      final places = parseGoogleSavedPlacesCsv(
        utf8.decode(await file.readAsBytes()),
      );
      if (places.isEmpty) {
        _showMessage('CSV 裡沒有可匯入的店家。');
        return;
      }
      setState(() {
        _sourcePlaces = places;
        _matches = const [];
        _selected.clear();
        _candidateSelections.clear();
        _resolvedCount = 0;
      });
      _showMessage('已讀取 ${places.length} 筆店家，請開始比對。');
    } on FormatException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _resolveAll() async {
    if (_sourcePlaces.isEmpty || _isResolving) return;
    setState(() {
      _isResolving = true;
      _matches = const [];
      _selected.clear();
      _candidateSelections.clear();
      _resolvedCount = 0;
    });
    try {
      var imported = 0;
      for (var offset = 0; offset < _sourcePlaces.length; offset += 100) {
        final end = offset + 100 > _sourcePlaces.length
            ? _sourcePlaces.length
            : offset + 100;
        imported += await ref
            .read(importedPlacesRepositoryProvider)
            .importOriginalPlaces(_sourcePlaces.sublist(offset, end));
        if (!mounted) return;
        setState(() => _resolvedCount = imported);
      }
      if (!mounted) return;
      _showMessage('已匯入 $imported 筆私人收藏。請到「我的」逐筆確認後建立公開店家。');
    } on ImportedPlacesException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Future<void> _saveSelected() async {
    final selections =
        <({ImportedPlaceSource source, ImportedPlaceCandidate candidate})>[];
    for (final index in _selected) {
      final match = _matches[index];
      final candidateIndex = _candidateSelections[index] ?? 0;
      if (candidateIndex < match.candidates.length) {
        selections.add((
          source: match.source,
          candidate: match.candidates[candidateIndex],
        ));
      }
    }
    if (selections.isEmpty) {
      _showMessage('請先選擇至少一筆正確的比對結果。');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認匯入收藏'),
        content: Text('將匯入 ${selections.length} 筆私人收藏。匯入後不會建立公開店家資料。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('確認匯入'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSaving = true);
    try {
      var saved = 0;
      for (var offset = 0; offset < selections.length; offset += 100) {
        final end = offset + 100 > selections.length
            ? selections.length
            : offset + 100;
        saved += await ref
            .read(importedPlacesRepositoryProvider)
            .save(selections.sublist(offset, end));
      }
      if (!mounted) return;
      _showMessage('已匯入 $saved 筆私人收藏。');
    } on ImportedPlacesException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _clearImportedPlaces() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除已匯入資料？'),
        content: const Text('這只會刪除 Google 地圖收藏匯入的私人資料，不會影響店家、評論、照片或帳號。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final deleted = await ref.read(importedPlacesRepositoryProvider).clear();
      _showMessage('已清除 $deleted 筆匯入資料。');
    } on ImportedPlacesException catch (error) {
      _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Google 地圖收藏匯入')),
      body: _matches.isEmpty
          ? _ImportStart(
              sourceCount: _sourcePlaces.length,
              resolvedCount: _resolvedCount,
              isResolving: _isResolving,
              onPickCsv: _pickCsv,
              onResolve: _resolveAll,
              onClear: _clearImportedPlaces,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _matches.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _ImportSummary(
                    matchedCount: _matches
                        .where((item) => item.candidates.isNotEmpty)
                        .length,
                    selectedCount: _selected.length,
                    isSaving: _isSaving,
                    onSave: _saveSelected,
                  );
                }
                return _MatchCard(
                  index: index - 1,
                  match: _matches[index - 1],
                  selected: _selected.contains(index - 1),
                  selectedCandidate: _candidateSelections[index - 1] ?? 0,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _selected.add(index - 1);
                      } else {
                        _selected.remove(index - 1);
                      }
                    });
                  },
                  onCandidateChanged: (candidate) {
                    if (candidate == null) return;
                    setState(() => _candidateSelections[index - 1] = candidate);
                  },
                );
              },
            ),
    );
  }
}

class _ImportStart extends StatelessWidget {
  const _ImportStart({
    required this.sourceCount,
    required this.resolvedCount,
    required this.isResolving,
    required this.onPickCsv,
    required this.onResolve,
    required this.onClear,
  });

  final int sourceCount;
  final int resolvedCount;
  final bool isResolving;
  final VoidCallback onPickCsv;
  final VoidCallback onResolve;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.file_upload_outlined, size: 64),
        const SizedBox(height: 16),
        Text(
          '匯入 Google 地圖已儲存清單',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        const Text(
          '請選擇 Google Takeout 的「已儲存」CSV。系統會使用 Geoapify 比對店名與座標；資料只會存到你的私人收藏，不會公開新增店家。',
        ),
        const SizedBox(height: 8),
        const Text(
          '比對完成後請確認候選店家。資料來源：Powered by Geoapify © OpenStreetMap contributors。',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: isResolving ? null : onPickCsv,
          icon: const Icon(Icons.description_outlined),
          label: const Text('選擇 CSV 檔'),
        ),
        if (sourceCount > 0) ...[
          const SizedBox(height: 12),
          Text('已讀取 $sourceCount 筆店家。'),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: isResolving ? null : onResolve,
            icon: isResolving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.travel_explore),
            label: Text(
              isResolving ? '比對中 $resolvedCount / $sourceCount' : '開始比對',
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: isResolving ? null : onClear,
          icon: const Icon(Icons.delete_outline),
          label: const Text('清除先前匯入的收藏資料'),
        ),
      ],
    );
  }
}

class _ImportSummary extends StatelessWidget {
  const _ImportSummary({
    required this.matchedCount,
    required this.selectedCount,
    required this.isSaving,
    required this.onSave,
  });

  final int matchedCount;
  final int selectedCount;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('比對結果', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('找到 $matchedCount 筆候選店家，已選擇 $selectedCount 筆。'),
            const SizedBox(height: 8),
            const Text('請取消名稱或地址不正確的項目，也可選擇其他候選店家。'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isSaving ? null : onSave,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bookmark_add_outlined),
              label: Text(isSaving ? '匯入中…' : '確認匯入 $selectedCount 筆'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.index,
    required this.match,
    required this.selected,
    required this.selectedCandidate,
    required this.onSelected,
    required this.onCandidateChanged,
  });

  final int index;
  final ImportedPlaceMatch match;
  final bool selected;
  final int selectedCandidate;
  final ValueChanged<bool> onSelected;
  final ValueChanged<int?> onCandidateChanged;

  @override
  Widget build(BuildContext context) {
    final candidates = match.candidates;
    final candidateValue = selectedCandidate < candidates.length
        ? selectedCandidate
        : 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${index + 1}. ${match.source.title}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (match.source.note != null) ...[
              const SizedBox(height: 4),
              Text(
                match.source.note!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            if (candidates.isEmpty)
              const Text('找不到候選店家，這筆不會匯入。')
            else ...[
              DropdownButtonFormField<int>(
                initialValue: candidateValue,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '比對結果',
                ),
                items: [
                  for (
                    var candidateIndex = 0;
                    candidateIndex < candidates.length;
                    candidateIndex += 1
                  )
                    DropdownMenuItem(
                      value: candidateIndex,
                      child: Text(
                        '${candidates[candidateIndex].name}｜${candidates[candidateIndex].address}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: onCandidateChanged,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: selected,
                onChanged: (value) => onSelected(value ?? false),
                title: const Text('匯入這筆私人收藏'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
