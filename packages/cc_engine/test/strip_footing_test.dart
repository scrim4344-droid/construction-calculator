import 'package:cc_engine/cc_engine.dart';
import 'package:test/test.dart';

void main() {
  group('SoilResistanceCalculator', () {
    test('песок средней крупности → R0 = 250 кПа', () {
      final r =
          SoilResistanceCalculator.preliminaryR(soil: FoundationSoilType.sandMedium);
      expect(r.value, 250);
      expect(r.steps, hasLength(1));
      expect(r.steps.first.inputs, hasLength(1));
      expect(r.steps.first.inputs.first.symbol, 'R0');
    });

    test('глина мягкопластичная → R0 = 120 кПа', () {
      final r =
          SoilResistanceCalculator.preliminaryR(soil: FoundationSoilType.claySoft);
      expect(r.value, 120);
    });
  });

  group('StripFootingDesigner', () {
    test('одноэтажный газобетон 8×10 на суглинке тугопластичном', () {
      // q ≈ 8.75 кН/м² (см. test FoundationLoadsCalculator)
      // A = 80 м², L = периметр (36) + поперечная (8) = 44 м
      // N_total = 700 кН, N = 15.9 кН/пог.м
      // R = 250 кПа, b = 15.9 · 1.1 / 250 ≈ 0.07 → принято 0.3 м
      final d = StripFootingDesigner.design(
        verticalLoadKnPerM2: 8.75,
        footprintAreaM2: 80,
        loadBearingWallsPerimeterM: 44,
        soilType: FoundationSoilType.loamStiff,
        freezingDepthM: 1.4,
      );
      expect(d.widthM, 0.3);
      expect(d.depthM, closeTo(1.5, 1e-9));
      expect(d.heightM, 0.6);
      expect(d.longitudinalCount, 4);
      expect(d.longitudinalDiameterMm, 12);
      expect(d.longitudinalClass, RebarClass.a500c);
      expect(d.concreteClass, ConcreteClass.b20);
      expect(d.steps, isNotEmpty);
      // Все шаги имеют формулу + подстановку
      for (final s in d.steps) {
        expect(s.title, isNotEmpty);
        expect(s.formula, isNotEmpty);
      }
    });

    test('двухэтажный кирпич 10×12 на мягкопластичной глине → шире', () {
      // Большая нагрузка (~25 кН/м²) и слабый грунт ⇒ b > 0.4
      final d = StripFootingDesigner.design(
        verticalLoadKnPerM2: 25.0,
        footprintAreaM2: 120,
        loadBearingWallsPerimeterM: 50,
        soilType: FoundationSoilType.claySoft,
        freezingDepthM: 1.6,
      );
      // N = 25*120/50 = 60 кН/пог.м, b = 60*1.1/120 = 0.55 → 0.55 м
      expect(d.widthM, greaterThanOrEqualTo(0.5));
      expect(d.longitudinalCount, greaterThanOrEqualTo(6));
    });

    test('минимальная глубина заложения 0.5 м даже при df=0', () {
      final d = StripFootingDesigner.design(
        verticalLoadKnPerM2: 5.0,
        footprintAreaM2: 60,
        loadBearingWallsPerimeterM: 30,
        soilType: FoundationSoilType.sandGravel,
        freezingDepthM: 0.0,
      );
      expect(d.depthM, 0.5);
    });
  });
}
