import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/foundation.dart';
import '../../models/house_project.dart';
import '../../state/app_state.dart';
import '../../widgets/hints.dart';
import 'foundation_device_page.dart';

/// Шаг 1 раздела «Фундамент»: выбор типа фундамента.
///
/// Получает на вход идентификатор проекта; всё чтение/запись идёт через
/// [AppState], чтобы данные сохранялись в общем хранилище и автоматически
/// синхронизировались с другими экранами.
class FoundationTypePage extends StatelessWidget {
  const FoundationTypePage({super.key, required this.projectId});

  final String projectId;

  HouseProject? _findProject(AppState state) {
    for (final p in state.projects) {
      if (p.id == projectId) return p;
    }
    return null;
  }

  Future<void> _selectType(BuildContext context, FoundationType type) async {
    final state = context.read<AppState>();
    final project = _findProject(state);
    if (project == null) return;

    // Если пользователь поменял тип — сбрасываем подвыборы, иначе
    // оставляем как есть (пусть RadioListTile подхватит сохранённое).
    if (project.foundation.type != type) {
      project.foundation.type = type;
      project.foundation.device = null;
      project.foundation.grillageMaterial = null;
      await state.saveProject(project);
    }

    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoundationDevicePage(projectId: projectId),
      ),
    );

    // Возвращаемся на экран проекта, минуя выбор типа: пользователь уже
    // зафиксировал свой выбор на следующем шаге.
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final project = _findProject(state);
    final selectedType = project?.foundation.type;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Тип фундамента'),
        actions: const [
          HintIconButton(
            title: 'Параметры фундамента',
            sections: Hints.foundationWizard,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Выберите тип фундамента',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              for (final type in FoundationType.values) ...[
                _FoundationTypeCard(
                  type: type,
                  selected: selectedType == type,
                  onTap: () => _selectType(context, type),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FoundationTypeCard extends StatelessWidget {
  const _FoundationTypeCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final FoundationType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(type.title, style: theme.textTheme.titleMedium),
        subtitle: Text(type.description),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
