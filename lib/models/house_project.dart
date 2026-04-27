import 'client_brief.dart';
import 'construction_type.dart';
import 'drawings_collection.dart';
import 'foundation_design.dart';
import 'roof_design.dart';
import 'staircase_design.dart';
import 'walls_design.dart';

/// Корневая модель проекта.
///
/// Один [HouseProject] — это «папка» со всеми данными по одному
/// проектируемому объекту: бриф клиента, элементы конструктива (фундамент,
/// стены, крыша, лестница) и сгенерированные чертежи.
///
/// Принцип «единого источника правды»: любые расчёты и любые чертежи
/// строятся именно из этого объекта, а не из локального состояния отдельных
/// экранов. Это позволяет легко сохранить/восстановить проект и не
/// рассинхронизировать данные.
class HouseProject {
  final String id;
  String name;
  final ConstructionType constructionType;
  final DateTime createdAt;
  DateTime updatedAt;

  ClientBrief brief;
  FoundationDesign foundation;
  WallsDesign walls;
  RoofDesign roof;
  StaircaseDesign staircase;
  DrawingsCollection drawings;

  HouseProject({
    required this.id,
    required this.name,
    required this.constructionType,
    required this.createdAt,
    required this.updatedAt,
    ClientBrief? brief,
    FoundationDesign? foundation,
    WallsDesign? walls,
    RoofDesign? roof,
    StaircaseDesign? staircase,
    DrawingsCollection? drawings,
  })  : brief = brief ?? ClientBrief(),
        foundation = foundation ?? FoundationDesign(),
        walls = walls ?? WallsDesign(),
        roof = roof ?? RoofDesign(),
        staircase = staircase ?? StaircaseDesign(),
        drawings = drawings ?? DrawingsCollection();

  void touch() {
    updatedAt = DateTime.now();
  }

  /// Какие конструктивные элементы должны быть в составе сооружения.
  /// Лестница появляется только если её нужно строить (см. бриф).
  bool get includesStaircase => brief.requiresStaircase;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'constructionType': constructionType.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'brief': brief.toJson(),
        'foundation': foundation.toJson(),
        'walls': walls.toJson(),
        'roof': roof.toJson(),
        'staircase': staircase.toJson(),
        'drawings': drawings.toJson(),
      };

  static HouseProject fromJson(Map<String, dynamic> json) {
    return HouseProject(
      id: json['id'] as String,
      name: json['name'] as String,
      constructionType: ConstructionType.fromName(
        json['constructionType'] as String? ?? '',
      ),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      brief: json['brief'] is Map<String, dynamic>
          ? ClientBrief.fromJson(json['brief'] as Map<String, dynamic>)
          : ClientBrief(),
      foundation: json['foundation'] is Map<String, dynamic>
          ? FoundationDesign.fromJson(
              json['foundation'] as Map<String, dynamic>,
            )
          : FoundationDesign(),
      walls: json['walls'] is Map<String, dynamic>
          ? WallsDesign.fromJson(json['walls'] as Map<String, dynamic>)
          : WallsDesign(),
      roof: json['roof'] is Map<String, dynamic>
          ? RoofDesign.fromJson(json['roof'] as Map<String, dynamic>)
          : RoofDesign(),
      staircase: json['staircase'] is Map<String, dynamic>
          ? StaircaseDesign.fromJson(json['staircase'] as Map<String, dynamic>)
          : StaircaseDesign(),
      drawings: json['drawings'] is Map<String, dynamic>
          ? DrawingsCollection.fromJson(
              json['drawings'] as Map<String, dynamic>,
            )
          : DrawingsCollection(),
    );
  }
}
