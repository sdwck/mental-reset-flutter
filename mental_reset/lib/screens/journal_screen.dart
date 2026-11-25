import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/result.dart';
import '../data/session.dart';
import '../state/sessions_model.dart';
import '../widgets/state_views.dart';

/// Дневник: список сессий из общей модели. Три состояния: loading / data / error.
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  Future<void> _delete(BuildContext context, MindfulSession s) async {
    // read — в callback-е: подписка не нужна, только вызов метода.
    final r = await context.read<SessionsModel>().remove(s.id);
    if (!context.mounted) return;
    final text = switch (r) {
      Ok() => 'Сессия «${s.title}» удалена',
      Err(:final message) => 'Не удалось удалить: $message',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    // watch — в build: экран перестраивается при каждом notifyListeners().
    final model = context.watch<SessionsModel>();

    final Widget body = switch (model.status) {
      LoadStatus.loading => const LoadingView(),
      LoadStatus.error => ErrorView(
          message: model.error ?? 'Ошибка',
          onRetry: () => context.read<SessionsModel>().load(),
        ),
      LoadStatus.data => model.items.isEmpty
          ? const Center(child: Text('Пока нет сессий'))
          : RefreshIndicator(
              onRefresh: () => context.read<SessionsModel>().load(),
              child: ListView.builder(
                itemCount: model.items.length,
                itemBuilder: (context, i) {
                  final s = model.items[i];
                  return Dismissible(
                    key: ValueKey(s.id), // ключ по id, а не по индексу
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.redAccent,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete),
                    ),
                    onDismissed: (_) => _delete(context, s),
                    child: ListTile(
                      title: Text(s.title),
                      subtitle: Text(
                          '${practiceTypeLabels[s.practiceType]} · ${s.durationMin} мин'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/journal/session/${s.id}'),
                    ),
                  );
                },
              ),
            ),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Дневник сессий')),
      body: body,
    );
  }
}
