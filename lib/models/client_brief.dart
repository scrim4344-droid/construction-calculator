import '../data/region_catalog.dart';
import '../data/rooms_catalog.dart';
import '../data/soil_types.dart';
import '../data/wall_materials.dart';
import 'soil_layer.dart';

/// Техническое задание клиента — пожелания, которые мы собираем перед расчётами.
///
/// Заполняется через многошаговый визард и автосохраняется после каждого
/// шага. На основе технического задания движок правил подбирает состав сооружения.
class ClientBrief {
  /// Город из каталога [kRegionCatalog] либо введённый вручную (в режиме
  /// проектировщика).
  String? region;

  /// Снеговой район (1..8), по СП 20.13330.
  int? snowZone;

  /// Ветровой район (Ia..VII).
  String? windZone;

  /// Слои грунта на участке (инженерно-геологический разрез).
  /// Каждый слой содержит тип, мощность и опциональные физико-механические
  /// показатели по СП 22.13330 / СП 47.13330.
  final List<SoilLayer> soilLayers;

  /// Тип грунта верхнего/первого слоя — удобный геттер для случаев, когда
  /// нужно одно «обобщённое» значение (например, в кратких сводках).
  SoilType? get soilType =>
      soilLayers.isEmpty ? null : soilLayers.first.type;

  /// Этажность (1, 2, 3).
  int? floors;

  /// Признаки наличия: мансарда, подвал, гараж, терраса, балкон, эркер,
  /// второй свет, лестница (явный запрос).
  bool? hasMansard;
  bool? hasBasement;
  bool? hasGarage;
  bool? hasTerrace;
  bool? hasBalcony;
  bool? hasOriel; // эркер
  bool? hasDoubleHeight; // второй свет
  bool? hasStaircase;

  /// Целевая общая площадь, м².
  double? targetArea;

  /// Габариты пятна застройки, м.
  double? footprintWidth;
  double? footprintLength;

  /// Состав комнат: ключ — [RoomKind.name], значение — количество.
  final Map<String, int> rooms;

  /// Желаемый материал стен.
  WallMaterial? wallMaterial;

  /// Особые пожелания клиента в свободной форме.
  String? specialRequirements;

  ClientBrief({
    this.region,
    this.snowZone,
    this.windZone,
    List<SoilLayer>? soilLayers,
    this.floors,
    this.hasMansard,
    this.hasBasement,
    this.hasGarage,
    this.hasTerrace,
    this.hasBalcony,
    this.hasOriel,
    this.hasDoubleHeight,
    this.hasStaircase,
    this.targetArea,
    this.footprintWidth,
    this.footprintLength,
    Map<String, int>? rooms,
    this.wallMaterial,
    this.specialRequirements,
  })  : rooms = rooms ?? <String, int>{},
        soilLayers = soilLayers ?? <SoilLayer>[];

  bool get isStarted =>
      region != null ||
      soilLayers.any((l) => !l.isEmpty) ||
      floors != null ||
      targetArea != null ||
      rooms.values.any((v) => v > 0) ||
      wallMaterial != null ||
      (specialRequirements?.isNotEmpty ?? false);

  /// Все ключевые поля заполнены (готовый техническое задание).
  bool get isComplete =>
      region != null &&
      snowZone != null &&
      windZone != null &&
      soilLayers.any((l) => l.type != null) &&
      floors != null &&
      targetArea != null &&
      footprintWidth != null &&
      footprintLength != null &&
      wallMaterial != null;

  /// Нужна ли лестница: либо явный флаг, либо этажность > 1, либо мансарда,
  /// либо подвал.
  bool get requiresStaircase {
    if (hasStaircase == true) return true;
    if ((floors ?? 1) > 1) return true;
    if (hasMansard == true) return true;
    if (hasBasement == true) return true;
    return false;
  }

  String get summary {
    if (!isStarted) return 'Не заполнен';
    final parts = <String>[];
    if (floors != null) {
      parts.add('${floors!} эт.${hasMansard == true ? ' + мансарда' : ''}');
    }
    if (targetArea != null) {
      parts.add('${targetArea!.toStringAsFixed(0)} м²');
    }
    if (region != null) parts.add(region!);
    if (parts.isEmpty) return 'Заполняется';
    return parts.join(' · ');
  }

  Map<String, dynamic> toJson() => {
        'region': region,
        'snowZone': snowZone,
        'windZone': windZone,
        'soilLayers': soilLayers.map((l) => l.toJson()).toList(),
        'floors': floors,
        'hasMansard': hasMansard,
        'hasBasement': hasBasement,
        'hasGarage': hasGarage,
        'hasTerrace': hasTerrace,
        'hasBalcony': hasBalcony,
        'hasOriel': hasOriel,
        'hasDoubleHeight': hasDoubleHeight,
        'hasStaircase': hasStaircase,
        'targetArea': targetArea,
        'footprintWidth': footprintWidth,
        'footprintLength': footprintLength,
        'rooms': rooms,
        'wallMaterial': wallMaterial?.name,
        'specialRequirements': specialRequirements,
      };

  static ClientBrief fromJson(Map<String, dynamic> json) {
    final rawRooms = json['rooms'];
    final rooms = <String, int>{};
    if (rawRooms is Map) {
      rawRooms.forEach((k, v) {
        if (v is int) rooms[k.toString()] = v;
      });
    }
    final rawLayers = json['soilLayers'];
    final layers = <SoilLayer>[];
    if (rawLayers is List) {
      for (final l in rawLayers) {
        if (l is Map<String, dynamic>) {
          layers.add(SoilLayer.fromJson(l));
        } else if (l is Map) {
          layers.add(SoilLayer.fromJson(Map<String, dynamic>.from(l)));
        }
      }
    } else if (json['soilType'] is String) {
      // Миграция со старого формата (был один тип грунта без слоёв).
      final t = SoilType.fromName(json['soilType'] as String?);
      if (t != null) layers.add(SoilLayer(type: t));
    }
    return ClientBrief(
      region: json['region'] as String?,
      snowZone: json['snowZone'] as int?,
      windZone: json['windZone'] as String?,
      soilLayers: layers,
      floors: json['floors'] as int?,
      hasMansard: json['hasMansard'] as bool?,
      hasBasement: json['hasBasement'] as bool?,
      hasGarage: json['hasGarage'] as bool?,
      hasTerrace: json['hasTerrace'] as bool?,
      hasBalcony: json['hasBalcony'] as bool?,
      hasOriel: json['hasOriel'] as bool?,
      hasDoubleHeight: json['hasDoubleHeight'] as bool?,
      hasStaircase: json['hasStaircase'] as bool?,
      targetArea: (json['targetArea'] as num?)?.toDouble(),
      footprintWidth: (json['footprintWidth'] as num?)?.toDouble(),
      footprintLength: (json['footprintLength'] as num?)?.toDouble(),
      rooms: rooms,
      wallMaterial: WallMaterial.fromName(json['wallMaterial'] as String?),
      specialRequirements: json['specialRequirements'] as String?,
    );
  }
}
