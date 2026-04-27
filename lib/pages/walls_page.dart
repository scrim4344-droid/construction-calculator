import 'package:flutter/material.dart';

/// Заглушка раздела «Стены». Будет реализован после фундамента.
class WallsPage extends StatelessWidget {
  const WallsPage({super.key, required this.projectId});

  // ignore: unused_element
  final String projectId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Стены')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Раздел в разработке.\n\nЗдесь появится выбор материала стен '
            '(кирпич, газобетон, дерево и т. д.), ввод толщины и высоты.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
