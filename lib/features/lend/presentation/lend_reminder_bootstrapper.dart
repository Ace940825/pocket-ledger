import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/lend_repository.dart';
import '../data/lend_reminder_service.dart';
import '../providers/lend_providers.dart';
import '../../../database/app_database.dart';
import '../../../providers/app_providers.dart';

/// 还款提醒服务（单例式 provider，集中管理本地通知排程）。
final Provider<LendReminderService> lendReminderServiceProvider =
    Provider<LendReminderService>(
  (Ref ref) => LendReminderService(leadDays: 3),
);

/// 应用级挂载点：初始化通知权限 + 启动全量排程 + 借还变更实时重排程。
///
/// [AppShell] 是 [StatelessWidget]（无 initState），无法承载启动副作用，
/// 故单独抽出本 [ConsumerStatefulWidget]，放在 [MaterialApp] 之上，生命周期
/// 与应用一致。
class LendReminderBootstrapper extends ConsumerStatefulWidget {
  const LendReminderBootstrapper({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LendReminderBootstrapper> createState() =>
      _LendReminderBootstrapperState();
}

class _LendReminderBootstrapperState
    extends ConsumerState<LendReminderBootstrapper> {
  StreamSubscription<List<LendRecord>>? _sub;
  final Set<String> _scheduled = <String>{};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final LendReminderService svc = ref.read(lendReminderServiceProvider);
    await svc.init();
    final String bookId = ref.read(currentBookIdProvider);
    final LendRepository repo = ref.read(lendRepositoryProvider);
    // watch 首帧即全量发射，初始化完成后再订阅，首帧排程时 _ready 已为真。
    _sub = repo.watch(bookId).listen(_onLendList);
  }

  void _onLendList(List<LendRecord> records) {
    final LendReminderService svc = ref.read(lendReminderServiceProvider);
    final Set<String> next = <String>{};
    for (final LendRecord r in records) {
      svc.scheduleForLend(r);
      next.add(r.id);
    }
    // 取消已不在列表里的记录（结清 / 删除 / 改挂账户）的提醒。
    for (final String id in _scheduled) {
      if (!next.contains(id)) svc.cancelForLend(id);
    }
    _scheduled
      ..clear()
      ..addAll(next);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
