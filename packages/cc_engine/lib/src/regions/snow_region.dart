import 'package:meta/meta.dart';

/// Снеговые районы РФ по СП 20.13330.2016, карта 1 приложения Е.
///
/// Значения `sg` — расчётный вес снегового покрова на 1 м² горизонтальной
/// поверхности земли (кПа). Это базовая величина, дальше она корректируется
/// коэффициентом µ (форма кровли) и γf (надёжности по нагрузке).
@immutable
class SnowRegion {
  const SnowRegion({
    required this.id,
    required this.title,
    required this.sg,
  });

  /// Номер района: 1‑VIII (в норме «римские», в коде — арабские для удобства).
  final int id;

  /// Человекочитаемое название: «I район», «II район» и т.д.
  final String title;

  /// Расчётный вес снегового покрова, кПа (= кН/м²). СП 20, табл. 10.1.
  final double sg;

  /// Все 8 снеговых районов РФ. Привязка регионов к району — отдельным
  /// справочником (region_catalog.dart на уровне приложения).
  static const List<SnowRegion> all = [
    SnowRegion(id: 1, title: 'I район', sg: 0.8),
    SnowRegion(id: 2, title: 'II район', sg: 1.2),
    SnowRegion(id: 3, title: 'III район', sg: 1.5),
    SnowRegion(id: 4, title: 'IV район', sg: 2.0),
    SnowRegion(id: 5, title: 'V район', sg: 2.5),
    SnowRegion(id: 6, title: 'VI район', sg: 3.0),
    SnowRegion(id: 7, title: 'VII район', sg: 3.5),
    SnowRegion(id: 8, title: 'VIII район', sg: 4.0),
  ];

  static SnowRegion byId(int id) =>
      all.firstWhere((r) => r.id == id, orElse: () => all.first);
}
