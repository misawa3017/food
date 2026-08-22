import 'package:flutter_test/flutter_test.dart';

import 'package:food_app/features/admin/google_saved_places_csv.dart';

void main() {
  test('parses Google Takeout saved places CSV and preserves quoted notes', () {
    const csv = '\uFEFF標題,筆記,網址,標籤,留言\n'
        '168鹹粥,"排隊店, 記得早點去",https://www.google.com/maps/place/one,,\n'
        '168鹹粥,,https://www.google.com/maps/place/duplicate,,\n'
        '六松今苑,,https://www.google.com/maps/place/two,,\n';

    final places = parseGoogleSavedPlacesCsv(csv);

    expect(places, hasLength(2));
    expect(places.first.title, '168鹹粥');
    expect(places.first.note, '排隊店, 記得早點去');
    expect(places.last.googleMapsUrl, 'https://www.google.com/maps/place/two');
  });

  test('rejects CSV that is not a Google Takeout saved list', () {
    expect(
      () => parseGoogleSavedPlacesCsv('name,address\n店家,台北市\n'),
      throwsFormatException,
    );
  });
}
