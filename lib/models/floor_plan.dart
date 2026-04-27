import 'dart:convert';

/// Категория элемента плана — определяет внешний вид при отрисовке.
enum PlanRoomKind {
  room, // обычная комната
  staircase, // лестничный проём
  free; // свободная зона / коридор / прихожая

  static PlanRoomKind fromName(String? n) {
    return PlanRoomKind.values.firstWhere(
      (v) => v.name == n,
      orElse: () => PlanRoomKind.room,
    );
  }
}

/// Тип проёма в стене.
enum OpeningKind {
  door, // межкомнатная дверь
  externalDoor, // входная дверь со стороны улицы
  window, // окно
  archway; // открытый проход (между свободными зонами)

  static OpeningKind fromName(String? n) {
    return OpeningKind.values.firstWhere(
      (v) => v.name == n,
      orElse: () => OpeningKind.door,
    );
  }
}

/// Сторона стены, на которой расположен проём (от точки `(x, y)` комнаты).
enum WallSide {
  top,
  bottom,
  left,
  right;

  bool get isHorizontal => this == top || this == bottom;

  static WallSide fromName(String? n) {
    return WallSide.values.firstWhere(
      (v) => v.name == n,
      orElse: () => WallSide.top,
    );
  }
}

/// Прямоугольник на схематическом плане.
///
/// Координаты и размеры — в метрах от левого верхнего угла пятна застройки.
class PlanRoom {
  final String label;
  final double x;
  final double y;
  final double width;
  final double height;
  final double area;
  final PlanRoomKind kind;

  /// Имя функционального типа комнаты (`RoomKind.name`), например
  /// `bedroom`, `kitchen`, `bathroom`. Нужно для правил расстановки
  /// дверей/окон. Не заполняется для staircase/free.
  final String? roomKindName;

  const PlanRoom({
    required this.label,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.area,
    this.kind = PlanRoomKind.room,
    this.roomKindName,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'area': area,
        'kind': kind.name,
        if (roomKindName != null) 'roomKindName': roomKindName,
      };

  PlanRoom copyWith({
    String? label,
    double? x,
    double? y,
    double? width,
    double? height,
    double? area,
    PlanRoomKind? kind,
    String? roomKindName,
  }) =>
      PlanRoom(
        label: label ?? this.label,
        x: x ?? this.x,
        y: y ?? this.y,
        width: width ?? this.width,
        height: height ?? this.height,
        area: area ?? this.area,
        kind: kind ?? this.kind,
        roomKindName: roomKindName ?? this.roomKindName,
      );

  static PlanRoom fromJson(Map<String, dynamic> j) => PlanRoom(
        label: j['label'] as String,
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        width: (j['width'] as num).toDouble(),
        height: (j['height'] as num).toDouble(),
        area: (j['area'] as num).toDouble(),
        kind: PlanRoomKind.fromName(j['kind'] as String?),
        roomKindName: j['roomKindName'] as String?,
      );
}

/// Проём в стене — дверь, входная дверь или окно.
///
/// Координата проёма задаётся в системе координат пятна застройки:
/// [x], [y] — координата начала проёма по той стене, на которой он стоит,
/// [length] — длина проёма вдоль стены. Например, окно шириной 1.5 м на
/// верхней стене комнаты, начинающееся в 1 м от её левого угла, имеет
/// `side = top`, `x = roomX + 1`, `y = roomY`, `length = 1.5`.
class PlanOpening {
  final OpeningKind kind;
  final WallSide side;
  final double x;
  final double y;
  final double length;

  /// Сторона, на которую открывается дверь (для рисования створки).
  /// Условные значения: `1` — наружу/внутрь по нормали справа/вниз,
  /// `-1` — слева/вверх. Игнорируется для окон.
  final int swing;

  const PlanOpening({
    required this.kind,
    required this.side,
    required this.x,
    required this.y,
    required this.length,
    this.swing = 1,
  });

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'side': side.name,
        'x': x,
        'y': y,
        'length': length,
        'swing': swing,
      };

  static PlanOpening fromJson(Map<String, dynamic> j) => PlanOpening(
        kind: OpeningKind.fromName(j['kind'] as String?),
        side: WallSide.fromName(j['side'] as String?),
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        length: (j['length'] as num).toDouble(),
        swing: (j['swing'] as num?)?.toInt() ?? 1,
      );
}

/// Схематический план одного этажа.
class FloorPlan {
  final String floorLabel;
  final double width;
  final double height;
  final List<PlanRoom> rooms;
  final List<PlanOpening> openings;

  const FloorPlan({
    required this.floorLabel,
    required this.width,
    required this.height,
    required this.rooms,
    this.openings = const [],
  });

  FloorPlan copyWith({
    String? floorLabel,
    double? width,
    double? height,
    List<PlanRoom>? rooms,
    List<PlanOpening>? openings,
  }) =>
      FloorPlan(
        floorLabel: floorLabel ?? this.floorLabel,
        width: width ?? this.width,
        height: height ?? this.height,
        rooms: rooms ?? this.rooms,
        openings: openings ?? this.openings,
      );

  Map<String, dynamic> toJson() => {
        'floorLabel': floorLabel,
        'width': width,
        'height': height,
        'rooms': rooms.map((r) => r.toJson()).toList(),
        'openings': openings.map((o) => o.toJson()).toList(),
      };

  static FloorPlan fromJson(Map<String, dynamic> j) => FloorPlan(
        floorLabel: j['floorLabel'] as String,
        width: (j['width'] as num).toDouble(),
        height: (j['height'] as num).toDouble(),
        rooms: [
          for (final r in (j['rooms'] as List))
            PlanRoom.fromJson(Map<String, dynamic>.from(r as Map)),
        ],
        openings: [
          for (final o in (j['openings'] as List? ?? const []))
            PlanOpening.fromJson(Map<String, dynamic>.from(o as Map)),
        ],
      );

  String encode() => jsonEncode(toJson());

  static FloorPlan? tryDecode(String payload) {
    try {
      final m = jsonDecode(payload);
      if (m is Map<String, dynamic>) return FloorPlan.fromJson(m);
    } catch (_) {}
    return null;
  }
}
