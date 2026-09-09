import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'app.dart';
import 'core/bootstrap.dart';
import 'core/config/env.dart';
import 'database/app_database.dart';
import 'providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 获取或生成数据库密钥。密钥存 iOS Keychain / Android Keystore，
  //    绝不硬编码在代码中，也不随备份文件外泄。
  const FlutterSecureStorage storage = FlutterSecureStorage();
  String? dbKey = await storage.read(key: Env.databaseKeyStorageKey);
  if (dbKey == null || dbKey.isEmpty) {
    dbKey = const Uuid().v4();
    await storage.write(key: Env.databaseKeyStorageKey, value: dbKey);
  }

  // 2. 打开本地加密数据库（SQLCipher）
  final AppDatabase database = AppDatabase.open(password: dbKey);

  // 3. 首次启动写入默认账本、账户与分类
  await bootstrapData(database);

  runApp(
    ProviderScope(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(database),
      ],
      child: const App(),
    ),
  );
}
