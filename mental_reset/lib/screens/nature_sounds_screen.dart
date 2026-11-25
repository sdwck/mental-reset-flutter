import 'package:flutter/material.dart';

/// Пример ЭФЕМЕРНОГО состояния: выбранный звук нужен только этому экрану,
/// поэтому хватает setState — Provider здесь был бы лишним.
class NatureSoundsScreen extends StatefulWidget {
  const NatureSoundsScreen({super.key});

  @override
  State<NatureSoundsScreen> createState() => _NatureSoundsScreenState();
}

class _NatureSoundsScreenState extends State<NatureSoundsScreen> {
  static const _sounds = [
    ('Rain', Icons.grain),
    ('Forest', Icons.forest),
    ('Waves', Icons.waves),
    ('Fire', Icons.local_fire_department),
  ];
  String? _playing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nature Sounds')),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        children: [
          for (final (name, icon) in _sounds)
            Card(
              color: _playing == name ? Colors.orange.withValues(alpha: 0.6) : null,
              child: InkWell(
                onTap: () => setState(() => _playing = _playing == name ? null : name),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [Icon(icon, size: 36), const SizedBox(height: 8), Text(name)],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
