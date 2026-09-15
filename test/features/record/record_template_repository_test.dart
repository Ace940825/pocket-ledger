import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pocket_ledger/database/app_database.dart';
import 'package:pocket_ledger/features/record/data/record_template_repository.dart';

/// [RecordTemplateRepository] 的回归测试（真 SQLite，内存库）。
///
/// 模板是纯本地数据：保存后可在当前账本列出、套用、删除；空名称应被拒绝。
void main() {
  late AppDatabase db;
  late RecordTemplateRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = RecordTemplateRepository(db);
  });

  tearDown(() => db.close());

  test('保存模板后可在当前账本列出，并按创建时间倒序', () async {
    final String a = await repo.add(
      bookId: 'b1',
      name: '午饭',
      tabIndex: 0,
      accountId: 'acc1',
      note: '公司楼下',
    );
    final String b = await repo.add(
      bookId: 'b1',
      name: '滴滴通勤',
      tabIndex: 0,
      categoryId: 'cat1',
    );

    final List<RecordTemplate> list = await repo.watchAll('b1').first;
    expect(list.length, 2);
    // 倒序：后写的「滴滴通勤」排第一。
    expect(list.first.id, b);
    expect(list.last.id, a);
    expect(list.first.name, '滴滴通勤');
    expect(list.first.categoryId, 'cat1');
    expect(list.last.accountId, 'acc1');
    expect(list.last.note, '公司楼下');
  });

  test('不同账本的模板互不串门', () async {
    await repo.add(bookId: 'b1', name: '午饭', tabIndex: 0);
    await repo.add(bookId: 'b2', name: '私房钱', tabIndex: 1);

    final List<RecordTemplate> list = await repo.watchAll('b1').first;
    expect(list.length, 1);
    expect(list.first.name, '午饭');
  });

  test('空名称应被拒绝', () {
    expect(
      () => repo.add(bookId: 'b1', name: '   ', tabIndex: 0),
      throwsA(isA<FormatException>()),
    );
  });

  test('删除模板后不再列出', () async {
    final String id = await repo.add(bookId: 'b1', name: '临时', tabIndex: 0);
    await repo.remove(id);

    final List<RecordTemplate> list = await repo.watchAll('b1').first;
    expect(list.isEmpty, isTrue);
  });
}
