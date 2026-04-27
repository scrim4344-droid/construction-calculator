import '../calc_step.dart';
import '../regions/snow_region.dart';
import '../regions/wind_region.dart';
import 'permanent_load.dart';
import 'snow_load.dart';
import 'wind_load.dart';

/// Полезная нагрузка для жилых помещений по СП 20, табл. 8.3:
/// `1.5 кН/м²` нормативная, `× γf = 1.3` ⇒ расчётная `1.95 кН/м²`.
const double residentialUsefulLoad = 1.95;

/// Расчёт суммарной вертикальной нагрузки на фундамент жилого
/// частного дома, на 1 м² застройки.
///
/// Это базовый расчёт «по площади»: применим к ленточному фундаменту
/// (потом делим на периметр несущих стен ⇒ погонная нагрузка) и плитному
/// (используем как есть для подбора армирования). Свайные считаются
/// иначе — суммарная нагрузка на ростверк делится на количество свай.
class FoundationLoadsCalculator {
  /// Входные данные расчёта.
  ///
  /// `floors` — число надземных этажей. Постоянная нагрузка от перекрытий
  ///           масштабируется как (floors), от стен — линейно (floors),
  ///           от кровли — единожды.
  static FoundationLoadsResult compute({
    required SnowRegion snowRegion,
    required WindRegion windRegion,
    required RoofShape roofShape,
    required double roofSlopeDegrees,
    required TerrainType windTerrain,
    required double buildingHeight,
    required List<WeightComponent> wallComponents,
    required List<WeightComponent> floorComponents,
    required List<WeightComponent> roofComponents,
    required int floors,
    double usefulLoad = residentialUsefulLoad,
    String snowRegionOrigin = 'Принято по умолчанию',
    String windRegionOrigin = 'Принято по умолчанию',
    String roofSlopeOrigin =
        'Из проекта: уклон кровли (если не задан — 30° по умолчанию)',
    String floorsOrigin = 'Из брифа, поле «Этажность»',
    String wallsOrigin = 'Из брифа, поле «Материал стен»',
    String floorsCompOrigin =
        'По умолчанию: деревянное перекрытие по балкам (типичная замена в ИЖС)',
    String roofMaterialOrigin =
        'Из модели крыши проекта (поле roofingMaterial)',
    String buildingHeightOrigin =
        'Грубая оценка: floors · 3 м + 2 м на крышу',
  }) {
    final snow = SnowLoadCalculator.calculate(
      region: snowRegion,
      roofShape: roofShape,
      slopeDegrees: roofSlopeDegrees,
      regionOrigin: snowRegionOrigin,
    );
    final wind = WindLoadCalculator.calculate(
      region: windRegion,
      terrain: windTerrain,
      heightMeters: buildingHeight,
      regionOrigin: windRegionOrigin,
      heightOrigin: buildingHeightOrigin,
    );
    final perFloorWalls =
        PermanentLoadCalculator.sum(wallComponents, componentsOrigin: wallsOrigin)
            .value;
    final perFloorFloors = PermanentLoadCalculator.sum(
      floorComponents,
      componentsOrigin: floorsCompOrigin,
    ).value;
    final roof = PermanentLoadCalculator.sum(
      roofComponents,
      componentsOrigin: roofMaterialOrigin,
    ).value;

    final permanent = perFloorWalls * floors +
        perFloorFloors * floors +
        roof; // кровля одна на здание
    final useful = usefulLoad * floors;

    final total = permanent + snow.value + useful; // ветер не суммируем
    // в вертикальную (для подбора подошвы), он
    // используется отдельно для анкеровки.

    return FoundationLoadsResult(
      snow: snow,
      wind: wind,
      permanentPerM2: permanent,
      usefulPerM2: useful,
      totalVerticalKnPerM2: total,
      summary: [
        CalcStep(
          title: 'Постоянная нагрузка от стен',
          formula: 'gw · n',
          substitution:
              '$perFloorWalls · $floors = ${_round(perFloorWalls * floors)}',
          result: perFloorWalls * floors,
          unit: 'кН/м²',
          reference: 'СП 20.13330.2016, разд. 7',
          inputs: [
            CalcInput(
              symbol: 'gw',
              value: '$perFloorWalls кН/м²',
              origin: 'Из шага «Сумма постоянных нагрузок» по стенам.',
            ),
            CalcInput(
              symbol: 'n',
              value: '$floors',
              origin: floorsOrigin,
            ),
          ],
        ),
        CalcStep(
          title: 'Постоянная нагрузка от перекрытий',
          formula: 'gf · n',
          substitution:
              '$perFloorFloors · $floors = ${_round(perFloorFloors * floors)}',
          result: perFloorFloors * floors,
          unit: 'кН/м²',
          reference: 'СП 20.13330.2016, разд. 7',
          inputs: [
            CalcInput(
              symbol: 'gf',
              value: '$perFloorFloors кН/м²',
              origin: 'Из шага «Сумма постоянных нагрузок» по перекрытиям.',
            ),
            CalcInput(
              symbol: 'n',
              value: '$floors',
              origin: floorsOrigin,
            ),
          ],
        ),
        CalcStep(
          title: 'Постоянная нагрузка от кровли',
          formula: 'gr',
          substitution: '$roof',
          result: roof,
          unit: 'кН/м²',
          reference: 'СП 20.13330.2016, разд. 7',
          inputs: [
            CalcInput(
              symbol: 'gr',
              value: '$roof кН/м²',
              origin: 'Из шага «Сумма постоянных нагрузок» по кровле. '
                  'Кровля одна на всё здание, поэтому не умножается на n.',
            ),
          ],
        ),
        CalcStep(
          title: 'Полезная нагрузка',
          formula: 'p · n',
          substitution: '$usefulLoad · $floors = ${_round(useful)}',
          result: useful,
          unit: 'кН/м²',
          reference: 'СП 20.13330.2016, табл. 8.3 (жилые помещения)',
          inputs: [
            CalcInput(
              symbol: 'p',
              value: '$usefulLoad кН/м²',
              origin: 'Расчётное значение полезной нагрузки для жилых '
                  'помещений: нормативное 1.5 кН/м² × γf = 1.3 = 1.95.',
              reference: 'СП 20.13330.2016, табл. 8.3',
            ),
            CalcInput(
              symbol: 'n',
              value: '$floors',
              origin: floorsOrigin,
            ),
          ],
        ),
        CalcStep(
          title: 'Снеговая нагрузка (итог)',
          formula: 'S',
          substitution: '${snow.value}',
          result: snow.value,
          unit: 'кН/м²',
          reference: 'См. раздел «Снеговая нагрузка»',
          inputs: [
            CalcInput(
              symbol: 'S',
              value: '${_round(snow.value)} кН/м²',
              origin: 'Из расчёта снеговой нагрузки выше.',
            ),
          ],
        ),
        CalcStep(
          title: 'Суммарная вертикальная нагрузка на фундамент',
          formula: 'q = g · n + p · n + S',
          substitution: '${_round(permanent)} + ${_round(useful)} + '
              '${_round(snow.value)} = ${_round(total)}',
          result: total,
          unit: 'кН/м²',
          reference: 'СП 20.13330.2016, разд. 6 (сочетание нагрузок)',
          note: 'Без учёта ветровой составляющей — она не суммируется в '
              'вертикальную нагрузку для подбора подошвы (используется '
              'отдельно при расчёте анкеровки и опрокидывания).',
          inputs: [
            CalcInput(
              symbol: 'g · n',
              value: '${_round(permanent)} кН/м²',
              origin: 'Сумма постоянных нагрузок (стены + перекрытия + кровля).',
            ),
            CalcInput(
              symbol: 'p · n',
              value: '${_round(useful)} кН/м²',
              origin: 'Полезная нагрузка × этажность.',
            ),
            CalcInput(
              symbol: 'S',
              value: '${_round(snow.value)} кН/м²',
              origin: 'Снеговая нагрузка.',
            ),
          ],
        ),
      ],
    );
  }

  static double _round(double v) => (v * 1000).roundToDouble() / 1000;
}

/// Результат расчёта нагрузок на фундамент.
class FoundationLoadsResult {
  const FoundationLoadsResult({
    required this.snow,
    required this.wind,
    required this.permanentPerM2,
    required this.usefulPerM2,
    required this.totalVerticalKnPerM2,
    required this.summary,
  });

  /// Расчёт снеговой нагрузки (с журналом шагов для ПЗ).
  final CalcResult snow;

  /// Расчёт ветровой нагрузки (с журналом шагов для ПЗ).
  final CalcResult wind;

  /// Суммарная постоянная нагрузка на 1 м² застройки, кН/м².
  final double permanentPerM2;

  /// Суммарная полезная нагрузка на 1 м² застройки, кН/м².
  final double usefulPerM2;

  /// Финальная вертикальная нагрузка на фундамент, кН/м² (без ветра).
  final double totalVerticalKnPerM2;

  /// Сводный список шагов расчёта для ПЗ (без шагов снега и ветра —
  /// они в [snow.steps] и [wind.steps]).
  final List<CalcStep> summary;
}
