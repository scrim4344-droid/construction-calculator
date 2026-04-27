import '../data/soil_types.dart';
import '../data/wall_materials.dart';
import '../models/client_brief.dart';
import '../models/foundation.dart';
import '../models/foundation_design.dart';
import '../models/foundation_rationale.dart';
import '../models/roof_design.dart';
import '../models/soil_layer.dart';
import '../models/staircase_design.dart';
import '../models/walls_design.dart';

/// Результат подбора состава сооружения по техническому заданию.
///
/// Это «рекомендация» — то, что приложение предложит клиенту автоматически
/// и проектировщику в качестве отправной точки.
class CompositionPlan {
  final FoundationDesign foundation;
  final FoundationRationale foundationRationale;
  final WallsDesign walls;
  final RoofDesign roof;
  final StaircaseDesign staircase;
  final bool includesStaircase;
  final bool includesGarage;
  final bool includesTerrace;
  final bool includesBalcony;
  final bool includesOriel;
  final bool includesDoubleHeight;
  final bool includesBasement;
  final bool includesMansard;

  CompositionPlan({
    required this.foundation,
    required this.foundationRationale,
    required this.walls,
    required this.roof,
    required this.staircase,
    required this.includesStaircase,
    required this.includesGarage,
    required this.includesTerrace,
    required this.includesBalcony,
    required this.includesOriel,
    required this.includesDoubleHeight,
    required this.includesBasement,
    required this.includesMansard,
  });
}

/// Результат выбора фундамента вместе с обоснованием.
class _FoundationPick {
  final FoundationDesign design;
  final FoundationRationale rationale;
  const _FoundationPick(this.design, this.rationale);
}

/// Движок правил «техническое задание → состав сооружения».
///
/// Сейчас правила примитивные и иллюстративные. Когда мы будем углубляться
/// в нормативы (СП 22.13330 «Основания зданий и сооружений», СП 50.13330
/// «Тепловая защита» и т. п.), их можно усиливать без изменения остальных
/// слоёв приложения.
class CompositionPlanner {
  static CompositionPlan plan(ClientBrief brief) {
    final pick = _planFoundation(brief);
    final walls = _planWalls(brief);
    final roof = _planRoof(brief);
    final staircase = StaircaseDesign(
      type: brief.requiresStaircase ? 'marsh' : null,
    );

    return CompositionPlan(
      foundation: pick.design,
      foundationRationale: pick.rationale,
      walls: walls,
      roof: roof,
      staircase: staircase,
      includesStaircase: brief.requiresStaircase,
      includesGarage: brief.hasGarage == true,
      includesTerrace: brief.hasTerrace == true,
      includesBalcony: brief.hasBalcony == true,
      includesOriel: brief.hasOriel == true,
      includesDoubleHeight: brief.hasDoubleHeight == true,
      includesBasement: brief.hasBasement == true,
      includesMansard: brief.hasMansard == true,
    );
  }

