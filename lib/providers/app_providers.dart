import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../core/config/env.dart';
import '../core/errors/failures.dart';
import '../database/app_database.dart';
import '../database/daos/accounts_dao.dart';
import '../database/daos/books_dao.dart';
import '../database/daos/categories_dao.dart';
import '../database/daos/pending_ops_dao.dart';
import '../database/daos/transactions_dao.dart';
import '../features/settings/data/sync_settings.dart';
import '../features/settings/providers/sync_settings_providers.dart';
import '../sync/adapters/cloudflare_adapter.dart';
import '../sync/adapters/offline_adapter.dart';
import '../sync/sync_adapter.dart';
import '../sync/sync_engine.dart';

/// 安全存储（iOS Keychain / Android Keystore）
final Provider<FlutterSecureStorage> secureStorageProvider =
    Provider<FlutterSecureStorage>((Ref ref) => const FlutterSecureStorage());

/// 本地主数据库。
///
/// 必须在 `main()` 中通过 `overrideWithValue` 注入（因为需要异步读取密钥），
/// 未注入时直接抛错，避免静默使用一个未初始化的实例。
final Provider<AppDatabase> appDatabaseProvider =
    Provider<AppDatabase>((Ref ref) {
  throw const DatabaseFailure(
    'AppDatabase 未初始化：请在 main() 中通过 overrideWithValue 注入',
  );
});

final Provider<TransactionsDao> transactionsDaoProvider =
    Provider<TransactionsDao>(
  (Ref ref) => ref.watch(appDatabaseProvider).transactionsDao,
);

final Provider<AccountsDao> accountsDaoProvider = Provider<AccountsDao>(
  (Ref ref) => ref.watch(appDatabaseProvider).accountsDao,
);

final Provider<CategoriesDao> categoriesDaoProvider = Provider<CategoriesDao>(
  (Ref ref) => ref.watch(appDatabaseProvider).categoriesDao,
);

final Provider<BooksDao> booksDaoProvider = Provider<BooksDao>(
  (Ref ref) => ref.watch(appDatabaseProvider).booksDao,
);

final Provider<PendingOpsDao> pendingOpsDaoProvider = Provider<PendingOpsDao>(
  (Ref ref) => ref.watch(appDatabaseProvider).pendingOpsDao,
);

/// 设备唯一标识，首次生成后持久化，用于同步时区分来源设备。
final FutureProvider<String> deviceIdProvider =
    FutureProvider<String>((Ref ref) async {
  final FlutterSecureStorage storage = ref.watch(secureStorageProvider);
  final String? existing = await storage.read(key: Env.deviceIdStorageKey);
  if (existing != null && existing.isNotEmpty) return existing;

  final String id = const Uuid().v4();
  await storage.write(key: Env.deviceIdStorageKey, value: id);
  return id;
});

/// 数据库加密密钥。首次运行时生成并写入 Keychain，之后复用。
///
/// 密钥本身**绝不能**硬编码或明文存储。
final FutureProvider<String> databaseKeyProvider =
    FutureProvider<String>((Ref ref) async {
  final FlutterSecureStorage storage = ref.watch(secureStorageProvider);
  final String? existing =
      await storage.read(key: Env.databaseKeyStorageKey);
  if (existing != null && existing.isNotEmpty) return existing;

  final String key = const Uuid().v4();
  await storage.write(key: Env.databaseKeyStorageKey, value: key);
  return key;
});

/// 云端适配器。关闭开关或配置不完整时自动降级为纯本地。
///
/// 配置来自 [syncSettingsProvider]（用户在设置页填写）。
/// 首次启动时该 provider 还在异步读取 Keychain，此时 `.value` 为 null，
/// 这里降级为 OfflineAdapter；配置就绪后本 provider 自动重算，
/// 同步引擎随之切到 Cloudflare —— 冷启动不会因为一次异步读而卡住。
final Provider<SyncAdapter> syncAdapterProvider =
    Provider<SyncAdapter>((Ref ref) {
  if (!Env.cloudSyncEnabled) return const OfflineAdapter();

  final SyncSettings settings =
      ref.watch(syncSettingsProvider).value ?? const SyncSettings();
  if (!settings.canSync) return const OfflineAdapter();

  return CloudflareAdapter(baseUrl: settings.baseUrl, token: settings.token);
});

final FutureProvider<SyncEngine> syncEngineProvider =
    FutureProvider<SyncEngine>((Ref ref) async {
  final AppDatabase db = ref.watch(appDatabaseProvider);
  final SyncAdapter adapter = ref.watch(syncAdapterProvider);
  final String deviceId = await ref.watch(deviceIdProvider.future);

  return SyncEngine(
    database: db,
    adapter: adapter,
    deviceId: deviceId,
    storage: ref.watch(secureStorageProvider),
  );
});

/// 同步状态控制器。
///
/// 两个设计要点：
/// 1. `build()` 只读取当前快照，不自动发起网络请求 —— 避免冷启动时的无谓流量
/// 2. 同步失败不影响本地使用，UI 只展示状态，不阻塞任何操作
final AutoDisposeAsyncNotifierProvider<SyncController, SyncState>
    syncControllerProvider =
    AsyncNotifierProvider.autoDispose<SyncController, SyncState>(
  SyncController.new,
);

class SyncController extends AutoDisposeAsyncNotifier<SyncState> {
  @override
  Future<SyncState> build() async {
    final AppDatabase db = ref.watch(appDatabaseProvider);
    final SyncAdapter adapter = ref.watch(syncAdapterProvider);
    final int pending = await db.pendingOpsDao.watchCount().first;

    int lastSyncedAt = 0;
    if (adapter is! OfflineAdapter) {
      final SyncEngine engine = await ref.watch(syncEngineProvider.future);
      lastSyncedAt = await engine.lastSyncedAt();
    }

    return SyncState(
      status: adapter is OfflineAdapter ? SyncStatus.disabled : SyncStatus.idle,
      lastSyncedAt: lastSyncedAt,
      pendingCount: pending,
      adapterName: adapter.name,
    );
  }

  /// 手动触发一轮同步
  Future<void> syncNow() async {
    final SyncEngine engine = await ref.read(syncEngineProvider.future);
    state = const AsyncLoading<SyncState>();
    final SyncState result = await engine.run();
    state = AsyncData<SyncState>(result);
  }
}

/// 当前账本 ID。多账本功能展开后由用户切换。
final StateProvider<String> currentBookIdProvider =
    StateProvider<String>((Ref ref) => 'default');
