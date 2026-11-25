"""Builds the L4 report (HTML -> PDF via headless Edge) from real source files and real screenshots."""
import html, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
APP = ROOT.parent / "mental_reset"
SHOTS = ROOT / "screenshots"
EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"


def code(rel, start=None, end=None):
    lines = (APP / rel).read_text(encoding="utf-8").splitlines()
    if start:
        i = next(n for n, l in enumerate(lines) if start in l)
        j = next((n for n, l in enumerate(lines[i + 1:], i + 1) if end and end in l), len(lines) - 1) if end else len(lines) - 1
        lines = lines[i:j + 1]
    return f'<p class="cap">Файл <code>{rel}</code></p><pre>{html.escape(chr(10).join(lines))}</pre>'


def fig(name, n, caption):
    p = SHOTS / name
    if not p.exists():
        return ""
    return f'<figure><img src="{p.as_uri()}"><figcaption>Рисунок {n} — {caption}</figcaption></figure>'


def table(head, rows):
    h = "".join(f"<th>{c}</th>" for c in head)
    b = "".join("<tr>" + "".join(f"<td>{c}</td>" for c in r) + "</tr>" for r in rows)
    return f"<table><tr>{h}</tr>{b}</table>"


CSS = """
@page { size: A4; margin: 2cm 2cm 2cm 2.5cm; }
body { font-family: Calibri, 'Segoe UI', sans-serif; font-size: 11.5pt; line-height: 1.45; color: #111; }
.title { height: 25cm; display: flex; flex-direction: column; justify-content: space-between; text-align: center; page-break-after: always; }
.title h1 { color: #1b2a4a; font-size: 22pt; margin: 0; }
.right { text-align: left; margin-left: 55%; }
h2 { color: #1b2a4a; font-size: 15pt; margin-top: 22px; page-break-after: avoid; }
h3 { color: #2a4170; font-size: 12.5pt; page-break-after: avoid; }
pre { background: #f4f6fa; border: 1px solid #dde3ee; padding: 8px 10px; font-family: Consolas, monospace; font-size: 8.6pt; line-height: 1.3; white-space: pre-wrap; page-break-inside: auto; }
code { font-family: Consolas, monospace; font-size: 10pt; }
.cap { font-size: 9.5pt; color: #555; margin: 8px 0 2px; }
table { border-collapse: collapse; width: 100%; margin: 8px 0; font-size: 10pt; page-break-inside: avoid; }
th { background: #1b2a4a; color: #fff; text-align: left; padding: 6px; }
td { border-bottom: 1px solid #dde3ee; padding: 6px; vertical-align: top; }
tr:nth-child(even) td { background: #f2f5fa; }
figure { text-align: center; page-break-inside: avoid; margin: 14px 0; }
figure img { max-height: 13cm; max-width: 100%; border: 1px solid #ccc; }
figcaption { font-style: italic; font-size: 9.5pt; color: #444; margin-top: 4px; }
.row { display: flex; gap: 12px; justify-content: center; page-break-inside: avoid; }
.row figure img { max-height: 11cm; }
"""

TITLE = """
<div class="title">
 <div><b>ТЕХНИЧЕСКИЙ УНИВЕРСИТЕТ МОЛДОВЫ</b><br>Факультет вычислительной техники, информатики и микроэлектроники (FCIM)<br>Департамент программной инженерии и автоматики</div>
 <div><h1>ОТЧЁТ</h1><p style="font-size:14pt"><b>по лабораторной работе № 4</b></p>
 <p><i>«State management и паттерн Repository с mock-данными»</i></p>
 <p>Дисциплина: Программирование мобильных приложений (PAM)</p>
 <p><b>Тема проекта: Mental Reset — мультифункциональное мобильное приложение для релаксации, фокуса, медитации и арт-терапии</b></p></div>
 <div class="right">Выполнил: студент группы TI-235<br><b>Bobeico Vladislav</b><br><br>Проверил: унив. лектор<br><b>Leah Arcadie</b></div>
 <div>Кишинёв 2026</div>
</div>
"""


