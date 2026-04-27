import '../calc_step.dart';
import 'soil_resistance.dart';

/// Класс бетона по СП 63.13330.2018.
enum ConcreteClass { b15, b20, b25, b30 }

extension ConcreteClassExt on ConcreteClass {
  String get title {
    switch (this) {
      case ConcreteClass.b15:
        return 'B15';
      case ConcreteClass.b20:
        return 'B20';
      case ConcreteClass.b25:
        return 'B25';
      case ConcreteClass.b30:
        return 'B30';
    }
  }
}

/// Класс арматуры по ГОСТ 5781 / ГОСТ 34028.
enum RebarClass { a240, a400, a500c }

extension RebarClassExt on RebarClass {
  String get title {
    switch (this) {
      case RebarClass.a240:
        return 'A240 (гладкая)';
      case RebarClass.a400:
        return 'A400 (рифлёная)';
      case RebarClass.a500c:
        return 'A500C (свариваемая, рифлёная)';
    }
  }
}

/// Параметры подобранного ленточного фундамента.
class StripFootingDesign {
  const StripFootingDesign({
    required this.widthM,
    required this.heightM,
    required this.depthM,
    required this.concreteClass,
    required this.longitudinalDiameterMm,
    required this.longitudinalCount,
    required this.longitudinalClass,
    required this.stirrupDiameterMm,
    required this.stirrupSpacingMm,
    required this.stirrupClass,
    required this.steps,
  });

  /// Ширина подошвы ленты, м.
  final double widthM;

  /// Высота ленты (от подошвы до верха), м.
  final double heightM;

  /// Глубина заложения подошвы от поверхности земли, м.
  /// Должна быть не меньше нормативной глубины промерзания + 0.1 м
  /// (СП 22, п. 5.5.4) для пучинистых грунтов.
  final double depthM;

  final ConcreteClass concreteClass;

  /// Диаметр продольной арматуры, мм.
  final int longitudinalDiameterMm;

  /// Количество стержней продольной арматуры (типично 4 — по 2 сверху и снизу).
  final int longitudinalCount;

  final RebarClass longitudinalClass;

  /// Диаметр поперечной арматуры (хомутов), мм.
  final int stirrupDiameterMm;

  /// Шаг поперечной арматуры, мм.
  final int stirrupSpacingMm;

  final RebarClass stirrupClass;

  /// Журнал расчёта (для ПЗ).
  final List<CalcStep> steps;
}

/// Подбор сечения ленточного фундамента и базового армирования.
///
/// Расчёт ширины подошвы по условию: q ≤ R, где q — давление под
/// подошвой, R — расчётное сопротивление грунта.
///
/// Для предварительного расчёта используется упрощённая модель:
///   - Грузовая площадь стены = площадь дома / периметр несущих стен.
///   - Погонная нагрузка на ленту: N = q · A / L, где q — кН/м² застройки,
///     A — площадь дома, L — периметр несущих стен.
///   - Требуемая ширина: b = N / R (с учётом γс — коэф. условий работы).
///
/// Армирование принимается конструктивно по СП 63 п. 10.3.6:
///   - 4 ⌀12 А500С (2 сверху + 2 снизу) для b ≤ 0.4 м,
///   - 6 ⌀12 А500С для 0.4 < b ≤ 0.6,
///   - 8 ⌀12 А500С для b > 0.6.
///   - Хомуты ⌀8 А240 с шагом 200 мм.
class StripFootingDesigner {
  /// Минимальная глубина заложения подошвы по СП 22, п. 5.5.4 (без учёта
  /// промерзания — для непучинистых грунтов и тёплых зданий).
  static const double minDepthM = 0.5;

  /// Минимальная высота ленты для частного дома.
  static const double minHeightM = 0.5;

