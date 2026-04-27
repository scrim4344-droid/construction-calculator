import '../data/rooms_catalog.dart';
import '../models/client_brief.dart';
import '../models/floor_plan.dart';

/// Генератор схематических планов этажей по брифу.
///
/// Алгоритм:
///   1. Разворачиваем состав комнат («Спальня: 3» → три комнаты с типовыми
///      площадями).
///   2. Распределяем по этажам:
///        — 1-й этаж: общественная зона + прихожая (если её нет в брифе,
///          добавляется автоматически);
///        — 2..N этажи: приватная зона.
///      Если этажность > 1 (или есть мансарда/подвал) — на КАЖДЫЙ этаж
///      добавляется лестничный проём фиксированной площади.
///   3. Резервируем минимум 20 % площади пятна под свободную зону. Если
///      рассчитанные комнаты не помещаются в 80 % — масштабируем их вниз.
///      Остаток до 100 % забивается псевдо-комнатой «Свободная зона»,
///      чтобы slice-and-dice не «съедал» дырки между комнатами.
///   4. Slice-and-dice укладка: рекурсивно режем длинную сторону пятна
///      пропорционально весам.
class FloorPlanGenerator {
  /// Типовые площади помещений, м² (для частного дома).
  static const Map<RoomKind, double> _typicalArea = {
    RoomKind.bedroom: 14,
    RoomKind.bathroom: 5,
    RoomKind.kitchen: 12,
    RoomKind.livingRoom: 25,
    RoomKind.study: 12,
    RoomKind.hallway: 8,
    RoomKind.boilerRoom: 6,
    RoomKind.storage: 4,
  };

  static const Set<RoomKind> _publicZone = {
    RoomKind.livingRoom,
    RoomKind.kitchen,
    RoomKind.hallway,
    RoomKind.boilerRoom,
    RoomKind.storage,
  };

  /// Минимальная доля свободного пространства от площади этажа.
  static const double _minFreeShare = 0.20;

  /// Типовые размеры лестничного проёма — фиксированы, чтобы
  /// лестница была в одном и том же месте на всех этажах (в реальности
  /// лестничный марш проходит через перекрытие в фиксированной точке).
  static const double _staircaseStripWidth = 3.0; // мин. ширина марша
  static const double _staircaseDepth = 4.0;

  static List<FloorPlan> generate(ClientBrief brief) {
    final width = brief.footprintWidth;
    final length = brief.footprintLength;
    if (width == null || length == null || width <= 0 || length <= 0) {
      return const [];
    }
    final floors = brief.floors ?? 1;
    final rooms = _expandRooms(brief);
    final perFloor = _distributeByFloors(rooms, floors);
    final needsStaircase = brief.requiresStaircase;

    final plans = <FloorPlan>[];
    for (var i = 0; i < perFloor.length; i++) {
      final floorRooms = perFloor[i];

      // Прихожая как отдельная комната больше не нужна — её роль играет начало
      // магистрального коридора.
      floorRooms.removeWhere((r) => r.kind == RoomKind.hallway);

      final layout = _layoutFloor(
        floorRooms,
        width,
        length,
        needsStaircase: needsStaircase,
        isFirstFloor: i == 0,
      );
      final openings = _planOpenings(
        layout,
        width,
        length,
        isFirstFloor: i == 0,
      );
      plans.add(FloorPlan(
        floorLabel: 'Этаж ${i + 1}',
        width: width,
        height: length,
        rooms: layout,
        openings: openings,
      ));
    }

    if (brief.hasMansard == true) {
      // Мансарда — отдельный «этаж». На MVP: только лестница +
      // свободная зона; будущие версии распределят сюда часть приватных.
      final layout = _layoutFloor(
        const [],
        width,
        length,
        needsStaircase: needsStaircase,
        isFirstFloor: false,
      );
      final openings = _planOpenings(
        layout,
        width,
        length,
        isFirstFloor: false,
      );
      plans.add(FloorPlan(
        floorLabel: 'Мансарда',
        width: width,
        height: length,
        rooms: layout,
        openings: openings,
      ));
    }
    return plans;
  }

