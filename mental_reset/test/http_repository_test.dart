// Интеграционный тест L5: требует запущенный backend на http://localhost:5080
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_reset/core/result.dart';
import 'package:mental_reset/data/api_client.dart';
import 'package:mental_reset/data/http_session_repository.dart';
import 'package:mental_reset/data/session.dart';
import 'package:mental_reset/state/auth_model.dart';
import 'package:mental_reset/data/token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  HttpOverrides.global = null; // разрешить реальную сеть в тесте

  test('login + CRUD через HttpSessionRepository', () async {
    SharedPreferences.setMockInitialValues({});
    final tokens = TokenStore();
    final api = ApiClient(tokens);
    final auth = AuthModel(api, tokens);
    final repo = HttpSessionRepository(api);

    final email = 'flutter${DateTime.now().millisecondsSinceEpoch}@pam.md';
    expect(await auth.login(email, 'secret1', register: true), isA<Ok<void>>());
    expect(tokens.token, isNotNull);
    expect((await SharedPreferences.getInstance()).getString('jwt_token'), tokens.token);

    final created = await repo.create(MindfulSession(
        id: '', title: 'Тест из Flutter', practiceType: 'meditation', durationMin: 12,
        notes: 'integration', soundEnabled: true, createdAt: DateTime.now()));
    expect(created, isA<Ok<MindfulSession>>());
    final id = (created as Ok<MindfulSession>).value.id;

    final list = await repo.getAll(page: 1, pageSize: 10, query: 'Flutter');
    expect((list as Ok<List<MindfulSession>>).value.single.id, id);

    expect(await repo.delete(id), isA<Ok<void>>());
    expect(await repo.getById(id), isA<Err<MindfulSession>>()); // 404 → Err

    await tokens.clear();
    final unauth = await repo.getAll();
    expect(unauth, isA<Err<List<MindfulSession>>>()); // 401 → Err + токен стёрт
  });
}
