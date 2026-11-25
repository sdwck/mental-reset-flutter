import 'package:shared_preferences/shared_preferences.dart';

/// Хранение JWT (поток C9): login → setString, запуск → getString, 401 → remove.
/// Лабораторная конфигурация: prefs не шифруются.
class TokenStore {
  static const _key = 'jwt_token';
  String? _cached;

  String? get token => _cached;

  Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return _cached = prefs.getString(_key);
  }

  Future<void> save(String token) async {
    _cached = token;
    await (await SharedPreferences.getInstance()).setString(_key, token);
  }

  Future<void> clear() async {
    _cached = null;
    await (await SharedPreferences.getInstance()).remove(_key);
  }
}
