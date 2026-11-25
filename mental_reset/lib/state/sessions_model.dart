import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../core/result.dart';
import '../data/session.dart';
import '../data/session_repository.dart';

enum LoadStatus { loading, data, error }

/// Разделяемое состояние темы: список сессий.
/// Repository приходит через конструктор (внедрение зависимости).
class SessionsModel extends ChangeNotifier {
  SessionsModel(this._repo);

  final SessionRepository _repo;

  List<MindfulSession> _items = [];
  LoadStatus _status = LoadStatus.loading;
  String? _error;

  /// Наружу — только read-only представление коллекции.
  UnmodifiableListView<MindfulSession> get items => UnmodifiableListView(_items);
  LoadStatus get status => _status;
  String? get error => _error;

  int get totalMinutes => _items.fold(0, (sum, s) => sum + s.durationMin);

  MindfulSession? byId(String id) {
    for (final s in _items) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();

    switch (await _repo.getAll()) {
      case Ok(:final value):
        _items = [...value];
        _status = LoadStatus.data;
      case Err(:final message):
        _error = message;
        _status = LoadStatus.error;
    }
    notifyListeners();
  }

  /// Загрузка одной сессии — для экрана деталей (свои три состояния).
  Future<Result<MindfulSession>> fetch(String id) => _repo.getById(id);

  Future<Result<MindfulSession>> add(MindfulSession draft) async {
    final r = await _repo.create(draft);
    if (r case Ok(:final value)) {
      _items = [value, ..._items];
      notifyListeners();
    }
    return r;
  }

  Future<Result<MindfulSession>> edit(MindfulSession session) async {
    final r = await _repo.update(session);
    if (r case Ok(:final value)) {
      _items = [for (final s in _items) s.id == value.id ? value : s];
      notifyListeners();
    }
    return r;
  }

  Future<Result<void>> remove(String id) async {
    final r = await _repo.delete(id);
    if (r is Ok) {
      _items = _items.where((s) => s.id != id).toList();
      notifyListeners();
    }
    return r;
  }
}
