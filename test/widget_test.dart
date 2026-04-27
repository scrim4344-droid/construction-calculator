// Базовые smoke-тесты на верхнем уровне приложения.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:construction_calculator/main.dart';
import 'package:construction_calculator/models/user_mode.dart';
import 'package:construction_calculator/state/app_state.dart';
import 'package:construction_calculator/storage/project_repository.dart';
import 'package:construction_calculator/storage/settings_repository.dart';

Future<AppState> _createState({
  Map<String, Object> initialValues = const {},
}) async {
  SharedPreferences.setMockInitialValues(
    {'hints_enabled': false, ...initialValues},
  );
  final settings = await SettingsRepository.create();
  final projects = await ProjectRepository.create();
  return AppState(settingsRepository: settings, projectRepository: projects);
}

Future<void> _setupWideScreen(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1280, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  testWidgets('Home page shows brand and types of construction',
      (WidgetTester tester) async {
    await _setupWideScreen(tester);
    final state = await _createState();
    await tester.pumpWidget(ConstructionCalculatorApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('КОНСТРУКТОР'), findsOneWidget);
    expect(find.text('Что вы хотите спроектировать?'), findsOneWidget);
    expect(find.text('Частный дом'), findsOneWidget);
    expect(find.text('Многоквартирный дом'), findsOneWidget);
  });

  testWidgets('Landing has 6-step instruction', (WidgetTester tester) async {
    await _setupWideScreen(tester);
    final state = await _createState();
    await tester.pumpWidget(ConstructionCalculatorApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('Инструкция из 6 шагов'), findsOneWidget);
  });

  test('AppState defaults mode to designer when nothing is stored', () async {
    final state = await _createState();
    expect(state.mode, UserMode.designer);
    expect(state.hasMode, isTrue);
  });
}
