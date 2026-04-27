import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/drawing.dart';
import '../models/floor_plan.dart';
import '../models/house_project.dart';
import '../models/user_mode.dart';
import '../services/dxf_writer.dart';
import '../services/file_download.dart';
import '../services/pdf_builder.dart';
import '../state/app_state.dart';
import '../widgets/floor_plan_view.dart';
import 'floor_plan_editor_page.dart';

/// Экран «Чертежи».
///
/// Показывает все чертежи проекта, отсортированные по дате создания
/// (новые сверху). Старые партии остаются доступными — их можно листать
/// ниже. Чертежи типа [DrawingKind.schematicPlan] отрисовываются как
/// планы с комнатами; остальные — текстовое описание-заглушка.
class DrawingsPage extends StatelessWidget {
  const DrawingsPage({super.key, required this.projectId});

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
    final theme = Theme.of(context);

    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Чертежи')),
        body: const Center(child: Text('Проект не найден.')),
      );
    }

    if (project.drawings.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Чертежи')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.draw_outlined,
                    size: 96,
                    color: theme.colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Чертежей пока нет',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Чертежи появятся здесь после прохождения этапа создания: '
                    'заполните бриф и состав сооружения, затем приложение '
                    'сгенерирует эскизы или рабочие чертежи в зависимости от '
                    'выбранного режима.',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final batches = _groupByBatch(project.drawings.drawings);
    final mode = state.mode ?? UserMode.client;
    final canEdit = mode == UserMode.designer;
    return Scaffold(
      appBar: AppBar(title: const Text('Чертежи')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: batches.length,
            itemBuilder: (context, i) {
              final batch = batches[i];
              return _BatchCard(
                index: batches.length - i,
                createdAt: batch.first.createdAt,
                drawings: batch,
                isLatest: i == 0,
                project: project,
                canEdit: canEdit,
              );
            },
          ),
        ),
      ),
    );
  }

  List<List<Drawing>> _groupByBatch(List<Drawing> drawings) {
    final batches = <List<Drawing>>[];
    for (final d in drawings) {
      if (batches.isEmpty ||
          batches.last.first.createdAt != d.createdAt) {
        batches.add([d]);
      } else {
        batches.last.add(d);
      }
    }
    return batches;
  }
}

class _BatchCard extends StatefulWidget {
  const _BatchCard({
    required this.index,
    required this.createdAt,
    required this.drawings,
    required this.isLatest,
    required this.project,
    required this.canEdit,
  });

  final int index;
  final DateTime createdAt;
  final List<Drawing> drawings;
  final bool isLatest;
  final HouseProject project;
  final bool canEdit;

  @override
  State<_BatchCard> createState() => _BatchCardState();
}

