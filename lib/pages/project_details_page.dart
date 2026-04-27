import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/house_project.dart';
import '../state/app_state.dart';
import '../widgets/hints.dart';
import 'brief_page.dart';
import 'composition_page.dart';
import 'drawings_page.dart';

/// Главный экран проекта.
///
/// Показывает три карточки верхнего уровня: техническое задание клиента, состав
/// сооружения и чертежи. Состав сооружения — это уже отдельный экран,
/// внутри которого живут конструктивные элементы (фундамент, стены, крыша,
/// лестница и т. д., в зависимости от технического задания).
class ProjectDetailsPage extends StatelessWidget {
  const ProjectDetailsPage({super.key, required this.projectId});

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
    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Проект')),
        body: const Center(child: Text('Проект не найден.')),
      );
    }

    final theme = Theme.of(context);
    final compositionFilled = project.foundation.isFilled ||
        project.walls.isFilled ||
        project.roof.isFilled ||
        project.staircase.isFilled;

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: const [
          HintIconButton(
            title: 'Структура проекта',
            sections: Hints.projectDetails,
          ),
        ],
      ),
      body: HintAutoShow(
        screenKey: 'project-details',
        title: 'Структура проекта',
        sections: Hints.projectDetails,
        child: Center(
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
                          project.constructionType.title,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Заполните разделы по очереди — каждый раздел можно '
                          'править в любой момент.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Техническое задание клиента',
                  subtitle: project.brief.summary,
                  done: project.brief.isStarted,
                  icon: Icons.assignment_outlined,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BriefPage(projectId: project.id),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _SectionCard(
                  title: 'Состав сооружения',
                  subtitle: _compositionSubtitle(project),
                  done: compositionFilled,
                  icon: Icons.account_tree_outlined,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CompositionPage(projectId: project.id),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _SectionCard(
                  title: 'Чертежи',
                  subtitle: project.drawings.summary,
                  done: !project.drawings.isEmpty,
                  icon: Icons.draw_outlined,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DrawingsPage(projectId: project.id),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _compositionSubtitle(HouseProject project) {
    final parts = <String>[];
    if (project.foundation.isFilled) parts.add('Фундамент');
    if (project.walls.isFilled) parts.add('Стены');
    if (project.roof.isFilled) parts.add('Крыша');
    if (project.includesStaircase && project.staircase.isFilled) {
      parts.add('Лестница');
    }
    if (parts.isEmpty) return 'Не заполнено';
    return parts.join(' · ');
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.done,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool done;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(subtitle),
        trailing: Icon(
          done ? Icons.check_circle : Icons.chevron_right,
          color: done ? theme.colorScheme.primary : null,
        ),
        onTap: onTap,
      ),
    );
  }
}
