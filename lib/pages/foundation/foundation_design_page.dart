import 'package:cc_engine/cc_engine.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/client_brief.dart';
import '../../models/house_project.dart';
import '../../models/soil_layer.dart';
import '../../services/file_download.dart';
import '../../services/foundation_explanation_pdf.dart';
import '../../state/app_state.dart';
import '../../widgets/calc_steps_card.dart';
import '../../widgets/hints.dart';

/// Шаг 2 эталонного модуля «Фундамент»: подбор сечения ленточного
/// фундамента и базового армирования.
///
/// Использует [StripFootingDesigner] из `cc_engine`. Все шаги расчёта
/// видны на странице с пометкой «откуда взялось». При завершении
/// будущей работы это уйдёт в ПЗ (шаг 3) и в DXF (шаг 4).
class FoundationDesignPage extends StatelessWidget {
  const FoundationDesignPage({
    super.key,
    required this.projectId,
    required this.loads,
  });

  final String projectId;
  final FoundationLoadsResult loads;

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
        appBar: AppBar(title: const Text('Сечение фундамента')),
        body: const Center(child: Text('Проект не найден.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Подбор сечения фундамента'),
        actions: const [
          HintIconButton(
            title: 'Подбор сечения',
            sections: Hints.foundationDesign,
          ),
        ],
      ),
      body: HintAutoShow(
        screenKey: 'foundation-design',
        title: 'Подбор сечения',
        sections: Hints.foundationDesign,
        child: _DesignContent(
          project: project,
          loads: loads,
        ),
      ),
    );
  }
}

class _DesignContent extends StatelessWidget {
  const _DesignContent({
    required this.project,
    required this.loads,
  });

  final HouseProject project;
  final FoundationLoadsResult loads;

  double get totalLoadKnPerM2 => loads.totalVerticalKnPerM2;

