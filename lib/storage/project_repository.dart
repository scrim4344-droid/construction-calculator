import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/house_project.dart';

/// Хранилище проектов на диске.
///
/// Используем [SharedPreferences] как универсальный ключ-значение бэкенд:
/// на вебе он пишет в localStorage, на десктопе — в файл, на мобильных —
/// в нативные настройки. Все проекты сериализуются в JSON и хранятся под
/// одним ключом — для текущих объёмов (десятки проектов) этого достаточно.
class ProjectRepository {
  static const _key = 'projects.v1';

  final SharedPreferences _prefs;

  ProjectRepository(this._prefs);

  static Future<ProjectRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ProjectRepository(prefs);
  }

  List<HouseProject> loadAll() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(HouseProject.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<HouseProject> projects) async {
    final encoded = jsonEncode(projects.map((p) => p.toJson()).toList());
    await _prefs.setString(_key, encoded);
  }
}
