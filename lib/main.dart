import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/home_page.dart';
import 'pages/mode_selection_page.dart';
import 'state/app_state.dart';
import 'storage/project_repository.dart';
import 'storage/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsRepository.create();
  final projects = await ProjectRepository.create();
  final state = AppState(
    settingsRepository: settings,
    projectRepository: projects,
  );
  runApp(ConstructionCalculatorApp(state: state));
}

class ConstructionCalculatorApp extends StatelessWidget {
  const ConstructionCalculatorApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        title: 'Калькулятор проектировщика',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const _Root(),
      ),
    );
  }
}

/// Корневой виджет: показывает выбор режима при первом запуске,
/// в остальных случаях — главный экран со списком проектов.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final hasMode = context.select<AppState, bool>((s) => s.hasMode);
    return hasMode ? const HomePage() : const ModeSelectionPage();
  }
}
