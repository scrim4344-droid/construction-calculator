import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';

/// Иконка «?» в AppBar, открывает диалог с пошаговой подсказкой по экрану.
///
/// Подсказки оформлены единообразно по всем экранам, чтобы у пользователя
/// формировалась привычная навигация: «не понятно — нажми вопросик в углу».
class HintIconButton extends StatelessWidget {
  const HintIconButton({
    super.key,
    required this.title,
    required this.sections,
    this.tooltip = 'Подсказка по этому экрану',
  });

  final String title;
  final List<HintSection> sections;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: const Icon(Icons.help_outline),
      onPressed: () => showHintDialog(
        context,
        title: title,
        sections: sections,
        // Из ручного «?» можно тоже выключить экскурсию, чтобы не лазить
        // в настройки — поведение симметрично авто-показу.
        showDisableButton: true,
      ),
    );
  }
}

/// Виджет-обёртка, который при первом построении в текущей сессии
/// автоматически показывает обучающую подсказку для экрана `screenKey`.
///
/// Не вмешивается в дерево виджетов: возвращает [child] как есть.
/// Состояние «уже показывали» хранится в [AppState], сбрасывается на
/// новой загрузке страницы — пользователя «ведут за руку» при каждом
/// заходе. Когда пользователь нажимает «Не показывать подсказки» в
/// диалоге, флаг `hintsEnabled` сохраняется в SharedPreferences.
class HintAutoShow extends StatefulWidget {
  const HintAutoShow({
    super.key,
    required this.screenKey,
    required this.title,
    required this.sections,
    required this.child,
  });

  final String screenKey;
  final String title;
  final List<HintSection> sections;
  final Widget child;

  @override
  State<HintAutoShow> createState() => _HintAutoShowState();
}

