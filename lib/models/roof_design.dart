/// Состояние проектирования крыши.
///
/// Заполнение появится в следующей фазе. Сейчас — пустая модель
/// с поддержкой сериализации.
class RoofDesign {
  String? type; // gable, hip, flat, mansard и т. д.
  double? slopeAngle; // градусы
  String? roofingMaterial; // metal, tile, soft

  RoofDesign({this.type, this.slopeAngle, this.roofingMaterial});

  bool get isFilled => type != null;

  String get summary {
    if (!isFilled) return 'Не заполнено';
    return '${type ?? '?'}${slopeAngle != null ? ' · ${slopeAngle!.toStringAsFixed(0)}°' : ''}';
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'slopeAngle': slopeAngle,
        'roofingMaterial': roofingMaterial,
      };

  static RoofDesign fromJson(Map<String, dynamic> json) => RoofDesign(
        type: json['type'] as String?,
        slopeAngle: (json['slopeAngle'] as num?)?.toDouble(),
        roofingMaterial: json['roofingMaterial'] as String?,
      );
}
