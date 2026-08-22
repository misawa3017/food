import '../../data/models/imported_place.dart';

List<ImportedPlaceSource> parseGoogleSavedPlacesCsv(String csv) {
  final rows = _parseCsv(csv);
  if (rows.isEmpty) return const [];
  final header = rows.first
      .map((value) => value.replaceFirst('\uFEFF', '').trim())
      .toList();
  final titleIndex = header.indexOf('標題');
  final noteIndex = header.indexOf('筆記');
  final urlIndex = header.indexOf('網址');
  if (titleIndex < 0 || urlIndex < 0) {
    throw const FormatException('這不是 Google 地圖「已儲存」匯出的 CSV 檔。');
  }
  final seen = <String>{};
  return rows
      .skip(1)
      .map(
        (row) => _placeFromRow(
          row,
          titleIndex: titleIndex,
          noteIndex: noteIndex,
          urlIndex: urlIndex,
        ),
      )
      .whereType<ImportedPlaceSource>()
      .where((place) => seen.add(place.title))
      .toList(growable: false);
}

ImportedPlaceSource? _placeFromRow(
  List<String> row, {
  required int titleIndex,
  required int noteIndex,
  required int urlIndex,
}) {
  if (titleIndex >= row.length) return null;
  final title = row[titleIndex].trim();
  if (title.isEmpty) return null;
  final note = noteIndex >= 0 && noteIndex < row.length
      ? row[noteIndex].trim()
      : '';
  final url = urlIndex < row.length ? row[urlIndex].trim() : '';
  return ImportedPlaceSource(
    title: title,
    note: note.isEmpty ? null : note,
    googleMapsUrl: url.isEmpty ? null : url,
  );
}

List<List<String>> _parseCsv(String source) {
  return _CsvParser(source).parse();
}

class _CsvParser {
  _CsvParser(this.source);

  final String source;
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;

  List<List<String>> parse() {
    for (var index = 0; index < source.length; index += 1) {
      index = _consume(index);
    }
    if (quoted) throw const FormatException('CSV 檔案的引號格式不完整。');
    if (field.isNotEmpty || row.isNotEmpty) {
      _finishRow(addEmptyRow: true);
    }
    return rows;
  }

  int _consume(int index) {
    final char = source[index];
    if (char == '"') return _consumeQuote(index);
    if (char == ',' && !quoted) {
      row.add(field.toString());
      field.clear();
      return index;
    }
    if ((char == '\n' || char == '\r') && !quoted) {
      final nextIndex =
          char == '\r' && index + 1 < source.length && source[index + 1] == '\n'
          ? index + 1
          : index;
      _finishRow();
      return nextIndex;
    }
    field.write(char);
    return index;
  }

  int _consumeQuote(int index) {
    if (quoted && index + 1 < source.length && source[index + 1] == '"') {
      field.write('"');
      return index + 1;
    }
    quoted = !quoted;
    return index;
  }

  void _finishRow({bool addEmptyRow = false}) {
    row.add(field.toString());
    field.clear();
    if (addEmptyRow || row.any((value) => value.isNotEmpty)) rows.add(row);
    row = <String>[];
  }
}