class _BatchCardState extends State<_BatchCard> {
  // Свежая версия развёрнута по умолчанию, старые свёрнуты.
  late bool _expanded = widget.isLatest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: widget.isLatest
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: widget.isLatest ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(12),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Версия №${widget.index}',
                              style: theme.textTheme.titleMedium,
                            ),
                            if (widget.isLatest)
                              Chip(
                                label: const Text('текущая'),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: theme
                                    .colorScheme.primaryContainer,
                              ),
                            if (widget.drawings.any((d) => d.isManualEdit))
                              Chip(
                                label: const Text('ручная правка'),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: theme
                                    .colorScheme.tertiaryContainer,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatDate(widget.createdAt)} · '
                          'листов: ${widget.drawings.length}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.isLatest)
                    IconButton(
                      tooltip: 'Скачать комплект (PDF/DXF)',
                      icon: const Icon(Icons.download_outlined),
                      onPressed: _showExportDialog,
                    ),
                  IconButton(
                    tooltip: _expanded ? 'Свернуть' : 'Развернуть',
                    icon: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                    ),
                    onPressed: () =>
                        setState(() => _expanded = !_expanded),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final d in widget.drawings)
                          _DrawingTile(
                            drawing: d,
                            project: widget.project,
                            canEdit: widget.canEdit && widget.isLatest,
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Future<void> _showExportDialog() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Скачать комплект'),
        content: const Text(
          'Выберите формат:\n'
          '• PDF — A3 ландшафт, по листу на этаж, с рамкой и штампом.\n'
          '• DXF — векторный обмен с CAD (AutoCAD, LibreCAD, QCAD).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Отмена'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop('dxf'),
            child: const Text('DXF'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('pdf'),
            child: const Text('PDF'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    try {
      if (choice == 'pdf') {
        await _exportPdf();
      } else if (choice == 'dxf') {
        await _exportDxf();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить файл: $e')),
      );
    }
  }

  Future<void> _exportPdf() async {
    final bytes = await PdfBuilder.buildBatch(
      project: widget.project,
      drawings: widget.drawings,
      versionNumber: widget.index,
    );
    final filename = _safeFileName(
      '${widget.project.name}_v${widget.index}',
      'pdf',
    );
    await FileDownload.downloadBytes(
      bytes: bytes,
      filename: filename,
      mimeType: 'application/pdf',
    );
  }

  Future<void> _exportDxf() async {
    // Если этажей > 1 — отдаём ZIP не реализуем здесь, выгрузим первый
    // схематический план, остальные пользователь может скачать отдельно
    // открыв старые версии. Чтобы не делать ZIP-зависимость, сгенерируем
    // несколько файлов друг за другом — браузер откроет столько диалогов
    // сохранения, сколько листов.
    var n = 0;
    for (final d in widget.drawings) {
      if (d.kind != DrawingKind.schematicPlan) continue;
      final plan = FloorPlan.tryDecode(d.payload);
      if (plan == null) continue;
      final dxf = DxfWriter.write(
        plan,
        title:
            '${widget.project.name} · ${plan.floorLabel} · v${widget.index}',
      );
      final filename = _safeFileName(
        '${widget.project.name}_v${widget.index}_${plan.floorLabel}',
        'dxf',
      );
      await FileDownload.downloadText(
        content: dxf,
        filename: filename,
        mimeType: 'application/dxf',
      );
      n++;
    }
    if (n == 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет схематических планов для DXF.')),
      );
    }
  }

  String _safeFileName(String base, String ext) {
    final cleaned = base
        .replaceAll(RegExp(r'[^\p{L}\p{N}_\-]+', unicode: true), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    return '$cleaned.$ext';
  }
}

class _DrawingTile extends StatelessWidget {
  const _DrawingTile({
    required this.drawing,
    required this.project,
    required this.canEdit,
  });

  final Drawing drawing;
  final HouseProject project;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (drawing.kind == DrawingKind.schematicPlan) {
      final plan = FloorPlan.tryDecode(drawing.payload);
      if (plan != null) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      drawing.title,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (canEdit)
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FloorPlanEditorPage(
                            project: project,
                            drawingId: drawing.id,
                            initialPlan: plan,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Редактировать'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                drawing.kind.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _FullscreenPlanPage(
                      title: drawing.title,
                      plan: plan,
                    ),
                  ),
                ),
                child: FloorPlanView(plan: plan),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Нажмите план, чтобы увеличить',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.description_outlined),
      title: Text(drawing.title),
      subtitle: Text(
        '${drawing.kind.title}'
        '${drawing.payload.isEmpty ? '' : '\n${drawing.payload}'}',
      ),
      isThreeLine: drawing.payload.isNotEmpty,
    );
  }
}

class _FullscreenPlanPage extends StatelessWidget {
  const _FullscreenPlanPage({required this.title, required this.plan});

  final String title;
  final FloorPlan plan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: FloorPlanView(plan: plan),
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(dt.day)}.${two(dt.month)}.${dt.year} '
      '${two(dt.hour)}:${two(dt.minute)}';
}
