import 'package:uuid/uuid.dart';

import '../models/drawing.dart';
import '../models/house_project.dart';
import '../models/user_mode.dart';
import 'floor_plan_generator.dart';

/// Генератор чертежей по проекту.
///
/// На текущей итерации содержит:
///   * **Схематические планы этажей** — реально отрисовываемые планы,
///     посчитанные [FloorPlanGenerator] из технического задания. Сохраняются в
///     [Drawing.payload] как JSON-описание [FloorPlan].
///   * **Тексто-заглушки** для остальных листов (разрез, фасад, узел,
///     генплан) — они появятся как живые чертежи на следующих этапах.
class DrawingGenerator {
  static const _uuid = Uuid();

  static List<Drawing> generate({
    required HouseProject project,
    required UserMode mode,
  }) {
    final now = DateTime.now();
    final isClient = mode == UserMode.client;
    final drawings = <Drawing>[];

    // Генплан / привязка — текстовая заглушка.
    drawings.add(Drawing(
      id: _uuid.v4(),
      title: isClient ? 'Эскиз генплана' : 'Генплан и схема привязки',
      kind: isClient ? DrawingKind.sketch : DrawingKind.workingPlan,
      createdAt: now,
      payload: 'Регион: ${project.brief.region ?? 'не указан'}\n'
          'Снеговой район: ${project.brief.snowZone ?? '?'}\n'
          'Ветровой район: ${project.brief.windZone ?? '?'}',
    ));

    // План фундамента — текстовая заглушка с типом фундамента.
    if (project.foundation.isFilled) {
      drawings.add(Drawing(
        id: _uuid.v4(),
        title: 'План фундамента',
        kind: DrawingKind.workingPlan,
        createdAt: now,
        payload: 'Фундамент: ${project.foundation.summary}',
      ));
    }

    // Схематические планы этажей — отрисовываемые.
    final plans = FloorPlanGenerator.generate(project.brief);
    for (final plan in plans) {
      drawings.add(Drawing(
        id: _uuid.v4(),
        title: 'План: ${plan.floorLabel}',
        kind: DrawingKind.schematicPlan,
        createdAt: now,
        payload: plan.encode(),
      ));
    }

    // Кровля — заглушка.
    if (project.roof.isFilled) {
      drawings.add(Drawing(
        id: _uuid.v4(),
        title: isClient ? 'Эскиз кровли' : 'План кровли',
        kind: isClient ? DrawingKind.sketch : DrawingKind.workingPlan,
        createdAt: now,
        payload: 'Крыша: ${project.roof.summary}',
      ));
    }

    if (!isClient) {
      drawings.add(Drawing(
        id: _uuid.v4(),
        title: 'Разрез 1-1',
        kind: DrawingKind.workingSection,
        createdAt: now,
        payload: 'Поперечный разрез по основным несущим стенам.',
      ));
      drawings.add(Drawing(
        id: _uuid.v4(),
        title: 'Узел: опирание мауэрлата',
        kind: DrawingKind.workingDetail,
        createdAt: now,
        payload: 'Параметрический узел мауэрлат — стена.',
      ));
      drawings.add(Drawing(
        id: _uuid.v4(),
        title: 'Главный фасад',
        kind: DrawingKind.facade,
        createdAt: now,
        payload: 'Фронтальный фасад дома.',
      ));
    }

    return drawings;
  }
}
