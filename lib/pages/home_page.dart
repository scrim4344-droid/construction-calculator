import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/house_project.dart';
import '../models/user_mode.dart';
import '../state/app_state.dart';
import 'project_create_page.dart';
import 'project_details_page.dart';
import 'settings_page.dart';

/// Главный экран — список проектов пользователя.
///
/// На этом экране пользователь видит все ранее созданные проекты, может
/// открыть существующий, создать новый или удалить лишний. Также отсюда
/// доступны настройки (изменение режима).
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final mode = state.mode ?? UserMode.client;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Калькулятор проектировщика'),
        actions: [
          IconButton(
            tooltip: 'Настройки',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createProject(context),
        icon: const Icon(Icons.add),
        label: const Text('Новый проект'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: state.projects.isEmpty
              ? _EmptyState(mode: mode)
              : _ProjectList(projects: state.projects),
        ),
      ),
    );
  }

  Future<void> _createProject(BuildContext context) async {
    final state = context.read<AppState>();
    final project = await Navigator.push<HouseProject>(
      context,
      MaterialPageRoute(builder: (_) => const ProjectCreatePage()),
    );
    if (project == null) return;
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectDetailsPage(projectId: project.id),
      ),
    );
    // Поднимаем дату обновления, чтобы только что отредактированный проект
    // оказался на верху списка.
    await state.saveProject(project);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.mode});

  final UserMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.architecture_outlined,
            size: 96,
            color: theme.colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Пока нет проектов',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            mode == UserMode.client
                ? 'Создайте новый проект и заполните бриф — '
                    'приложение поможет подобрать решения для вашего дома.'
                : 'Создайте новый проект клиента и пройдитесь по разделам — '
                    'приложение соберёт исходные данные и выдаст расчёт и чертежи.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ProjectList extends StatelessWidget {
  const _ProjectList({required this.projects});

  final List<HouseProject> projects;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: projects.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _ProjectTile(project: projects[i]),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({required this.project});

  final HouseProject project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const Icon(Icons.home_work_outlined),
        title: Text(project.name, style: theme.textTheme.titleMedium),
        subtitle: Text(
          '${project.constructionType.title} · '
          'обновлён ${_formatDate(project.updatedAt)}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'rename':
                _rename(context);
                break;
              case 'delete':
                _delete(context);
                break;
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'rename', child: Text('Переименовать')),
            PopupMenuItem(value: 'delete', child: Text('Удалить')),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProjectDetailsPage(projectId: project.id),
          ),
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context) async {
    final state = context.read<AppState>();
    final controller = TextEditingController(text: project.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Переименовать проект'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Название'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await state.renameProject(project.id, name);
  }

  Future<void> _delete(BuildContext context) async {
    final state = context.read<AppState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить проект?'),
        content: Text(
          'Проект «${project.name}» будет удалён без возможности восстановления.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await state.deleteProject(project.id);
  }
}

String _formatDate(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}.${two(dt.month)}.${dt.year} '
      '${two(dt.hour)}:${two(dt.minute)}';
}
