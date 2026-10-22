import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_ledger/features/ledger/presentation/widgets/import_conflict_dialog.dart';
import 'package:pocket_ledger/theme/app_theme.dart';

/// 导入冲突对话框测试（2026-10-22：数据库已有数据时的三选一）。
///
/// 锁死：文案 / 三个选项的返回语义 / 明暗两版渲染。
void main() {
  testWidgets('三选一返回语义：合并 / 覆盖 / 取消', (tester) async {
    for (final (String label, ImportConflictMode? expected) in <(String, ImportConflictMode?)>[
      ('合并原有数据', ImportConflictMode.merge),
      ('覆盖原有数据', ImportConflictMode.overwrite),
      ('取消', null),
    ]) {
      ImportConflictMode? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppThemeData.light,
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showImportConflictDialog(
                      context,
                      existingCount: 15631,
                      incomingCount: 500,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 文案：标题 + 双笔数副文。
      expect(find.text('数据库中已有数据，您想如何处理？'), findsOneWidget);
      expect(find.text('当前账本已有 15631 笔流水，本次准备导入 500 笔。'),
          findsOneWidget);

      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(result, expected);
    }
  });

  testWidgets('明暗两版渲染', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final bool dark in <bool>[false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppThemeData.dark : AppThemeData.light,
          home: const ImportConflictDialog(
            existingCount: 15631,
            incomingCount: 500,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(ImportConflictDialog),
        matchesGoldenFile(
          dark ? 'import_conflict_dialog_dark.png'
                : 'import_conflict_dialog_light.png',
        ),
      );
    }
  });
}