  static List<_RoomReq> _expandRooms(ClientBrief brief) {
    final out = <_RoomReq>[];
    for (final k in RoomKind.values) {
      final n = brief.rooms[k.name] ?? 0;
      for (var i = 0; i < n; i++) {
        out.add(_RoomReq(
          kind: k,
          label: n == 1 ? k.title : '${k.title} ${i + 1}',
          area: _typicalArea[k] ?? 10,
        ));
      }
    }
    return out;
  }

  static List<List<_RoomReq>> _distributeByFloors(
    List<_RoomReq> rooms,
    int floors,
  ) {
    if (floors <= 1) return [List.of(rooms)];
    final ground = <_RoomReq>[];
    final upstairs = <_RoomReq>[];
    for (final r in rooms) {
      if (_publicZone.contains(r.kind)) {
        ground.add(r);
      } else {
        upstairs.add(r);
      }
    }
    if (floors == 2) {
      return [ground, upstairs];
    }
    final extras = floors - 1;
    final slices = List<List<_RoomReq>>.generate(extras, (_) => <_RoomReq>[]);
    for (var i = 0; i < upstairs.length; i++) {
      slices[i % extras].add(upstairs[i]);
    }
    return [ground, ...slices];
  }

  /// Подготавливаем раскладку этажа. Лестница, если нужна, размещается в
  /// фиксированной полосе (вдоль правой или верхней стены) — это гарантирует,
  /// что лестница окажется в одних и тех же координатах на всех этажах.
  /// Оставшаяся область раскладывается комнатами + свободной зоной (≥0.20).
  static List<PlanRoom> _layoutFloor(
    List<_RoomReq> rooms,
    double width,
    double length, {
    required bool needsStaircase,
    required bool isFirstFloor,
  }) {
    final result = <PlanRoom>[];
    var areaX = 0.0;
    var areaY = 0.0;
    var areaW = width;
    var areaH = length;

    if (needsStaircase) {
      // Выбираем ориентацию полосы: полоса вдоль правой стены, если пятно
      // достаточно широкое; иначе — вдоль верхней.
      final stripVertical = width >= 6.0;
      if (stripVertical) {
        final stripX = width - _staircaseStripWidth;
        // Лестница привязана к верхнему краю полосы.
        final stairH = _staircaseDepth.clamp(0.0, length).toDouble();
        result.add(PlanRoom(
          label: 'Лестница',
          x: stripX,
          y: 0,
          width: _staircaseStripWidth,
          height: stairH,
          area: _staircaseStripWidth * stairH,
          kind: PlanRoomKind.staircase,
        ));
        if (length > stairH) {
          result.add(PlanRoom(
            label: 'Коридор',
            x: stripX,
            y: stairH,
            width: _staircaseStripWidth,
            height: length - stairH,
            area: _staircaseStripWidth * (length - stairH),
            kind: PlanRoomKind.free,
          ));
        }
        areaX = 0;
        areaY = 0;
        areaW = width - _staircaseStripWidth;
        areaH = length;
      } else {
        // Полоса сверху.
        final stairW = _staircaseDepth.clamp(0.0, width).toDouble();
        result.add(PlanRoom(
          label: 'Лестница',
          x: 0,
          y: 0,
          width: stairW,
          height: _staircaseStripWidth,
          area: stairW * _staircaseStripWidth,
          kind: PlanRoomKind.staircase,
        ));
        if (width > stairW) {
          result.add(PlanRoom(
            label: 'Коридор',
            x: stairW,
            y: 0,
            width: width - stairW,
            height: _staircaseStripWidth,
            area: (width - stairW) * _staircaseStripWidth,
            kind: PlanRoomKind.free,
          ));
        }
        areaX = 0;
        areaY = _staircaseStripWidth;
        areaW = width;
        areaH = length - _staircaseStripWidth;
      }
    }

    // Коридорная раскладка: в оставшейся области прорезаем магистральный
    // коридор сквозь весь этаж. На 1-м этаже начало коридора у наружной
    // стены становится прихожей. Комнаты делятся на два «банка» по обе
    // стороны от коридора — каждая комната гарантированно выходит
    // в коридор одной своей длинной стороной.
    if (areaW > 0 && areaH > 0) {
      _placeWithCorridor(
        result,
        rooms,
        areaX,
        areaY,
        areaW,
        areaH,
        isFirstFloor: isFirstFloor,
      );
    }
    return result;
  }

