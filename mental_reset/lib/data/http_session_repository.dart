import '../core/result.dart';
import 'api_client.dart';
import 'session.dart';
import 'session_repository.dart';

/// L5: та же абстракция SessionRepository, но на HTTP к собственному backend-у.
class HttpSessionRepository implements SessionRepository {
  HttpSessionRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<List<MindfulSession>>> getAll({int page = 1, int pageSize = 20, String? query}) =>
      _api.send('GET', '/sessions',
          query: {
            'page': '$page',
            'pageSize': '$pageSize',
            if (query != null && query.isNotEmpty) 'q': query,
          },
          // Пагинированный конверт: { items, page, pageSize, total }
          parse: (j) => [
                for (final e in (j['items'] as List)) MindfulSession.fromJson(e as Map<String, dynamic>)
              ]);

  @override
  Future<Result<MindfulSession>> getById(String id) => _api.send('GET', '/sessions/$id',
      parse: (j) => MindfulSession.fromJson(j as Map<String, dynamic>));

  @override
  Future<Result<MindfulSession>> create(MindfulSession draft) => _api.send('POST', '/sessions',
      body: draft.toJson(), parse: (j) => MindfulSession.fromJson(j as Map<String, dynamic>));

  @override
  Future<Result<MindfulSession>> update(MindfulSession session) =>
      _api.send('PUT', '/sessions/${session.id}',
          body: session.toJson(), parse: (j) => MindfulSession.fromJson(j as Map<String, dynamic>));

  @override
  Future<Result<void>> delete(String id) =>
      _api.send<void>('DELETE', '/sessions/$id', parse: (_) {});
}
