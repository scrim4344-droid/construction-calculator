import 'package:flutter/material.dart';

/// Заглушка раздела «Лестница». Появляется в составе сооружения только
/// когда этажность > 1 (или явный флаг в техническом задании).
class StaircasePage extends StatelessWidget {
  const StaircasePage({super.key, required this.projectId});

  // ignore: unused_element
  final String projectId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Лестница')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Раздел в разработке.\n\nЗдесь появится выбор типа лестницы '
            '(маршевая / винтовая / поворотная), высота этажа и расчёт '
            'количества ступеней.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