  /// Минимальная ширина коридора (СП 55.13330 п. 4.10 — 0.85 м,
  /// берём с запасом для удобного прохода с дверьми).
  static const double _corridorWidth = 1.4;

  /// Начальный сегмент коридора, который становится прихожей.
  static const double _hallwayLen = 3.0;

  static void _placeWithCorridor(
    List<PlanRoom> result,
    List<_RoomReq> rooms,
    double areaX,
    double areaY,
    double areaW,
    double areaH, {
    required bool isFirstFloor,
  }) {
    // Ориентируем коридор вдоль длинной стороны области — станет
    // больше комнат вдоль него и они будут пропорциональными.
    final horizontal = areaW >= areaH;
    final canPlaceCorridor = horizontal
        ? areaH > _corridorWidth + 2.0
        : areaW > _corridorWidth + 2.0;
    if (!canPlaceCorridor) {
      // Область слишком мала — откатываемся к старой логике.
      final positioned = _layoutRoomsInRect(rooms, areaW, areaH);
      for (final p in positioned) {
        result.add(PlanRoom(
          label: p.label,
          x: p.x + areaX,
          y: p.y + areaY,
          width: p.width,
          height: p.height,
          area: p.area,
          kind: p.kind,
          roomKindName: p.roomKindName,
        ));
      }
      return;
    }

    final (groupA, groupB) = _balanceSplit(rooms);

    if (horizontal) {
      final cy = areaY + (areaH - _corridorWidth) / 2;
      _addCorridorBlocks(
        result,
        x: areaX,
        y: cy,
        w: areaW,
        h: _corridorWidth,
        isFirstFloor: isFirstFloor,
        horizontal: true,
      );
      // Верхний банк (выше коридора).
      final topH = cy - areaY;
      _fillBank(result, groupA, areaX, areaY, areaW, topH);
      // Нижний банк.
      final botY = cy + _corridorWidth;
      final botH = areaY + areaH - botY;
      _fillBank(result, groupB, areaX, botY, areaW, botH);
    } else {
      final cx = areaX + (areaW - _corridorWidth) / 2;
      _addCorridorBlocks(
        result,
        x: cx,
        y: areaY,
        w: _corridorWidth,
        h: areaH,
        isFirstFloor: isFirstFloor,
        horizontal: false,
      );
      // Левый банк.
      final leftW = cx - areaX;
      _fillBank(result, groupA, areaX, areaY, leftW, areaH);
      // Правый банк.
      final rightX = cx + _corridorWidth;
      final rightW = areaX + areaW - rightX;
      _fillBank(result, groupB, rightX, areaY, rightW, areaH);
    }
  }

