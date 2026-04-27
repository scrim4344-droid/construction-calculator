import 'package:meta/meta.dart';

/// Ветровые районы РФ по СП 20.13330.2016, карта 2 приложения Е и табл. 11.1.
///
/// Значение `w0` — нормативное значение ветрового давления, кПа.
@immutable
class WindRegion {
  const WindRegion({
    required this.id,
    required this.title,
    required this.w0,
  });

  /// Номер района: 1а, 1, 2, 3, 4, 5, 6, 7. В коде используем арабские
  /// цифры; «1а» представлен как 0 (отдельный «нулевой» район для удобства).
  final int id;
  final String title;

  /// Нормативное ветровое давление, кПа (= кН/м²). СП 20, табл. 11.1.
  final double w0;

  static const List<WindRegion> all = [
    WindRegion(id: 0, title: 'Iа район', w0: 0.17),
    WindRegion(id: 1, title: 'I район', w0: 0.23),
    WindRegion(id: 2, title: 'II район', w0: 0.30),
    WindRegion(id: 3, title: 'III район', w0: 0.38),
    WindRegion(id: 4, title: 'IV район', w0: 0.48),
    WindRegion(id: 5, title: 'V район', w0: 0.60),
    WindRegion(id: 6, title: 'VI район', w0: 0.73),
    WindRegion(id: 7, title: 'VII район', w0: 0.85),
  ];

  static WindRegion byId(int id) =>
      all.firstWhere((r) => r.id == id, orElse: () => all.first);
}
