import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/result.dart';
import 'token_store.dart';

/// Базовый адрес backend-а. Android-эмулятор: --dart-define=API_URL=http://10.0.2.2:5080
const apiBaseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:5080');

/// Общий HTTP-клиент. Три слоя отказа (C8) превращаются в Err(msg):
/// 1) транспорт — нет сети / таймаут;
/// 2) протокол — код ответа не 2xx (401 стирает токен);
/// 3) данные — тело не парсится в ожидаемую модель.
class ApiClient {
  ApiClient(this._tokens, {this.onUnauthorized, http.Client? client})
      : _http = client ?? http.Client();

  final TokenStore _tokens;
  final http.Client _http;
  final void Function()? onUnauthorized;

  Future<Result<T>> send<T>(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    required T Function(dynamic json) parse,
  }) async {
    final uri = Uri.parse('$apiBaseUrl$path').replace(queryParameters: query);
    final headers = {
      'Content-Type': 'application/json',
      if (_tokens.token != null) 'Authorization': 'Bearer ${_tokens.token}',
    };

    final http.Response res;
    try {
      final req = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      res = await http.Response.fromStream(
          await _http.send(req).timeout(const Duration(seconds: 8)));
    } on TimeoutException {
      return const Err('Сервер не отвечает (таймаут)');
    } catch (_) {
      return const Err('Нет связи с сервером. Проверьте, что backend запущен.');
    }

    if (res.statusCode == 401) {
      await _tokens.clear();
      onUnauthorized?.call();
      return const Err('Сессия истекла, войдите снова');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Err(_errorText(res));
    }

    try {
      final decoded = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
      return Ok(parse(decoded));
    } catch (_) {
      return const Err('Некорректный ответ сервера');
    }
  }

  String _errorText(http.Response res) {
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      if (j is Map && j['error'] is String) return '${j['error']} (HTTP ${res.statusCode})';
    } catch (_) {}
    return 'Ошибка сервера (HTTP ${res.statusCode})';
  }
}