  static _FoundationPick _planFoundation(ClientBrief brief) {
    final layers = brief.soilLayers;
    final floors = brief.floors ?? 1;
    final heavyWalls = brief.wallMaterial == WallMaterial.brick ||
        brief.wallMaterial == WallMaterial.expandedClay;

    final hasPeatOnTop = _hasPeatInTop(layers);
    final bearing = _bearingLayer(layers);
    final weakBearing = bearing != null &&
        bearing.deformationModulus != null &&
        bearing.deformationModulus! < 5; // МПа, «слабый» грунт

    final items = <RationaleItem>[];
    items.add(_inputsRationale(brief, bearing));

    if (hasPeatOnTop) {
      items.add(const RationaleItem(
        text: 'В верхних слоях (до ~3 м) присутствует торф — слабый биогенный '
            'грунт, опирание ленточного/плитного фундамента на него недопустимо. '
            'Рекомендуются буронабивные сваи с монолитным ростверком.',
        codeReference: 'СП 22.13330.2016, п. 6.4 «Заторфованные грунты»; '
            'СП 24.13330.2011 «Свайные фундаменты»',
      ));
      return _FoundationPick(
        FoundationDesign(
          type: FoundationType.pileWithGrillage,
          device: FoundationDevice.boredPile,
          grillageMaterial: GrillageMaterial.monolithic,
        ),
        FoundationRationale(items: items),
      );
    }
    if (weakBearing) {
      items.add(RationaleItem(
        text: 'Модуль деформации несущего слоя '
            'E = ${bearing.deformationModulus!.toStringAsFixed(1)} МПа < 5 МПа — '
            'грунт считается слабым, опирание поверхностных фундаментов приведёт '
            'к недопустимым осадкам. Передаём нагрузку на более плотные слои '
            'буронабивными сваями.',
        codeReference:
            'СП 22.13330.2016, п. 5.5 (оценка деформационных свойств); '
                'СП 24.13330.2011',
      ));
      return _FoundationPick(
        FoundationDesign(
          type: FoundationType.pileWithGrillage,
          device: FoundationDevice.boredPile,
          grillageMaterial: GrillageMaterial.monolithic,
        ),
        FoundationRationale(items: items),
      );
    }
    final bearingType = bearing?.type ?? brief.soilType;
    if (bearingType == SoilType.rock) {
      items.add(const RationaleItem(
        text: 'Несущий слой — скальный грунт. Он имеет высокую несущую '
            'способность и слабо деформируется — рационально опирать здание '
            'точечно через столбчатые опоры.',
        codeReference: 'СП 22.13330.2016, п. 5.6 «Скальные грунты»',
      ));
      return _FoundationPick(
        FoundationDesign(
          type: FoundationType.columnar,
          device: FoundationDevice.monolithic,
        ),
        FoundationRationale(items: items),
      );
    }
    if (bearingType == SoilType.clay && (floors >= 2 || heavyWalls)) {
      items.add(RationaleItem(
        text: 'Несущий слой — глина при этажности $floors '
            'и ${heavyWalls ? 'тяжёлых' : 'стандартных'} стенах. '
            'Глинистые грунты склонны к неравномерным осадкам и пучинистости. '
            'Плитный фундамент равномерно распределяет нагрузку и снижает осадки.',
        codeReference: 'СП 22.13330.2016, п. 5.7 «Пылевато-глинистые '
            'грунты»; СП 22.13330.2016, п. 5.10 (плитные фундаменты)',
      ));
      return _FoundationPick(
        FoundationDesign(
          type: FoundationType.slab,
          device: FoundationDevice.monolithic,
        ),
        FoundationRationale(items: items),
      );
    }
    if (heavyWalls && floors >= 2) {
      items.add(RationaleItem(
        text: 'Тяжёлые каменные стены при $floors этажах дают высокую '
            'погонную нагрузку на основание. Широкое распределение этой нагрузки обеспечивает '
            'ленточный монолитный фундамент под всеми несущими стенами.',
        codeReference: 'СП 15.13330 «Каменные и армокаменные '
            'конструкции»; СП 22.13330.2016',
      ));
      return _FoundationPick(
        FoundationDesign(
          type: FoundationType.strip,
          device: FoundationDevice.monolithic,
        ),
        FoundationRationale(items: items),
      );
    }
    if (brief.wallMaterial == WallMaterial.frame ||
        brief.wallMaterial == WallMaterial.timber) {
      items.add(const RationaleItem(
        text: 'Лёгкие стены (каркас/брус) дают малую нагрузку на основание. '
            'Винтовые сваи экономичнее ленты и не требуют мокрых процессов на площадке.',
        codeReference: 'СП 24.13330.2011 «Свайные фундаменты»; '
            'СП 64.13330 «Деревянные конструкции»',
      ));
      return _FoundationPick(
        FoundationDesign(
          type: FoundationType.pile,
          device: FoundationDevice.screwPile,
        ),
        FoundationRationale(items: items),
      );
    }
    items.add(const RationaleItem(
      text: 'Нет специфических факторов (торф / слабый грунт / скала / '
          'тяжёлые стены). По умолчанию рекомендуется ленточный монолитный '
          'фундамент мелкого заложения под несущими стенами.',
      codeReference: 'СП 22.13330.2016 «Основания зданий и сооружений»',
    ));
    return _FoundationPick(
      FoundationDesign(
        type: FoundationType.strip,
        device: FoundationDevice.monolithic,
      ),
      FoundationRationale(items: items),
    );
  }

  /// Вводная сводка: что мы взяли за исходные данные.
  static RationaleItem _inputsRationale(
    ClientBrief brief,
    SoilLayer? bearing,
  ) {
    final parts = <String>[];
    parts.add('Этажность: ${brief.floors ?? 1}');
    if (brief.hasMansard == true) parts.add('мансарда');
    if (brief.hasBasement == true) parts.add('подвал');
    if (brief.wallMaterial != null) {
      parts.add('стены — ${brief.wallMaterial!.title.toLowerCase()}');
    }
    if (bearing?.type != null) {
      parts.add('несущий слой — ${bearing!.type!.title.toLowerCase()}');
    } else if (brief.soilType != null) {
      parts.add('грунт — ${brief.soilType!.title.toLowerCase()}');
    }
    return RationaleItem(
      text: 'Исходные данные: ${parts.join(', ')}.',
      codeReference: 'СП 47.13330 «Инженерные изыскания для строительства»',
    );
  }

  /// Есть ли торф в верхних ~3 м (ориентировочная проверка).
  static bool _hasPeatInTop(List<SoilLayer> layers) {
    var depth = 0.0;
    for (final l in layers) {
      if (depth > 3) break;
      if (l.type == SoilType.peat) return true;
      depth += l.thickness ?? 0;
    }
    return false;
  }

  /// Несущий слой: первый сверху «non-weak» слой (не торф и не текучий).
  static SoilLayer? _bearingLayer(List<SoilLayer> layers) {
    for (final l in layers) {
      if (l.type == null) continue;
      if (l.type == SoilType.peat) continue;
      final il = l.liquidityIndex;
      if (il != null && il > 0.75) continue;
      return l;
    }
    return layers.isEmpty ? null : layers.first;
  }

  static WallsDesign _planWalls(ClientBrief brief) {
    final material = brief.wallMaterial;
    if (material == null) return WallsDesign();
    final thickness = _defaultThickness(material);
    return WallsDesign(
      material: material.name,
      thickness: thickness,
      height: 3.0,
    );
  }

  static double _defaultThickness(WallMaterial m) {
    switch (m) {
      case WallMaterial.brick:
        return 510;
      case WallMaterial.aerated:
        return 400;
      case WallMaterial.expandedClay:
        return 400;
      case WallMaterial.timber:
        return 200;
      case WallMaterial.frame:
        return 200;
    }
  }

  static RoofDesign _planRoof(ClientBrief brief) {
    final hasMansard = brief.hasMansard == true;
    return RoofDesign(
      type: hasMansard ? 'mansard' : 'gable',
      slopeAngle: hasMansard ? 45 : 30,
      roofingMaterial: 'metal',
    );
  }
}
