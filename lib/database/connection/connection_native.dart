import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

/// 打开本地加密数据库。
///
/// **为什么用 NativeDatabase 而不是 createInBackground**：
/// `createInBackground` 会在独立 isolate 中打开数据库，而 `open.overrideFor`
/// 设置的 SQLCipher 动态库查找逻辑是**按 isolate 隔离的**，在子 isolate 中会失效，
/// 导致 Android 上无法加载 libsqlcipher。这里在主 isolate 直接打开以规避该问题；
/// 记账数据量小（万级行、单次查询毫秒级），主 isolate 读写完全够用。
///
/// - Android：SQLCipher 以 .so 形式提供，需显式注册打开方式
/// - iOS / macOS：SQLCipher 通过 CocoaPods 静态链接进 App，进程内符号可直接解析
QueryExecutor openEncryptedDatabase({
  required String name,
  required String password,
}) {
  if (Platform.isAndroid) {
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
  }

  return LazyDatabase(() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File(p.join(dir.path, name));

    return NativeDatabase(
      file,
      setup: (Database db) {
        // 单引号需转义，避免密码中的特殊字符破坏 SQL
        final String escaped = password.replaceAll("'", "''");
        db.execute("PRAGMA key = '$escaped'");
        // 与 SQLCipher 4 默认参数保持一致，保证跨版本可打开
        db.execute('PRAGMA cipher_compatibility = 4');
      },
    );
  });
}