  static void _addCorridorBlocks(
    List<PlanRoom> result, {
    required double x,
    required double y,
    required double w,
    required double h,
    required bool isFirstFloor,
    required bool horizontal,
  }) {
    if (w <= 0 || h <= 0) return;
    if (!isFirstFloor) {
      result.add(PlanRoom(
        label: 'Коридор',
        x: x,
        y: y,
        width: w,
        height: h,
        area: w * h,
        kind: PlanRoomKind.free,
      ));
      return;
    }
    if (horizontal && w > _hallwayLen + 1.5) {
      // Прихожая — левый край (наружная стена).
      result.add(PlanRoom(
        label: 'Прихожая',
        x: x,
        y: y,
        width: _hallwayLen,
        height: h,
        area: _hallwayLen * h,
        kind: PlanRoomKind.free,
        roomKindName: RoomKind.hallway.name,
      ));
      result.add(PlanRoom(
        label: 'Коридор',
        x: x + _hallwayLen,
        y: y,
        width: w - _hallwayLen,
        height: h,
        area: (w - _hallwayLen) * h,
        kind: PlanRoomKind.free,
      ));
    } else if (!horizontal && h > _hallwayLen + 1.5) {
      // Прихожая — нижний край.
      result.add(PlanRoom(
        label: 'Коридор',
        x: x,
        y: y,
        width: w,
        height: h - _hallwayLen,
        area: w * (h - _hallwayLen),
        kind: PlanRoomKind.free,
      ));
      result.add(PlanRoom(
        label: 'Прихожая',
        x: x,
        y: y + h - _hallwayLen,
        width: w,
        height: _hallwayLen,
        area: w * _hallwayLen,
        kind: PlanRoomKind.free,
        roomKindName: RoomKind.hallway.name,
      ));
    } else {
      // Для коротких коридоров весь сегмент «Прихожая».
      result.add(PlanRoom(
        label: 'Прихожая',
        x: x,
        y: y,
        width: w,
        height: h,
        area: w * h,
        kind: PlanRoomKind.free,
        roomKindName: RoomKind.hallway.name,
      ));
    }
  }

  /// Делим список комнат на две группы с минимальным разрывом по сумме
  /// площадей: сортируем по убыванию и жадно раскладываем по балансу.
  static (List<_RoomReq>, List<_RoomReq>) _balanceSplit(
    List<_RoomReq> rooms,
  ) {
    final sorted = List<_RoomReq>.from(rooms)
      ..sort((a, b) => b.area.compareTo(a.area));
    final a = <_RoomReq>[];
    final b = <_RoomReq>[];
    var sumA = 0.0;
    var sumB = 0.0;
    for (final r in sorted) {
      if (sumA <= sumB) {
        a.add(r);
        sumA += r.area;
      } else {
        b.add(r);
        sumB += r.area;
      }
    }
    return (a, b);
  }

  /// Раскладывает комнаты в прямоугольник [w]×[h] с полным
  /// заполнением (без свободной зоны внутри банка). Если комнат нет —
  /// весь банк становится свободной зоной.
  static void _fillBank(
    List<PlanRoom> result,
    List<_RoomReq> rooms,
    double x,
    double y,
    double w,
    double h,
  ) {
    if (w <= 0.5 || h <= 0.5) return;
    if (rooms.isEmpty) {
      result.add(PlanRoom(
        label: 'Свободная зона',
        x: x,
        y: y,
        width: w,
        height: h,
        area: w * h,
        kind: PlanRoomKind.free,
      ));
      return;
    }
    final total = rooms.fold<double>(0, (s, r) => s + r.area);
    final bankArea = w * h;
    final scale = total > 0 ? bankArea / total : 1.0;
    final scaled = [
      for (final r in rooms)
        _RoomReq(
          kind: r.kind,
          label: r.label,
          area: r.area * scale,
        ),
    ];
    final out = <PlanRoom>[];
    _slice(out, scaled, 0, 0, w, h);
    for (final p in out) {
      result.add(PlanRoom(
        label: p.label,
        x: p.x + x,
        y: p.y + y,
        width: p.width,
        height: p.height,
        area: p.area,
        kind: p.kind,
        roomKindName: p.roomKindName,
      ));
    }
  }

