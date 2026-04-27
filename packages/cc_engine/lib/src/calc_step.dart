import 'package:meta/meta.dart';

/// Один шаг расчёта — формула, её обозначения, значения, и результат.
///
/// Все расчёты движка возвращают список таких шагов, чтобы из них прямо
/// рендерилась пояснительная записка (ПЗ): «по формуле X (Y) с подстановкой
/// значений Z получаем W». Без необходимости запускать расчёт второй раз.
@immutable
class CalcStep {
  const CalcStep({
    required this.title,
    required this.formula,
    required this.substitution,
    required this.result,
    required this.unit,
    this.reference,
    this.note,
  });

  /// Заголовок шага: «Снеговая нагрузка», «Расчётное сопротивление грунта»
  /// и т.п. — то, что попадёт в подзаголовок раздела ПЗ.
  final String title;

  /// Символьная формула: `S = µ · Sg · γf`. Без подставленных значений.
  /// Используется в ПЗ как блок формулы.
  final String formula;

  /// Подстановка значений: `S = 1.0 · 1.5 · 1.4 = 2.1`.
  final String substitution;

  /// Числовой результат шага. Используется в дальнейших шагах и в выводе.
  final double result;

  /// Единица измерения результата: «кН/м²», «м³», «кг» и т.п.
  final String unit;

  /// Ссылка на нормативный документ, например `СП 20.13330.2016, табл. 10.1`.
  /// Может быть null, если шаг чисто арифметический.
  final String? reference;

  /// Произвольный пояснительный текст, попадающий в ПЗ под формулой
  /// (например, «принят по табл. 10.1 для III снегового района»).
  final String? note;

  /// Удобное значение «результат с единицей», для логов и отладки.
  String get formattedResult => '$result $unit';

  @override
  String toString() =>
      'CalcStep($title: $formula = $substitution = $formattedResult)';
}

/// Контейнер для итогового результата расчётного блока: список шагов плюс
/// ключевой числовой итог. Можно вкладывать (см. [FoundationLoads]).
@immutable
class CalcResult {
  const CalcResult({required this.steps, required this.value});

  final List<CalcStep> steps;

  /// Финальное число этого блока — то, что используется снаружи
  /// (например, в `FoundationLoads.totalVerticalLoad`).
  final double value;

  @override
  String toString() => 'CalcResult($value, ${steps.length} steps)';
}
