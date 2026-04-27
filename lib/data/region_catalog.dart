/// Снеговой и ветровой районы по СП 20.13330.2016.
///
/// Снеговые районы обозначаются римскими цифрами от I до VIII (от меньшей
/// расчётной нагрузки к большей). Ветровые — от Ia (минимальная) до VII.
class RegionInfo {
  final String city;
  final int snowZone; // 1..8
  final String windZone; // например, "Ia", "I", "II", ..., "VII"

  const RegionInfo({
    required this.city,
    required this.snowZone,
    required this.windZone,
  });

  /// Снеговой район в виде римской цифры.
  String get snowZoneRoman => _toRoman(snowZone);

  RegionInfo copyWith({String? city, int? snowZone, String? windZone}) {
    return RegionInfo(
      city: city ?? this.city,
      snowZone: snowZone ?? this.snowZone,
      windZone: windZone ?? this.windZone,
    );
  }
}

/// Каталог 30 крупных городов РФ с предзаполненными значениями районов
/// по СП 20.13330. Значения приведены ориентировочно — при необходимости
/// проектировщик может задать собственные значения через визард технического задания.
const List<RegionInfo> kRegionCatalog = [
  RegionInfo(city: 'Москва', snowZone: 3, windZone: 'I'),
  RegionInfo(city: 'Санкт-Петербург', snowZone: 3, windZone: 'II'),
  RegionInfo(city: 'Новосибирск', snowZone: 4, windZone: 'III'),
  RegionInfo(city: 'Екатеринбург', snowZone: 3, windZone: 'II'),
  RegionInfo(city: 'Казань', snowZone: 4, windZone: 'II'),
  RegionInfo(city: 'Нижний Новгород', snowZone: 4, windZone: 'I'),
  RegionInfo(city: 'Челябинск', snowZone: 3, windZone: 'II'),
  RegionInfo(city: 'Самара', snowZone: 4, windZone: 'III'),
  RegionInfo(city: 'Омск', snowZone: 3, windZone: 'II'),
  RegionInfo(city: 'Ростов-на-Дону', snowZone: 2, windZone: 'III'),
  RegionInfo(city: 'Уфа', snowZone: 5, windZone: 'II'),
  RegionInfo(city: 'Красноярск', snowZone: 3, windZone: 'III'),
  RegionInfo(city: 'Воронеж', snowZone: 3, windZone: 'II'),
  RegionInfo(city: 'Пермь', snowZone: 5, windZone: 'II'),
  RegionInfo(city: 'Волгоград', snowZone: 2, windZone: 'III'),
  RegionInfo(city: 'Краснодар', snowZone: 2, windZone: 'IV'),
  RegionInfo(city: 'Саратов', snowZone: 3, windZone: 'III'),
  RegionInfo(city: 'Тюмень', snowZone: 3, windZone: 'II'),
  RegionInfo(city: 'Тольятти', snowZone: 4, windZone: 'III'),
  RegionInfo(city: 'Ижевск', snowZone: 5, windZone: 'I'),
  RegionInfo(city: 'Барнаул', snowZone: 4, windZone: 'III'),
  RegionInfo(city: 'Иркутск', snowZone: 2, windZone: 'III'),
  RegionInfo(city: 'Хабаровск', snowZone: 3, windZone: 'III'),
  RegionInfo(city: 'Владивосток', snowZone: 2, windZone: 'IV'),
  RegionInfo(city: 'Калининград', snowZone: 3, windZone: 'II'),
  RegionInfo(city: 'Сочи', snowZone: 1, windZone: 'IV'),
  RegionInfo(city: 'Ставрополь', snowZone: 2, windZone: 'III'),
  RegionInfo(city: 'Архангельск', snowZone: 4, windZone: 'II'),
  RegionInfo(city: 'Мурманск', snowZone: 5, windZone: 'IV'),
  RegionInfo(city: 'Якутск', snowZone: 2, windZone: 'II'),
];

const List<int> kSnowZones = [1, 2, 3, 4, 5, 6, 7, 8];
const List<String> kWindZones = ['Ia', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII'];

String _toRoman(int n) {
  switch (n) {
    case 1:
      return 'I';
    case 2:
      return 'II';
    case 3:
      return 'III';
    case 4:
      return 'IV';
    case 5:
      return 'V';
    case 6:
      return 'VI';
    case 7:
      return 'VII';
    case 8:
      return 'VIII';
  }
  return n.toString();
}