  @override
  Widget build(BuildContext context) {
    final brief = project.brief;
    final missing = _missing(brief);
    if (missing.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 48),
              const SizedBox(height: 12),
              Text(
                'Чтобы подобрать сечение фундамента, заполните бриф:',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(missing.map((f) => '• $f').join('\n')),
            ],
          ),
        ),
      );
    }

    final soil = _soilFromBrief(brief.soilLayers);
    final footprintArea =
        (brief.footprintWidth ?? 8.0) * (brief.footprintLength ?? 10.0);
    final perimeter = 2 *
        ((brief.footprintWidth ?? 8.0) + (brief.footprintLength ?? 10.0));
    // Грубо учитываем 1 поперечную несущую стену.
    final wallsLength = perimeter + (brief.footprintWidth ?? 8.0);
    final freezing = _freezingDepthForRegion(brief.region);

    final design = StripFootingDesigner.design(
      verticalLoadKnPerM2: totalLoadKnPerM2,
      footprintAreaM2: footprintArea,
      loadBearingWallsPerimeterM: wallsLength,
      soilType: soil,
      freezingDepthM: freezing,
      loadOrigin:
          'Из расчёта нагрузок на предыдущей странице '
          '(q = g·n + p·n + S по СП 20.13330)',
      footprintOrigin:
          'Из брифа: «${brief.footprintWidth} × ${brief.footprintLength} м» '
          '⇒ A = ${footprintArea.toStringAsFixed(1)} м²',
      wallsOrigin:
          'Из брифа: периметр ${perimeter.toStringAsFixed(1)} м '
          '+ 1 поперечная несущая стена ${brief.footprintWidth} м '
          '⇒ L = ${wallsLength.toStringAsFixed(1)} м (упрощённо)',
      soilOrigin:
          'Из брифа, шаг «Грунты»: верхний слой — '
          '${brief.soilLayers.isNotEmpty ? (brief.soilLayers.first.type?.title ?? "не задано") : "не задано"}',
      freezingOrigin:
          'СП 131.13330 для региона «${brief.region ?? "—"}»: '
          'df = ${freezing.toStringAsFixed(1)} м',
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InputDataCard(
          totalLoad: totalLoadKnPerM2,
          footprintArea: footprintArea,
          wallsLength: wallsLength,
          soil: soil,
          freezing: freezing,
          brief: brief,
        ),
        const SizedBox(height: 16),
        CalcStepsCard(
          title: 'Сопротивление грунта и подбор подошвы',
          icon: Icons.layers_outlined,
          steps: design.steps.take(7).toList(), // soil + A + L + N + b
        ),
        const SizedBox(height: 16),
        CalcStepsCard(
          title: 'Глубина заложения и геометрия ленты',
          icon: Icons.height_outlined,
          steps: design.steps.skip(7).take(2).toList(),
        ),
        const SizedBox(height: 16),
        CalcStepsCard(
          title: 'Армирование и бетон',
          icon: Icons.grid_4x4_outlined,
          steps: design.steps.skip(9).toList(),
        ),
        const SizedBox(height: 24),
        _ResultCard(design: design),
        const SizedBox(height: 16),
        _DownloadExplanationButton(
          project: project,
          loads: loads,
          design: design,
          inputDataRows: {
            'Объект': project.name,
            'Регион': brief.region ?? '—',
            'Этажность': '${brief.floors ?? "—"} эт.',
            'Габариты пятна':
                '${brief.footprintWidth} × ${brief.footprintLength} м',
            'Площадь застройки A': '${footprintArea.toStringAsFixed(1)} м²',
            'Длина несущих стен L':
                '${wallsLength.toStringAsFixed(1)} м',
            'Грунт основания': soil.title,
            'R0 грунта': '${soil.r0KPa} кПа',
            'Глубина промерзания df':
                '${freezing.toStringAsFixed(1)} м (СП 131.13330)',
            'Снеговой район':
                'Из брифа → ${SnowRegion.byId(brief.snowZone ?? 3).title}',
            'Ветровой район':
                'Из брифа → район ${brief.windZone ?? 2}',
          },
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  static List<String> _missing(ClientBrief b) {
    final m = <String>[];
    if (b.footprintWidth == null || b.footprintLength == null) {
      m.add('габариты пятна застройки (ширина и длина)');
    }
    return m;
  }

  /// Маппинг между типом грунта в брифе (SoilType) и FoundationSoilType
  /// в cc_engine. Сейчас в брифе типы упрощённые («песок», «глина», …).
  /// Этот конвертер достанет верхний слой и подберёт ближайший аналог.
  static FoundationSoilType _soilFromBrief(List<SoilLayer> layers) {
    if (layers.isEmpty || layers.first.type == null) {
      return FoundationSoilType.loamStiff; // безопасное допущение
    }
    final name = layers.first.type!.name.toLowerCase();
    if (name.contains('gravel')) return FoundationSoilType.sandGravel;
    if (name.contains('coarse')) return FoundationSoilType.sandCoarse;
    if (name.contains('sand') && name.contains('fine')) {
      return FoundationSoilType.sandFine;
    }
    if (name.contains('sand')) return FoundationSoilType.sandMedium;
    if (name.contains('sandyloam') || name.contains('sandy_loam')) {
      return FoundationSoilType.sandyLoamHard;
    }
    if (name.contains('clay') && name.contains('hard')) {
      return FoundationSoilType.clayHard;
    }
    if (name.contains('clay') && name.contains('soft')) {
      return FoundationSoilType.claySoft;
    }
    if (name.contains('clay')) return FoundationSoilType.clayStiff;
    if (name.contains('loam') && name.contains('soft')) {
      return FoundationSoilType.loamSoft;
    }
    if (name.contains('loam')) return FoundationSoilType.loamStiff;
    return FoundationSoilType.loamStiff;
  }

  /// Грубая оценка нормативной глубины промерзания по региону. Для
  /// итогового проекта берётся из СП 131.13330 (карта 1) — здесь
  /// упрощённо.
  static double _freezingDepthForRegion(String? region) {
    if (region == null) return 1.4;
    final r = region.toLowerCase();
    if (r.contains('мурманск') ||
        r.contains('архангельск') ||
        r.contains('сургут')) return 2.0;
    if (r.contains('новосибирск') ||
        r.contains('екатеринбург') ||
        r.contains('пермь') ||
        r.contains('омск') ||
        r.contains('тюмень')) return 1.8;
    if (r.contains('москва') ||
        r.contains('казань') ||
        r.contains('челябинск') ||
        r.contains('самара')) return 1.4;
    if (r.contains('ростов') ||
        r.contains('волгоград') ||
        r.contains('краснодар') ||
        r.contains('сочи')) return 0.8;
    return 1.4;
  }
}

class _InputDataCard extends StatelessWidget {
  const _InputDataCard({
    required this.totalLoad,
    required this.footprintArea,
    required this.wallsLength,
    required this.soil,
    required this.freezing,
    required this.brief,
  });

  final double totalLoad;
  final double footprintArea;
  final double wallsLength;
  final FoundationSoilType soil;
  final double freezing;
  final ClientBrief brief;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment_outlined),
                const SizedBox(width: 12),
                Text('Исходные данные',
                    style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            _row('Нагрузка на фундамент q',
                '${totalLoad.toStringAsFixed(2)} кН/м²'),
            _row(
                'Габариты пятна',
                '${brief.footprintWidth} × ${brief.footprintLength} м '
                    '⇒ A = ${footprintArea.toStringAsFixed(1)} м²'),
            _row(
                'Длина несущих стен L',
                '${wallsLength.toStringAsFixed(1)} м '
                    '(периметр + 1 поперечная)'),
            _row('Грунт основания', soil.title),
            _row('R0 грунта', '${soil.r0KPa} кПа'),
            _row(
                'Глубина промерзания df',
                '${freezing.toStringAsFixed(1)} м '
                    '(СП 131.13330 для «${brief.region ?? "—"}»)'),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 200, child: Text(label)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.design});
  final StripFootingDesign design;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.architecture_outlined),
                const SizedBox(width: 12),
                Text('Подобранное сечение',
                    style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            _row('Ширина подошвы b',
                '${design.widthM.toStringAsFixed(2)} м'),
            _row('Высота ленты h',
                '${design.heightM.toStringAsFixed(2)} м'),
            _row('Глубина заложения d',
                '${design.depthM.toStringAsFixed(2)} м'),
            const Divider(height: 24),
            _row('Бетон', design.concreteClass.title),
            _row(
                'Продольная арматура',
                '${design.longitudinalCount}⌀${design.longitudinalDiameterMm} '
                    '${design.longitudinalClass.title}'),
            _row(
                'Поперечная арматура',
                '⌀${design.stirrupDiameterMm} '
                    '${design.stirrupClass.title}, '
                    'шаг ${design.stirrupSpacingMm} мм'),
            const SizedBox(height: 12),
            Text(
              'Дальше: пояснительная записка ПЗ → DXF узла → '
              'строка ВОР (бетон м³, арматура кг). '
              'Появятся в следующих итерациях.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 200, child: Text(label)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

class _DownloadExplanationButton extends StatefulWidget {
  const _DownloadExplanationButton({
    required this.project,
    required this.loads,
    required this.design,
    required this.inputDataRows,
  });

  final HouseProject project;
  final FoundationLoadsResult loads;
  final StripFootingDesign design;
  final Map<String, String> inputDataRows;

  @override
  State<_DownloadExplanationButton> createState() =>
      _DownloadExplanationButtonState();
}

class _DownloadExplanationButtonState
    extends State<_DownloadExplanationButton> {
  bool _busy = false;

  Future<void> _download() async {
    setState(() => _busy = true);
    try {
      final bytes = await FoundationExplanationPdf.build(
        project: widget.project,
        loads: widget.loads,
        design: widget.design,
        inputDataRows: widget.inputDataRows,
      );
      await FileDownload.downloadBytes(
        bytes: bytes,
        filename:
            'ПЗ_фундамент_${widget.project.name.replaceAll(" ", "_")}.pdf',
        mimeType: 'application/pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сгенерировать ПЗ: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onPressed: _busy ? null : _download,
      icon: _busy
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.picture_as_pdf_outlined),
      label: Text(_busy
          ? 'Готовим ПЗ…'
          : 'Скачать пояснительную записку (PDF)'),
    );
  }
}
