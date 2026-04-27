// Smoke-тест: PdfBuilder корректно собирает PDF из синтетического плана
// без бросков исключений (типовая ловушка — кириллица + дуги дверей).
//
// Если установлена переменная окружения CC_DUMP_SAMPLE_PDF=1 — итоговый
// файл также пишется в /tmp/sample_plan.pdf для визуальной проверки.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:construction_calculator/models/construction_type.dart';
import 'package:construction_calculator/models/drawing.dart';
import 'package:construction_calculator/models/drawings_collection.dart';
import 'package:construction_calculator/models/floor_plan.dart';
import 'package:construction_calculator/models/house_project.dart';
import 'package:construction_calculator/services/pdf_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('PdfBuilder produces a non-empty PDF for a sample plan', () async {

    const plan = FloorPlan(
      floorLabel: 'Этаж 1',
      width: 12,
      height: 9,
      rooms: [
        // Прихожая
        PlanRoom(
          label: 'Прихожая',
          x: 0,
          y: 0,
          width: 3,
          height: 1.4,
          area: 4.2,
          kind: PlanRoomKind.free,
          roomKindName: 'hallway',
        ),
        // Коридор
        PlanRoom(
          label: 'Коридор',
          x: 3,
          y: 0,
          width: 9,
          height: 1.4,
          area: 12.6,
          kind: PlanRoomKind.free,
        ),
        // Гостиная
        PlanRoom(
          label: 'Гостиная',
          x: 0,
          y: 1.4,
          width: 7,
          height: 5,
          area: 35,
          roomKindName: 'livingRoom',
        ),
        // Кухня
        PlanRoom(
          label: 'Кухня',
          x: 7,
          y: 1.4,
          width: 5,
          height: 3,
          area: 15,
          roomKindName: 'kitchen',
        ),
        // Спальня
        PlanRoom(
          label: 'Спальня',
          x: 7,
          y: 4.4,
          width: 5,
          height: 2,
          area: 10,
          roomKindName: 'bedroom',
        ),
        // Санузел
        PlanRoom(
          label: 'Санузел',
          x: 0,
          y: 6.4,
          width: 3,
          height: 2.6,
          area: 7.8,
          roomKindName: 'bathroom',
        ),
        // Лестница
        PlanRoom(
          label: 'Лестница',
          x: 3,
          y: 6.4,
          width: 3,
          height: 2.6,
          area: 7.8,
          kind: PlanRoomKind.staircase,
        ),
        // Свободная зона
        PlanRoom(
          label: 'Свободная зона',
          x: 6,
          y: 6.4,
          width: 6,
          height: 2.6,
          area: 15.6,
          kind: PlanRoomKind.free,
        ),
      ],
      openings: [
        // Входная дверь со стороны улицы.
        PlanOpening(
          kind: OpeningKind.externalDoor,
          side: WallSide.top,
          x: 0.8,
          y: 0,
          length: 0.95,
        ),
        // Окно гостиной.
        PlanOpening(
          kind: OpeningKind.window,
          side: WallSide.left,
          x: 0,
          y: 3,
          length: 1.8,
        ),
        // Окно кухни.
        PlanOpening(
          kind: OpeningKind.window,
          side: WallSide.right,
          x: 12,
          y: 2,
          length: 1.5,
        ),
        // Окно спальни.
        PlanOpening(
          kind: OpeningKind.window,
          side: WallSide.right,
          x: 12,
          y: 4.8,
          length: 1.5,
        ),
        // Окно санузла.
        PlanOpening(
          kind: OpeningKind.window,
          side: WallSide.left,
          x: 0,
          y: 7.4,
          length: 0.6,
        ),
        // Дверь гостиной из коридора.
        PlanOpening(
          kind: OpeningKind.door,
          side: WallSide.top,
          x: 4,
          y: 1.4,
          length: 0.9,
        ),
        // Дверь кухни.
        PlanOpening(
          kind: OpeningKind.door,
          side: WallSide.top,
          x: 8,
          y: 1.4,
          length: 0.9,
        ),
        // Дверь спальни.
        PlanOpening(
          kind: OpeningKind.door,
          side: WallSide.left,
          x: 7,
          y: 5,
          length: 0.9,
        ),
        // Дверь санузла.
        PlanOpening(
          kind: OpeningKind.door,
          side: WallSide.top,
          x: 1,
          y: 6.4,
          length: 0.7,
        ),
        // Открытый проход в свободную зону.
        PlanOpening(
          kind: OpeningKind.archway,
          side: WallSide.left,
          x: 6,
          y: 7.4,
          length: 1.6,
        ),
      ],
    );

    final now = DateTime.now();
    final drawing = Drawing(
      id: 'd1',
      title: 'Схематический план — 1 этаж',
      kind: DrawingKind.schematicPlan,
      createdAt: now,
      payload: plan.encode(),
    );
    final project = HouseProject(
      id: 'p1',
      name: 'Тестовый дом',
      constructionType: ConstructionType.privateHouse,
      createdAt: now,
      updatedAt: now,
      drawings: DrawingsCollection(drawings: [drawing]),
    );

    final bytes = await PdfBuilder.buildBatch(
      project: project,
      drawings: [drawing],
      versionNumber: 1,
    );
    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(2000));

    if (Platform.environment['CC_DUMP_SAMPLE_PDF'] == '1') {
      final out = File('/tmp/sample_plan.pdf');
      await out.writeAsBytes(bytes);
      // ignore: avoid_print
      print('Saved sample PDF to ${out.path}');
    }
  });
}
