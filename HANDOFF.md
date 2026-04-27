# HANDOFF.md — Передача проекта другой нейросети / разработчику

> **Цель этого файла:** если пользователь (Scrim, scrim4344@gmail.com) подключит к проекту новую нейросеть или нового разработчика, прочтение **только этого файла** должно дать полный контекст: что сделано, какие решения приняты, что в очереди, и как продолжить с любой точки. Файл лежит в корне репозитория и попадает в каждый архив `construction_calculator_vN.tar.gz`.
>
> **Если ты ИИ и читаешь это:** не задавай пользователю вопросы по уже принятым решениям (раздел «Решения, обсуждённые с пользователем»). Не предлагай ему облака/языки/стили заново. Просто продолжи с раздела «Где остановились» и иди по «Следующим шагам».

---

## 1. Что это за проект

«**Калькулятор проектировщика**» (construction_calculator) — Flutter‑приложение для расчёта индивидуального жилого дома (частного дома). Два режима:

- **Клиент** — без знаний в проектировании. Заполняет бриф (8 шагов: участок, этажность, комнаты, материал, регион и т.д.), приложение **автоматически** подбирает состав сооружения (фундамент / стены / кровля / лестница) и генерирует чертежи и PDF.
- **Проектировщик** — может вручную править состав, открывать полноэкранный редактор плана этажа (двигать комнаты, добавлять двери и окна), сохранять версии чертежей.

**Контекст бизнеса:** пользователь планирует **продавать** приложение. Целевая аудитория — частники без знаний и строительные организации. См. `roadmap.md` (отдельный файл, в корне `/home/ubuntu/work/`, должен лежать рядом с архивом) — там расписана коммерческая стратегия (Free / Pro / Studio / Enterprise) и приоритеты.

**Стек:** Flutter (Dart 3.x) + provider + shared_preferences + pdf + uuid. Web и Android платформы. Сейчас фокус на **Web** (демо‑версия).

---

## 2. Решения, обсуждённые с пользователем

| # | Решение | Дата |
|---|---------|------|
| 1 | Делаем PR/коммиты локально, без GitHub. Доставка пользователю — `git format-patch` + `tar.gz` архив + ссылка на демо | первая сессия |
| 2 | PDF‑чертежи должны рисоваться **тем же стилем**, что в `FloorPlanPainter` (толстые стены 0.38/0.20 м, дуги дверей, двойная линия окон, штриховка лестницы) — это **сделано** в `pdf_builder.dart` | первая сессия |
| 3 | Подсказки/тултипы на каждом экране через виджет `HintIconButton` («?» в AppBar) — **сделано** | вторая сессия |
| 4 | Подсказки **автоматически** показываются при первом заходе на каждый экран в текущей сессии. В диалоге кнопка «Не показывать подсказки» (выключает глобально, без перехода в настройки). Флаг `hints_enabled` в SharedPreferences, дефолт `true`. — **сделано** | вторая сессия |
| 5 | После каждой правки — пересобирать Flutter Web и слать пользователю URL + архив | вторая сессия |
| 6 | **Делаем всю Группу A** roadmap (10 пунктов): размеры на чертежах, оси, полный комплект АР, штамп СПДС, расчёты нагрузок, теплотехника, ВОР, аккаунты, тарифы, юридический минимум, адаптив десктоп | третья сессия |
| 7 | Юр.лица пока нет — биллинг откладываем, делаем full‑featured demo | третья сессия |
| 8 | **Облако:** **Supabase** на этап MVP (бесплатный тариф, EU дата‑центры). После регистрации юрлица в РФ — миграция на **Yandex Cloud** (Managed PostgreSQL + Object Storage). Архитектура: интерфейс `RemoteRepository` с двумя реализациями | третья сессия |
| 9 | Брендинг — **нейтральный** на этом этапе | третья сессия |
| 10 | **Эталонный расчётный модуль — фундамент.** Один отполированный flow (нагрузки → подбор подошвы → армирование → ПЗ → DXF узла → строка в смете) | третья сессия |
| 11 | Работа итерациями по 1–2 пункта Группы A, после каждого шага — демо‑URL + архив + патч | третья сессия |

---

## 3. Текущее состояние кода

**Ветка:** `devin/1777270216-pdf-walls-doors-windows` (от `main`, 4 коммита поверх).

