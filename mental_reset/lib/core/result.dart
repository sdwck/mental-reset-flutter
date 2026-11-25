/// Результат операции репозитория (лекция C8).
/// sealed — компилятор заставляет обработать оба случая в switch.
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  final T value;
  const Ok(this.value);
}

final class Err<T> extends Result<T> {
  final String message;
  const Err(this.message);
}
