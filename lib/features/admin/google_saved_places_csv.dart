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
  final places = <ImportedPlaceSource>[];
  for (final row in rows.skip(1)) {
    if (titleIndex >= row.length) continue;
    final title = row[titleIndex].trim();
    if (title.isEmpty || !seen.add(title)) continue;
    final note = noteIndex >= 0 && noteIndex < row.length
        ? row[noteIndex].trim()
        : '';
    final url = urlIndex < row.length ? row[urlIndex].trim() : '';
    places.add(
      ImportedPlaceSource(
        title: title,
        note: note.isEmpty ? null : note,
        googleMapsUrl: url.isEmpty ? null : url,
      ),
    );
  }
  return places;
}

List<List<String>> _parseCsv(String source) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;

  for (var index = 0; index < source.length; index += 1) {
    final char = source[index];
    if (char == '"') {
      if (quoted && index + 1 < source.length && source[index + 1] == '"') {
        field.write('"');
        index += 1;
      } else {
        quoted = !quoted;
      }
    } else if (char == ',' && !quoted) {
      row.add(field.toString());
      field.clear();
    } else if ((char == '\n' || char == '\r') && !quoted) {
      if (char == '\r' &&
          index + 1 < source.length &&
          source[index + 1] == '\n') {
        index += 1;
      }
      row.add(field.toString());
      field.clear();
      if (row.any((value) => value.isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      field.write(char);
    }
  }
  if (quoted) throw const FormatException('CSV 檔案的引號格式不完整。');
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}
