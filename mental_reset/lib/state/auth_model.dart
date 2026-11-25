import 'package:flutter/foundation.dart';

import '../core/result.dart';
import '../data/api_client.dart';
import '../data/token_store.dart';

/// Состояние аутентификации: есть ли сохранённый JWT.
class AuthModel extends ChangeNotifier {
  AuthModel(this._api, this._tokens);

  final ApiClient _api;
  final TokenStore _tokens;

  bool get isLoggedIn => _tokens.token != null;

  /// Запуск: getString — восстановить токен из prefs.
  Future<void> restore() async {
    await _tokens.load();
    notifyListeners();
  }

  Future<Result<void>> login(String email, String password, {bool register = false}) async {
    final r = await _api.send<String>('POST', register ? '/auth/register' : '/auth/login',
        body: {'email': email, 'password': password}, parse: (j) => j['token'] as String);
    switch (r) {
      case Ok(:final value):
        await _tokens.save(value); // login → setString
        notifyListeners();
        return const Ok(null);
      case Err(:final message):
        return Err(message);
    }
  }

  Future<void> logout() async {
    await _tokens.clear();
    notifyListeners();
  }

  /// Вызывается ApiClient-ом при 401.
  void expired() => notifyListeners();
}
