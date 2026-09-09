import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimens.dart';
import '../../../../providers/app_providers.dart';
import '../data/sync_settings.dart';
import '../providers/sync_settings_providers.dart';

/// 云同步配置卡片：开关 + Workers 端点 + 访问令牌。
///
/// 端点与令牌是凭据，保存进 Keychain / Keystore，不落数据库。
/// 全部留空 = 纯本地模式，应用功能不受任何影响。
class SyncConfigCard extends ConsumerStatefulWidget {
  const SyncConfigCard({super.key});

  @override
  ConsumerState<SyncConfigCard> createState() => _SyncConfigCardState();
}

class _SyncConfigCardState extends ConsumerState<SyncConfigCard> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();

  bool _obscureToken = true;
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  /// 只在首次拿到配置时回填输入框。
  ///
  /// 若无条件赋值，每次 provider 重建都会把用户正在输入的内容冲掉。
  void _seedOnce(SyncSettings settings) {
    if (_seeded) return;
    _urlController.text = settings.baseUrl;
    _tokenController.text = settings.token;
    _seeded = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await ref.read(syncSettingsProvider.notifier).save(
            baseUrl: _urlController.text,
            token: _tokenController.text,
          );
      // 适配器与状态卡片都依赖配置，配置变了必须让它们重算
      ref.invalidate(syncControllerProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存到本机钥匙串')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setEnabled(bool value) async {
    await ref.read(syncSettingsProvider.notifier).setEnabled(value);
    ref.invalidate(syncControllerProvider);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<SyncSettings> asyncSettings =
        ref.watch(syncSettingsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        child: asyncSettings.when(
          loading: () => const SizedBox(
            height: 48,
            child: Center(child: LinearProgressIndicator()),
          ),
          error: (Object e, StackTrace? s) => Text('配置读取失败：$e'),
          data: (SyncSettings settings) {
            _seedOnce(settings);
            final String? blocked = settings.blockedReason;

            return Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.cloud_outlined),
                      const SizedBox(width: AppDimens.spaceSm),
                      Text('云端配置', style: theme.textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: AppDimens.spaceSm),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('启用云同步'),
                    subtitle: Text(
                      blocked ?? '配置已就绪，可立即同步',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: blocked == null
                            ? AppColors.income
                            : AppColors.textTertiary,
                      ),
                    ),
                    value: settings.enabled,
                    onChanged: _setEnabled,
                  ),

                  TextFormField(
                    controller: _urlController,
                    enabled: settings.enabled,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Workers 端点',
                      hintText: 'https://pocket-ledger.xxx.workers.dev',
                      prefixIcon: Icon(Icons.link),
                    ),
                    validator: (String? v) {
                      final String url = (v ?? '').trim();
                      if (url.isEmpty) return '请填写端点，或关闭云同步';
                      if (!url.startsWith('https://')) {
                        return '必须使用 https，令牌不允许明文传输';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimens.spaceMd),

                  TextFormField(
                    controller: _tokenController,
                    enabled: settings.enabled,
                    obscureText: _obscureToken,
                    decoration: InputDecoration(
                      labelText: '访问令牌',
                      prefixIcon: const Icon(Icons.key_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureToken
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscureToken = !_obscureToken),
                      ),
                    ),
                    validator: (String? v) =>
                        (v ?? '').trim().isEmpty ? '请填写令牌' : null,
                  ),
                  const SizedBox(height: AppDimens.spaceMd),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: settings.enabled && !_saving ? _save : null,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('保存配置'),
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                  Text(
                    '部署 Cloudflare Workers 后填入以上两项。端点与令牌只保存在本机钥匙串，'
                    '不会写入数据库，也不随任何备份外传。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
