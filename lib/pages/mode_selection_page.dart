import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_mode.dart';
import '../state/app_state.dart';
import '../widgets/hints.dart';

/// Экран выбора режима.
///
/// Показывается при первом запуске приложения и доступен из настроек,
/// чтобы пользователь мог поменять режим (например, проектировщик хочет
/// показать клиенту, как видят бриф они).
class ModeSelectionPage extends StatelessWidget {
  const ModeSelectionPage({super.key, this.canGoBack = false});

  /// Если `true`, на экране есть кнопка возврата (используется при заходе
  /// со страницы настроек). По умолчанию — нет (первый запуск).
  final bool canGoBack;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Кто вы?'),
        automaticallyImplyLeading: canGoBack,
        actions: const [
          HintIconButton(
            title: 'Выбор режима',
            sections: Hints.modeSelection,
          ),
        ],
      ),
      body: HintAutoShow(
        screenKey: 'mode-selection',
        title: 'Выбор режима',
        sections: Hints.modeSelection,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Выберите режим работы приложения',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'От режима зависит уровень детализации интерфейса и состав '
                  'выходных документов.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                for (final mode in UserMode.values) ...[
                  _ModeCard(
                    mode: mode,
                    selected: state.mode == mode,
                    onTap: () async {
                      await state.setMode(mode);
                      if (canGoBack && context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final UserMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                mode == UserMode.client
                    ? Icons.person_outline
                    : Icons.engineering_outlined,
                size: 40,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(mode.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(mode.description, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
