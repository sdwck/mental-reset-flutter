import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_model.dart';
import '../state/debug_settings.dart';
import '../state/sessions_model.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Consumer перестраивает только этот кусок, а не весь экран.
          Consumer<SessionsModel>(
            builder: (context, model, _) => Card(
              child: ListTile(
                leading: const Icon(Icons.insights),
                title: Text('Сессий: ${model.items.length}'),
                subtitle: Text('Время осознанности: ${model.totalMinutes} мин'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Выйти'),
            onTap: () => context.read<AuthModel>().logout(),
          ),
          Consumer<DebugSettings>(
            builder: (context, debug, _) => SwitchListTile(
              title: const Text('Симулировать аварию сервера'),
              subtitle: const Text('Mock-репозиторий будет возвращать Err'),
              value: debug.simulateFailure,
              onChanged: (v) => context.read<DebugSettings>().setSimulateFailure(v),
            ),
          ),
        ],
      ),
    );
  }
}
