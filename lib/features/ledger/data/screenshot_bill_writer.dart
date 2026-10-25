import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../database/app_database.dart';
import '../../../database/daos/accounts_dao.dart';
import '../../../database/daos/categories_dao.dart';
import '../../../domain/enums.dart';
import '../../../shared/models/money.dart';
import '../../accounts/data/account_repository.dart';
import '../../categories/data/category_repository.dart';
import 'bill_import_sources.dart';
import 'bill_io.dart';
import 'transaction_repository.dart';

/// 截图自动记账落库结果：成功写入的流水 ID 清单 + 每笔被跳过的原因。
class ScreenshotBillSaveOutcome {
  const ScreenshotBillSaveOutcome({
    required this.txnIds,
    required this.skippedReasons,
  });

  /// 成功写入的流水 ID（按写入顺序）。
  final List<String> txnIds;

  /// 被跳过行的原因（金额非法 / 必要字段缺失等）。
  final List<String> skippedReasons;
}

/// 截图自动记账落库器：把 OCR 解析出的 [BillRow] 直接写入账本。
///
/// 与「账单导入」配置页的通用路径同语义（bill_import_page `_import` 的
/// module=ledger 分支）：账户 / 分类按名称归户、缺失自动创建；第三方卡号
/// 账户名优先按卡号末四位匹配现有账户。OCR 行恒为日常记账模块，不走
/// 借还 / 储蓄 / 分期 / 投资 / 报销等特殊路由。
Future<ScreenshotBillSaveOutcome> saveScreenshotBillRows({
  required TransactionRepository txnRepo,
  required AccountRepository accRepo,
  required CategoryRepository catRepo,
  required AccountsDao accountsDao,
  required CategoriesDao categoriesDao,
  required String bookId,
  required List<BillRow> rows,
  String? screenshotPath,
}) async {
  final List<Account> accounts = await accountsDao.watchByBook(bookId).first;
  final List<Category> categories = await categoriesDao.watchAll(bookId).first;

  // 名称（小写）→ ID 缓存（与导入页同构，避免同批重复建户 / 建分类）。
  final Map<String, String> accCache = <String, String>{};
  final Map<String, String> catCache = <String, String>{};

  final List<String> txnIds = <String>[];
  final List<String> skipped = <String>[];
  bool firstSaved = true;

  for (final BillRow row in rows) {
    try {
      final String accountId = await _resolveAccount(
        row.accountName,
        bookId,
        accounts,
        accRepo,
        accCache,
      );
      final String? toAccountId = row.toAccountName == null
          ? null
          : await _resolveAccount(
              row.toAccountName!,
              bookId,
              accounts,
              accRepo,
              accCache,
            );
      final String? categoryId = row.categoryName == null
          ? null
          : await _resolveCategory(
              row.categoryName!,
              row.type,
              bookId,
              categories,
              catRepo,
              catCache,
            );

      final String tid = await txnRepo.add(
        source: '导入',
        bookId: bookId,
        type: row.type,
        amountMinor: row.amountMinor,
        accountId: accountId,
        toAccountId: toAccountId,
        categoryId: categoryId,
        occurredAt: row.occurredAt.toUtc().millisecondsSinceEpoch,
        note: row.note,
        currency: row.currency,
        sourceModule: row.module,
        tags: row.tags.isEmpty ? null : row.tags,
        discountMinor: row.discountMinor,
        feeMinor: row.feeMinor,
        subcategory: row.subcategoryName,
        excludeFromBudget: row.excludeFromBudget,
        excludeFromStats: row.excludeFromStats,
        isReimbursable: row.isReimbursable,
        // 来源截图作为附件挂在第一笔流水上（对标咔皮记账：详情里能看到原图）。
        attachmentUrls: firstSaved && screenshotPath != null
            ? <String>[screenshotPath]
            : null,
      );
      txnIds.add(tid);
      firstSaved = false;
    } catch (e) {
      skipped.add('${row.accountName} ${row.type.label} '
          '${Money.fromMinor(row.amountMinor).format()}：$e');
    }
  }
  return ScreenshotBillSaveOutcome(txnIds: txnIds, skippedReasons: skipped);
}

/// 把系统传递的临时截图复制到 `<appDocs>/attachments/`，返回持久化路径。
///
/// 快捷指令写入的是容器临时目录文件，重启或系统清理后可能失效；
/// 作为流水附件长期保存必须先复制（与记一笔拍照附件同一目录约定）。
Future<String?> copyScreenshotToAttachments(XFile file) async {
  try {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${docs.path}/attachments');
    if (!await dir.exists()) await dir.create(recursive: true);
    final String ext =
        file.path.toLowerCase().endsWith('.png') ? '.png' : '.jpg';
    final String fileName = '${const Uuid().v7()}$ext';
    final File dst = File('${dir.path}/$fileName');
    final File src = File(file.path);
    if (await src.exists()) {
      await src.copy(dst.path);
    } else {
      await dst.writeAsBytes(await file.readAsBytes());
    }
    return dst.path;
  } catch (e) {
    return null;
  }
}

/// 按名称解析账户（与导入页 `_resolveAccount` 同语义）：
/// 第三方卡号账户名优先按卡号末四位匹配现有账户；同名匹配；缺失自动创建。
Future<String> _resolveAccount(
  String name,
  String bookId,
  List<Account> accounts,
  AccountRepository repo,
  Map<String, String> cache, {
  AccountType createType = AccountType.cash,
}) async {
  final String key = '$bookId|${name.trim().toLowerCase()}';
  final String? cached = cache[key];
  if (cached != null) return cached;

  final String? last4 = extractCardLast4(name);
  if (last4 != null) {
    final String? matched = matchAccountByCardLast4(last4, accounts);
    if (matched != null) {
      cache[key] = matched;
      return matched;
    }
  }

  for (final Account a in accounts) {
    if (a.name.trim().toLowerCase() == name.trim().toLowerCase()) {
      cache[key] = a.id;
      return a.id;
    }
  }
  final AccountType effectiveType =
      last4 != null ? AccountType.bankCard : createType;
  final String id = await repo.add(
    bookId: bookId,
    name: name.trim(),
    type: effectiveType,
    cardNumber: last4,
  );
  cache[key] = id;
  return id;
}

/// 按名称 + 类型解析分类（与导入页 `_resolveCategory` 同语义）：
/// 同名同类型匹配；缺失经 `ensureNamed` 自动创建。
Future<String?> _resolveCategory(
  String name,
  TxnType type,
  String bookId,
  List<Category> categories,
  CategoryRepository repo,
  Map<String, String> cache,
) async {
  final String key = '$bookId|${type.index}:${name.trim().toLowerCase()}';
  final String? cached = cache[key];
  if (cached != null) return cached;
  // TxnType 与 CategoryType 枚举顺序一致（income/expense/transfer），
  // 按 index 映射（与导入页同口径，勿直接比较枚举类型）。
  final CategoryType catType = CategoryType.values[type.index];
  for (final Category c in categories) {
    if (c.type == catType &&
        c.name.trim().toLowerCase() == name.trim().toLowerCase()) {
      cache[key] = c.id;
      return c.id;
    }
  }
  final String id = await repo.ensureNamed(
    bookId: bookId,
    name: name.trim(),
    type: catType,
    iconKey: null,
  );
  cache[key] = id;
  return id;
}
