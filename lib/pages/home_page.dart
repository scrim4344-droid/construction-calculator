import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/construction_type.dart';
import '../models/house_project.dart';
import '../services/link_opener.dart';
import '../state/app_state.dart';
import '../widgets/hints.dart';
import 'project_create_page.dart';
import 'project_details_page.dart';
import 'settings_page.dart';

const String _shareUrl =
    'https://scrim4344-droid.github.io/construction-calculator/';
const String _shareTitle =
    'Калькулятор проектировщика: расчёты и чертежи онлайн';
const String _shareText =
    'Создаём проект здания онлайн: бриф, состав, чертежи в PDF/DXF, '
    'расчёт фундамента по СП 20/22/63 с пояснительной запиской.';

const List<_LandingStep> _steps = [
  _LandingStep(
    icon: Icons.foundation_outlined,
    title: 'Выберите тип сооружения',
    description: 'Частный дом, многоквартирный, промышленное здание или '
        'металлоконструкции. Сейчас полностью реализован частный дом.',
  ),
  _LandingStep(
    icon: Icons.add_home_outlined,
    title: 'Создайте проект',
    description: 'Укажите название проекта. Все данные хранятся локально '
        'в браузере.',
  ),
  _LandingStep(
    icon: Icons.fact_check_outlined,
    title: 'Заполните бриф из 8 шагов',
    description: 'Участок, этажность, комнаты, материал стен, кровля, '
        'отделка, снеговой и ветровой район.',
  ),
  _LandingStep(
    icon: Icons.architecture_outlined,
    title: 'Получите состав сооружения',
    description: 'Приложение автоматически подбирает фундамент, стены, '
        'перекрытия, кровлю и лестницу по СП.',
  ),
  _LandingStep(
    icon: Icons.calculate_outlined,
    title: 'Сделайте расчёт фундамента',
    description: 'Снеговая и ветровая нагрузка, постоянная и полезная, '
        'подбор подошвы и армирования с раскрытием источников значений.',
  ),
  _LandingStep(
    icon: Icons.picture_as_pdf_outlined,
    title: 'Скачайте чертежи и ПЗ',
    description: 'План этажа в PDF/DXF (стены, двери, окна, лестница) и '
        'пояснительная записка к расчёту фундамента в PDF.',
  ),
];

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const _BrandTitle(),
        actions: [
          const HintIconButton(
            title: 'Главный экран',
            sections: Hints.home,
          ),
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
      body: const HintAutoShow(
        screenKey: 'home',
        title: 'Главный экран',
        sections: Hints.home,
        child: _LandingBody(),
      ),
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.home_work_outlined,
              color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          'КОНСТРУКТОР',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _LandingBody extends StatelessWidget {
  const _LandingBody();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final isWide = c.maxWidth >= 900;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Hero(),
                    const SizedBox(height: 16),
                    const _ShareRow(),
                    const SizedBox(height: 28),
                    const _Description(),
                    const SizedBox(height: 32),
                    Text(
                      'Что вы хотите спроектировать?',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Выберите тип сооружения — мы сразу откроем создание '
                      'проекта с этим типом.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    if (isWide)
                      const _TypesGrid()
                    else
                      const _TypesList(),
                    const SizedBox(height: 40),
                    Text(
                      'Инструкция из 6 шагов',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 16),
                    if (isWide)
                      const _StepsGrid()
                    else
                      const _StepsList(),
                    const SizedBox(height: 40),
                    const _ProjectsSection(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _shareTitle,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Бриф → состав → чертежи → расчёты → пояснительная записка. '
          'Без установки, прямо в браузере.',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Description extends StatelessWidget {
  const _Description();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'В этом приложении вы можете создать проект здания прямо '
            'в браузере. Заполнение брифа в первый раз занимает 10–15 минут. '
            'Программа подскажет состав сооружения, нарисует план этажа, '
            'рассчитает фундамент по действующим СП и сформирует '
            'пояснительную записку с подробным выводом всех значений и '
            'ссылками на пункты норм.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Чтобы начать — выберите тип сооружения ниже. Затем введёте '
            'название проекта и попадёте в бриф.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow();

  @override
  Widget build(BuildContext context) {
    final shareText =
        Uri.encodeComponent('$_shareTitle — $_shareText\n$_shareUrl');
    final url = Uri.encodeComponent(_shareUrl);
    final title = Uri.encodeComponent(_shareTitle);
    final shares = <_Share>[
      _Share(
        label: 'WhatsApp',
        color: const Color(0xFF25D366),
        icon: Icons.chat_bubble_outline,
        href: 'https://api.whatsapp.com/send?text=$shareText',
      ),
      _Share(
        label: 'Telegram',
        color: const Color(0xFF26A5E4),
        icon: Icons.send_outlined,
        href: 'https://t.me/share/url?url=$url&text=$title',
      ),
      _Share(
        label: 'ВКонтакте',
        color: const Color(0xFF0077FF),
        icon: Icons.public,
        href: 'https://vk.com/share.php?url=$url&title=$title',
      ),
      _Share(
        label: 'Одноклассники',
        color: const Color(0xFFEE8208),
        icon: Icons.thumb_up_alt_outlined,
        href: 'https://connect.ok.ru/offer?url=$url&title=$title',
      ),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final s in shares) _ShareButton(share: s)],
    );
  }
}

class _Share {
  const _Share({
    required this.label,
    required this.color,
    required this.icon,
    required this.href,
  });

  final String label;
  final Color color;
  final IconData icon;
  final String href;
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.share});

  final _Share share;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: share.color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => LinkOpener.open(share.href),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(share.icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Text(
                share.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandingStep {
  const _LandingStep({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _StepsGrid extends StatelessWidget {
  const _StepsGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _steps.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        mainAxisExtent: 200,
      ),
      itemBuilder: (_, i) => _StepCard(index: i + 1, step: _steps[i]),
    );
  }
}

class _StepsList extends StatelessWidget {
  const _StepsList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          _StepCard(index: i + 1, step: _steps[i]),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.index, required this.step});

  final int index;
  final _LandingStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(step.icon, color: theme.colorScheme.primary),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            step.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              step.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const Map<ConstructionType, IconData> _typeIcons = {
  ConstructionType.privateHouse: Icons.cottage_outlined,
  ConstructionType.apartmentBuilding: Icons.apartment_outlined,
  ConstructionType.commercialBuilding: Icons.store_mall_directory_outlined,
  ConstructionType.commercialStructure: Icons.warehouse_outlined,
  ConstructionType.metalStructure: Icons.precision_manufacturing_outlined,
};

const Map<ConstructionType, String> _typeDescriptions = {
  ConstructionType.privateHouse:
      'ИЖС, частный дом до 3 этажей. Полный поток: бриф → чертежи → расчёт '
          'фундамента → ПЗ.',
  ConstructionType.apartmentBuilding:
      'Многоквартирный дом 4–10 этажей по СП. Поддержка планируется в одном '
          'из следующих обновлений.',
  ConstructionType.commercialBuilding:
      'Торговый, офисный или общественный объект. В работе.',
  ConstructionType.commercialStructure:
      'Складское, производственное или вспомогательное сооружение. В работе.',
  ConstructionType.metalStructure:
      'Каркасы, фермы, ангары из проката. Расчёт по СП 16. В работе.',
};

class _TypesGrid extends StatelessWidget {
  const _TypesGrid();

  @override
  Widget build(BuildContext context) {
    const types = ConstructionType.values;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: types.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        mainAxisExtent: 196,
      ),
      itemBuilder: (_, i) => _TypeCard(type: types[i]),
    );
  }
}

