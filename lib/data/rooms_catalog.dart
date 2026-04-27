/// Фиксированный каталог помещений, по которому собирается состав комнат.
///
/// Ключ совпадает с [RoomKind.name], значение — заголовок для UI.
/// Полный набор не меняется в зависимости от проекта: пользователь только
/// задаёт количество каждого типа помещений (счётчиками +/−).
enum RoomKind {
  bedroom,
  bathroom,
  kitchen,
  livingRoom,
  study,
  hallway,
  boilerRoom,
  storage;

  String get title {
    switch (this) {
      case RoomKind.bedroom:
        return 'Спальня';
      case RoomKind.bathroom:
        return 'Санузел';
      case RoomKind.kitchen:
        return 'Кухня';
      case RoomKind.livingRoom:
        return 'Гостиная';
      case RoomKind.study:
        return 'Кабинет';
      case RoomKind.hallway:
        return 'Прихожая';
      case RoomKind.boilerRoom:
        return 'Котельная';
      case RoomKind.storage:
        return 'Кладовая';
    }
  }

  /// Подсказка по умолчанию (сколько таких помещений обычно бывает).
  int get defaultCount {
    switch (this) {
      case RoomKind.bedroom:
        return 2;
      case RoomKind.bathroom:
        return 1;
      case RoomKind.kitchen:
        return 1;
      case RoomKind.livingRoom:
        return 1;
      case RoomKind.study:
        return 0;
      case RoomKind.hallway:
        return 1;
      case RoomKind.boilerRoom:
        return 1;
      case RoomKind.storage:
        return 0;
    }
  }
}
