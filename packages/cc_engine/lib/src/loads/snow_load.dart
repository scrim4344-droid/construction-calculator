import '../calc_step.dart';
import '../regions/snow_region.dart';

/// Тип кровли для подбора коэффициента формы µ по СП 20, прил. Б.
enum RoofShape {
  /// Плоская, односкатная или малоуклонная (α ≤ 30°).
  flatOrLowSlope,

  /// Двускатная с уклоном 30° < α < 60°.
  gable,

  /// Крутая (α ≥ 60°) — снег не задерживается.
  steep,
}

/// Расчёт снеговой нагрузки на кровлю по СП 20.13330.2016.
class SnowLoadCalculator {
  /// Коэффициент надёжности по снеговой нагрузке (СП 20, п. 10.12). Для
  /// постоянных и длительных сочетаний при расчёте по предельному
  /// состоянию I группы.
  static const double gammaFsnow = 1.4;

  /// Расчётное значение снеговой нагрузки на горизонтальную проекцию,
  /// кН/м². Возвращается с журналом расчёта для ПЗ.
  ///
  /// `S = µ · Sg · γf`
  /// где:
  ///   µ  — коэффициент перехода от веса снегового покрова на земле к
  ///        снеговой нагрузке на кровлю (зависит от формы кровли);
  ///   Sg — расчётный вес снегового покрова на 1 м² (СП 20, табл. 10.1);
  ///   γf — коэффициент надёжности по нагрузке (1.4 по п. 10.12).
  ///
  /// `regionOrigin` — текстовое описание, откуда взят `region` (например,
  /// «Из брифа: «Регион → Москва» → III снеговой район по карте 1
  /// прил. Е СП 20»). Это попадает в `CalcInput.origin` и видно в UI.
  static CalcResult calculate({
    required SnowRegion region,
    required RoofShape roofShape,
    required double slopeDegrees,
    String regionOrigin = 'Принято по умолчанию',
  }) {
    final mu = _muForRoof(roofShape, slopeDegrees);
    final s = mu * region.sg * gammaFsnow;

    return CalcResult(
      value: s,
      steps: [
        CalcStep(
          title: 'Расчётный вес снегового покрова Sg',
          formula: 'Sg',
          substitution: 'Sg = ${region.sg} кН/м²',
          result: region.sg,
          unit: 'кН/м²',
          reference: 'СП 20.13330.2016, табл. 10.1, ${region.title}',
          note: 'Принят по карте 1 приложения Е для выбранного региона.',
          inputs: [
            CalcInput(
              symbol: 'Sg',
              value: '${region.sg} кН/м²',
              origin: regionOrigin,
              reference: 'СП 20.13330.2016, табл. 10.1',
            ),
          ],
        ),
        CalcStep(
          title: 'Коэффициент формы кровли µ',
          formula: 'µ = f(α)',
          substitution: 'µ = $mu (α = $slopeDegrees°)',
          result: mu,
          unit: '—',
          reference: 'СП 20.13330.2016, прил. Б, схема Б.1',
          note: _muNote(roofShape, slopeDegrees),
          inputs: [
            CalcInput(
              symbol: 'α',
              value: '$slopeDegrees°',
              origin: 'Из проекта: уклон кровли (заполняется в брифе или '
                  'на странице кровли). Если не задан — 30° по умолчанию.',
            ),
            CalcInput(
              symbol: 'µ',
              value: '$mu',
              origin: 'Получен по форме кровли и углу α: '
                  '${_muOrigin(roofShape, slopeDegrees)}',
              reference: 'СП 20.13330.2016, прил. Б, схема Б.1',
            ),
          ],
        ),
        CalcStep(
          title: 'Снеговая нагрузка S',
          formula: 'S = µ · Sg · γf',
          substitution:
              'S = $mu · ${region.sg} · $gammaFsnow = ${_round(s)}',
          result: s,
          unit: 'кН/м²',
          reference: 'СП 20.13330.2016, п. 10.1, формула (10.1)',
          inputs: [
            CalcInput(
              symbol: 'µ',
              value: '$mu',
              origin: 'Из шага «Коэффициент формы кровли µ» выше.',
            ),
            CalcInput(
              symbol: 'Sg',
              value: '${region.sg} кН/м²',
              origin: regionOrigin,
              reference: 'СП 20.13330.2016, табл. 10.1',
            ),
            CalcInput(
              symbol: 'γf',
              value: '$gammaFsnow',
              origin: 'Константа: коэффициент надёжности по снеговой '
                  'нагрузке для расчёта по I группе предельных состояний.',
              reference: 'СП 20.13330.2016, п. 10.12',
            ),
          ],
        ),
      ],
    );
  }

  static double _muForRoof(RoofShape shape, double slopeDeg) {
    // СП 20, прил. Б.1, упрощённо для скатных кровель.
    switch (shape) {
      case RoofShape.flatOrLowSlope:
        return 1.0;
      case RoofShape.gable:
        // Линейная интерполяция: µ=1.0 при 30°, µ=0 при 60°.
        if (slopeDeg <= 30) return 1.0;
        if (slopeDeg >= 60) return 0.0;
        return (60 - slopeDeg) / 30.0;
      case RoofShape.steep:
        return 0.0;
    }
  }

  static String _muNote(RoofShape shape, double slopeDeg) {
    switch (shape) {
      case RoofShape.flatOrLowSlope:
        return 'Кровля плоская или малоуклонная (α ≤ 30°), µ = 1.0.';
      case RoofShape.gable:
        return 'Двускатная кровля, µ интерполируется между 1.0 при 30° '
            'и 0 при 60°.';
      case RoofShape.steep:
        return 'Крутая кровля (α ≥ 60°), снег не задерживается, µ = 0.';
    }
  }

  static String _muOrigin(RoofShape shape, double slopeDeg) {
    switch (shape) {
      case RoofShape.flatOrLowSlope:
        return 'плоская/малоуклонная (α ≤ 30°) ⇒ µ = 1.0';
      case RoofShape.gable:
        return 'двускатная (30° < α < 60°), линейная интерполяция между '
            '1.0 (при 30°) и 0 (при 60°)';
      case RoofShape.steep:
        return 'крутая (α ≥ 60°), снег не задерживается ⇒ µ = 0';
    }
  }

  static double _round(double v) => (v * 1000).roundToDouble() / 1000;
}
