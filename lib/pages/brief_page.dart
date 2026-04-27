import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/client_brief.dart';
import '../models/house_project.dart';
import '../models/user_mode.dart';
import '../state/app_state.dart';
import 'brief/brief_wizard_page.dart';

/// Стартовая страница раздела «Бриф клиента» — показывает текущую сводку
/// брифа и кнопку запуска визарда (или «продолжить заполнять»).
///
/// В режиме «Клиент» подчёркиваем, что после прохождения визарда
/// приложение само подтянет состав сооружения и сгенерирует эскизы.
class BriefPage extends StatelessWidget {
  const BriefPage({super.key, required this.projectId});

  final String projectId;

  HouseProject? _findProject(AppState state) {
    for (final p in state.projects) {
      if (p.id == projectId) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final project = _findProject(state);
    final mode = state.mode ?? UserMode.client;
    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Бриф клиента')),
        body: const Center(child: Text('Проект не найден.')),
      );
    }

    final theme = Theme.of(context);
    final brief = project.brief;
    final started = brief.isStarted;
    final complete = brief.isComplete;

    return Scaffold(
      appBar: AppBar(title: const Text('Бриф клиента')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        complete
                            ? 'Бриф заполнен'
                            : started
                                ? 'Бриф заполняется'
                                : 'Бриф ещё не заполнен',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(brief.summary),
                      const SizedBox(height: 8),
                      Text(
                        mode == UserMode.client
                            ? 'После прохождения визарда приложение автоматически '
                                'подберёт состав сооружения и сгенерирует эскизы.'
                            : 'После прохождения визарда состав сооружения '
                                'подтянется автоматически. Вы сможете править '
                                'элементы и перегенерировать чертежи.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BriefWizardPage(projectId: project.id),
                  ),
                ),
                icon: Icon(started
                    ? Icons.edit_outlined
                    : Icons.play_arrow_outlined),
                label: Text(
                  started ? 'Продолжить заполнение' : 'Начать заполнение',
                ),
              ),
              if (complete) ...[
                const SizedBox(height: 8),
                Text(
                  _detailsSummary(brief),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _detailsSummary(ClientBrief brief) {
    final parts = <String>[];
    if (brief.region != null) {
      parts.add(
        'Регион: ${brief.region} '
        '(снег ${brief.snowZone ?? '?'}, ветер ${brief.windZone ?? '?'})',
      );
    }
    final filledLayers = brief.soilLayers.where((l) => !l.isEmpty).length;
    if (filledLayers > 0) {
      parts.add('Грунты: $filledLayers сл. '
          '(${brief.soilType?.title ?? '—'} наверху)');
    }
    if (brief.floors != null) parts.add('Этажей: ${brief.floors}');
    if (brief.targetArea != null) {
      parts.add('Площадь: ${brief.targetArea!.toStringAsFixed(0)} м²');
    }
    if (brief.wallMaterial != null) {
      parts.add('Стены: ${brief.wallMaterial!.title}');
    }
    return parts.join('\n');
  }
}