  /// Раскладка комнат в прямоугольник [w] × [h] (без лестницы):
  /// масштабируем комнаты под «(1 - _minFreeShare)», добавляем свободную зону,
  /// пропускаем через slice-and-dice.
  static List<PlanRoom> _layoutRoomsInRect(
    List<_RoomReq> rooms,
    double w,
    double h,
  ) {
    if (w <= 0 || h <= 0) return const [];
    final footprint = w * h;
    final maxRoomsArea = footprint * (1 - _minFreeShare);
    final realRooms = List<_RoomReq>.from(rooms);
    final realArea = realRooms.fold<double>(0, (s, r) => s + r.area);
    final scale = realArea > maxRoomsArea && realArea > 0
        ? maxRoomsArea / realArea
        : 1.0;
    final scaled = [
      for (final r in realRooms)
        _RoomReq(
          kind: r.kind,
          label: r.label,
          area: r.area * scale,
        ),
    ];
    final used = scaled.fold<double>(0, (s, r) => s + r.area);
    if (used < footprint * 0.99) {
      scaled.add(_RoomReq.free(footprint - used));
    }
    return _sliceAndDice(scaled, w, h);
  }

  static List<PlanRoom> _sliceAndDice(
    List<_RoomReq> rooms,
    double width,
    double length,
  ) {
    final out = <PlanRoom>[];
    if (rooms.isEmpty) return out;
    _slice(out, rooms, 0, 0, width, length);
    return out;
  }

  static void _slice(
    List<PlanRoom> out,
    List<_RoomReq> rooms,
    double x,
    double y,
    double w,
    double h,
  ) {
    if (rooms.isEmpty) return;
    if (rooms.length == 1) {
      final r = rooms.first;
      out.add(PlanRoom(
        label: r.label,
        x: x,
        y: y,
        width: w,
        height: h,
        area: w * h,
        kind: r.planKind,
        roomKindName: r.kind?.name,
      ));
      return;
    }
    final total = rooms.fold<double>(0, (s, r) => s + r.area);
    final half = total / 2;
    var acc = 0.0;
    var splitIdx = 1;
    for (var i = 0; i < rooms.length; i++) {
      acc += rooms[i].area;
      if (acc >= half) {
        splitIdx = i + 1;
        break;
      }
    }
    splitIdx = splitIdx.clamp(1, rooms.length - 1);
    final left = rooms.sublist(0, splitIdx);
    final right = rooms.sublist(splitIdx);
    final leftArea = left.fold<double>(0, (s, r) => s + r.area);
    final ratio = total > 0 ? leftArea / total : 0.5;

    if (w >= h) {
      final cut = w * ratio;
      _slice(out, left, x, y, cut, h);
      _slice(out, right, x + cut, y, w - cut, h);
    } else {
      final cut = h * ratio;
      _slice(out, left, x, y, w, cut);
      _slice(out, right, x, y + cut, w, h - cut);
    }
  }

  // ---------------------------------------------------------------------
  // Расстановка дверей и окон по нормам (СП 55.13330, СП 1.13130, СП 50,
  // СП 23-102). Логика упрощённая, но соответствует принципам нормативов:
  //   * жилые комнаты должны иметь окно (СП 55.13330, п. 9.12);
  //   * межкомнатные двери ≥ 0.8 м, в санузел ≥ 0.6 м (СП 1.13130);
  //   * входная дверь — на 1-м этаже со стороны прихожей.
  // ---------------------------------------------------------------------

  /// Стандартные ширины проёмов (м).
  static const double _doorWidth = 0.9; // межкомнатная типовая
  static const double _bathDoorWidth = 0.7; // санузел/кладовая
  static const double _entryDoorWidth = 0.95; // входная (СП 1.13130)
  static const double _minWindow = 1.0;
  static const double _maxWindow = 2.4;

  /// Минимальная длина общей стены, чтобы дверь поместилась с зазорами.
  static const double _minSharedWallForDoor = 1.4;