  /// Расчёт.
  static StripFootingDesign design({
    required double verticalLoadKnPerM2,
    required double footprintAreaM2,
    required double loadBearingWallsPerimeterM,
    required FoundationSoilType soilType,
    required double freezingDepthM,
    String loadOrigin =
        'Из расчёта нагрузок на фундамент (q = g + p + S по СП 20)',
    String footprintOrigin = 'Из брифа: пятно застройки (W × L)',
    String wallsOrigin =
        'Из габаритов: периметр + поперечные несущие стены (упрощённо)',
    String soilOrigin =
        'Из брифа: тип грунта верхнего слоя (инженерно-геологические данные)',
    String freezingOrigin =
        'СП 131.13330: нормативная глубина промерзания для региона',
  }) {
    // 1. Сопротивление грунта.
    final r = SoilResistanceCalculator.preliminaryR(
      soil: soilType,
      soilOrigin: soilOrigin,
    );
    final rKPa = r.value;

    // 2. Погонная нагрузка на ленту, кН/пог.м.
    // Площадь * нагрузка / длину несущих стен.
    final totalLoadKn = verticalLoadKnPerM2 * footprintAreaM2;
    final linearLoadKnPerM = totalLoadKn / loadBearingWallsPerimeterM;

    // 3. Требуемая ширина подошвы, м.
    // b = N (кН/м) / (R (кПа) * 1 м) = N / R.
    // Минимум 0.3 м (конструктивно для частного дома).
    const gammaC = 1.1; // коэф. надёжности по нагрузке для подбора.
    final bRaw = (linearLoadKnPerM * gammaC) / rKPa;
    final bRequired = bRaw < 0.3 ? 0.3 : bRaw;
    // Округляем вверх до 0.05 м.
    final bDesign = ((bRequired * 20).ceil()) / 20.0;

    // 4. Глубина заложения.
    final dDesign = freezingDepthM + 0.1 < minDepthM
        ? minDepthM
        : freezingDepthM + 0.1;

    // 5. Высота ленты — конструктивно.
    const hDesign = 0.6;

    // 6. Армирование — конструктивно.
    final int longCount;
    if (bDesign <= 0.4) {
      longCount = 4;
    } else if (bDesign <= 0.6) {
      longCount = 6;
    } else {
      longCount = 8;
    }

    final steps = <CalcStep>[
      ...r.steps,
      CalcStep(
        title: 'Площадь застройки A',
        formula: 'A',
        substitution: 'A = $footprintAreaM2 м²',
        result: footprintAreaM2,
        unit: 'м²',
        inputs: [
          CalcInput(
            symbol: 'A',
            value: '$footprintAreaM2 м²',
            origin: footprintOrigin,
          ),
        ],
      ),
      CalcStep(
        title: 'Периметр несущих стен L',
        formula: 'L',
        substitution: 'L = $loadBearingWallsPerimeterM м',
        result: loadBearingWallsPerimeterM,
        unit: 'м',
        note: 'Учитываются только стены, опирающиеся на ленту: '
            'наружный периметр + внутренние несущие стены.',
        inputs: [
          CalcInput(
            symbol: 'L',
            value: '$loadBearingWallsPerimeterM м',
            origin: wallsOrigin,
          ),
        ],
      ),
      CalcStep(
        title: 'Полная вертикальная нагрузка на здание',
        formula: 'N_total = q · A',
        substitution:
            'N_total = $verticalLoadKnPerM2 · $footprintAreaM2 = ${_round(totalLoadKn)}',
        result: totalLoadKn,
        unit: 'кН',
        inputs: [
          CalcInput(
            symbol: 'q',
            value: '$verticalLoadKnPerM2 кН/м²',
            origin: loadOrigin,
          ),
          CalcInput(
            symbol: 'A',
            value: '$footprintAreaM2 м²',
            origin: 'Из шага «Площадь застройки» выше.',
          ),
        ],
      ),
      CalcStep(
        title: 'Погонная нагрузка на ленту',
        formula: 'N = N_total / L',
        substitution:
            'N = ${_round(totalLoadKn)} / $loadBearingWallsPerimeterM = ${_round(linearLoadKnPerM)}',
        result: linearLoadKnPerM,
        unit: 'кН/пог.м',
        note: 'Упрощённое распределение: вся нагрузка на здание делится '
            'поровну на все несущие стены.',
        inputs: [
          CalcInput(
            symbol: 'N_total',
            value: '${_round(totalLoadKn)} кН',
            origin: 'Из шага «Полная вертикальная нагрузка» выше.',
          ),
          CalcInput(
            symbol: 'L',
            value: '$loadBearingWallsPerimeterM м',
            origin: 'Из шага «Периметр несущих стен» выше.',
          ),
        ],
      ),
      CalcStep(
        title: 'Требуемая ширина подошвы',
        formula: 'b ≥ N · γc / R',
        substitution:
            'b = ${_round(linearLoadKnPerM)} · $gammaC / $rKPa = ${_round(bRaw)} → принято b = $bDesign м',
        result: bDesign,
        unit: 'м',
        reference: 'СП 22.13330.2016, формула (5.7) — упрощённо',
        note: 'Округлено вверх до 50 мм. Минимум — 0.3 м конструктивно.',
        inputs: [
          CalcInput(
            symbol: 'N',
            value: '${_round(linearLoadKnPerM)} кН/пог.м',
            origin: 'Из шага «Погонная нагрузка на ленту» выше.',
          ),
          CalcInput(
            symbol: 'γc',
            value: '$gammaC',
            origin: 'Коэффициент условий работы для подбора подошвы '
                '(для предварительного расчёта принят 1.1).',
            reference: 'СП 22.13330.2016, п. 5.6.7',
          ),
          CalcInput(
            symbol: 'R',
            value: '$rKPa кПа',
            origin: 'Из шага «Расчётное сопротивление грунта» выше.',
          ),
        ],
      ),
      CalcStep(
        title: 'Глубина заложения подошвы',
        formula: 'd ≥ df + 0.1',
        substitution:
            'd = $freezingDepthM + 0.1 = ${_round(freezingDepthM + 0.1)} → принято d = $dDesign м',
        result: dDesign,
        unit: 'м',
        reference: 'СП 22.13330.2016, п. 5.5.4',
        note: 'Подошва закладывается ниже расчётной глубины промерзания '
            'для исключения морозного пучения. Минимум 0.5 м.',
        inputs: [
          CalcInput(
            symbol: 'df',
            value: '$freezingDepthM м',
            origin: freezingOrigin,
            reference: 'СП 131.13330',
          ),
        ],
      ),
      CalcStep(
        title: 'Высота ленты',
        formula: 'h',
        substitution: 'h = $hDesign м',
        result: hDesign,
        unit: 'м',
        note: 'Конструктивно: для частного дома 0.6 м достаточно. '
            'Уточняется расчётом на изгиб в следующих итерациях.',
        inputs: [
          CalcInput(
            symbol: 'h',
            value: '$hDesign м',
            origin: 'Конструктивно для частного дома.',
            reference: 'СП 63.13330.2018, п. 10.3',
          ),
        ],
      ),
      CalcStep(
        title: 'Продольная арматура',
        formula: '$longCount⌀12 А500С',
        substitution: '$longCount стержней Ø12, '
            'класс А500С (свариваемая)',
        result: longCount.toDouble(),
        unit: 'шт.',
        reference: 'СП 63.13330.2018, п. 10.3.6 (минимальное армирование)',
        note: 'Распределяется: ${longCount ~/ 2} стержней снизу + '
            '${longCount ~/ 2} сверху. Защитный слой бетона 50 мм '
            '(СП 63, п. 10.3.4).',
        inputs: [
          CalcInput(
            symbol: 'b',
            value: '$bDesign м',
            origin: 'Из шага «Требуемая ширина подошвы».',
          ),
          CalcInput(
            symbol: 'количество',
            value: '$longCount шт.',
            origin: bDesign <= 0.4
                ? 'b ≤ 0.4 м ⇒ 4 стержня (минимум по СП 63)'
                : bDesign <= 0.6
                    ? '0.4 < b ≤ 0.6 м ⇒ 6 стержней'
                    : 'b > 0.6 м ⇒ 8 стержней',
          ),
        ],
      ),
      const CalcStep(
        title: 'Поперечная арматура (хомуты)',
        formula: '⌀8 А240 шаг 200 мм',
        substitution: 'Ø8, класс А240, шаг 200 мм',
        result: 200,
        unit: 'мм',
        reference: 'СП 63.13330.2018, п. 10.3.13',
        note: 'Шаг 200 мм — стандартное конструктивное значение для '
            'ленточного фундамента частного дома.',
      ),
      const CalcStep(
        title: 'Класс бетона',
        formula: 'B20',
        substitution: 'B20 (тяжёлый, F100 W4)',
        result: 20,
        unit: 'МПа',
        reference: 'СП 63.13330.2018, п. 6.1.6',
        note: 'Для фундаментов частных домов в большинстве случаев '
            'достаточно В20 с морозостойкостью F100 и водонепроницаемостью W4.',
      ),
    ];

    return StripFootingDesign(
      widthM: bDesign,
      heightM: hDesign,
      depthM: dDesign,
      concreteClass: ConcreteClass.b20,
      longitudinalDiameterMm: 12,
      longitudinalCount: longCount,
      longitudinalClass: RebarClass.a500c,
      stirrupDiameterMm: 8,
      stirrupSpacingMm: 200,
      stirrupClass: RebarClass.a240,
      steps: steps,
    );
  }

  static double _round(double v) => (v * 100).roundToDouble() / 100;
}
