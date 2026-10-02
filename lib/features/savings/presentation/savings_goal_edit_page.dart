import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failures.dart';
import '../../../database/app_database.dart';
import '../../../providers/app_providers.dart';
import '../../../routing/app_router.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../accounts/providers/accounts_providers.dart';
import '../../record/presentation/account_picker_sheet.dart';
import '../../record/providers/recording_settings_provider.dart';
import '../providers/savings_providers.dart';

/// 存钱计划编辑页（参照小青账「存钱计划」编辑页截图）：
///
/// 存钱信息（头像 + 名称/备注预览、名称输入 15 字、备注输入 150 字）→
/// 存钱快捷属性（账本行 / 转出·扣款账户 / 转至 / 转入·入款账户）→
/// 底部固定绿色渐变「保存」。
///
/// 落库口径：名称 / 备注 / 入款账户（goal.accountId）/ 转出·扣款账户
/// （goal.sourceAccountId）均可改；目标金额 / 已存 / 截止日 / 模式等保持原值。
/// 转出账户留空时回落 App 默认资产账户，避免编辑页再出现空占位。
class SavingsGoalEditPage extends ConsumerStatefulWidget {
  const SavingsGoalEditPage({super.key, required this.goal});

  final SavingsGoal goal;

  @override
  _SavingsGoalEditPageState createState() => _SavingsGoalEditPageState();
}

class _SavingsGoalEditPageState extends ConsumerState<SavingsGoalEditPage> {
  static const Color _sageA = AppPalette.sageMist;
  static const Color _sageB = AppPalette.sageRibbon;
  static const Color _greenSoft = AppPalette.softGreen;
  static const Color _greenDeep = AppPalette.deepGreen;