```
dddee39 (main)  Initial import from archive
c250e5f         PDF: рисуем стены, двери и окна толстой графикой
90de92f         test: smoke-тест на PdfBuilder с реалистичным планом
d6cd801         feat(ui): подсказки на каждом этапе (?, диалоги в AppBar)
29a1138 (HEAD)  feat(hints): авто-показ подсказок при заходе + кнопка отключения
```

**Файлы и их роль (только что критично знать новой нейросети):**

```
lib/
├── main.dart                              # ConstructionCalculatorApp + MaterialApp + Provider
├── models/
│   ├── client_brief.dart                  # Бриф: 8 шагов вопросов → значения
│   ├── construction_type.dart             # privateHouse / multiApartment / metal
│   ├── drawing.dart                       # Кадр чертежа (PDF/DXF/JSON payload)
│   ├── floor_plan.dart                    # PlanRoom + PlanOpening (door/window)
│   ├── house_project.dart                 # Корневая модель проекта (бриф + фундамент + стены + крыша + ...)
│   ├── foundation.dart                    # FoundationType, FoundationDevice, материалы
│   ├── walls.dart, roof.dart              # Параметры стен/кровли
│   ├── staircase.dart                     # Параметры лестницы
│   └── user_mode.dart                     # client / designer
├── state/
│   └── app_state.dart                     # ChangeNotifier: проекты + режим + флаг подсказок
├── storage/
│   ├── settings_repository.dart           # SharedPreferences: mode + hints_enabled
│   └── project_repository.dart            # SharedPreferences: список проектов как JSON
├── services/
│   ├── composition_planner.dart           # ЯДРО: правила подбора фундамента/стен/крыши по брифу
│   ├── floor_plan_generator.dart          # Авто-генерация плана этажа (комнаты + проёмы)
│   ├── drawing_generator.dart             # Сборка партии чертежей (DrawingBatch)
│   ├── pdf_builder.dart                   # Генератор PDF (план + спецификации). Кириллица, толстые стены
│   ├── dxf_writer.dart                    # AutoCAD DXF экспорт
│   └── file_download.dart                 # Условный импорт web/native для скачивания
├── widgets/
│   ├── floor_plan_view.dart               # Виджет рендера плана (используется и в редакторе, и в превью)
│   └── hints.dart                         # HintIconButton + HintAutoShow + showHintDialog + Hints class
├── pages/
│   ├── mode_selection_page.dart           # /
│   ├── home_page.dart                     # Список проектов + FAB
│   ├── settings_page.dart                 # Настройки (режим + переключатель подсказок)
│   ├── project_create_page.dart           # Новый проект (название + тип)
│   ├── project_details_page.dart          # 3 раздела: бриф / состав / чертежи
│   ├── brief/brief_wizard_page.dart       # 8-шаговый визард брифа (1100 строк)
│   ├── brief_page.dart                    # Старая страница, не используется (мёртвый код, удалить позже)
│   ├── composition_page.dart              # Список конструктивных элементов (фундамент/стены/...)
│   ├── foundation/foundation_type_page.dart    # Шаг 1 фундамента
│   ├── foundation/foundation_device_page.dart  # Шаг 2 фундамента
│   ├── drawings_page.dart                 # Список партий чертежей + экспорт + редактор
│   └── floor_plan_editor_page.dart        # Полноэкранный редактор плана (1060 строк, нужно резать)
└── data/
    └── region_catalog.dart                # Справочник регионов (для будущих расчётов: снег/ветер/Tхол)
```

---

## 4. Что уже сделано в этой ветке

### 4.1 PDF с видимыми стенами/дверями/окнами
- `lib/services/pdf_builder.dart`: переписан `_paintPlan`. Сначала заливается «масса стены» тёмным, поверх — прямоугольники комнат с отступом в полтолщины стены. Окна — заливка + контур + двойная линия (CAD‑символ). Двери — створка + четверть‑круг открывания (полилиния 24 сегмента). Лестница — штриховка ступеней + диагональная стрелка.
- Толщины: `_outerWall = 0.38 м`, `_innerWall = 0.20 м` — синхронизировано с `FloorPlanPainter`.
- Smoke‑тест: `test/pdf_smoke_test.dart` — собирает PDF на реалистичном плане. С `CC_DUMP_SAMPLE_PDF=1` сохраняет в `/tmp/sample_plan.pdf`.