  /// Пересчитать набор проёмов для уже готовой [plan]. Используется
  /// редактором плана: после ручной правки координат комнат двери и окна
  /// нужно переразложить под новую геометрию (СП 55.13330, СП 1.13130,
  /// СП 23-102 — те же правила, что в авторасчёте).
  static List<PlanOpening> recomputeOpenings(
    FloorPlan plan, {
    required bool isFirstFloor,
  }) =>
      _planOpenings(
        plan.rooms,
        plan.width,
        plan.height,
        isFirstFloor: isFirstFloor,
      );

  static List<PlanOpening> _planOpenings(
    List<PlanRoom> rooms,
    double planWidth,
    double planHeight, {
    required bool isFirstFloor,
  }) {
    final openings = <PlanOpening>[];
    if (rooms.isEmpty) return openings;

    // 1. Двери между смежными комнатами по правилам связности.
    for (var i = 0; i < rooms.length; i++) {
      for (var j = i + 1; j < rooms.length; j++) {
        final a = rooms[i];
        final b = rooms[j];
        // Между двумя свободными зонами — открытый проход (архивольт),
        // чтобы не было визуальной стены между «Прихожей» и «Коридором»
        // или между основным и лестничным коридорами.
        if (a.kind == PlanRoomKind.free && b.kind == PlanRoomKind.free) {
          final shared = _sharedWall(a, b);
          if (shared != null && shared.length > 0.5) {
            openings.add(PlanOpening(
              kind: OpeningKind.archway,
              side: shared.isVertical ? WallSide.left : WallSide.top,
              x: shared.isVertical ? shared.coord : shared.start,
              y: shared.isVertical ? shared.start : shared.coord,
              length: shared.length,
            ));
          }
          continue;
        }
        if (!_shouldHaveDoor(a, b)) continue;
        final shared = _sharedWall(a, b);
        if (shared == null) continue;
        final width = _doorWidthBetween(a, b);
        if (shared.length < _minSharedWallForDoor) continue;
        if (shared.length < width + 0.4) continue;
        // Дверь по центру общего сегмента.
        final mid = (shared.start + shared.end) / 2;
        final doorStart = mid - width / 2;
        final swing = shared.swing;
        openings.add(PlanOpening(
          kind: OpeningKind.door,
          side: shared.isVertical ? WallSide.left : WallSide.top,
          x: shared.isVertical ? shared.coord : doorStart,
          y: shared.isVertical ? doorStart : shared.coord,
          length: width,
          swing: swing,
        ));
      }
    }

    // 2. Окна на наружных стенах для жилых комнат (и кухни).
    for (final r in rooms) {
      if (!_needsWindow(r)) continue;
      // Из всех наружных сторон выбираем самую длинную.
      WallSide? bestSide;
      var bestLen = 0.0;
      for (final side in WallSide.values) {
        if (!_isOuterWall(r, side, planWidth, planHeight)) continue;
        final wallLen = side.isHorizontal ? r.width : r.height;
        if (wallLen > bestLen) {
          bestLen = wallLen;
          bestSide = side;
        }
      }
      if (bestSide == null || bestLen < _minWindow + 0.6) continue;
      // Ширина по правилу So/Sp ≈ 1:8 (СП 23-102) при высоте окна ~1.5 м:
      // w = area / (8 * 1.5). Ограничиваем сверху и снизу типовыми
      // значениями.
      final desired = (r.area / 12).clamp(_minWindow, _maxWindow);
      final usable = (bestLen - 0.6).clamp(_minWindow, _maxWindow);
      final winLen = desired < usable ? desired : usable;
      final wallStart = bestSide.isHorizontal ? r.x : r.y;
      final winStart = wallStart + (bestLen - winLen) / 2;
      double winX, winY;
      switch (bestSide) {
        case WallSide.top:
          winX = winStart;
          winY = r.y;
          break;
        case WallSide.bottom:
          winX = winStart;
          winY = r.y + r.height;
          break;
        case WallSide.left:
          winX = r.x;
          winY = winStart;
          break;
        case WallSide.right:
          winX = r.x + r.width;
          winY = winStart;
          break;
      }
      openings.add(PlanOpening(
        kind: OpeningKind.window,
        side: bestSide,
        x: winX,
        y: winY,
        length: winLen,
      ));
    }

    // 3. Входная дверь — на 1-м этаже, в прихожей или свободной зоне с
    // выходом на улицу.
    if (isFirstFloor) {
      PlanRoom? entryRoom;
      for (final r in rooms) {
        final isHallway = r.roomKindName == RoomKind.hallway.name;
        final isFree = r.kind == PlanRoomKind.free;
        if (!isHallway && !isFree) continue;
        if (_hasOuterWall(r, planWidth, planHeight)) {
          entryRoom = r;
          if (isHallway) break; // приоритет — настоящая прихожая
        }
      }
      if (entryRoom != null) {
        WallSide? bestSide;
        var bestLen = 0.0;
        for (final side in WallSide.values) {
          if (!_isOuterWall(entryRoom, side, planWidth, planHeight)) continue;
          final wallLen = side.isHorizontal
              ? entryRoom.width
              : entryRoom.height;
          if (wallLen > bestLen) {
            bestLen = wallLen;
            bestSide = side;
          }
        }
        if (bestSide != null && bestLen >= _entryDoorWidth + 0.6) {
          final wallStart = bestSide.isHorizontal ? entryRoom.x : entryRoom.y;
          final start = wallStart + (bestLen - _entryDoorWidth) / 2;
          double dx, dy;
          switch (bestSide) {
            case WallSide.top:
              dx = start;
              dy = entryRoom.y;
              break;
            case WallSide.bottom:
              dx = start;
              dy = entryRoom.y + entryRoom.height;
              break;
            case WallSide.left:
              dx = entryRoom.x;
              dy = start;
              break;
            case WallSide.right:
              dx = entryRoom.x + entryRoom.width;
              dy = start;
              break;
          }
          openings.add(PlanOpening(
            kind: OpeningKind.externalDoor,
            side: bestSide,
            x: dx,
            y: dy,
            length: _entryDoorWidth,
            swing: 1,
          ));
        }
      }
    }

    return openings;
  }

