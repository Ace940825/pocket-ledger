import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../providers/recording_settings_provider.dart';

/// 记一笔内部「记账页面设置」底部弹窗。
///
/// 从 [RecordSheet] 顶部设置图标打开，不是主页设置。
/// 包含：一般 / 默认 / 分类 三 Tab，以及键盘主题等二级弹窗。
class RecordingSettingsSheet extends ConsumerStatefulWidget {
  const RecordingSettingsSheet({super.key, this.initialTab = 0});

  /// 打开后停留的 Tab：0=一般，1=默认，2=分类。
  final int initialTab;

  /// [initialTab]：0=一般，1=默认（默认选择资产设置），2=分类。
  static Future<void> show(BuildContext context, {int initialTab = 0}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecordingSettingsSheet(initialTab: initialTab),
    );
  }

  @override
  ConsumerState<RecordingSettingsSheet> createState() =>
      _RecordingSettingsSheetState();
}

class _RecordingSettingsSheetState extends ConsumerState<RecordingSettingsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _version = 'opt'; // 'full' / 'opt'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      initialIndex: widget.initialTab.clamp(0, 2),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.66,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusXl),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              _buildHandle(),
              _buildHeader(context),
              _buildVersionToggle(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: <Widget>[
                    _GeneralTab(version: _version),
                    _DefaultTab(version: _version),
                    _CategoryTab(version: _version),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: <Widget>[
          const Expanded(
            child: Text(
              '记账页面设置',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.close, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionToggle() {
    final bool isOpt = _version == 'opt';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F2F4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: <Widget>[
            _VersionButton(
              label: '完整版',
              selected: !isOpt,
              onTap: () => setState(() => _version = 'full'),
            ),
            _VersionButton(
              label: '优化版',
              selected: isOpt,
              isOpt: true,
              onTap: () => setState(() => _version = 'opt'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: AppColors.textPrimary,
      unselectedLabelColor: AppColors.textTertiary,
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(color: AppColors.primary, width: 3),
        insets: EdgeInsets.symmetric(horizontal: 48),
      ),
      tabs: const <Tab>[
        Tab(text: '一般'),
        Tab(text: '默认'),
        Tab(text: '分类'),
      ],
    );
  }
}

class _VersionButton extends StatelessWidget {
  const _VersionButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isOpt = false,
  });

  final String label;
  final bool selected;
  final bool isOpt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? (isOpt ? AppColors.primary : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(17),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected
                  ? (isOpt ? Colors.white : AppColors.textPrimary)
                  : AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

class _GeneralTab extends ConsumerWidget {
  const _GeneralTab({required this.version});

  final String version;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RecordingSettings settings = ref.watch(recordingSettingsProvider);

    if (version == 'opt') {
      return ListView(
        padding: const EdgeInsets.all(14),
        children: <Widget>[
          _SettingsTile(
            label: '键盘外观',
            sub: '公式 / 排序 / 高度 / 行数 / 金额位置 / 按钮 / 图标背景',
            badge: '对齐截图',
            badgeColor: AppColors.info,
            onTap: () => _KeyboardThemeSheet.show(context),
          ),
          _SettingsTile(
            label: '记账偏好',
            sub: '日期类型 / 记录未来账单 / 图片裁剪 / 优惠算法',
            badge: '归组',
            badgeColor: AppColors.success,
            onTap: () => _SimpleSettingsSheet.show(context, '记账偏好'),
          ),
          _SettingsTile(
            label: '记账布局',
            sub: '按钮区配置 + Tab 开关',
            badge: '合并',
            badgeColor: AppColors.info,
            onTap: () => _SimpleSettingsSheet.show(context, '记账布局'),
          ),
          _SettingsTile(
            label: '反馈与动效',
            sub: '震动反馈 + 界面动效',
            badge: '改名',
            badgeColor: AppColors.success,
            onTap: () => _SimpleSettingsSheet.show(context, '反馈与动效'),
          ),
          _buildOptNote(
            '⚡ 关键优化点（一般）\n'
            '• 「记账功能」+「记账 Tab 管理」合并为「记账布局」\n'
            '• 「键盘主题」二级页按小青账截图布局：基础/高级分组 + 实时键盘预览\n'
            '• 日期类型 / 记录未来账单 / 图片裁剪 / 优惠算法 归组为「记账偏好」\n'
            '• 「触感 / 视觉」改名「反馈与动效」',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: <Widget>[
        _SettingsTile(
          label: '键盘主题',
          sub:
              '${settings.themeStyle.label} · ${settings.formula.label} · ${settings.numberOrder.label} · ${settings.subMode.label}',
          onTap: () => _KeyboardThemeSheet.show(context),
        ),
        _SettingsTile(
          label: '日期类型',
          sub: '记账日期选择方式',
          onTap: () => _SimpleSettingsSheet.show(context, '日期类型'),
        ),
        _SettingsSwitchTile(
          label: '记录未来账单',
          sub: '允许记录未来日期的账单',
          value: settings.recordFutureBill,
          onChanged: (_) =>
              ref.read(recordingSettingsProvider.notifier).toggleRecordFutureBill(),
        ),
        _SettingsSwitchTile(
          label: '图片裁剪',
          sub: '拍照后自动裁剪',
          value: settings.imageCrop,
          onChanged: (_) =>
              ref.read(recordingSettingsProvider.notifier).toggleImageCrop(),
        ),
        _SettingsTile(
          label: '优惠算法',
          sub: '折扣分摊计算方式',
          onTap: () => _SimpleSettingsSheet.show(context, '优惠算法'),
        ),
        _SettingsTile(
          label: '记账功能',
          sub: '按钮区配置 + 模块开关',
          onTap: () => _SimpleSettingsSheet.show(context, '记账功能'),
        ),
        _SettingsTile(
          label: '记账 Tab 管理',
          sub: '首页 Tab 开关列表',
          onTap: () => _SimpleSettingsSheet.show(context, '记账 Tab 管理'),
        ),
        _SettingsTile(
          label: '触感 / 视觉',
          sub: '震动反馈 + 界面动效',
          onTap: () => _SimpleSettingsSheet.show(context, '触感 / 视觉'),
        ),
      ],
    );
  }
}

class _DefaultTab extends ConsumerWidget {
  const _DefaultTab({required this.version});

  final String version;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RecordingSettings settings = ref.watch(recordingSettingsProvider);

    if (version == 'opt') {
      return ListView(
        padding: const EdgeInsets.all(14),
        children: <Widget>[
          _SettingsTile(
            label: '默认账本',
            sub: 'XIAO QING BILL',
            badge: '上提',
            badgeColor: AppColors.warning,
            onTap: () => _SimpleSettingsSheet.show(context, '默认账本'),
          ),
          _SettingsTile(
            label: '账本管理',
            sub: '排序 / 封存列表',
            badge: '分离',
            badgeColor: AppColors.success,
            onTap: () => _SimpleSettingsSheet.show(context, '账本管理'),
          ),
          _SettingsTile(
            label: '智能记忆',
            sub: '分类资产 + 备注 自动记忆',
            badge: '合并去重',
            badgeColor: AppColors.warning,
            onTap: () => _SimpleSettingsSheet.show(context, '智能记忆'),
          ),
          _RemovedTile(
            label: '重新加载数据',
            sub: '已移除 → 自动刷新',
          ),
          _buildOptNote(
            '⚡ 关键优化点（默认）\n'
            '• 合并「常用资产 / 备注管理」为统一的「智能记忆」\n'
            '• 「默认账本隐藏」从「我的账本 → 更多」上提至此\n'
            '• 「账本管理」从「我的账本 → 更多」分离为独立入口\n'
            '• 「重新加载数据」改为自动刷新并移除手动入口',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: <Widget>[
        _SettingsTile(
          label: '默认账本',
          sub: 'XIAO QING BILL',
          onTap: () => _SimpleSettingsSheet.show(context, '默认账本'),
        ),
        _SettingsSwitchTile(
          label: '跟随模式',
          sub: '主页账本切换时「记一笔」同步切换',
          value: settings.followMode,
          onChanged: (_) =>
              ref.read(recordingSettingsProvider.notifier).toggleFollowMode(),
        ),
        _SettingsTile(
          label: '重新加载数据',
          sub: '手动刷新本地缓存',
          onTap: () {},
        ),
        _SettingsSwitchTile(
          label: '分类资产记忆',
          sub: '选分类自动带出上次使用的资产',
          value: settings.categoryAssetMemory,
          onChanged: (_) =>
              ref.read(recordingSettingsProvider.notifier).toggleCategoryAssetMemory(),
        ),
        _SettingsTile(
          label: '常用资产',
          sub: '显示模式 + 管理',
          onTap: () => _SimpleSettingsSheet.show(context, '常用资产'),
        ),
        _SettingsTile(
          label: '常用备注',
          sub: '显示模式 + 管理',
          onTap: () => _SimpleSettingsSheet.show(context, '常用备注'),
        ),
      ],
    );
  }
}

class _CategoryTab extends ConsumerWidget {
  const _CategoryTab({required this.version});

  final String version;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RecordingSettings settings = ref.watch(recordingSettingsProvider);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: <Widget>[
        _SettingsTile(
          label: '记账分类样式',
          sub: settings.categoryStyle,
          onTap: () => _SimpleSettingsSheet.show(context, '记账分类样式'),
        ),
        _SettingsTile(
          label: '分类图标设置',
          sub: '大小 ${settings.iconSize} · 圆角 ${settings.iconRadius}',
          onTap: () => _SimpleSettingsSheet.show(context, '分类图标设置'),
        ),
        _SettingsTile(
          label: '分类显示行数',
          sub: '${settings.categoryRows} 行',
          onTap: () => _SimpleSettingsSheet.show(context, '分类显示行数'),
        ),
        if (version == 'opt')
          _buildOptNote('分类设置已较精简，结构保持不变。'),
      ],
    );
  }
}

Widget _buildOptNote(String text) {
  return Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFE6FBF6),
      border: Border.all(color: const Color(0xFFBDEFE3)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        height: 1.7,
        color: Color(0xFF235C52),
      ),
    ),
  );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.label,
    required this.sub,
    this.onTap,
    this.badge,
    this.badgeColor,
  });

  final String label;
  final String sub;
  final VoidCallback? onTap;
  final String? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (badge != null) ...<Widget>[
                          const SizedBox(width: 7),
                          _Badge(text: badge!, color: badgeColor!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right, color: Color(0xFFC4C9CF)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.label,
    required this.sub,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.success,
            ),
          ],
        ),
      ),
    );
  }
}

