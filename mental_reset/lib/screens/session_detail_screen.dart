import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/result.dart';
import '../data/session.dart';
import '../state/sessions_model.dart';
import '../widgets/state_views.dart';

/// Детали сессии: экран сам загружает запись по id через репозиторий
/// и рисует свои три состояния.
class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  late Future<Result<MindfulSession>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<SessionsModel>().fetch(widget.sessionId);
  }

  @override
  Widget build(BuildContext context) {
    // Если запись отредактировали — берём свежую версию из общей модели.
    final fresh = context.select<SessionsModel, MindfulSession?>(
        (m) => m.byId(widget.sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сессия'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/journal/session/${widget.sessionId}/edit'),
          ),
        ],
      ),
      body: FutureBuilder<Result<MindfulSession>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          return switch (snap.data!) {
            Err(:final message) => ErrorView(
                message: message,
                onRetry: () => setState(_load),
              ),
            Ok(:final value) => _Details(session: fresh ?? value),
          };
        },
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.session});

  final MindfulSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(s.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        ListTile(leading: const Icon(Icons.category), title: Text(practiceTypeLabels[s.practiceType] ?? s.practiceType)),
        ListTile(leading: const Icon(Icons.timer), title: Text('${s.durationMin} мин')),
        ListTile(leading: const Icon(Icons.notes), title: Text(s.notes)),
        ListTile(
          leading: Icon(s.soundEnabled ? Icons.volume_up : Icons.volume_off),
          title: Text(s.soundEnabled ? 'Со звуком' : 'Без звука'),
        ),
      ],
    );
  }
}