  static bool _shouldHaveDoor(PlanRoom a, PlanRoom b) {
    // Лестница связана через коридор/прихожую без двери (открытый проём
    // не отрисовываем как дверь, чтобы не загромождать схему).
    if (a.kind == PlanRoomKind.staircase || b.kind == PlanRoomKind.staircase) {
      return false;
    }
    final aFree = a.kind == PlanRoomKind.free;
    final bFree = b.kind == PlanRoomKind.free;
    // Между двумя свободными зонами двери не нужны (это один коридор).
    if (aFree && bFree) return false;
    // Свободная зона <-> любая комната — дверь есть.
    if (aFree || bFree) return true;
    // Гостиная <-> кухня — открытый проход (студия). Считаем как дверь.
    final aKind = a.roomKindName;
    final bKind = b.roomKindName;
    final livingKitchen = (aKind == RoomKind.livingRoom.name &&
            bKind == RoomKind.kitchen.name) ||
        (aKind == RoomKind.kitchen.name &&
            bKind == RoomKind.livingRoom.name);
    if (livingKitchen) return true;
    // Все остальные пары жилых/служебных комнат напрямую не соединяем —
    // только через коридор (СП 55.13330: спальни и санузлы не должны
    // выходить непосредственно друг в друга и в кухню).
    return false;
  }

  static double _doorWidthBetween(PlanRoom a, PlanRoom b) {
    bool isNarrow(String? n) =>
        n == RoomKind.bathroom.name ||
        n == RoomKind.storage.name ||
        n == RoomKind.boilerRoom.name;
    if (isNarrow(a.roomKindName) || isNarrow(b.roomKindName)) {
      return _bathDoorWidth;
    }
    return _doorWidth;
  }

