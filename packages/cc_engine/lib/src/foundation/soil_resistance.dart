import '../calc_step.dart';

/// Тип грунта основания (упрощённо для частного дома).
///
/// Расчётные сопротивления взяты из СП 22.13330.2016, табл. В.3 — это
/// предварительные значения для предварительных расчётов. Для итогового
/// проекта проектировщик должен задать R по результатам инженерно-
/// геологических изысканий (СП 47.13330) или формулой (5.7) СП 22.
enum FoundationSoilType {
  /// Гравелистые пески, R0 ≈ 500 кПа.
  sandGravel,

  /// Крупные пески, R0 ≈ 350 кПа.
  sandCoarse,

  /// Средние пески, R0 ≈ 250 кПа.
  sandMedium,

  /// Мелкие пески (маловлажные), R0 ≈ 200 кПа.
  sandFine,

  /// Супеси (твёрдые), R0 ≈ 300 кПа.
  sandyLoamHard,

  /// Суглинки тугопластичные, R0 ≈ 250 кПа.
  loamStiff,

  /// Суглинки мягкопластичные, R0 ≈ 150 кПа.
  loamSoft,

  /// Глины полутвёрдые, R0 ≈ 300 кПа.
  clayHard,

  /// Глины тугопластичные, R0 ≈ 200 кПа.
  clayStiff,

  /// Глины мягкопластичные, R0 ≈ 120 кПа.
  claySoft,
}

extension FoundationSoilTypeExt on FoundationSoilType {
  /// Расчётное сопротивление грунта R0 в кПа (предварительное значение
  /// для частного дома по табл. В.3 СП 22).
  double get r0KPa {
    switch (this) {
      case FoundationSoilType.sandGravel:
        return 500;
      case FoundationSoilType.sandCoarse:
        return 350;
      case FoundationSoilType.sandMedium:
        return 250;
      case FoundationSoilType.sandFine:
        return 200;
      case FoundationSoilType.sandyLoamHard:
        return 300;
      case FoundationSoilType.loamStiff:
        return 250;
      case FoundationSoilType.loamSoft:
        return 150;
      case FoundationSoilType.clayHard:
        return 300;
      case FoundationSoilType.clayStiff:
        return 200;
      case FoundationSoilType.claySoft:
        return 120;
    }
  }

  String get title {
    switch (this) {
      case FoundationSoilType.sandGravel:
        return 'Песок гравелистый';
      case FoundationSoilType.sandCoarse:
        return 'Песок крупный';
      case FoundationSoilType.sandMedium:
        return 'Песок средней крупности';
      case FoundationSoilType.sandFine:
        return 'Песок мелкий';
      case FoundationSoilType.sandyLoamHard:
        return 'Супесь твёрдая';
      case FoundationSoilType.loamStiff:
        return 'Суглинок тугопластичный';
      case FoundationSoilType.loamSoft:
        return 'Суглинок мягкопластичный';
      case FoundationSoilType.clayHard:
        return 'Глина полутвёрдая';
      case FoundationSoilType.clayStiff:
        return 'Глина тугопластичная';
      case FoundationSoilType.claySoft:
        return 'Глина мягкопластичная';
    }
  }
}

/// Расчёт расчётного сопротивления грунта основания R, кПа.
///
/// Для предварительных расчётов используется R = R0, без поправок на
/// глубину и ширину подошвы. Для итогового проекта применяется формула
/// (5.7) СП 22.13330 с учётом γc, k, Mγ, Mq, Mc, b, d, γII и т.д.
class SoilResistanceCalculator {
  static CalcResult preliminaryR({
    required FoundationSoilType soil,
    String soilOrigin =
        'Из брифа: тип грунта верхнего слоя (закладка инженерно-геологических данных)',
  }) {
    final r0 = soil.r0KPa;
    return CalcResult(
      value: r0,
      steps: [
        CalcStep(
          title: 'Расчётное сопротивление грунта R',
          formula: 'R ≈ R0',
          substitution: 'R = $r0 кПа (для «${soil.title}»)',
          result: r0,
          unit: 'кПа',
          reference: 'СП 22.13330.2016, табл. В.3 (предварительные значения)',
          note: 'Это предварительное значение. Для итогового проекта '
              'считается по формуле (5.7) с учётом ширины подошвы, '
              'глубины заложения и физико-механических характеристик '
              'грунта (φII, cII, γII, γII´).',
          inputs: [
            CalcInput(
              symbol: 'R0',
              value: '$r0 кПа',
              origin: 'Табличное значение для типа грунта «${soil.title}». '
                  '$soilOrigin',
              reference: 'СП 22.13330.2016, табл. В.3',
            ),
          ],
        ),
      ],
    );
  }
}
