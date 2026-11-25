import '../core/result.dart';
import 'session.dart';
import 'session_repository.dart';

/// Mock-реализация: данные в памяти, искусственная задержка
/// и переключаемая авария (shouldFail читается при каждом вызове).
class MockSessionRepository implements SessionRepository {
  MockSessionRepository({
    required bool Function() shouldFail,
    this.delay = const Duration(milliseconds: 700),
  }) : _shouldFail = shouldFail;

  final bool Function() _shouldFail;
  final Duration delay;
  int _nextId = 4;

  final List<MindfulSession> _db = [
    MindfulSession(
      id: '1',
      title: 'Утреннее дыхание',
      practiceType: 'breathe',
      durationMin: 5,
      notes: 'Спокойно начать день',
      soundEnabled: false,
      createdAt: DateTime(2026, 11, 20, 8, 30),
    ),
    MindfulSession(
      id: '2',
      title: 'Фокус на лабах',
      practiceType: 'timer',
      durationMin: 25,
      notes: 'Один помидор без телефона',
      soundEnabled: true,
      createdAt: DateTime(2026, 11, 22, 15, 0),
    ),
    MindfulSession(
      id: '3',
      title: 'Вечерняя перезагрузка',
      practiceType: 'meditation',
      durationMin: 15,
      notes: 'Снять напряжение после работы',
      soundEnabled: true,
      createdAt: DateTime(2026, 11, 24, 22, 10),
    ),
  ];

  Future<Result<T>> _run<T>(T Function() op) async {
    await Future.delayed(delay);
    if (_shouldFail()) {
      return const Err('Сервер недоступен (симуляция аварии). Попробуйте ещё раз.');
    }
    try {
      return Ok(op());
    } on StateError catch (e) {
      return Err(e.message);
    }
  }

  MindfulSession _find(String id) => _db.firstWhere(
        (s) => s.id == id,
        orElse: () => throw StateError('Сессия #$id не найдена'),
      );

  @override
  Future<Result<List<MindfulSession>>> getAll({int page = 1, int pageSize = 20, String? query}) =>
      _run(() => List.unmodifiable(_db.reversed
          .where((s) => query == null || s.title.toLowerCase().contains(query.toLowerCase()))
          .skip((page - 1) * pageSize)
          .take(pageSize)));

  @override
  Future<Result<MindfulSession>> getById(String id) => _run(() => _find(id));

  @override
  Future<Result<MindfulSession>> create(MindfulSession draft) => _run(() {
        final created = MindfulSession(
          id: '${_nextId++}',
          title: draft.title,
          practiceType: draft.practiceType,
          durationMin: draft.durationMin,
          notes: draft.notes,
          soundEnabled: draft.soundEnabled,
          createdAt: DateTime.now(),
        );
        _db.add(created);
        return created;
      });

  @override
  Future<Result<MindfulSession>> update(MindfulSession session) => _run(() {
        final i = _db.indexWhere((s) => s.id == session.id);
        if (i < 0) throw StateError('Сессия #${session.id} не найдена');
        _db[i] = session;
        return session;
      });

  @override
  Future<Result<void>> delete(String id) => _run(() {
        _db.remove(_find(id));
      });
}