class _HintAutoShowState extends State<HintAutoShow> {
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    final state = context.read<AppState>();
    if (!state.shouldAutoShowHint(widget.screenKey)) return;
    _scheduled = true;
    state.markHintShown(widget.screenKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showHintDialog(
        context,
        title: widget.title,
        sections: widget.sections,
        showDisableButton: true,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Один раздел подсказки. Может быть либо текстовым абзацем (через [body]),
/// либо нумерованным/маркированным списком (через [bullets]).
class HintSection {
  const HintSection({
    required this.heading,
    this.body,
    this.bullets = const [],
    this.icon,
  });

  final String heading;
  final String? body;
  final List<String> bullets;
  final IconData? icon;
}

Future<void> showHintDialog(
  BuildContext context, {
  required String title,
  required List<HintSection> sections,
  bool showDisableButton = false,
}) {
  final theme = Theme.of(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        icon: const Icon(Icons.lightbulb_outline),
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final s in sections) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (s.icon != null) ...[
                        Icon(
                          s.icon,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          s.heading,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (s.body != null) ...[
                    Text(
                      s.body!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  if (s.bullets.isNotEmpty) ...[
                    for (final b in s.bullets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 6, right: 8),
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                b,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (showDisableButton)
            TextButton(
              onPressed: () async {
                // Снимаем экскурсию глобально и закрываем диалог. Используем
                // context самой страницы (он переживает закрытие диалога),
                // чтобы безопасно дёрнуть AppState.
                final state = context.read<AppState>();
                Navigator.pop(dialogContext);
                await state.setHintsEnabled(false);
              },
              child: const Text('Не показывать подсказки'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Понятно'),
          ),
        ],
      );
    },
  );
}

/// Все тексты подсказок собраны в одном месте — проще править формулировки
/// без обхода экранов. Каждый метод возвращает список секций для диалога.
class Hints {
  const Hints._();

  static const List<HintSection> projectCreate = [
    HintSection(
      heading: 'Создание проекта',
      icon: Icons.add,
      body: 'Два поля: название и тип сооружения. Название можно поменять '
          'позже — это просто метка для списка проектов.',
    ),
    HintSection(
      heading: 'Тип сооружения',
      icon: Icons.home_work_outlined,
      bullets: [
        'Частный дом — основной сценарий: фундамент, стены, крыша, '
            'опционально лестница и мансарда.',
        'Многоквартирный дом — заглушка («скоро»), пока не используется.',
        'Металлоконструкция — заглушка («скоро»), пока не используется.',
      ],
    ),
    HintSection(
      heading: 'Что дальше',
      icon: Icons.arrow_forward,
      body: 'После «Создать проект» откроется экран проекта с тремя '
          'разделами: бриф, состав, чертежи. Стартуйте с брифа.',
    ),
  ];

  static const List<HintSection> home = [
    HintSection(
      heading: 'Что это за экран?',
      icon: Icons.architecture_outlined,
      body: 'Главный экран — короткая инструкция и выбор того, что вы '
          'хотите спроектировать. Ниже — ваши уже созданные проекты, '
          'если они есть.',
    ),
    HintSection(
      heading: 'Как создать проект',
      icon: Icons.add,
      bullets: [
        'Выберите тип сооружения в блоке «Что вы хотите спроектировать?».',
        'Введите название проекта и нажмите «Создать».',
        'После создания откроется проект — там бриф, состав и чертежи.',
      ],
    ),
    HintSection(
      heading: 'Поделиться приложением',
      icon: Icons.share_outlined,
      body: 'Кнопки сверху (WhatsApp, Telegram, ВКонтакте, Одноклассники) '
          'отправят ссылку на это приложение в выбранный мессенджер или '
          'соцсеть.',
    ),
    HintSection(
      heading: 'Удалить или переименовать',
      icon: Icons.more_vert,
      body: 'Меню «⋮» справа на карточке проекта — переименовать или '
          'удалить. Удаление необратимо.',
    ),
  ];

  static const List<HintSection> projectDetails = [
    HintSection(
      heading: 'Три раздела проекта',
      icon: Icons.account_tree_outlined,
      body: 'Заполняйте по очереди. Каждый раздел можно править в любой '
          'момент — данные обновятся, чертежи перегенерируются.',
    ),
    HintSection(
      heading: '1. Бриф клиента',
      icon: Icons.assignment_outlined,
      body: 'Опросник в 8 шагов: участок, грунт, этажность, площадь, '
          'комнаты, дополнения, материал стен, особые пожелания. Можно '
          'выйти на любом шаге — прогресс сохранится.',
    ),
    HintSection(
      heading: '2. Состав сооружения',
      icon: Icons.foundation_outlined,
      body: 'Фундамент, стены, крыша, лестница. В режиме «Клиент» — '
          'только просмотр (всё подобрано автоматически по брифу). В '
          'режиме «Проектировщик» — каждый элемент можно открыть и '
          'отредактировать вручную.',
    ),
    HintSection(
      heading: '3. Чертежи',
      icon: Icons.draw_outlined,
      body: 'Сгенерированные планы этажей. Можно скачать PDF/DXF, '
          'а в режиме «Проектировщик» — открыть редактор и подвинуть '
          'комнаты, добавить двери и окна.',
    ),
  ];

  static const List<HintSection> composition = [
    HintSection(
      heading: 'Состав сооружения',
      icon: Icons.account_tree_outlined,
      body: 'Список конструктивных элементов, подобранных по брифу.',
    ),
    HintSection(
      heading: 'Режим «Клиент»',
      icon: Icons.person_outline,
      body: 'Список — только для просмотра. Чтобы поменять рекомендацию, '
          'отредактируйте бриф (например, измените тип грунта или этажность). '
          'После этого нажмите «Перегенерировать» внизу — состав и чертежи '
          'обновятся.',
    ),
    HintSection(
      heading: 'Режим «Проектировщик»',
      icon: Icons.engineering_outlined,
      bullets: [
        'Каждый элемент списка кликабельный — открывается визард с '
            'параметрами (тип фундамента, материал стен и т. д.).',
        '«Перегенерировать чертежи» создаёт новую партию эскизов с '
            'учётом текущего состава. Старые партии остаются в истории.',
        '«Сбросить к авторасчёту» — вернуть рекомендацию движка правил.',
      ],
    ),
    HintSection(
      heading: 'Обоснование выбора фундамента',
      icon: Icons.fact_check_outlined,
      body: 'Под карточкой фундамента — короткий список «почему именно '
          'такой» (со ссылками на СП). Полезно показать клиенту.',
    ),
  ];

  static const List<HintSection> briefWizard = [
    HintSection(
      heading: 'Бриф в 8 шагов',
      icon: Icons.assignment_outlined,
      body: 'Стрелки внизу — «Назад / Далее». Прогресс сохраняется после '
          'каждого шага: можно безопасно закрыть приложение.',
    ),
    HintSection(
      heading: 'Шаги',
      icon: Icons.list_alt,
      bullets: [
        '1. Регион — снеговой/ветровой район подтягиваются автоматически '
            '(СП 20.13330). Проектировщик может переопределить вручную.',
        '2. Тип грунта — нужен для подбора фундамента (СП 22.13330).',
        '3. Этажность + мансарда / подвал.',
        '4. Целевая площадь и пятно застройки.',
        '5. Комнаты — выберите, сколько каких типов нужно.',
        '6. Дополнения — гараж, терраса, балкон, эркер, второй свет, '
            'лестница.',
        '7. Материал стен (кирпич, газобетон, дерево…) — повлияет на '
            'выбор фундамента и крыши.',
        '8. Особые пожелания — свободный текст.',
      ],
    ),
    HintSection(
      heading: 'После «Завершить»',
      icon: Icons.check_circle_outline,
      body: 'Состав сооружения автоматически подтягивается из движка '
          'правил. В режиме «Клиент» — сразу же генерируется первая '
          'партия эскизов планов.',
    ),
  ];

  static const List<HintSection> foundationWizard = [
    HintSection(
      heading: 'Параметры фундамента',
      icon: Icons.foundation_outlined,
      body: 'Подобранный по брифу тип уже выбран. Можно поменять, если '
          'у вас есть основания (геология участка, опыт стройки).',
    ),
    HintSection(
      heading: 'Что выбираем',
      icon: Icons.checklist,
      bullets: [
        'Тип: ленточный, плита, сваи, столбчатый, ростверк.',
        'Устройство: монолит / сборные блоки.',
        'Материал и марка бетона.',
        'Глубина заложения — связана с глубиной промерзания (зависит от '
            'региона).',
      ],
    ),
    HintSection(
      heading: 'Обоснование выбора',
      icon: Icons.menu_book_outlined,
      body: 'Под параметрами — список причин «почему именно так» со '
          'ссылками на СП. Полезно объяснить клиенту.',
    ),
    HintSection(
      heading: 'Расчёт нагрузок',
      icon: Icons.calculate_outlined,
      body: 'Кнопка «Рассчитать нагрузки» — открывает страницу с полным '
          'расчётом по СП 20.13330: снег, ветер, постоянная и полезная '
          'нагрузки. Видно каждую формулу и подстановку значений.',
    ),
  ];

  static const List<HintSection> foundationDesign = [
    HintSection(
      heading: 'Что подбираем',
      icon: Icons.architecture_outlined,
      body: 'Сечение ленточного фундамента: ширину подошвы b, высоту '
          'ленты h, глубину заложения d. Плюс базовое армирование '
          'продольной арматурой и хомутами по СП 63.13330.',
    ),
    HintSection(
      heading: 'Как считаем',
      icon: Icons.functions,
      bullets: [
        'R — расчётное сопротивление грунта (СП 22.13330, табл. В.3).',
        'A — площадь застройки из брифа.',
        'L — длина несущих стен (периметр + поперечные).',
        'N = q · A / L — погонная нагрузка на ленту.',
        'b ≥ N · γc / R — требуемая ширина подошвы.',
        'd ≥ df + 0.1 м — глубина заложения от поверхности земли.',
      ],
    ),
    HintSection(
      heading: 'Откуда берётся каждое значение',
      icon: Icons.info_outline,
      body: 'Под каждой формулой раскрывающийся блок «Откуда взяты '
          'значения» — там видно, что взято из брифа, что из расчёта '
          'нагрузок, что из СП. Удобно проверять.',
    ),
    HintSection(
      heading: 'Что дальше',
      icon: Icons.arrow_forward,
      body: 'Эти параметры пойдут в пояснительную записку (ПЗ), узел '
          'фундамента в DXF и строку ВОР: бетон м³, арматура кг по '
          'диаметрам, опалубка м².',
    ),
  ];

  static const List<HintSection> foundationLoads = [
    HintSection(
      heading: 'Что считаем',
      icon: Icons.calculate_outlined,
      body: 'Расчёт нагрузок на фундамент по СП 20.13330.2016. '
          'На входе — данные из брифа: снеговой и ветровой районы, '
          'этажность, материал стен и кровли. На выходе — суммарная '
          'вертикальная нагрузка на 1 м² застройки и ветровое давление.',
    ),
    HintSection(
      heading: 'Что увидите ниже',
      icon: Icons.list_alt,
      bullets: [
        'Снеговая нагрузка S = µ · Sg · γf — с расшифровкой коэффициентов.',
        'Ветровая нагрузка wm = w0 · k(z) · c · γf.',
        'Постоянные нагрузки от стен, перекрытий и кровли.',
        'Полезная нагрузка для жилых помещений (СП 20, табл. 8.3).',
        'Сумма по СП 20, разд. 6 (сочетание нагрузок).',
      ],
    ),
    HintSection(
      heading: 'Что дальше',
      icon: Icons.arrow_forward,
      body: 'В следующей итерации эти нагрузки уйдут в подбор подошвы '
          'и армирование (СП 22 + СП 63), а потом — в пояснительную '
          'записку и строку ВОР. Сейчас можно проверить корректность '
          'входных данных.',
    ),
  ];

  static const List<HintSection> drawings = [
    HintSection(
      heading: 'История чертежей',
      icon: Icons.history,
      body: 'Каждое сохранение — отдельная партия (версия). Свежие сверху, '
          'старые ниже. Ничего не теряется.',
    ),
    HintSection(
      heading: 'Что можно сделать',
      icon: Icons.touch_app_outlined,
      bullets: [
        'Скачать партию в PDF — все этажи одним файлом, шрифт с '
            'кириллицей, толстые стены / двери / окна как на экране.',
        'Скачать в DXF — каждый этаж отдельным файлом для AutoCAD.',
        'В режиме «Проектировщик» — открыть план этажа в редакторе '
            '(карандаш на карточке плана).',
      ],
    ),
    HintSection(
      heading: 'Перегенерация',
      icon: Icons.refresh,
      body: 'Если вы поменяли бриф или состав сооружения — вернитесь в '
          '«Состав» и нажмите «Перегенерировать». Появится новая партия, '
          'старая останется ниже.',
    ),
  ];

  static const List<HintSection> floorPlanEditor = [
    HintSection(
      heading: 'Редактор плана',
      icon: Icons.draw_outlined,
      body: 'Подвинуть комнаты, поменять размеры, добавить двери и окна. '
          'Изменения округляются до сетки 0.1 м, минимальная сторона — 1 м.',
    ),
    HintSection(
      heading: 'Режим «Комнаты»',
      icon: Icons.crop_square,
      bullets: [
        'Касание — выделить.',
        'Тащить за тело — переместить.',
        'Тащить за угловую ручку — изменить размеры (от противоположного '
            'угла).',
        'Кнопки в AppBar: «+» — добавить комнату, корзина — удалить '
            'выделенную.',
      ],
    ),
    HintSection(
      heading: 'Режим «Двери и окна»',
      icon: Icons.door_sliding_outlined,
      bullets: [
        'Касание по проёму — выделить.',
        'Тащить за тело — двигать вдоль стены.',
        'Тащить за концы — менять длину проёма.',
        'Кнопки: дверь / окно / входная дверь / удалить выделенный.',
        'Минимальная длина проёма — 0.6 м (СП 55.13330).',
      ],
    ),
    HintSection(
      heading: 'Сохранение',
      icon: Icons.save_outlined,
      body: 'Дискета — сохранить как новую версию (старые планы не '
          'затираются, остаются в истории на вкладке «Чертежи»). Стрелка '
          'обновления — сбросить ручные правки и вернуться к авторасчёту. '
          'Если есть пересечения комнат — кнопка сохранения заблокирована.',
    ),
  ];
}