### 4.2 Подсказки на всех экранах
- `lib/widgets/hints.dart`:
  - `HintIconButton` — иконка «?» в AppBar.
  - `HintAutoShow(screenKey, title, sections, child)` — обёртка вокруг тела Scaffold, авто‑открывает диалог при первом построении в текущей сессии.
  - `showHintDialog(context, title, sections, showDisableButton)` — модалка. С `showDisableButton: true` показывает «Не показывать подсказки» рядом с «Понятно».
  - `Hints` класс — все тексты подсказок: `modeSelection, home, projectCreate, projectDetails, composition, briefWizard, foundationWizard, drawings, floorPlanEditor`.
- `AppState`: добавлены `hintsEnabled` (persisted), `_hintsShownThisSession` (in-memory Set), методы `setHintsEnabled`, `shouldAutoShowHint`, `markHintShown`.
- `SettingsRepository`: `loadHintsEnabled()` / `saveHintsEnabled()` поверх SharedPreferences (ключ `hints_enabled`, дефолт `true`).
- `pages/settings_page.dart`: `SwitchListTile` «Показывать обучающие подсказки» — для повторного включения после ручного выключения.
- Все 9 ключевых страниц обёрнуты в `HintAutoShow` (mode‑selection, home, project-create, project-details, composition, brief-wizard, foundation-type, foundation-device, drawings, floor-plan-editor).

### 4.3 Тесты
- `test/widget_test.dart`: 3 smoke‑теста. В тестах `hints_enabled=false` по умолчанию через `SharedPreferences.setMockInitialValues`, иначе автодиалог ломает `findOneWidget`.
- `test/pdf_smoke_test.dart`: 1 тест — PDF собирается на реалистичном плане без падений.
- `flutter analyze` — чисто. `flutter test` — 4 теста зелёные.

---

## 5. Где остановились

**Текущая версия: v6.** Реализованы шаги 1, 2 и 3 эталонного модуля «Фундамент».

**Демо (доступно из РФ без VPN):** https://scrim4344-droid.github.io/construction-calculator/

**GitHub-репозиторий:** https://github.com/scrim4344-droid/construction-calculator (ветка `init`, GitHub Actions деплоит на каждый push в `init`/`main`).

**Прежний демо-URL:** https://web-huyvayzd.devinapps.com/ — работает, но из РФ только через VPN/proxy. Заменён на GitHub Pages (см. выше).

**Сделано в v6 (новое):**

- ✅ **Шаг 3 фундамента — Пояснительная записка (ПЗ) в PDF.** Файл `lib/services/foundation_explanation_pdf.dart`. Структура: титульный лист → исходные данные (с источниками каждой величины) → расчёт снеговой → ветровой → постоянной/полезной/сводки → сопротивление грунта и подбор сечения → принятые параметры → выводы. PDF строится **прямо из CalcStep + CalcInput**, поэтому данные в ПЗ всегда совпадают с тем, что показано на экране.
- ✅ Кнопка «Скачать пояснительную записку (PDF)» на странице подбора сечения (`FoundationDesignPage`). Кнопка `_DownloadExplanationButton` (StatefulWidget) с индикатором загрузки.
- ✅ Smoke-тест ПЗ: `test/foundation_explanation_pdf_smoke_test.dart`. С `CC_DUMP_SAMPLE_PDF=1` пишет образец в `/tmp/sample_explanation.pdf`.
- ✅ FoundationDesignPage теперь принимает `FoundationLoadsResult` целиком (а не только totalLoad), чтобы можно было прокинуть в ПЗ полный журнал расчёта снеговой/ветровой/постоянной нагрузок.

**Сделано в v5:**

