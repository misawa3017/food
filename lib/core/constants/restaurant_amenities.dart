/// 店家可提供的固定設施選項。
///
/// 使用固定值可避免同一設施被以不同文字重複儲存，方便未來篩選。
abstract final class RestaurantAmenities {
  static const all = <String>[
    '停車場',
    '可刷卡',
    '行動支付',
    'Wi-Fi',
    '可訂位',
    '外帶',
    '外送',
    '親子友善',
    '無障礙設施',
    '寵物友善',
  ];
}
