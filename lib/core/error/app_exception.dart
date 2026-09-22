/// 模块：core / error
/// 职责：定义全局异常基类与所有业务异常。
/// 依赖：无（core 最底层）。
/// 约束：
///   1. 此文件被所有模块依赖，禁止 import 任何 modules/ 下的文件。
///   2. 所有业务异常必须继承 [AppException]，便于统一捕获与日志。
///   3. 不直接继承 Exception，避免与 Dart 内置异常混淆。
library;

/// 应用异常基类。
///
/// 生命周期：一次性对象，抛出后即被捕获或向上传递。
/// 可变性：全字段 final，不可变。
abstract class AppException implements Exception {
  /// 人类可读的错误消息，可直接展示给用户。
  final String message;

  /// 可选的原始错误对象（如底层数据库异常），仅用于日志排查。
  final Object? cause;

  const AppException(this.message, {this.cause});

  @override
  String toString() =>
      '$runtimeType: $message${cause != null ? ' | cause: $cause' : ''}';
}

/// 实体不存在。
///
/// 使用场景：按 id 查询时目标行不存在。
class NotFoundException extends AppException {
  const NotFoundException(super.message, {super.cause});
}

/// 数据校验失败。
///
/// 使用场景：入参不符合业务规则（如 id 为空、名称超长）。
class ValidationException extends AppException {
  const ValidationException(super.message, {super.cause});
}

/// 数据库操作失败。
///
/// 使用场景：SQL 执行异常、连接失败等底层错误。
/// 命名带 App 前缀，避免与 sqflite 的 DatabaseException 冲突。
class AppDatabaseException extends AppException {
  const AppDatabaseException(super.message, {super.cause});
}