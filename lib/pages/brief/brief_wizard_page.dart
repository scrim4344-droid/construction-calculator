import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/region_catalog.dart';
import '../../data/rooms_catalog.dart';
import '../../data/soil_types.dart';
import '../../data/wall_materials.dart';
import '../../models/client_brief.dart';
import '../../models/house_project.dart';
import '../../models/soil_layer.dart';
import '../../models/user_mode.dart';
import '../../state/app_state.dart';
import '../../widgets/hints.dart';

/// Многошаговый визард брифа клиента.
///
/// Шаги:
///   1) Регион (с автозаполнением снегового/ветрового района по СП 20.13330,
///      проектировщик может вручную переопределить значения);
///   2) Тип грунта;
///   3) Этажность + наличие мансарды/подвала;
///   4) Целевая площадь и пятно застройки;
///   5) Состав комнат (фиксированный список со счётчиками);
///   6) Дополнения (гараж/терраса/балкон/эркер/второй свет/лестница);
///   7) Желаемый материал стен;
///   8) Особые пожелания (свободный текст).
///
/// Бриф сохраняется в проект **после каждого шага**, поэтому даже если
/// пользователь закроет вкладку — прогресс не потеряется. По кнопке
/// «Завершить» состав сооружения автоматически подтягивается из движка
/// правил, а в режиме «Клиент» сразу же генерируется первая партия чертежей.
class BriefWizardPage extends StatefulWidget {
  const BriefWizardPage({super.key, required this.projectId});

  final String projectId;

  @override
  State<BriefWizardPage> createState() => _BriefWizardPageState();
}

class _BriefWizardPageState extends State<BriefWizardPage> {
  int _step = 0;
  static const int _stepsCount = 8;

  HouseProject? _findProject(AppState state) {
    for (final p in state.projects) {
      if (p.id == widget.projectId) return p;
    }
    return null;
  }

  Future<void> _save(BuildContext context, HouseProject project) async {
    await context.read<AppState>().saveProject(project);
  }

