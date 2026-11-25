"""Builds the L5 report PDF from real backend/app sources, real test output and the real git diff."""
import html, subprocess
from pathlib import Path

import build_report as b

ROOT = b.ROOT
PAM = ROOT.parent


def src(path, start=None, end=None):
    lines = (PAM / path).read_text(encoding="utf-8").splitlines()
    if start:
        i = next(n for n, l in enumerate(lines) if start in l)
        j = next((n for n, l in enumerate(lines[i + 1:], i + 1) if end and end in l), len(lines) - 1) if end else len(lines) - 1
        lines = lines[i:j + 1]
    return f'<p class="cap">Файл <code>{path}</code></p><pre>{html.escape(chr(10).join(lines))}</pre>'


def pre(text, cap):
    return f'<p class="cap">{cap}</p><pre>{html.escape(text)}</pre>'


TITLE = b.TITLE.replace("№ 4", "№ 5").replace("«State management и паттерн Repository с mock-данными»", "«Интеграция с собственным backend-ом»")


def body(contract_out, test_out, diff_stat, main_diff):
    p = [TITLE]
    p.append("<h2>Цель работы</h2><p>Поднять собственный backend, расширить его сущностью темы, связать аутентификацию "
             "с JWT в <code>shared_preferences</code>, реализовать <code>HttpSessionRepository</code> поверх интерфейса из L4 "
             "и заменить mock-реализацию только в корне композиции.</p>")

    p.append("<h2>1. Backend: ASP.NET Core Minimal API + SQLite</h2><p>Выбранный язык — C# (.NET 10). База шаблона — "
             "аутентификация и CRUD <code>/notes</code>; расширение темы — таблица <code>Sessions</code> и CRUD "
             "<code>/sessions</code> по образцу notes; загрузка файлов <code>POST /files</code> (multipart). "
             "Все защищённые маршруты требуют заголовок <code>Authorization: Bearer &lt;JWT&gt;</code>.</p>")
    p.append(b.table(["Метод", "Маршрут", "Ответ"], [
        ["GET", "/health", "200 {status}"],
        ["POST", "/auth/register, /auth/login", "201/200 {token} · 400 · 401 · 409"],
        ["GET", "/sessions?page&amp;pageSize&amp;q", "200 {items, page, pageSize, total}"],
        ["GET / PUT / DELETE", "/sessions/{id}", "200 / 200 / 204 · 404"],
        ["POST", "/sessions", "201 · 400 {error}"],
        ["CRUD", "/notes …", "как sessions (база шаблона)"],
        ["POST", "/files (multipart)", "201 {id, fileName, size, url}"],
    ]))
    p.append(src("backend/src/Program.cs", "// ---------- Sessions", "// ---------- Files"))

    p.append("<h2>2. Проверка контракта через curl</h2><p>Скрипт <code>backend/tests/contract.sh</code> проходит "
             "регистрацию, логин, 401 без токена, CRUD, валидацию (400), пагинацию, поиск, загрузку файла и 404 после удаления.</p>")
    p.append(pre(contract_out, "Вывод <code>bash tests/contract.sh</code>"))

    p.append("<h2>3. JWT в shared_preferences</h2><p>Поток C9: при успешном логине токен сохраняется "
             "(<code>setString</code>), при запуске приложения восстанавливается (<code>getString</code>), при ответе 401 "
             "удаляется (<code>remove</code>), и маршрутизатор перенаправляет на <code>/auth</code>.</p>")
    p.append(src("mental_reset/lib/data/token_store.dart", "class TokenStore", None))
    p.append(src("mental_reset/lib/state/auth_model.dart", "Future<Result<void>> login", "Future<void> logout"))

    p.append("<h2>4. HttpSessionRepository и три слоя отказа</h2><p>Все сетевые вызовы идут через <code>ApiClient.send</code>, "
             "который сводит отказы к <code>Err(msg)</code>: транспорт (нет сети, таймаут), протокол (код не 2xx, 401 стирает "
             "токен), данные (тело не разбирается). Репозиторий реализует тот же интерфейс <code>SessionRepository</code>, что и mock.</p>")
    p.append(src("mental_reset/lib/data/api_client.dart", "Future<Result<T>> send", "String _errorText"))
    p.append(src("mental_reset/lib/data/http_session_repository.dart", "class HttpSessionRepository", None))
    p.append(src("mental_reset/lib/data/session.dart", "factory MindfulSession.fromJson", "MindfulSession copyWith"))

    p.append("<h2>5. Замена mock только в корне композиции</h2><p>Изменения относительно L4 (<code>git diff --stat</code>). "
             "Экраны, загружающие данные (<code>journal_screen.dart</code>, <code>session_detail_screen.dart</code>, "
             "<code>session_form_screen.dart</code>), и модель <code>SessionsModel</code> не изменены. Изменены только корень "
             "композиции <code>main.dart</code>, слой данных и экраны входа/профиля — по заданию об аутентификации.</p>")
    p.append(pre(diff_stat, "git diff --stat (L4 → L5)"))
    p.append(pre(main_diff, "git diff lib/main.dart"))

    p.append("<h2>6. Пагинация и поиск</h2><p><code>getAll</code> получил опциональные именованные параметры "
             "<code>page</code>, <code>pageSize</code>, <code>query</code> со значениями по умолчанию, поэтому существующий вызов "
             "<code>getAll()</code> в <code>SessionsModel.load()</code> не изменился. Mock-реализация поддерживает те же параметры.</p>")
    p.append(src("mental_reset/lib/data/session_repository.dart", "abstract interface class", None))

    p.append("<h2>7. Интеграционный тест клиента</h2><p><code>test/http_repository_test.dart</code> работает с запущенным "
             "backend-ом: регистрация, проверка токена в prefs, create, поиск, delete, 404 → Err, 401 → Err.</p>")
    p.append(pre(test_out, "Вывод <code>flutter test</code>"))

    p.append("<h2>8. Границы L5</h2><p>Офлайн-кэша нет: если backend остановлен, экран показывает ошибку «Нет связи с сервером» "
             "с кнопкой «Повторить», а не вчерашние данные. Это контракт L5; локальное хранение данных — материал L6. "
             "Секрет JWT по умолчанию, открытый CORS и незашифрованные prefs — лабораторная конфигурация. Сервер работает "
             "локально (<code>dotnet run --urls http://localhost:5080</code>); Android-эмулятор обращается по "
             "<code>--dart-define=API_URL=http://10.0.2.2:5080</code>.</p>")

    p.append("<h2>Вывод</h2><ol><li>Поднят собственный backend на ASP.NET Core с JWT, SQLite, пагинацией, поиском и загрузкой файлов; "
             "контракт проверен curl-скриптом.</li><li>Добавлена сущность темы <code>sessions</code> по образцу <code>notes</code>.</li>"
             "<li>Аутентификация работает с backend-ом, токен хранится в <code>shared_preferences</code>.</li>"
             "<li><code>HttpSessionRepository</code> реализует интерфейс L4, все отказы сведены к <code>Err</code>.</li>"
             "<li>Mock заменён только в корне композиции; экраны данных и модель не тронуты.</li></ol>")
    return "".join(p)


def main():
    contract_out = (ROOT / "l5_contract_output.txt").read_text(encoding="utf-8")
    test_out = (ROOT / "l5_flutter_test_output.txt").read_text(encoding="utf-8")
    diff_stat = (ROOT / "l5_diff_stat.txt").read_text(encoding="utf-8")
    main_diff = (ROOT / "l5_main_diff.txt").read_text(encoding="utf-8")
    out_html = ROOT / "L5_report.html"
    out_html.write_text(f"<!doctype html><html><head><meta charset='utf-8'><style>{b.CSS}</style></head><body>"
                        f"{body(contract_out, test_out, diff_stat, main_diff)}</body></html>", encoding="utf-8")
    out_pdf = ROOT / "PAM_L5_BobeicoVladislav.pdf"
    subprocess.run([b.EDGE, "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
                    f"--print-to-pdf={out_pdf}", out_html.as_uri()], check=True, capture_output=True)
    print(out_pdf, out_pdf.stat().st_size)


if __name__ == "__main__":
    main()
