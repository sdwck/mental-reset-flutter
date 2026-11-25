import '../core/result.dart';
import 'session.dart';

/// Контракт хранилища сессий. Экраны и модели знают только этот интерфейс.
/// L4: реализация на mock-данных. L5: HttpSessionRepository —
/// меняется лишь корень композиции (main.dart).
abstract interface class SessionRepository {
  /// page / pageSize / query — опциональные именованные параметры (L5):
  /// старые вызовы getAll() продолжают работать без изменений.
  Future<Result<List<MindfulSession>>> getAll({int page = 1, int pageSize = 20, String? query});
  Future<Result<MindfulSession>> getById(String id);
  Future<Result<MindfulSession>> create(MindfulSession draft);
  Future<Result<MindfulSession>> update(MindfulSession session);
  Future<Result<void>> delete(String id);
}
