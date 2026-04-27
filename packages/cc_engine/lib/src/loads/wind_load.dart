import '../calc_step.dart';
import '../regions/wind_region.dart';

/// Тип местности по СП 20, п. 11.1.6.
enum TerrainType {
  /// A — открытые побережья, степи, тундра.
  a,

  /// B — городские территории, лесные массивы (типичный частный дом).
  b,

  /// C — городские районы с плотной застройкой выше 25 м.
  c,
}

/// Расчёт ветровой нагрузки по СП 20.13330.2016.
///
/// Для частного дома (h ≤ 10 м) в основной массе случаев вертикальная
/// составляющая мала по сравнению с собственным весом, но она нужна для
/// расчёта стоек каркаса и анкеровки фундамента.
class WindLoadCalculator {
  /// Коэффициент надёжности по ветровой нагрузке (СП 20, п. 11.1.12).
  static const double gammaFwind = 1.4;

  /// Расчётное значение нормативного ветрового давления на отметке h
  /// от земли, кН/м².
  ///
  /// `wm = w0 · k(z) · c · γf`
  /// где:
  ///   w0   — нормативное ветровое давление по району (СП 20, табл. 11.1);
  ///   k(z) — коэффициент изменения по высоте (табл. 11.2 СП 20);
  ///   c    — аэродинамический коэффициент (для наветренной стены 0.8);
  ///   γf   — коэффициент надёжности 1.4.
  static CalcResult calculate({
    required WindRegion region,
    required TerrainType terrain,
    required double heightMeters,
    double aerodynamicCoefficient = 0.8,
    String regionOrigin = 'Принято по умолчанию',
    String heightOrigin = 'Грубая оценка по этажности',
  }) {
    final k = _kForHeight(terrain, heightMeters);
    final wm = region.w0 * k * aerodynamicCoefficient * gammaFwind;

    return CalcResult(
      value: wm,
      steps: [
        CalcStep(
          title: 'Нормативное ветровое давление w0',
          formula: 'w0',
          substitution: 'w0 = ${region.w0} кН/м²',
          result: region.w0,
          unit: 'кН/м²',
          reference: 'СП 20.13330.2016, табл. 11.1, ${region.title}',
          inputs: [
            CalcInput(
              symbol: 'w0',
              value: '${region.w0} кН/м²',
              origin: regionOrigin,
              reference: 'СП 20.13330.2016, табл. 11.1',
            ),
          ],
        ),
        CalcStep(
          title: 'Коэффициент по высоте k(z)',
          formula: 'k(z) = f(тип местности, z)',
          substitution:
              'k = $k (z = $heightMeters м, тип ${terrain.name.toUpperCase()})',
          result: k,
          unit: '—',
          reference: 'СП 20.13330.2016, табл. 11.2',
          note: 'Коэффициент учитывает шероховатость подстилающей '
              'поверхности и логарифмический профиль скорости ветра.',
          inputs: [
            CalcInput(
              symbol: 'z',
              value: '$heightMeters м',
              origin: heightOrigin,
            ),
            CalcInput(
              symbol: 'тип местности',
              value: terrain.name.toUpperCase(),
              origin: 'Принят B (городские территории, лесные массивы) — '
                  'типично для частного дома. Меняется на странице расчёта '
                  'в следующей версии.',
              reference: 'СП 20.13330.2016, п. 11.1.6',
            ),
            CalcInput(
              symbol: 'k(z)',
              value: '$k',
              origin: 'Линейная интерполяция табл. 11.2 СП 20 для z и '
                  'выбранного типа местности.',
              reference: 'СП 20.13330.2016, табл. 11.2',
            ),
          ],
        ),
        CalcStep(
          title: 'Расчётное ветровое давление wm',
          formula: 'wm = w0 · k(z) · c · γf',
          substitution:
              'wm = ${region.w0} · $k · $aerodynamicCoefficient · $gammaFwind = ${_round(wm)}',
          result: wm,
          unit: 'кН/м²',
          reference: 'СП 20.13330.2016, п. 11.1.3',
          note: 'Для расчёта анкеровки фундамента и стоек каркаса.',
          inputs: [
            CalcInput(
              symbol: 'w0',
              value: '${region.w0} кН/м²',
              origin: 'Из шага «Нормативное ветровое давление w0» выше.',
            ),
            CalcInput(
              symbol: 'k(z)',
              value: '$k',
              origin: 'Из шага «Коэффициент по высоте k(z)» выше.',
            ),
            CalcInput(
              symbol: 'c',
              value: '$aerodynamicCoefficient',
              origin: 'Аэродинамический коэффициент. Принят 0.8 для '
                  'наветренной стены.',
              reference: 'СП 20.13330.2016, п. 11.1.7',
            ),
            CalcInput(
              symbol: 'γf',
              value: '$gammaFwind',
              origin: 'Константа: коэффициент надёжности по ветровой '
                  'нагрузке.',
              reference: 'СП 20.13330.2016, п. 11.1.12',
            ),
          ],
        ),
      ],
    );
  }

  /// Линейная аппроксимация табл. 11.2 СП 20 для типичных высот.
  /// Для частного дома до 10 м точности достаточно.
  static double _kForHeight(TerrainType t, double z) {
    final clamped = z.clamp(5.0, 480.0);
    switch (t) {
      case TerrainType.a:
        // k(5)=0.75, k(10)=1.0
        if (clamped <= 10) return 0.75 + (clamped - 5) * (1.0 - 0.75) / 5;
        return 1.0 + (clamped - 10) * (1.25 - 1.0) / 10;
      case TerrainType.b:
        // k(5)=0.5, k(10)=0.65
        if (clamped <= 10) return 0.5 + (clamped - 5) * (0.65 - 0.5) / 5;
        return 0.65 + (clamped - 10) * (0.85 - 0.65) / 10;
      case TerrainType.c:
        // k(5)=0.4, k(10)=0.4 (constant), k(20)=0.55
        if (clamped <= 10) return 0.4;
        return 0.4 + (clamped - 10) * (0.55 - 0.4) / 10;
    }
  }

  static double _round(double v) => (v * 1000).roundToDouble() / 1000;
}
