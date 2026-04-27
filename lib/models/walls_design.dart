/// Состояние проектирования стен.
///
/// Заполнение появится в следующей фазе (после готового технического задания). Здесь
/// заведена пустая модель с поддержкой сериализации, чтобы дальше
/// безболезненно добавлять поля.
class WallsDesign {
  String? material; // brick, aerated, timber, frame
  double? thickness; // мм
  double? height; // м

  WallsDesign({this.material, this.thickness, this.height});

  bool get isFilled => material != null && thickness != null;

  String get summary {
    if (!isFilled) return 'Не заполнено';
    return '${material ?? '?'} · ${thickness?.toStringAsFixed(0) ?? '?'} мм';
  }

  Map<String, dynamic> toJson() => {
        'material': material,
        'thickness': thickness,
        'height': height,
      };

  static WallsDesign fromJson(Map<String, dynamic> json) => WallsDesign(
        material: json['material'] as String?,
        thickness: (json['thickness'] as num?)?.toDouble(),
        height: (json['height'] as num?)?.toDouble(),
      );
}
