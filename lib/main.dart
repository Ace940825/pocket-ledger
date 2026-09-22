import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'app.dart';
import 'core/bootstrap.dart';
import 'core/config/env.dart';
import 'database/app_database.dart';
import 'features/record/providers/recording_settings_provider.dart';
import 'providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 0. 启用 Android 系统 Photo Picker：多选图片的 limit（最多 9 张）才会被
  //    系统相册硬性锁定（选满后其余变灰不可选）。默认的 ACTION_GET_CONTENT
  //    模式会完全忽略 limit，导致可选超 9 张。iOS 端 PHPicker 不受影响，
  //    selectionLimit 一直生效。须在任何 image_picker 调用前设置。
  final ImagePickerPlatform pickerImpl = ImagePickerPlatform.instance;
  if (pickerImpl is ImagePickerAndroid) {
    pickerImpl.useAndroidPhotoPicker = true;
  }

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

  // 4. 预加载 SharedPreferences（记账页面设置统一持久化，弹窗重开/重启不丢）
  appPrefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(database),
      ],
      child: const App(),
    ),
  );
}
