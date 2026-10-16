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

  // 1. 预加载 SharedPreferences：既是数据库密钥的备份位，也是记账设置页的
  //    持久化底座，必须先于安全存储逻辑完成初始化。
  appPrefs = await SharedPreferences.getInstance();

  // 2. 获取或生成数据库密钥。主位存 iOS Keychain / Android Keystore，
  //    绝不硬编码在代码中，也不随备份文件外泄。部分 Android 模拟器镜像上
  //    Keystore 的 keygen 会永久挂起（写操作不再返回，主线程空转、界面
  //    卡在启动页），因此读写一律加超时兜底，并在 Keystore 不可用时把
  //    密钥落到 SharedPreferences 备份位——保证同一设备每次启动都用
  //    同一把密钥，否则旧的 SQLCipher 数据库将无法打开。
  String? dbKey = await _readSecureStorage(Env.databaseKeyStorageKey);
  if (dbKey != null &&
      dbKey.isNotEmpty &&
      appPrefs.containsKey(Env.databaseKeyStorageKey)) {
    // 主位已恢复：清掉备份位，避免日后两份密钥混淆。
    await appPrefs.remove(Env.databaseKeyStorageKey);
  }
  dbKey ??= appPrefs.getString(Env.databaseKeyStorageKey);
  if (dbKey == null || dbKey.isEmpty) {
    dbKey = const Uuid().v4();
    final bool backedUp = await _writeSecureStorage(
      Env.databaseKeyStorageKey,
      dbKey,
    );
    if (!backedUp) {
      await appPrefs.setString(Env.databaseKeyStorageKey, dbKey);
    }
  }

  // 3. 打开本地加密数据库（SQLCipher）
  final AppDatabase database = AppDatabase.open(password: dbKey);

  // 4. 首次启动写入默认账本、账户与分类
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

/// 读取安全存储。Keystore 读异常或挂起时返回 null，由调用方回落
/// SharedPreferences 备份位——绝不让 main() 卡死在启动页。
Future<String?> _readSecureStorage(String key) async {
  try {
    return await const FlutterSecureStorage()
        .read(key: key)
        .timeout(const Duration(seconds: 6));
  } on Exception {
    return null;
  }
}

/// 写入安全存储，返回是否成功。部分 Android 模拟器镜像上 Keystore keygen
/// 会永久挂起（线程卡死不再返回），必须靠超时把启动流程拉回来。
Future<bool> _writeSecureStorage(String key, String value) async {
  try {
    await const FlutterSecureStorage()
        .write(key: key, value: value)
        .timeout(const Duration(seconds: 6));
    return true;
  } on Exception {
    return false;
  }
}
