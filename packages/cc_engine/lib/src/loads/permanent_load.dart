import '../calc_step.dart';

/// Один весовой компонент дома: «стены», «перекрытия», «кровля» и т.п.
///
/// `weightKnPerM2` — расчётный собственный вес на 1 м² горизонтальной
/// проекции. Уже включает в себя коэффициент надёжности γf = 1.1
/// (СП 20, табл. 7.1).
class WeightComponent {
  const WeightComponent({
    required this.title,
    required this.weightKnPerM2,
    this.reference,
  });

  final String title;
  final double weightKnPerM2;
  final String? reference;
}

/// Сумма постоянных нагрузок на 1 м² плана дома, кН/м².
///
/// Эта величина потом умножается на площадь застройки и делится на
/// длину опирающихся стен, чтобы получить погонную нагрузку на
/// ленточный фундамент. Для свайного — суммируется и распределяется
/// по сваям.
class PermanentLoadCalculator {
  /// Усреднённые расчётные значения собственного веса конструкций жилого
  /// частного дома (с учётом γf = 1.1). Это «практические» оценки —
  /// для финального расчёта проектировщик может задать свои значения.
  ///
  /// Источники: СП 20 табл. 7.1 + типовая каталожная разбивка (Кикин,
  /// Берлинов и др.).
  static const Map<String, WeightComponent> defaults = {
    'walls_brick': WeightComponent(
      title: 'Кирпичные стены, 380 мм',
      weightKnPerM2: 6.6, // ≈ 1800 кг/м³ × 0.38 м × 9.81 / 1000 × γf=1.1
      reference: 'СП 20, табл. 7.1; ρ = 1800 кг/м³',
    ),
    'walls_aerated': WeightComponent(
      title: 'Газобетонные стены, 400 мм',
      weightKnPerM2: 2.6,
      reference: 'СП 20, табл. 7.1; ρ ≈ 600 кг/м³',
    ),
    'walls_timber': WeightComponent(
      title: 'Деревянные стены, брус 200 мм',
      weightKnPerM2: 1.2,
      reference: 'СП 20, табл. 7.1; ρ ≈ 550 кг/м³',
    ),
    'walls_frame': WeightComponent(
      title: 'Каркасные стены с утеплителем',
      weightKnPerM2: 0.8,
      reference: 'СП 20, табл. 7.1',
    ),
    'floor_concrete_slab': WeightComponent(
      title: 'Монолитное ж/б перекрытие, 200 мм',
      weightKnPerM2: 5.5, // 25 кН/м³ × 0.2 × γf=1.1
      reference: 'СП 20, табл. 7.1; γ = 25 кН/м³',
    ),
    'floor_timber_joists': WeightComponent(
      title: 'Деревянное перекрытие по балкам',
      weightKnPerM2: 1.5,
      reference: 'СП 20, табл. 7.1',
    ),
    'roof_metal_tile': WeightComponent(
      title: 'Кровля по стропилам, металлочерепица',
      weightKnPerM2: 0.6,
      reference: 'СП 20, табл. 7.1',
    ),
    'roof_clay_tile': WeightComponent(
      title: 'Кровля по стропилам, керамическая черепица',
      weightKnPerM2: 1.0,
      reference: 'СП 20, табл. 7.1',
    ),
    'roof_soft_bitumen': WeightComponent(
      title: 'Кровля по стропилам, мягкая битумная',
      weightKnPerM2: 0.3,
      reference: 'СП 20, табл. 7.1',
    ),
  };

  static CalcResult sum(
    List<WeightComponent> components, {
    String componentsOrigin = 'Из брифа: материал стен и кровли',
  }) {
    final total = components.fold<double>(0, (a, c) => a + c.weightKnPerM2);
    final steps = <CalcStep>[
      for (final c in components)
        CalcStep(
          title: c.title,
          formula: 'gi',
          substitution: '${c.weightKnPerM2} кН/м²',
          result: c.weightKnPerM2,
          unit: 'кН/м²',
          reference: c.reference,
          inputs: [
            CalcInput(
              symbol: 'gi',
              value: '${c.weightKnPerM2} кН/м²',
              origin: '$componentsOrigin → подобран компонент «${c.title}». '
                  'Каталожное значение с учётом γf = 1.1 (СП 20, табл. 7.1).',
              reference: c.reference,
            ),
          ],
        ),
      CalcStep(
        title: 'Сумма постоянных нагрузок',
        formula: 'g = Σ gi',
        substitution:
            '${components.map((c) => c.weightKnPerM2).join(' + ')} = ${_round(total)}',
        result: total,
        unit: 'кН/м²',
        reference: 'СП 20.13330.2016, разд. 7',
        inputs: [
          for (final c in components)
            CalcInput(
              symbol: 'g_${c.title.split(' ').first.toLowerCase()}',
              value: '${c.weightKnPerM2} кН/м²',
              origin: c.title,
              reference: c.reference,
            ),
        ],
      ),
    ];
    return CalcResult(value: total, steps: steps);
  }

  static double _round(double v) => (v * 1000).roundToDouble() / 1000;
}
