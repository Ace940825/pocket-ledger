import '../errors/failures.dart';

/// 显式结果类型，避免到处 try/catch 掩盖错误。
///
/// 用 Dart 3 sealed class 实现，switch 时编译器会强制穷尽所有分支。
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;

  const factory Result.err(AppFailure error) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  /// 成功时返回值，失败时返回 [fallback]
  T getOrElse(T fallback) => switch (this) {
        Ok<T>(:final T value) => value,
        Err<T>() => fallback,
      };

  /// 成功时返回值，失败时返回 null
  T? getOrNull() => switch (this) {
        Ok<T>(:final T value) => value,
        Err<T>() => null,
      };

  R fold<R>({
    required R Function(T value) onOk,
    required R Function(AppFailure error) onErr,
  }) =>
      switch (this) {
        Ok<T>(:final T value) => onOk(value),
        Err<T>(:final AppFailure error) => onErr(error),
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.error);

  final AppFailure error;
}

/// 把可能抛异常的异步调用包装为 [Result]，避免异常穿透到 UI 层。
Future<Result<T>> guard<T>(Future<T> Function() action) async {
  try {
    return Result<T>.ok(await action());
  } on AppFailure catch (e) {
    return Result<T>.err(e);
  } catch (e, s) {
    return Result<T>.err(DatabaseFailure('操作失败：$e', cause: s));
  }
}
