import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../database/sync_enqueue.dart';
import '../../../domain/enums.dart';

/// 物品（资产）仓储。
///
/// 定位：管理「买回家后仍具价值」的大件，如家电、数码、家具。
/// 与日常记账的区别在于它有**折旧与保修期**两个维度：
/// - purchasePriceMinor 是买入价，currentValueMinor 是现值（可手工下调反映折旧）
/// - warrantyUntil 用于保修临期提醒
/// 这里不做自动折旧曲线，因为不同品类折旧差异极大，自动算反而给出误导性数字。
class InventoryRepository {
  const InventoryRepository(this._db);

  final AppDatabase _db;

  Stream<List<InventoryItem>> watch(String bookId) {
    return (_db.select(_db.inventoryItems)
          ..where(
            (InventoryItems t) =>
                t.bookId.equals(bookId) & t.deleted.equals(false),
          )
          ..orderBy(<OrderClauseGenerator<InventoryItems>>[
            (InventoryItems t) => OrderingTerm.desc(t.purchasedAt),
          ]))
        .watch();
  }

  Future<String> add({
    required String bookId,
    required String name,
    required int purchasePriceMinor,
    required int purchasedAt,
    int? currentValueMinor,
    String? category,
    int? warrantyUntil,
    String? photoUrl,
    String? location,
    String? note,
  }) {
    _validate(name: name, purchasePriceMinor: purchasePriceMinor);

    final String id = const Uuid().v7();
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final int value = currentValueMinor ?? purchasePriceMinor;

    return _db.transaction<String>(() async {
      await _db.into(_db.inventoryItems).insert(
            InventoryItemsCompanion(
              id: Value<String>(id),
              bookId: Value<String>(bookId),
              name: Value<String>(name.trim()),
              category: Value<String?>(category),
              purchasePriceMinor: Value<int>(purchasePriceMinor),
              currentValueMinor: Value<int>(value),
              purchasedAt: Value<int>(purchasedAt),
              warrantyUntil: Value<int?>(warrantyUntil),
              photoUrl: Value<String?>(photoUrl),
              location: Value<String?>(location),
              note: Value<String?>(note),
              updatedAt: Value<int>(now),
              dirty: const Value<bool>(true),
            ),
          );
      await enqueueSyncOp(
        _db,
        table: 'inventory_items',
        recordId: id,
        opType: SyncOpType.insert,
        updatedAt: now,
        payload: _payload(
          name: name,
          purchasePriceMinor: purchasePriceMinor,
          purchasedAt: purchasedAt,
          currentValueMinor: value,
          category: category,
          warrantyUntil: warrantyUntil,
          photoUrl: photoUrl,
          location: location,
          note: note,
        ),
      );
      return id;
    });
  }

  Future<void> update({
    required String id,
    required String name,
    required int purchasePriceMinor,
    required int currentValueMinor,
    required int purchasedAt,
    String? category,
    int? warrantyUntil,
    String? photoUrl,
    String? location,
    String? note,
  }) {
    _validate(name: name, purchasePriceMinor: purchasePriceMinor);
    if (currentValueMinor < 0) {
      throw const ValidationFailure('现值不能为负');
    }

    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    return _db.transaction<void>(() async {
      await (_db.update(_db.inventoryItems)
            ..where((InventoryItems t) => t.id.equals(id)))
          .write(
        InventoryItemsCompanion(
          name: Value<String>(name.trim()),
          category: Value<String?>(category),
          purchasePriceMinor: Value<int>(purchasePriceMinor),
          currentValueMinor: Value<int>(currentValueMinor),
          purchasedAt: Value<int>(purchasedAt),
          warrantyUntil: Value<int?>(warrantyUntil),
          photoUrl: Value<String?>(photoUrl),
          location: Value<String?>(location),
          note: Value<String?>(note),
          updatedAt: Value<int>(now),
          dirty: const Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'inventory_items',
        recordId: id,
        opType: SyncOpType.update,
        updatedAt: now,
        payload: _payload(
          name: name,
          purchasePriceMinor: purchasePriceMinor,
          purchasedAt: purchasedAt,
          currentValueMinor: currentValueMinor,
          category: category,
          warrantyUntil: warrantyUntil,
          photoUrl: photoUrl,
          location: location,
          note: note,
        ),
      );
    });
  }

  Future<void> remove(String id) async {
    final int now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _db.transaction<void>(() async {
      await (_db.update(_db.inventoryItems)
            ..where((InventoryItems t) => t.id.equals(id)))
          .write(
        const InventoryItemsCompanion(
          deleted: Value<bool>(true),
          dirty: Value<bool>(true),
        ),
      );
      await enqueueSyncOp(
        _db,
        table: 'inventory_items',
        recordId: id,
        opType: SyncOpType.delete,
        updatedAt: now,
      );
    });
  }

  void _validate({
    required String name,
    required int purchasePriceMinor,
  }) {
    if (name.trim().isEmpty) throw const ValidationFailure('物品名称不能为空');
    if (purchasePriceMinor < 0) throw const ValidationFailure('购入价不能为负');
  }

  Map<String, Object?> _payload({
    required String name,
    required int purchasePriceMinor,
    required int purchasedAt,
    required int currentValueMinor,
    String? category,
    int? warrantyUntil,
    String? photoUrl,
    String? location,
    String? note,
  }) {
    return <String, Object?>{
      'name': name.trim(),
      'purchasePriceMinor': purchasePriceMinor,
      'purchasedAt': purchasedAt,
      'currentValueMinor': currentValueMinor,
      'category': category,
      'warrantyUntil': warrantyUntil,
      'photoUrl': photoUrl,
      'location': location,
      'note': note,
    };
  }
}

/// 物品维度的派生指标。
extension InventoryMath on InventoryItem {
  /// 折旧金额（分），现值为 0 或大于购入价时按实际差额计算
  int get depreciationMinor => purchasePriceMinor - currentValueMinor;

  /// 剩余价值占购入价的比例，购入价为 0 时视作 100%
  double get valueRatio => purchasePriceMinor == 0
      ? 1.0
      : currentValueMinor / purchasePriceMinor;

  /// 保修是否已过期
  bool isWarrantyExpired(DateTime now) =>
      warrantyUntil != null && warrantyUntil! < now.millisecondsSinceEpoch;
}