def body():
    n = iter(range(1, 100))
    parts = [TITLE]
    parts.append("<h2>Цель работы</h2><p>Перевести приложение Mental Reset с локального состояния экранов на разделяемое состояние "
                 "(<code>ChangeNotifier</code> + <code>provider</code>), выделить доступ к данным в интерфейс Repository c результатом "
                 "<code>Future&lt;Result&lt;T&gt;&gt;</code>, реализовать его на mock-данных с задержкой и переключаемой аварией, "
                 "внедрить репозиторий в модель через конструктор и показать три состояния (загрузка / данные / ошибка с retry) "
                 "на экранах, загружающих данные. Сущность темы — <b>сессия осознанности</b> (<code>MindfulSession</code>).</p>")

    parts.append("<h2>1. Таксономия состояния</h2>")
    parts.append(table(["Состояние", "Где живёт", "Инструмент", "Почему"], [
        ["Список сессий, статус загрузки, ошибка", "<code>SessionsModel</code>", "ChangeNotifier + Provider", "Нужен Дневнику, Деталям, Профилю и форме"],
        ["Переключатель аварии mock-сервера", "<code>DebugSettings</code>", "ChangeNotifier + Provider", "Меняется в Профиле, читается репозиторием"],
        ["Выбранный звук", "<code>_NatureSoundsScreenState</code>", "setState", "Нужен только экрану «Звуки»"],
        ["Поля формы, флаг <code>_saving</code>", "<code>_SessionFormScreenState</code>", "setState + TextEditingController", "Живут, пока открыта форма"],
        ["Текущая вкладка", "go_router <code>StatefulNavigationShell</code>", "маршрутизатор", "Навигация, а не данные"],
    ]))

    parts.append("<h2>2. Sealed Result и интерфейс Repository</h2><p>Репозиторий не выбрасывает исключения наружу: каждый метод "
                 "возвращает <code>Ok</code> или <code>Err</code>. Благодаря модификатору <code>sealed</code> выражение "
                 "<code>switch</code> по результату обязано обработать оба случая.</p>")
    parts.append(code("lib/core/result.dart"))
    parts.append(code("lib/data/session_repository.dart"))

    parts.append("<h2>3. Mock-реализация: задержка и переключаемая авария</h2><p>Данные хранятся в списке в памяти. Каждый вызов "
                 "ждёт 700 мс (<code>Future.delayed</code>), затем проверяет <code>shouldFail()</code> — функцию, читающую флаг "
                 "<code>DebugSettings.simulateFailure</code>. Если флаг включён, возвращается <code>Err</code>.</p>")
    parts.append(code("lib/data/mock_session_repository.dart", "Future<Result<T>> _run", "orElse"))

    parts.append("<h2>4. Модель SessionsModel</h2><p>Коллекция наружу отдаётся только как <code>UnmodifiableListView</code>; "
                 "каждая мутация (<code>load</code>, <code>add</code>, <code>edit</code>, <code>remove</code>) заканчивается "
                 "<code>notifyListeners()</code>. Репозиторий приходит через конструктор.</p>")
    parts.append(code("lib/state/sessions_model.dart", "class SessionsModel", None))

    parts.append("<h2>5. Корень композиции</h2><p><code>main.dart</code> — единственное место, где выбирается реализация "
                 "<code>SessionRepository</code>. Модель создаётся фабрикой в <code>create</code>, поэтому Provider сам "
                 "управляет её жизненным циклом. На L5 изменится только строка с <code>MockSessionRepository</code>.</p>")
    parts.append(code("lib/main.dart", "void main()", "^"))

    parts.append("<h2>6. watch / read / Consumer</h2>")
    parts.append(table(["Приём", "Где используется", "Зачем"], [
        ["<code>context.watch&lt;SessionsModel&gt;()</code>", "<code>JournalScreen.build</code>", "Подписка: список перерисовывается после каждой мутации"],
        ["<code>context.read&lt;SessionsModel&gt;()</code>", "onRetry, onRefresh, удаление, submit формы", "Вызов метода без подписки в callback-ах"],
        ["<code>Consumer&lt;SessionsModel&gt;</code>", "Карточка статистики в Профиле", "Перестраивается только карточка, а не весь экран"],
        ["<code>context.select</code>", "Детали сессии", "Подписка только на свою запись"],
        ["<code>ValueKey(s.id)</code>", "Элементы списка с Dismissible", "Стабильная идентичность при удалении"],
    ]))

    parts.append("<h2>7. Три состояния экрана</h2><p>Дневник рисует состояние по <code>model.status</code>, экран деталей сам "
                 "загружает запись через <code>getById</code> и показывает свои три состояния через <code>FutureBuilder</code>.</p>")
    parts.append(code("lib/screens/journal_screen.dart", "final Widget body", "LoadStatus.data"))
    parts.append('<div class="row">' + fig("01_loading.png", next(n), "Дневник: загрузка") +
                 fig("02_data.png", next(n), "Дневник: данные") + "</div>")
    parts.append('<div class="row">' + fig("03_fail_toggle.png", next(n), "Профиль: включена симуляция аварии") +
                 fig("04_error.png", next(n), "Дневник: ошибка с кнопкой «Повторить»") + "</div>")
    parts.append(fig("05_detail.png", next(n), "Детали сессии, загруженные по id"))

    parts.append("<h2>8. Форма пишет через Repository</h2><p>Форма из L3 стала <code>SessionFormScreen</code> (создание и "
                 "редактирование). Валидный submit вызывает <code>context.read&lt;SessionsModel&gt;().add(...)</code>; "
                 "при <code>Ok</code> форма закрывается, а Дневник и Профиль обновляются сами, потому что подписаны на модель. "
                 "При <code>Err</code> показывается SnackBar с действием «Повторить».</p>")
    parts.append(code("lib/screens/session_form_screen.dart", "Future<void> _submit", "@override\n"[:9]))
    parts.append('<div class="row">' + fig("06_form.png", next(n), "Заполненная форма новой сессии") +
                 fig("07_after_add.png", next(n), "Новая сессия сразу появилась в Дневнике") + "</div>")
    parts.append(fig("08_profile_stats.png", next(n), "Профиль: статистика обновилась без ручного обновления"))

    parts.append("<h2>9. Границы L4</h2><p>Сети нет: данные mock-репозитория живут в памяти, и после перезапуска приложения "
                 "состояние возвращается к исходным трём сессиям — это контракт L4. Реальный backend подключается на L5 "
                 "заменой реализации в корне композиции, локальное сохранение — материал L6. Аутентификация остаётся "
                 "локальной валидацией из L3.</p>")

    parts.append("<h2>Вывод</h2><ol>"
                 "<li>Разделено эфемерное (setState) и разделяемое (ChangeNotifier + Provider) состояние.</li>"
                 "<li>Модель <code>SessionsModel</code> отдаёт read-only коллекцию и вызывает <code>notifyListeners()</code> при каждой мутации.</li>"
                 "<li>Определён интерфейс <code>SessionRepository</code> с CRUD на <code>Future&lt;Result&lt;T&gt;&gt;</code> и sealed Result.</li>"
                 "<li>Mock-реализация имитирует задержку сети и переключаемую аварию.</li>"
                 "<li>Репозиторий внедряется через конструктор; реализация выбирается только в <code>main.dart</code>.</li>"
                 "<li>Экраны с данными показывают загрузку, данные и ошибку с повтором; форма пишет через репозиторий, подписанные экраны обновляются автоматически.</li></ol>")
    return "".join(parts)


def main():
    out_html = ROOT / "L4_report.html"
    out_html.write_text(f"<!doctype html><html><head><meta charset='utf-8'><style>{CSS}</style></head><body>{body()}</body></html>", encoding="utf-8")
    out_pdf = ROOT / "PAM_L4_BobeicoVladislav.pdf"
    subprocess.run([EDGE, "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
                    f"--print-to-pdf={out_pdf}", out_html.as_uri()], check=True, capture_output=True)
    print(out_pdf, out_pdf.stat().st_size)


if __name__ == "__main__":
    main()
