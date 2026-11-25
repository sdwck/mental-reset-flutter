import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Каталог практик — статичный, своих данных не загружает.
class ActivitiesHubScreen extends StatelessWidget {
  const ActivitiesHubScreen({super.key});

  static const _practices = [
    ('Breathe', 'A 2-minute moment of calm', Icons.air, Colors.lightBlue),
    ('Meditation', 'Clear your mind', Icons.self_improvement, Colors.purple),
    ('Focus Timer', 'Work and rest effectively', Icons.timer, Colors.redAccent),
    ('Calm Canvas', 'A moment of creative peace', Icons.brush, Colors.orange),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Практики')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/home/new-session'),
        icon: const Icon(Icons.add),
        label: const Text('Новая сессия'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (title, subtitle, icon, color) in _practices)
            Card(
              color: color.withValues(alpha: 0.25),
              child: ListTile(
                leading: Icon(icon, color: color),
                title: Text(title),
                subtitle: Text(subtitle),
              ),
            ),
        ],
      ),
    );
  }
}