- ✅ **Schema versioning** в `ProjectRepository` (формат `{schema_version, projects}` + миграции, `lib/storage/project_migrations.dart`).
- ✅ **`cc_engine`** — pure‑Dart пакет `packages/cc_engine/`. Все расчёты живут тут.
- ✅ **Шаг 1 фундамента — расчёт нагрузок** по СП 20.13330: снег, ветер, постоянные, полезная. Сводный класс `FoundationLoadsCalculator`. Каталог регионов `SnowRegion` / `WindRegion`.
- ✅ **CalcInput** в `calc_step.dart`: каждая величина в формуле теперь несёт `symbol`, `value`, `origin` (откуда взялось — из брифа, из каталога, из СП), `reference`. Это видно в UI как раскрывающийся блок «Откуда взяты значения» под каждой формулой.
- ✅ **Шаг 2 фундамента — подбор сечения**: `SoilResistanceCalculator` (СП 22 табл. В.3) + `StripFootingDesigner` (b, h, d) + конструктивное армирование по СП 63 (4–8 ⌀12 А500С + хомуты ⌀8 А240 шаг 200). UI: `lib/pages/foundation/foundation_design_page.dart`. Кнопка «Подобрать сечение фундамента» внизу страницы расчёта нагрузок.
- ✅ Виджет `lib/widgets/calc_steps_card.dart` — общий рендер `CalcStep` с раскрывающейся секцией «Откуда взяты значения». Используется обеими страницами фундамента.
- ✅ Тесты cc_engine: 12 (snow, wind, permanent, regions, foundation_loads, **strip_footing — 3 теста**). `dart test` зелёный.
- ✅ Тесты Flutter: 9 (3 widget + 1 PDF + 5 миграций). `flutter test` зелёный.
- ✅ `flutter analyze` чисто.

**Очередь реализации (что дальше):**

1. **Шаг 4 фундамента — Узел фундамента в DXF + диаграмма нагрузок PDF.** Отдельный лист в основном PDF + DXF файл узла с размерами, маркировкой арматуры, защитным слоем, гидроизоляцией.
2. **Шаг 5 фундамента — Строка ВОР.** Таблица: бетон В20 м³, арматура А500С/А240 по диаметрам кг, опалубка м², гидроизоляция м², щебень/песок подушки м³. Класс `Bom` в моделях, аккумулирование по элементам.

3. **После фундамента — следующие пункты Группы A:** размеры/оси на чертежах, штамп СПДС, форматы листов (A4–A1), теплотехника по СП 50, базовая смета, аккаунты + Supabase, тарифы Free/Pro/Studio, юридический минимум, адаптив для десктопа.

---

## 6. Архитектурные ограничения, которые надо учитывать

### 6.1 SharedPreferences и миграции

`ProjectRepository.loadAll()` сейчас:
```dart
try {
  final raw = _prefs.getString(_key);
  if (raw == null) return [];
  return parseJson(raw).map(HouseProject.fromJson).toList();
} catch (_) {
  return [];  // ← молчком теряет все проекты
}
```

**Нужно:** хранить `schema_version` рядом с данными. При несовпадении прогонять цепочку миграций `migration_v1_to_v2`, `migration_v2_to_v3`. Формат хранения:
```json
{ "schema_version": 1, "projects": [...] }
```

### 6.2 `AppState.projects` геттер мутирует приватный список

```dart
List<HouseProject> get projects =>
    List.unmodifiable(_projectList..sort(_byUpdatedDesc));
```

Сортировка **на каждом** ребилде. Надо: сортировать в setter‑ах (после `_persist()`), геттер только возвращает кэш. Либо ленивый `late` пересчёт.

### 6.3 `FoundationRationale` гоняется на каждом build

`composition_page.dart` вызывает `CompositionPlanner.plan(brief)` в build → каждое движение пальцем по экрану = пересчёт. Кэш в `HouseProject` или мемоизация.

### 6.4 Файлы > 1000 строк

`floor_plan_editor_page.dart` (1060) и `brief_wizard_page.dart` (1100) — рассыпать на сабвиджеты. Не сейчас, но **до** добавления осей и размеров.

### 6.5 DXF: один диалог save на каждый этаж

`dxf_writer.dart` для многоэтажки откроет N диалогов. Собирать в ZIP.

### 6.6 `withOpacity` deprecated

Flutter 3.27+ ругается. Использовать `.withValues(alpha: x)`. 6 мест в коде.

---

## 7. Как работать с проектом

### 7.1 Окружение

```
SDK:    /home/ubuntu/flutter/bin/flutter (Flutter 3.x)
Dart:   через flutter (не нужен отдельный)
PATH:   export PATH=/home/ubuntu/flutter/bin:$PATH
Repo:   /home/ubuntu/work/construction_calculator
```

### 7.2 Команды

```bash
cd /home/ubuntu/work/construction_calculator

flutter pub get                   # после изменений pubspec
flutter analyze                   # обязательно перед коммитом
flutter test                      # обязательно перед коммитом
flutter build web --release       # сборка web
```

