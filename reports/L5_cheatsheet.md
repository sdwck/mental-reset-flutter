# Шпаргалка к защите L5 (Mental Reset + свой backend)

**Одной фразой:** backend на ASP.NET Core Minimal API (C#, .NET 10, SQLite, JWT) с CRUD `/notes` (база) и `/sessions` (тема), пагинацией, поиском и загрузкой файлов; в приложении `HttpSessionRepository` реализует тот же интерфейс, что mock из L4, и подменяется только в `main.dart`.

## Как запустить на защите
1. Backend: в папке `pam\backend\src` выполнить `dotnet run --urls http://localhost:5080`
2. Проверка контракта: `bash tests/contract.sh` → 15 passed
3. Приложение: в `pam\mental_reset` выполнить `flutter run -d chrome` (эмулятор Android: `--dart-define=API_URL=http://10.0.2.2:5080`)
4. Тест клиента: `flutter test` (backend должен быть запущен)

## Вопросы
**1. Где поменялась реализация?** Только в `main.dart`: `HttpSessionRepository(api)` вместо `MockSessionRepository(...)`. `git diff --stat`: journal, detail, form и `SessionsModel` не тронуты.

**2. Три слоя отказа?** В `ApiClient.send`: транспорт (нет сети/таймаут 8 с) → «Нет связи с сервером»; протокол (не 2xx) → текст из `{error}` + код, 401 → стираем токен и редирект на `/auth`; данные (JSON не разбирается) → «Некорректный ответ сервера». Наружу всегда `Err(msg)`.

**3. Поток токена?** login → `setString('jwt_token')`; запуск → `getString` в `auth.restore()`; 401 → `remove`. Роутер слушает `AuthModel` (`refreshListenable`) и сам кидает на вход.

**4. fromJson/toJson?** `MindfulSession.fromJson` разбирает ответ (id приходит числом → строка). `toJson` отдаёт только поля, которые задаёт клиент; id и createdAt назначает сервер.

**5. Пагинация и поиск не сломали старый код?** `getAll({int page = 1, int pageSize = 20, String? query})` — именованные параметры со значениями по умолчанию, вызов `getAll()` в модели не изменился. Сервер отвечает конвертом `{items, page, pageSize, total}`.

**6. Сервер выключен — что видно?** Экран ошибки с «Повторить». Офлайн-кэша нет — это контракт L5, кэш будет на L6.

**7. Безопасность?** Секрет JWT по умолчанию, CORS открыт, prefs не шифруются, пароль — SHA-256 с солью-константой. Лабораторная конфигурация, не production. (Если спросят, как правильно: BCrypt/PBKDF2 через `PasswordHasher`, секрет из переменной окружения, `flutter_secure_storage`.)

**8. Где файлы?** `POST /files` multipart, до 5 МБ, файл кладётся в `uploads/`, отдаётся `GET /files/{id}`.

## Файлы
- `backend/src/Program.cs` — весь API
- `backend/tests/contract.sh` — тесты контракта
- `lib/data/api_client.dart`, `lib/data/http_session_repository.dart`, `lib/data/token_store.dart`
- `lib/state/auth_model.dart`, `lib/main.dart`, `test/http_repository_test.dart`