class _RemovedTile extends StatelessWidget {
  const _RemovedTile({required this.label, required this.sub});

  final String label;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.expense,
                    ),
                  ),
                ],
              ),
            ),
            _Badge(text: '已移除', color: AppColors.expense),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _SimpleSettingsSheet extends StatelessWidget {
  const _SimpleSettingsSheet({required this.title});

  final String title;

  static Future<void> show(BuildContext context, String title) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SimpleSettingsSheet(title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusXl),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            _buildHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child:
                        const Icon(Icons.close, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: Center(
                child: Text(
                  '「$title」设置页（占位）',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _KeyboardThemeSheet extends ConsumerWidget {
  const _KeyboardThemeSheet();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _KeyboardThemeSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.84,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusXl),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            _buildHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      '键盘主题',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.close,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildSectionTitle('基础设置'),
                    _buildThemeRow(ref),
                    _buildFormulaRow(ref),
                    _buildOrderRow(ref),
                    _buildHeightSlider(ref),
                    const SizedBox(height: 24),
                    _buildSectionTitle('高级设置'),
                    _buildSubModeTabs(ref),
                    _buildAdvancedRows(ref),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
            const _KeyboardPreview(),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildThemeRow(WidgetRef ref) {
    final RecordingSettings settings = ref.watch(recordingSettingsProvider);
    return _PillRow(
      label: '',
      options: KeyboardThemeStyle.values.map((e) => e.label).toList(),
      value: settings.themeStyle.label,
      onChanged: (String label) {
        final KeyboardThemeStyle style = KeyboardThemeStyle.values
            .firstWhere((KeyboardThemeStyle e) => e.label == label);
        ref.read(recordingSettingsProvider.notifier).setThemeStyle(style);
      },
    );
  }

  Widget _buildFormulaRow(WidgetRef ref) {
    final RecordingSettings settings = ref.watch(recordingSettingsProvider);
    return _PillRow(
      label: '计算公式',
      options: KeyboardFormula.values.map((e) => e.label).toList(),
      value: settings.formula.label,
      onChanged: (String label) {
        final KeyboardFormula formula = KeyboardFormula.values
            .firstWhere((KeyboardFormula e) => e.label == label);
        ref.read(recordingSettingsProvider.notifier).setFormula(formula);
      },
    );
  }

  Widget _buildOrderRow(WidgetRef ref) {
    final RecordingSettings settings = ref.watch(recordingSettingsProvider);
    return _PillRow(
      label: '数字排序',
      options: KeyboardNumberOrder.values.map((e) => e.label).toList(),
      value: settings.numberOrder.label,
      onChanged: (String label) {
        final KeyboardNumberOrder order = KeyboardNumberOrder.values
            .firstWhere((KeyboardNumberOrder e) => e.label == label);
        ref.read(recordingSettingsProvider.notifier).setNumberOrder(order);
      },
    );
  }

  Widget _buildHeightSlider(WidgetRef ref) {
    final RecordingSettings settings = ref.watch(recordingSettingsProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: 22,
            child: Text('◎', style: TextStyle(fontSize: 16, color: AppColors.textTertiary)),
          ),
          const Text(
            '键盘高度比例',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          Expanded(
            child: Slider(
              value: settings.heightScale,
              min: 0.8,
              max: 1.2,
              divisions: 4,
              activeColor: AppColors.primary,
              inactiveColor: AppColors.divider,
              onChanged: (double v) => ref
                  .read(recordingSettingsProvider.notifier)
                  .setHeightScale(double.parse(v.toStringAsFixed(1))),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              settings.heightScale.toStringAsFixed(1),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubModeTabs(WidgetRef ref) {
    final RecordingSettings settings = ref.watch(recordingSettingsProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: KeyboardSubMode.values.map((KeyboardSubMode mode) {
          final bool selected = settings.subMode == mode;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(mode.label),
              selected: selected,
              selectedColor: AppColors.primary,
              backgroundColor: const Color(0xFFF2F4F5),
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (_) =>
                  ref.read(recordingSettingsProvider.notifier).setSubMode(mode),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAdvancedRows(WidgetRef ref) {
    final RecordingSettings settings = ref.watch(recordingSettingsProvider);
    final notifier = ref.read(recordingSettingsProvider.notifier);

    return Column(
      children: <Widget>[
        _PillRow(
          label: '顶部区域行数',
          options: const <String>['1行', '2行'],
          value: settings.topAreaRows,
          onChanged: notifier.setTopAreaRows,
        ),
        _PillRow(
          label: '金额位置',
          options: const <String>['左', '右'],
          value: settings.amountPosition,
          onChanged: notifier.setAmountPosition,
        ),
        _PillRow(
          label: '功能按钮行数',
          options: const <String>['单行', '多行'],
          value: settings.funcButtonRows,
          onChanged: notifier.setFuncButtonRows,
        ),
        _PillRow(
          label: '功能按钮图标背景色',
          options: const <String>['关闭', '开启'],
          value: settings.iconBackground,
          onChanged: notifier.setIconBackground,
        ),
      ],
    );
  }
}

class _PillRow extends StatelessWidget {
  const _PillRow({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool hasLabel = label.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (hasLabel) ...<Widget>[
            SizedBox(
              width: 22,
              child: Text(
                _iconFor(label),
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            Expanded(
              flex: 0,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: hasLabel ? WrapAlignment.end : WrapAlignment.start,
              children: options.map((String option) {
                final bool selected = value == option;
                return GestureDetector(
                  onTap: () => onChanged(option),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : const Color(0xFFF2F4F5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      option,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _iconFor(String label) {
    switch (label) {
      case '计算公式':
        return '/%';
      case '数字排序':
        return '#';
      case '键盘高度比例':
        return '◎';
      case '顶部区域行数':
        return 'Aa';
      case '金额位置':
        return '\$';
      case '功能按钮行数':
        return '⊞';
      case '功能按钮图标背景色':
        return '✎';
      default:
        return '';
    }
  }
}

class _KeyboardPreview extends ConsumerWidget {
  const _KeyboardPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RecordingSettings settings = ref.watch(recordingSettingsProvider);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimens.radiusXl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildFuncButtons(settings),
          _buildAmountArea(settings),
          _buildKeypad(settings),
        ],
      ),
    );
  }

  Widget _buildFuncButtons(RecordingSettings settings) {
    final List<_FuncBtn> buttons = <_FuncBtn>[
      const _FuncBtn(label: '账户', icon: Icons.account_balance_outlined, color: Color(0xFFFFD666), textColor: Color(0xFFB8860B)),
      const _FuncBtn(label: '图片', icon: Icons.image_outlined, color: Color(0xFF7ED321), textColor: Colors.white),
      const _FuncBtn(label: '标签', icon: Icons.label_outlined, color: Color(0xFF50E3C2), textColor: Colors.white),
      const _FuncBtn(label: '不计入', icon: Icons.block, color: Color(0xFFB8B8B8), textColor: Colors.white),
      const _FuncBtn(label: '模板', icon: Icons.edit_note, color: Color(0xFF9013FE), textColor: Colors.white),
    ];

    final bool iconBg = settings.iconBackground == '开启';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: <Widget>[
          ...buttons.map((_FuncBtn b) {
            if (iconBg) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: b.color,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(b.icon, size: 11, color: b.textColor),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      b.label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Text(
                b.label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            );
          }),
          const Spacer(),
          const Icon(Icons.settings_outlined,
              size: 18, color: AppColors.textTertiary),
        ],
      ),
    );
  }

  Widget _buildAmountArea(RecordingSettings settings) {
    final bool isFull = settings.amountPosition == '左';
    final bool simpleDatePlain = settings.subMode == KeyboardSubMode.simple;

    if (isFull) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text(
                  '¥0.00',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                _ArrowBox(),
              ],
            ),
            Row(
              children: <Widget>[
                const Icon(Icons.calendar_today_outlined,
                    size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  '9月20日',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '请输入备注信息（最多150字）',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 金额在右：简约/紧凑共用紧凑布局
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _ArrowBox(),
              const Text(
                '¥0.00',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                '请输入备注信息（最多150字）',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.calendar_today_outlined,
                      size: 13, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    '9月20日',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          simpleDatePlain ? FontWeight.normal : FontWeight.w600,
                      color: simpleDatePlain
                          ? AppColors.textTertiary
                          : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeypad(RecordingSettings settings) {
    final List<List<String>> rows123 = <List<String>>[
      <String>['1', '2', '3'],
      <String>['4', '5', '6'],
      <String>['7', '8', '9'],
    ];
    final List<List<String>> rows789 = <List<String>>[
      <String>['7', '8', '9'],
      <String>['4', '5', '6'],
      <String>['1', '2', '3'],
    ];
    final List<List<String>> numRows =
        settings.numberOrder == KeyboardNumberOrder.descending
            ? rows789
            : rows123;

    final double height = 46 * settings.heightScale;
    final double fontSize = 19 * settings.heightScale;
    final double gap = settings.themeStyle == KeyboardThemeStyle.simple
        ? 1 * settings.heightScale
        : 8 * settings.heightScale;
    final double pad = settings.themeStyle == KeyboardThemeStyle.simple
        ? 1 * settings.heightScale
        : 10 * settings.heightScale;

    final Color keypadBg = settings.themeStyle == KeyboardThemeStyle.simple
        ? const Color(0xFFC8EDD9)
        : const Color(0xFFEAF7F3);

    Widget keyCell(String label, {bool save = false, int flex = 1}) {
      return Expanded(
        flex: flex,
        child: Container(
          height: height,
          margin: EdgeInsets.all(gap / 2),
          decoration: _keyDecoration(settings, save),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: save ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      );
    }

    final List<Widget> rows = <Widget>[];

    if (settings.formula == KeyboardFormula.plusMinus) {
      rows.add(Row(children: <Widget>[
        ...numRows[0].map((String n) => keyCell(n)),
        keyCell('⌫'),
      ]));
      rows.add(Row(children: <Widget>[
        ...numRows[1].map((String n) => keyCell(n)),
        keyCell('−'),
      ]));
      rows.add(Row(children: <Widget>[
        ...numRows[2].map((String n) => keyCell(n)),
        keyCell('+'),
      ]));
      rows.add(Row(children: <Widget>[
        keyCell('再记'),
        keyCell('0'),
        keyCell('.'),
        keyCell('保存', save: true),
      ]));
    } else {
      rows.add(Row(children: <Widget>[
        ...numRows[0].map((String n) => keyCell(n)),
        keyCell('⌫'),
      ]));
      rows.add(Row(children: <Widget>[
        ...numRows[1].map((String n) => keyCell(n)),
        keyCell('÷'),
      ]));
      rows.add(Row(children: <Widget>[
        ...numRows[2].map((String n) => keyCell(n)),
        keyCell('×'),
      ]));
      rows.add(Row(children: <Widget>[
        keyCell('.'),
        keyCell('0'),
        keyCell('−'),
        keyCell('+'),
      ]));
      rows.add(Row(children: <Widget>[
        keyCell('再记', flex: 2),
        keyCell('保存', save: true, flex: 2),
      ]));
    }

    return Container(
      color: keypadBg,
      padding: EdgeInsets.all(pad),
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }

  BoxDecoration _keyDecoration(RecordingSettings settings, bool save) {
    if (save) {
      return BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      );
    }
    switch (settings.themeStyle) {
      case KeyboardThemeStyle.simple:
        return BoxDecoration(
          color: Colors.transparent,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
          ),
        );
      case KeyboardThemeStyle.flat:
        return BoxDecoration(
          color: const Color(0xFFB8E6CC),
          borderRadius: BorderRadius.circular(12),
        );
      case KeyboardThemeStyle.bordered:
        return BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary, width: 1.5),
        );
      case KeyboardThemeStyle.custom:
        return BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, 1),
            ),
          ],
        );
    }
  }
}

class _ArrowBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: const Color(0xFFD6F3E8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.keyboard_arrow_down,
        size: 18,
        color: AppColors.primary,
      ),
    );
  }
}

class _FuncBtn {
  const _FuncBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
}