  late final TextEditingController _nameController;
  late final TextEditingController _noteController;
  String? _sourceAccountId; // 转出/扣款账户（落库 goal.sourceAccountId）
  late String? _targetAccountId; // 转入/入款账户（落库 goal.accountId）
  bool _sourceDefaultScheduled = false; // 冷启动首帧未就绪时，账户流到达后补填默认

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.goal.name);
    _noteController = TextEditingController(text: widget.goal.note ?? '');
    _targetAccountId = widget.goal.accountId;
    // 转出/扣款账户：优先回显已保存值，未保存则回落 App 默认资产账户。
    _sourceAccountId =
        widget.goal.sourceAccountId ?? _resolveDefaultAssetAccountId();
  }

  /// 解析 App 默认资产账户 ID（与创建页同口径）：
  /// 1) 记账设置「默认资产账户」名称在资金类账户中按名匹配；
  /// 2) 未设置名称时跟随资金类账户列表第一个；
  /// 3) 无账户时回落 null。
  String? _resolveDefaultAssetAccountId() {
    final List<Account> all =
        ref.read(accountsProvider).valueOrNull ?? const <Account>[];
    final List<Account> fund = fundAccountsOnly(all);
    if (fund.isEmpty) return null;
    final String? named =
        ref.read(recordingSettingsProvider).defaultAssetAccount;
    if (named != null) {
      for (final Account a in fund) {
        if (a.name == named) return a.id;
      }
    }
    return fund.first.id;
  }

  /// 账户流就绪前 _sourceAccountId 可能为空，待账户数据到达后补默认。
  void _maybeScheduleDefaultSource() {
    if (_sourceAccountId != null || _sourceDefaultScheduled) return;
    final AsyncValue<List<Account>> acc = ref.watch(accountsProvider);
    if (!acc.hasValue) return;
    _sourceDefaultScheduled = true;
    final String? def = _resolveDefaultAssetAccountId();
    if (def != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _sourceAccountId == null) {
          setState(() => _sourceAccountId = def);
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _maybeScheduleDefaultSource();
    return Scaffold(
      backgroundColor: AppPalette.surfaceMist,
      appBar: AppBar(
        title: const Text('存钱计划'),
        centerTitle: true,
        backgroundColor: AppPalette.surfaceMist,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: <Widget>[
                _section(
                  title: '存钱信息',
                  children: <Widget>[
                    _avatarRow(),
                    const SizedBox(height: 12),
                    _roundedField(
                      controller: _nameController,
                      hint: '名称(最多15字符)',
                      maxLength: 15,
                    ),
                    const SizedBox(height: 12),
                    _roundedField(
                      controller: _noteController,
                      hint: '备注(最多150字符)',
                      maxLength: 150,
                      maxLines: 3,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _section(
                  title: '存钱快捷属性',
                  children: <Widget>[
                    _infoRow(),
                    const SizedBox(height: 12),
                    _bookRow(),
                    const SizedBox(height: 12),
                    _accountPills(),
                  ],
                ),
              ],
            ),
          ),
          // 底部固定「保存」。
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient:
                      const LinearGradient(colors: <Color>[_sageA, _sageB]),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: SizedBox(
                  height: 48,
                  child: Center(
                    child: TextButton(
                      onPressed: _save,
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                      ),
                      child: const Text(
                        '保存',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 小节样式（与创建页同款） ----

  /// 小节卡片：绿色竖条标题 + 内容。
  Widget _section({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 4,
                height: 15,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[_sageA, _sageB],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  /// ⓘ 信息行（灰字说明）。
  Widget _infoRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppPalette.surfaceMist,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline,
              size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '快捷属性适用于完成存钱任务快捷填充属性使用。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// 头像行：🐱 头像 + 名称 / 备注预览（对标截图头像右侧两行）。
  /// 预览实时跟随输入框：名称清空回退原名称；备注清空同步消失。
  Widget _avatarRow() {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _greenSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: const Text('🐱', style: TextStyle(fontSize: 30)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ListenableBuilder(
            listenable: Listenable.merge(<Listenable>[
              _nameController,
              _noteController,
            ]),
            builder: (BuildContext context, _) {
              final String name = _nameController.text.trim().isEmpty
                  ? widget.goal.name
                  : _nameController.text.trim();
              final String note = _noteController.text.trim();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (note.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      note,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// 圆角灰底输入框（名称 / 备注）。
  Widget _roundedField({
    required TextEditingController controller,
    required String hint,
    required int maxLength,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14),
        filled: true,
        fillColor: AppPalette.surfaceMist,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    );
  }

  /// 账本行（绿色圆标 + 当前账本名 + chevron，只读展示）。
  Widget _bookRow() {
    final Book? book = ref.watch(currentBookProvider).valueOrNull;
    final String bookName = book?.name ?? '默认账本';
    return Row(
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: _greenSoft,
            shape: BoxShape.circle,
          ),
          child: Text(
            bookName.isEmpty ? '账' : bookName.characters.first,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _greenDeep,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '账本',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                bookName,
                style: TextStyle(
                    fontSize: 12.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right,
            size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ],
    );
  }

  /// 快捷属性账户区：转出账户/扣款账户 → 转至 → 转入账户/入款账户。
  Widget _accountPills() {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _accountPill(
                label: '转出账户',
                accountId: _sourceAccountId,
                onTap: () => _pickSourceAccount(),
              ),
            ),
            const SizedBox(width: 12),
            _labelPill('扣款账户'),
          ],
        ),
        const SizedBox(height: 10),
        // 「转至」分隔 chip。
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppPalette.surfaceMist,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.currency_yuan,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text('转至',
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: _accountPill(
                label: '转入账户',
                accountId: _targetAccountId,
                onTap: () => _pickTargetAccount(),
              ),
            ),
            const SizedBox(width: 12),
            _labelPill('入款账户'),
          ],
        ),
      ],
    );
  }

  /// 账户选择胶囊：未选显示字段名，已选显示账户名（可重选）。
  Widget _accountPill({
    required String label,
    required String? accountId,
    required VoidCallback onTap,
  }) {
    final List<Account> all =
        ref.watch(accountsProvider).valueOrNull ?? const <Account>[];
    Account? acc;
    for (final Account a in all) {
      if (a.id == accountId) {
        acc = a;
        break;
      }
    }
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: acc == null ? AppPalette.surfaceMist : _greenSoft,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              acc == null ? Icons.account_balance_wallet_outlined : Icons.check,
              size: 18,
              color: acc == null
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : _greenDeep,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                acc?.name ?? label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: acc == null
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : _greenDeep,
                  fontWeight: acc == null ? FontWeight.w400 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 右侧静态标签胶囊（扣款账户 / 入款账户）。
  Widget _labelPill(String label) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppPalette.surfaceMist,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }

  // ---- 交互 ----

  /// 转出/扣款账户：页面态快捷属性，暂不落库。
  Future<void> _pickSourceAccount() async {
    final Account? acc = await _pickAccount(
      title: '选择转出账户',
      selectedId: _sourceAccountId,
    );
    if (acc != null || _sourceAccountId != null) {
      setState(() => _sourceAccountId = acc?.id);
    }
  }

  /// 转入/入款账户：保存时落库 goal.accountId。
  Future<void> _pickTargetAccount() async {
    final Account? acc = await _pickAccount(
      title: '选择转入账户',
      selectedId: _targetAccountId,
    );
    if (acc != null || _targetAccountId != null) {
      setState(() => _targetAccountId = acc?.id);
    }
  }

  /// 账户选择：复用工程内「选择账户」弹层（与创建页同口径，资金类账户）。
  Future<Account?> _pickAccount({
    required String title,
    String? selectedId,
  }) {
    return showModalBottomSheet<Account>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) => AccountPickerSheet(
        filter: fundAccountsOnly,
        selectedId: selectedId,
        title: title,
        noneTitle: '不选择具体账户',
        onAdd: () {
          if (mounted) context.push(Routes.accountAdd);
        },
        onManage: () {
          if (mounted) context.push(Routes.accountManage);
        },
        onConfirm: (Account? acc) => Navigator.of(ctx).pop(acc),
      ),
    );
  }

  Future<void> _save() async {
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      showAppToast(context, '名称不能为空');
      return;
    }
    try {
      await ref.read(savingsRepositoryProvider).update(
            id: widget.goal.id,
            name: name,
            // 金额 / 已存 / 截止日保持原值（编辑页不提供修改入口）。
            targetMinor: widget.goal.targetMinor,
            currentMinor: widget.goal.currentMinor,
            accountId: _targetAccountId,
            sourceAccountId: _sourceAccountId,
            deadlineAt: widget.goal.deadlineAt,
            note: _noteController.text.trim(),
          );
    } on AppFailure catch (e) {
      if (mounted) showAppToast(context, e.message);
      return;
    } catch (_) {
      if (mounted) showAppToast(context, '保存失败，请稍后重试');
      return;
    }
    if (mounted) {
      showAppToast(context, '已保存');
      Navigator.of(context).pop();
    }
  }
}
