import 'package:cc_engine/cc_engine.dart';
import 'package:test/test.dart';

void main() {
  group('SnowLoadCalculator', () {
    test('III район, плоская кровля → S = 1.0 · 1.5 · 1.4 = 2.1 кН/м²', () {
      final r = SnowLoadCalculator.calculate(
        region: SnowRegion.byId(3),
        roofShape: RoofShape.flatOrLowSlope,
        slopeDegrees: 0,
      );
      expect(r.value, closeTo(2.1, 1e-9));
      expect(r.steps, hasLength(3));
      expect(r.steps.last.formula, 'S = µ · Sg · γf');
    });

    test('крутая кровля 60° → µ = 0 → S = 0', () {
      final r = SnowLoadCalculator.calculate(
        region: SnowRegion.byId(3),
        roofShape: RoofShape.steep,
        slopeDegrees: 60,
      );
      expect(r.value, 0.0);
    });

    test('двускатная 45° → µ = 0.5 → S = 0.5 · 1.5 · 1.4', () {
      final r = SnowLoadCalculator.calculate(
        region: SnowRegion.byId(3),
        roofShape: RoofShape.gable,
        slopeDegrees: 45,
      );
      expect(r.value, closeTo(0.5 * 1.5 * 1.4, 1e-9));
    });
  });

  group('WindLoadCalculator', () {
    test('II район, тип B, h=10 м → wm = w0 · k · c · γf', () {
      final r = WindLoadCalculator.calculate(
        region: WindRegion.byId(2),
        terrain: TerrainType.b,
        heightMeters: 10,
      );
      // w0=0.30, k(10,B)=0.65, c=0.8, γf=1.4
      expect(r.value, closeTo(0.30 * 0.65 * 0.8 * 1.4, 1e-9));
    });
  });

  group('PermanentLoadCalculator', () {
    test('сумма стен + перекрытие = 2 компонента, шагов = 3', () {
      final r = PermanentLoadCalculator.sum([
        PermanentLoadCalculator.defaults['walls_aerated']!,
        PermanentLoadCalculator.defaults['floor_concrete_slab']!,
      ]);
      expect(r.value, closeTo(2.6 + 5.5, 1e-9));
      expect(r.steps, hasLength(3));
    });
  });

  group('FoundationLoadsCalculator', () {
    test('одноэтажный газобетон с металлочерепицей в III снеговом районе', () {
      final result = FoundationLoadsCalculator.compute(
        snowRegion: SnowRegion.byId(3),
        windRegion: WindRegion.byId(2),
        roofShape: RoofShape.gable,
        roofSlopeDegrees: 30,
        windTerrain: TerrainType.b,
        buildingHeight: 6,
        wallComponents: [
          PermanentLoadCalculator.defaults['walls_aerated']!,
        ],
        floorComponents: [
          PermanentLoadCalculator.defaults['floor_timber_joists']!,
        ],
        roofComponents: [
          PermanentLoadCalculator.defaults['roof_metal_tile']!,
        ],
        floors: 1,
      );

      // Постоянная: 2.6 (стены) + 1.5 (перекрытие) + 0.6 (кровля) = 4.7
      expect(result.permanentPerM2, closeTo(4.7, 1e-9));

      // Снег: µ=1.0 (30°) · 1.5 · 1.4 = 2.1
      expect(result.snow.value, closeTo(2.1, 1e-9));

      // Полезная: 1.95 · 1
      expect(result.usefulPerM2, closeTo(1.95, 1e-9));

      // Итого: 4.7 + 1.95 + 2.1 = 8.75
      expect(result.totalVerticalKnPerM2, closeTo(8.75, 1e-9));
    });

    test('двухэтажный газобетон ⇒ постоянная и полезная удваиваются для стен/перекрытий', () {
      final result = FoundationLoadsCalculator.compute(
        snowRegion: SnowRegion.byId(3),
        windRegion: WindRegion.byId(2),
        roofShape: RoofShape.gable,
        roofSlopeDegrees: 30,
        windTerrain: TerrainType.b,
        buildingHeight: 9,
        wallComponents: [
          PermanentLoadCalculator.defaults['walls_aerated']!,
        ],
        floorComponents: [
          PermanentLoadCalculator.defaults['floor_concrete_slab']!,
        ],
        roofComponents: [
          PermanentLoadCalculator.defaults['roof_metal_tile']!,
        ],
        floors: 2,
      );

      // Постоянная: (2.6 · 2) + (5.5 · 2) + 0.6 = 5.2 + 11.0 + 0.6 = 16.8
      expect(result.permanentPerM2, closeTo(16.8, 1e-9));
      // Полезная: 1.95 · 2 = 3.9
      expect(result.usefulPerM2, closeTo(3.9, 1e-9));
    });
  });
}
