import 'package:drift/drift.dart';

/// 非 FFI 平台（如 Web）的兜底实现。
///
/// 当前项目目标平台为 iOS / Android，Web 暂不支持。
/// 若将来需要 Web，需改用 drift 的 WASM 后端并单独实现连接。
QueryExecutor openEncryptedDatabase({
  required String name,
  required String password,
}) {
  throw UnsupportedError(
    '当前平台不支持本地数据库，请使用 iOS / Android 运行。',
  );
}