  static bool _needsWindow(PlanRoom r) {
    if (r.kind != PlanRoomKind.room) return false;
    final n = r.roomKindName;
    return n == RoomKind.bedroom.name ||
        n == RoomKind.livingRoom.name ||
        n == RoomKind.kitchen.name ||
        n == RoomKind.study.name;
  }

  static bool _isOuterWall(
    PlanRoom r,
    WallSide side,
    double planW,
    double planH,
  ) {
    const eps = 0.05;
    switch (side) {
      case WallSide.top:
        return r.y < eps;
      case WallSide.bottom:
        return (r.y + r.height) > planH - eps;
      case WallSide.left:
        return r.x < eps;
      case WallSide.right:
        return (r.x + r.width) > planW - eps;
    }
  }

  static bool _hasOuterWall(PlanRoom r, double planW, double planH) {
    for (final s in WallSide.values) {
      if (_isOuterWall(r, s, planW, planH)) return true;
    }
    return false;
  }

  static _SharedWall? _sharedWall(PlanRoom a, PlanRoom b) {
    const eps = 0.05;
    // Вертикальная общая стена: a.right == b.left или наоборот.
    if ((a.x + a.width - b.x).abs() < eps) {
      final top = a.y > b.y ? a.y : b.y;
      final bottom = (a.y + a.height) < (b.y + b.height)
          ? (a.y + a.height)
          : (b.y + b.height);
      if (bottom - top > eps) {
        return _SharedWall(
          isVertical: true,
          coord: a.x + a.width,
          start: top,
          end: bottom,
          swing: 1,
        );
      }
    }
    if ((b.x + b.width - a.x).abs() < eps) {
      final top = a.y > b.y ? a.y : b.y;
      final bottom = (a.y + a.height) < (b.y + b.height)
          ? (a.y + a.height)
          : (b.y + b.height);
      if (bottom - top > eps) {
        return _SharedWall(
          isVertical: true,
          coord: a.x,
          start: top,
          end: bottom,
          swing: -1,
        );
      }
    }
    // Горизонтальная общая стена: a.bottom == b.top или наоборот.
    if ((a.y + a.height - b.y).abs() < eps) {
      final left = a.x > b.x ? a.x : b.x;
      final right = (a.x + a.width) < (b.x + b.width)
          ? (a.x + a.width)
          : (b.x + b.width);
      if (right - left > eps) {
        return _SharedWall(
          isVertical: false,
          coord: a.y + a.height,
          start: left,
          end: right,
          swing: 1,
        );
      }
    }
    if ((b.y + b.height - a.y).abs() < eps) {
      final left = a.x > b.x ? a.x : b.x;
      final right = (a.x + a.width) < (b.x + b.width)
          ? (a.x + a.width)
          : (b.x + b.width);
      if (right - left > eps) {
        return _SharedWall(
          isVertical: false,
          coord: a.y,
          start: left,
          end: right,
          swing: -1,
        );
      }
    }
    return null;
  }
}

class _SharedWall {
  final bool isVertical;
  final double coord; // x для вертикальной, y для горизонтальной
  final double start; // y или x начала пересечения
  final double end;
  final int swing;
  double get length => end - start;
  const _SharedWall({
    required this.isVertical,
    required this.coord,
    required this.start,
    required this.end,
    required this.swing,
  });
}

class _RoomReq {
  final RoomKind? kind;
  final String label;
  final double area;
  final bool isFree;

  _RoomReq({
    required this.kind,
    required this.label,
    required this.area,
    this.isFree = false,
  });

  factory _RoomReq.free(double area) => _RoomReq(
        kind: null,
        label: 'Прихожая / коридор',
        area: area,
        isFree: true,
      );

  PlanRoomKind get planKind =>
      isFree ? PlanRoomKind.free : PlanRoomKind.room;
}