### 7.3 Деплой демо

```python
# через Devin tool 'deploy'
deploy(command="frontend", dir="/home/ubuntu/work/construction_calculator/build/web")
```

URL: `https://web-huyvayzd.devinapps.com/`

### 7.4 Доставка пользователю

После каждой итерации:
```bash
cd /home/ubuntu/work/construction_calculator
git format-patch main..HEAD -o /home/ubuntu/work/patches
git diff main..HEAD > /home/ubuntu/work/patches/combined.diff

cd /home/ubuntu/work
tar --exclude='construction_calculator/build' \
    --exclude='construction_calculator/.dart_tool' \
    --exclude='construction_calculator/.flutter-plugins*' \
    --exclude='construction_calculator/android/.gradle' \
    --exclude='construction_calculator/android/build' \
    -czf construction_calculator_vN.tar.gz construction_calculator
```

Шлём пользователю через `message_user` с `attachments=[архив, патчи, демо‑скриншоты]`. URL демо — отдельной строкой.

### 7.5 Стиль коммитов

Префикс `feat(scope):` / `fix(scope):` / `test(scope):` / `refactor(scope):` / `docs:`. Тело на русском, многострочное, описывающее **зачем**, а не **что** (что видно из diff). Подпись:
```
git -c user.name="Devin AI" \
    -c user.email="158243242+devin-ai-integration[bot]@users.noreply.github.com" \
    commit -m "..."
```

### 7.6 Что НЕ делать

- `git push` куда‑либо (нет GitHub).
- `flutter create` без флагов в существующем проекте — переписывает `.metadata`.
- Менять формат сохранённых проектов **без миграции** (сольёшь все проекты пользователя).
- Менять тесты, не предупредив пользователя — он явно просил «не лезть в тесты».
- `dart format lib/` без необходимости — разберётся форматтер по‑новому и раздует diff (см. 4‑й коммит).

---

## 8. Технические нормы (нужно сверяться с СП при расчётах)

| СП / ГОСТ | Что регулирует | Где использовать |
|-----------|----------------|------------------|
| СП 22.13330.2016 | Основания зданий и сооружений | Расчёт фундамента |
| СП 63.13330.2018 | Бетонные и железобетонные конструкции | Армирование |
| СП 64.13330.2017 | Деревянные конструкции | Стропила, перекрытия по дереву |
| СП 15.13330.2020 | Каменные и армокаменные конструкции | Расчёт кладочных стен |
| СП 20.13330.2016 | Нагрузки и воздействия | Снег, ветер, постоянные |
| СП 50.13330.2012 | Тепловая защита зданий | Теплотехнический расчёт |
| СП 131.13330.2020 | Строительная климатология | Tхол, продолжительность отопительного периода |
| СП 14.13330.2018 | Строительство в сейсмических районах | Сейсмика (B/C группа) |
| ГОСТ Р 21.101‑2020 | Основные требования к проектной документации | Штамп, форматы, оформление |
| ГОСТ 2.303‑68 | Линии чертёжные | Толщины линий в DXF |
| ГОСТ 21.501‑2018 | Правила выполнения АР‑чертежей | Размеры, оси |

В `composition_planner.dart` уже стоят правильные ссылки на СП в комментариях — копировать оттуда формат.

---

## 9. Что точно **не** заходит пользователю

- Большие монолитные ответы. Любит формат «коротко + ссылка на файл/PR».
- Эмодзи / зелёные галочки.
- Английский в техническом контенте — пишем по‑русски.
- Не присылать кучу файлов в чат — лучше ссылка/скриншот/одна короткая выжимка + архив во вложении.
- Не задавать новые вопросы о уже принятых решениях (см. таблицу в разделе 2).

---

## 10. Если эта сессия закончилась — как продолжить

1. Распаковать последний `construction_calculator_vN.tar.gz`.
2. Открыть этот файл (`HANDOFF.md`).
3. Поднять окружение (раздел 7.1).
4. Прочесть раздел 5 («Где остановились»).
5. Идти строго по очереди реализации из раздела 5.
6. После каждого шага — пересобрать web, задеплоить, прислать пользователю URL + патч + новый архив.
7. **Обязательно обновить раздел 5 этого файла** — это живой документ, а не «отчёт о прошлом».
