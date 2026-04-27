import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/construction_type.dart';
import '../state/app_state.dart';
import '../widgets/hints.dart';

/// Экран создания нового проекта. Спрашиваем название и тип конструкции.
/// Возвращает созданный проект через `Navigator.pop(context, project)`.
class ProjectCreatePage extends StatefulWidget {
  const ProjectCreatePage({super.key});

  @override
  State<ProjectCreatePage> createState() => _ProjectCreatePageState();
}

class _ProjectCreatePageState extends State<ProjectCreatePage> {
  final _name = TextEditingController(text: 'Дом клиента');
  ConstructionType _type = ConstructionType.privateHouse;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final state = context.read<AppState>();
    final project = await state.createProject(name: name, type: _type);
    if (!mounted) return;
    Navigator.pop(context, project);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новый проект'),
        actions: const [
          HintIconButton(
            title: 'Новый проект',
            sections: Hints.projectCreate,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              Text('Название проекта', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Например: «Дом для семьи Ивановых»',
                ),
              ),
              const SizedBox(height: 24),
              Text('Тип конструкции', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final type in ConstructionType.values)
                RadioListTile<ConstructionType>(
                  value: type,
                  groupValue: _type,
                  onChanged: type.isImplemented
                      ? (v) => setState(() => _type = v ?? _type)
                      : null,
                  title: Row(
                    children: [
                      Expanded(child: Text(type.title)),
                      if (!type.isImplemented)
                        Text(
                          'скоро',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _saving ? null : _create,
                child: const Text('Создать проект'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