class _TypesList extends StatelessWidget {
  const _TypesList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final t in ConstructionType.values) ...[
          _TypeCard(type: t),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({required this.type});

  final ConstructionType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final implemented = type.isImplemented;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: implemented
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: implemented ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: implemented
            ? () => _startProject(context, type)
            : () => _showSoonDialog(context, type),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _typeIcons[type] ?? Icons.business_outlined,
                    size: 32,
                    color: implemented
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  if (!implemented)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'скоро',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                type.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: implemented
                      ? null
                      : theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  _typeDescriptions[type] ?? '',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startProject(
      BuildContext context, ConstructionType type) async {
    final state = context.read<AppState>();
    final project = await Navigator.push<HouseProject>(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectCreatePage(initialType: type),
      ),
    );
    if (project == null || !context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectDetailsPage(projectId: project.id),
      ),
    );
    await state.saveProject(project);
  }

  void _showSoonDialog(BuildContext context, ConstructionType type) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type.title),
        content: const Text(
          'Этот тип сооружения ещё в разработке. Сейчас полностью '
          'реализован только частный дом — на нём можно пройти весь поток '
          'бриф → чертежи → расчёт фундамента → пояснительная записка.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }
}

class _ProjectsSection extends StatelessWidget {
  const _ProjectsSection();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    if (state.projects.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Мои проекты',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < state.projects.length; i++) ...[
          _ProjectTile(project: state.projects[i]),
          if (i < state.projects.length - 1) const SizedBox(height: 8),
        ],
      ],
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
        leading: Icon(_typeIcons[project.constructionType] ??
            Icons.home_work_outlined),
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