  Future<void> _finish(BuildContext context, HouseProject project) async {
    final state = context.read<AppState>();
    final mode = state.mode ?? UserMode.client;
    await state.saveProject(project);
    await state.applyAutoComposition(project);
    if (mode == UserMode.client) {
      await state.regenerateDrawings(project);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mode == UserMode.client
              ? 'Бриф сохранён · состав сооружения и эскизы подобраны автоматически'
              : 'Бриф сохранён · состав сооружения подобран. Можно редактировать.',
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final project = _findProject(state);
    if (project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Бриф клиента')),
        body: const Center(child: Text('Проект не найден.')),
      );
    }
    final brief = project.brief;
    final isLast = _step == _stepsCount - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('Бриф · шаг ${_step + 1} из $_stepsCount'),
        actions: const [
          HintIconButton(
            title: 'Бриф клиента',
            sections: Hints.briefWizard,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              LinearProgressIndicator(value: (_step + 1) / _stepsCount),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildStep(context, project, brief),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      OutlinedButton(
                        onPressed: _step == 0
                            ? null
                            : () => setState(() => _step--),
                        child: const Text('Назад'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () async {
                          await _save(context, project);
                          if (!context.mounted) return;
                          if (isLast) {
                            await _finish(context, project);
                          } else {
                            setState(() => _step++);
                          }
                        },
                        child: Text(isLast ? 'Завершить' : 'Далее'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(
    BuildContext context,
    HouseProject project,
    ClientBrief brief,
  ) {
    final mode = context.read<AppState>().mode ?? UserMode.client;
    switch (_step) {
      case 0:
        return _RegionStep(brief: brief, mode: mode, onChanged: () => setState(() {}));
      case 1:
        return _SoilStep(
          brief: brief,
          mode: mode,
          onChanged: () => setState(() {}),
        );
      case 2:
        return _FloorsStep(brief: brief, onChanged: () => setState(() {}));
      case 3:
        return _AreaStep(brief: brief, onChanged: () => setState(() {}));
      case 4:
        return _RoomsStep(brief: brief, onChanged: () => setState(() {}));
      case 5:
        return _AddonsStep(brief: brief, onChanged: () => setState(() {}));
      case 6:
        return _WallsStep(brief: brief, onChanged: () => setState(() {}));
      case 7:
        return _NotesStep(brief: brief, onChanged: () => setState(() {}));
    }
    return const SizedBox.shrink();
  }
}

// =====================================================================
// Шаг 1: регион
// =====================================================================

class _RegionStep extends StatelessWidget {
  const _RegionStep({
    required this.brief,
    required this.mode,
    required this.onChanged,
  });

  final ClientBrief brief;
  final UserMode mode;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final designer = mode == UserMode.designer;
    return ListView(
      children: [
        Text('Регион строительства', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Выберите город — снеговой и ветровой районы заполнятся '
          'автоматически по СП 20.13330.'
          '${designer ? ' Значения районов можно вручную поменять или ввести свой город.' : ''}',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Город',
            border: OutlineInputBorder(),
          ),
          isExpanded: true,
          value: kRegionCatalog.any((r) => r.city == brief.region)
              ? brief.region
              : null,
          items: [
            for (final r in kRegionCatalog)
              DropdownMenuItem(value: r.city, child: Text(r.city)),
            if (designer)
              const DropdownMenuItem(
                value: '__custom__',
                child: Text('Другой город…'),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            if (value == '__custom__') {
              brief.region = '';
              brief.snowZone = null;
              brief.windZone = null;
            } else {
              final r = kRegionCatalog.firstWhere((c) => c.city == value);
              brief.region = r.city;
              brief.snowZone = r.snowZone;
              brief.windZone = r.windZone;
            }
            onChanged();
          },
        ),
        if (designer && brief.region != null) ...[
          const SizedBox(height: 16),
          TextFormField(
            initialValue: brief.region,
            decoration: const InputDecoration(
              labelText: 'Название города',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              brief.region = value;
              onChanged();
            },
          ),
        ],
        if (brief.region != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Снеговой район',
                    border: OutlineInputBorder(),
                  ),
                  value: brief.snowZone,
                  items: [
                    for (final z in kSnowZones)
                      DropdownMenuItem(value: z, child: Text('$z')),
                  ],
                  onChanged: designer
                      ? (v) {
                          brief.snowZone = v;
                          onChanged();
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Ветровой район',
                    border: OutlineInputBorder(),
                  ),
                  value: brief.windZone,
                  items: [
                    for (final z in kWindZones)
                      DropdownMenuItem(value: z, child: Text(z)),
                  ],
                  onChanged: designer
                      ? (v) {
                          brief.windZone = v;
                          onChanged();
                        }
                      : null,
                ),
              ),
            ],
          ),
          if (!designer)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Значения районов проставлены автоматически и недоступны для '
                'правки в режиме клиента.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// =====================================================================
// Шаг 2: грунт
// =====================================================================

class _SoilStep extends StatelessWidget {
  const _SoilStep({
    required this.brief,
    required this.mode,
    required this.onChanged,
  });

  final ClientBrief brief;
  final UserMode mode;
  final VoidCallback onChanged;

  void _ensureAtLeastOneLayer() {
    if (brief.soilLayers.isEmpty) brief.soilLayers.add(SoilLayer());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _ensureAtLeastOneLayer();
    final isClient = mode == UserMode.client;
    return ListView(
      children: [
        Text('Грунты на участке', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          isClient
              ? 'Укажите тип грунта верхнего слоя. Если есть инженерно-геологический '
                  'отчёт — раскройте «Расширенные показатели» и введите значения.'
              : 'Опишите все слои инженерно-геологического разреза с физико-'
                  'механическими показателями (СП 22.13330, СП 47.13330).',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < brief.soilLayers.length; i++)
          _SoilLayerCard(
            key: ValueKey('layer-$i'),
            index: i,
            layer: brief.soilLayers[i],
            startExpanded: !isClient,
            canRemove: brief.soilLayers.length > 1,
            onChanged: onChanged,
            onRemove: () {
              brief.soilLayers.removeAt(i);
              onChanged();
            },
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            brief.soilLayers.add(SoilLayer());
            onChanged();
          },
          icon: const Icon(Icons.add),
          label: const Text('Добавить слой'),
        ),
      ],
    );
  }
}

class _SoilLayerCard extends StatefulWidget {
  const _SoilLayerCard({
    super.key,
    required this.index,
    required this.layer,
    required this.startExpanded,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final SoilLayer layer;
  final bool startExpanded;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  State<_SoilLayerCard> createState() => _SoilLayerCardState();
}

class _SoilLayerCardState extends State<_SoilLayerCard> {
  late bool _expanded = widget.startExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layer = widget.layer;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Слой №${widget.index + 1}',
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                if (widget.canRemove)
                  IconButton(
                    tooltip: 'Удалить слой',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: widget.onRemove,
                  ),
              ],
            ),
            DropdownButtonFormField<SoilType>(
              decoration: const InputDecoration(
                labelText: 'Тип грунта',
                border: OutlineInputBorder(),
              ),
              value: layer.type,
              items: [
                for (final t in SoilType.values)
                  DropdownMenuItem(value: t, child: Text(t.title)),
              ],
              onChanged: (v) {
                layer.type = v;
                widget.onChanged();
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _NumField(
                    label: 'Глубина кровли, м',
                    value: layer.topDepth,
                    onChanged: (v) {
                      layer.topDepth = v;
                      widget.onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _NumField(
                    label: 'Мощность, м',
                    value: layer.thickness,
                    onChanged: (v) {
                      layer.thickness = v;
                      widget.onChanged();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(_expanded
                        ? Icons.expand_less
                        : Icons.expand_more),
                    const SizedBox(width: 4),
                    Text(
                      _expanded
                          ? 'Скрыть расширенные показатели'
                          : 'Расширенные показатели (физика и механика)',
                      style: theme.textTheme.labelLarge,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              const _SectionLabel('Физические показатели'),
              _NumGrid([
                _NumDef(
                  label: 'ρ, г/см³',
                  value: layer.density,
                  set: (v) => layer.density = v,
                ),
                _NumDef(
                  label: 'ρₛ, г/см³',
                  value: layer.particleDensity,
                  set: (v) => layer.particleDensity = v,
                ),
                _NumDef(
                  label: 'W, %',
                  value: layer.naturalMoisture,
                  set: (v) => layer.naturalMoisture = v,
                ),
                _NumDef(
                  label: 'e (пористость)',
                  value: layer.voidRatio,
                  set: (v) => layer.voidRatio = v,
                ),
                _NumDef(
                  label: 'Wₗ, %',
                  value: layer.liquidLimit,
                  set: (v) => layer.liquidLimit = v,
                ),
                _NumDef(
                  label: 'Wₚ, %',
                  value: layer.plasticLimit,
                  set: (v) => layer.plasticLimit = v,
                ),
                _NumDef(
                  label: 'Iₚ',
                  value: layer.plasticityIndex,
                  set: (v) => layer.plasticityIndex = v,
                ),
                _NumDef(
                  label: 'Iₗ',
                  value: layer.liquidityIndex,
                  set: (v) => layer.liquidityIndex = v,
                ),
              ], onChanged: widget.onChanged),
              const _SectionLabel('Механические показатели'),
              _NumGrid([
                _NumDef(
                  label: 'E, МПа',
                  value: layer.deformationModulus,
                  set: (v) => layer.deformationModulus = v,
                ),
                _NumDef(
                  label: 'φ, °',
                  value: layer.frictionAngle,
                  set: (v) => layer.frictionAngle = v,
                ),
                _NumDef(
                  label: 'c, кПа',
                  value: layer.cohesion,
                  set: (v) => layer.cohesion = v,
                ),
              ], onChanged: widget.onChanged),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}

class _NumDef {
  final String label;
  final double? value;
  final void Function(double?) set;
  _NumDef({required this.label, required this.value, required this.set});
}

class _NumGrid extends StatelessWidget {
  const _NumGrid(this.defs, {required this.onChanged});
  final List<_NumDef> defs;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < defs.length; i += 2) {
      final a = defs[i];
      final b = i + 1 < defs.length ? defs[i + 1] : null;
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: _NumField(
                label: a.label,
                value: a.value,
                onChanged: (v) {
                  a.set(v);
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: b == null
                  ? const SizedBox.shrink()
                  : _NumField(
                      label: b.label,
                      value: b.value,
                      onChanged: (v) {
                        b.set(v);
                        onChanged();
                      },
                    ),
            ),
          ],
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

class _NumField extends StatefulWidget {
  const _NumField({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final double? value;
  final ValueChanged<double?> onChanged;
  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: _format(widget.value));
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  static String _format(double? v) {
    if (v == null) return '';
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toString();
  }

  double? _parse(String v) {
    final norm = v.replaceAll(',', '.').trim();
    if (norm.isEmpty) return null;
    return double.tryParse(norm);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _ctl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (v) => widget.onChanged(_parse(v)),
    );
  }
}

// =====================================================================
// Шаг 3: этажность
// =====================================================================

class _FloorsStep extends StatelessWidget {
  const _FloorsStep({required this.brief, required this.onChanged});

  final ClientBrief brief;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        Text('Этажность', style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('1 этаж')),
            ButtonSegment(value: 2, label: Text('2 этажа')),
            ButtonSegment(value: 3, label: Text('3 этажа')),
          ],
          selected: brief.floors == null ? <int>{} : {brief.floors!},
          emptySelectionAllowed: true,
          onSelectionChanged: (set) {
            brief.floors = set.isEmpty ? null : set.first;
            onChanged();
          },
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          title: const Text('Мансарда'),
          subtitle: const Text('Жилое пространство под скатной крышей'),
          value: brief.hasMansard ?? false,
          onChanged: (v) {
            brief.hasMansard = v;
            onChanged();
          },
        ),
        SwitchListTile(
          title: const Text('Подвал / цокольный этаж'),
          value: brief.hasBasement ?? false,
          onChanged: (v) {
            brief.hasBasement = v;
            onChanged();
          },
        ),
      ],
    );
  }
}

// =====================================================================
// Шаг 4: площадь и пятно застройки
// =====================================================================

class _AreaStep extends StatefulWidget {
  const _AreaStep({required this.brief, required this.onChanged});

  final ClientBrief brief;
  final VoidCallback onChanged;

  @override
  State<_AreaStep> createState() => _AreaStepState();
}

class _AreaStepState extends State<_AreaStep> {
  late final TextEditingController _area;
  late final TextEditingController _width;
  late final TextEditingController _length;

  @override
  void initState() {
    super.initState();
    _area = TextEditingController(
      text: widget.brief.targetArea?.toStringAsFixed(0) ?? '',
    );
    _width = TextEditingController(
      text: widget.brief.footprintWidth?.toStringAsFixed(0) ?? '',
    );
    _length = TextEditingController(
      text: widget.brief.footprintLength?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _area.dispose();
    _width.dispose();
    _length.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const inputs = TextInputType.numberWithOptions(decimal: true);
    final formatters = [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
    ];
    return ListView(
      children: [
        Text('Площадь и габариты', style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        TextFormField(
          controller: _area,
          keyboardType: inputs,
          inputFormatters: formatters,
          decoration: const InputDecoration(
            labelText: 'Целевая общая площадь, м²',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            widget.brief.targetArea = _parse(v);
            widget.onChanged();
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _width,
                keyboardType: inputs,
                inputFormatters: formatters,
                decoration: const InputDecoration(
                  labelText: 'Ширина, м',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  widget.brief.footprintWidth = _parse(v);
                  widget.onChanged();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _length,
                keyboardType: inputs,
                inputFormatters: formatters,
                decoration: const InputDecoration(
                  labelText: 'Длина, м',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  widget.brief.footprintLength = _parse(v);
                  widget.onChanged();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Пятно застройки — габариты «коробки» дома по внешним стенам, '
          'без террасы и крыльца.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  double? _parse(String v) {
    final norm = v.replaceAll(',', '.').trim();
    if (norm.isEmpty) return null;
    return double.tryParse(norm);
  }
}

// =====================================================================
// Шаг 5: состав комнат
// =====================================================================

class _RoomsStep extends StatelessWidget {
  const _RoomsStep({required this.brief, required this.onChanged});

  final ClientBrief brief;
  final VoidCallback onChanged;

  int _count(RoomKind k) => brief.rooms[k.name] ?? 0;
  void _set(RoomKind k, int v) {
    if (v <= 0) {
      brief.rooms.remove(k.name);
    } else {
      brief.rooms[k.name] = v;
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        Text('Состав помещений', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Укажите желаемое количество помещений каждого типа.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        for (final k in RoomKind.values)
          ListTile(
            title: Text(k.title),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _count(k) <= 0
                      ? null
                      : () => _set(k, _count(k) - 1),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${_count(k)}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _set(k, _count(k) + 1),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// =====================================================================
// Шаг 6: дополнения
// =====================================================================

class _AddonsStep extends StatelessWidget {
  const _AddonsStep({required this.brief, required this.onChanged});

  final ClientBrief brief;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        Text('Дополнения', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Отметьте всё, что нужно учесть в проекте.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Гараж'),
          value: brief.hasGarage ?? false,
          onChanged: (v) {
            brief.hasGarage = v;
            onChanged();
          },
        ),
        SwitchListTile(
          title: const Text('Терраса'),
          value: brief.hasTerrace ?? false,
          onChanged: (v) {
            brief.hasTerrace = v;
            onChanged();
          },
        ),
        SwitchListTile(
          title: const Text('Балкон'),
          value: brief.hasBalcony ?? false,
          onChanged: (v) {
            brief.hasBalcony = v;
            onChanged();
          },
        ),
        SwitchListTile(
          title: const Text('Эркер'),
          value: brief.hasOriel ?? false,
          onChanged: (v) {
            brief.hasOriel = v;
            onChanged();
          },
        ),
        SwitchListTile(
          title: const Text('Второй свет'),
          subtitle: const Text(
            'Помещение высотой в два этажа без перекрытия',
          ),
          value: brief.hasDoubleHeight ?? false,
          onChanged: (v) {
            brief.hasDoubleHeight = v;
            onChanged();
          },
        ),
        SwitchListTile(
          title: const Text('Лестница'),
          subtitle: const Text(
            'Появится автоматически при этажности > 1, мансарде или подвале',
          ),
          value: brief.hasStaircase ?? false,
          onChanged: (v) {
            brief.hasStaircase = v;
            onChanged();
          },
        ),
      ],
    );
  }
}

// =====================================================================
// Шаг 7: материал стен
// =====================================================================

class _WallsStep extends StatelessWidget {
  const _WallsStep({required this.brief, required this.onChanged});

  final ClientBrief brief;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        Text('Желаемый материал стен', style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        for (final m in WallMaterial.values)
          RadioListTile<WallMaterial>(
            value: m,
            groupValue: brief.wallMaterial,
            title: Text(m.title),
            onChanged: (v) {
              brief.wallMaterial = v;
              onChanged();
            },
          ),
      ],
    );
  }
}

// =====================================================================
// Шаг 8: особые пожелания
// =====================================================================

class _NotesStep extends StatefulWidget {
  const _NotesStep({required this.brief, required this.onChanged});

  final ClientBrief brief;
  final VoidCallback onChanged;

  @override
  State<_NotesStep> createState() => _NotesStepState();
}

class _NotesStepState extends State<_NotesStep> {
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: widget.brief.specialRequirements);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        Text('Особые пожелания', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Опишите всё, что не уместилось в предыдущие шаги: пожелания по '
          'планировке, инженерным системам, отделке, особенностям участка.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _ctl,
          minLines: 6,
          maxLines: 12,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Например: широкие окна на южную сторону, '
                'отдельный вход для гостевой спальни…',
          ),
          onChanged: (v) {
            widget.brief.specialRequirements = v;
            widget.onChanged();
          },
        ),
      ],
    );
  }
}
