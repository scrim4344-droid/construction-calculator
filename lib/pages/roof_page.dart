import 'package:flutter/material.dart';

/// Заглушка раздела «Крыша». Будет реализован после стен.
class RoofPage extends StatelessWidget {
  const RoofPage({super.key, required this.projectId});

  // ignore: unused_element
  final String projectId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Крыша')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Раздел в разработке.\n\nЗдесь появится выбор типа крыши '
            '(скатная / плоская / мансардная), угол наклона и материал кровли.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
