import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:construction_calculator/storage/project_repository.dart';

/// Тесты на миграцию схемы хранения проектов.
///
/// Главная цель — гарантировать, что новый код **не теряет** проекты,
/// созданные старой версией приложения (где формат хранения был просто
/// массив без обёртки `schema_version`). Это блокер для облака и для
/// любого расширения [HouseProject].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('v1 → v2: проект из массива поднимается до обёртки и читается', () async {
    final v1Raw = jsonEncode([
      {
        'id': 'p1',
        'name': 'Старый проект',
        'constructionType': 'privateHouse',
        'createdAt': DateTime(2024, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2024, 1, 2).toIso8601String(),
        // Минимально валидный набор. Остальные поля HouseProject.fromJson
        // доберёт дефолтами через свои `?? ...`.
      },
    ]);

    SharedPreferences.setMockInitialValues({'projects.v1': v1Raw});
    final repo = await ProjectRepository.create();

    final loaded = repo.loadAll();
    expect(loaded, hasLength(1));
    expect(loaded.first.id, 'p1');
    expect(loaded.first.name, 'Старый проект');
  });

  test('v1 → v2: после чтения формат на диске пересохраняется как v2',
      () async {
    final v1Raw = jsonEncode([
      {
        'id': 'p1',
        'name': 'Старый',
        'constructionType': 'privateHouse',
        'createdAt': DateTime(2024, 1, 1).toIso8601String(),
        'updatedAt': DateTime(2024, 1, 2).toIso8601String(),
      },
    ]);
    SharedPreferences.setMockInitialValues({'projects.v1': v1Raw});

    final repo = await ProjectRepository.create();
    repo.loadAll();
    // Дать `saveAll` (запущенному без await в loadAll) выполниться.
    await Future<void>.delayed(Duration.zero);

    final prefs = await SharedPreferences.getInstance();
    final stored = jsonDecode(prefs.getString('projects.v1')!);
    expect(stored, isA<Map<String, dynamic>>());
    expect((stored as Map)['schema_version'],
        ProjectRepository.currentSchemaVersion);
    expect(stored['projects'], isA<List>());
  });

  test('пустой/отсутствующий ключ — пустой список, без падений', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = await ProjectRepository.create();
    expect(repo.loadAll(), isEmpty);
  });

  test('битый JSON — пустой список, без падений', () async {
    SharedPreferences.setMockInitialValues({'projects.v1': '<<not json>>'});
    final repo = await ProjectRepository.create();
    expect(repo.loadAll(), isEmpty);
  });

  test('один битый проект не валит остальные', () async {
    final raw = jsonEncode({
      'schema_version': 2,
      'projects': [
        {
          'id': 'good',
          'name': 'Нормальный',
          'constructionType': 'privateHouse',
          'createdAt': DateTime(2024, 1, 1).toIso8601String(),
          'updatedAt': DateTime(2024, 1, 1).toIso8601String(),
        },
        {'id': 'broken'}, // нет обязательных полей — fromJson упадёт
      ],
    });
    SharedPreferences.setMockInitialValues({'projects.v1': raw});

    final repo = await ProjectRepository.create();
    final loaded = repo.loadAll();
    expect(loaded, hasLength(1));
    expect(loaded.first.id, 'good');
  });
}
