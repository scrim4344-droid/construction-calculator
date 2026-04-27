import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

/// Страница настроек.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.lightbulb_outline),
            title: const Text('Показывать обучающие подсказки'),
            subtitle: const Text(
              'Авто-диалог с подсказкой при первом открытии каждого экрана '
              'в текущей сессии. Иконка «?» в углу остаётся доступной всегда.',
            ),
            isThreeLine: true,
            value: state.hintsEnabled,
            onChanged: (v) => state.setHintsEnabled(v),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('О приложении'),
            subtitle: Text(
              'Калькулятор проектировщика · версия 0.1.0\n'
              'Локальное хранение проектов на устройстве.',
            ),
            isThreeLine: true,
          ),
        ],
      ),
    );
  }
}
