import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/secrets.dart';
import '../../../core/utils/geo_utils.dart';
import 'bill_io.dart';

/// 截图识别后端：阿里云百炼 Qwen-VL（OpenAI 兼容视觉接口，大陆网络可达）。
///
/// 端点与模型有硬编码默认值，开箱即用；API Key 内置（见 [builtInOcrApiKey]，
/// 来自 gitignored 的 `lib/core/config/secrets.dart`，编译进 app 二进制）。
/// 三项仍可用 [--dart-define] 覆盖（便于临时切换密钥/端点而不改源码）：
///   SCREENSHOT_OCR_ENDPOINT  接口地址（默认百炼兼容模式 chat/completions）
///   SCREENSHOT_OCR_API_KEY   内置密钥为空时，可用此覆盖
///   SCREENSHOT_OCR_MODEL     视觉模型名（默认 qwen3-vl-plus）
const String kScreenshotOcrEndpoint = String.fromEnvironment(
  'SCREENSHOT_OCR_ENDPOINT',
  defaultValue:
      'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
);

const String kScreenshotOcrApiKey = String.fromEnvironment(
  'SCREENSHOT_OCR_API_KEY',
  defaultValue: builtInOcrApiKey,
);

const String kScreenshotOcrModel = String.fromEnvironment(
  'SCREENSHOT_OCR_MODEL',
  defaultValue: 'qwen3-vl-plus',
);

/// 截图自动记账：把账单截图直接送到阿里云百炼的多模态视觉模型，
/// 由模型抽取成结构化账单，再映射为 [BillRow] 交给导入确认页归户写入。
///
/// 设计为纯 Dart（仅依赖 `dio` + `image_picker`），不引入任何原生代码，
/// 因此 Windows 开发、iOS 免签分发均可直接运行，且端点位于大陆可达的
/// `dashscope.aliyuncs.com`（相比 `*.workers.dev` 不受墙影响）。
class ScreenshotOcrService {
  const ScreenshotOcrService._();

  static const ScreenshotOcrService instance = ScreenshotOcrService._();

  /// 复用 Dio 实例，避免每次识别新建 TCP 连接。
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  /// 是否已正确配置（内置或 --dart-define 覆盖了 API Key 才视为已配置）。
  bool get isConfigured => kScreenshotOcrApiKey.isNotEmpty;

  /// 识别一组截图，返回与 [parseInput] 同构的 [ParseResult]。
  Future<ParseResult> recognize(List<XFile> images) async {
    if (!isConfigured) {
      return const ParseResult(<BillRow>[], <String>[
        '识别服务未配置：内置密钥为空，请检查 lib/core/config/secrets.dart'
            ' 中的 builtInOcrApiKey（或用 --dart-define=SCREENSHOT_OCR_API_KEY 覆盖）。',
      ]);
    }
    if (images.isEmpty) return const ParseResult(<BillRow>[], <String>[]);

    try {
      // 读图 → data URI(base64)，整批作为多图消息一次上传（模型一并识别）。
      final List<String> dataUris = <String>[];
      for (final XFile f in images) {
        final List<int> bytes = await f.readAsBytes();
        dataUris.add('data:${_mimeOf(bytes)};base64,${base64Encode(bytes)}');
      }

      final List<Map<String, dynamic>> content = <Map<String, dynamic>>[
        for (final String uri in dataUris)
          <String, dynamic>{
            'type': 'image_url',
            'image_url': <String, dynamic>{'url': uri},
          },
        <String, dynamic>{'type': 'text', 'text': _userPrompt},
      ];

      final Response<dynamic> resp = await _dio.post<dynamic>(
        kScreenshotOcrEndpoint,
        options: Options(
          headers: <String, dynamic>{
            'Authorization': 'Bearer $kScreenshotOcrApiKey',
            'Content-Type': 'application/json',
          },
        ),
        data: jsonEncode(<String, dynamic>{
          'model': kScreenshotOcrModel,
          'messages': <Map<String, dynamic>>[
            <String, dynamic>{'role': 'system', 'content': _systemPrompt},
            <String, dynamic>{'role': 'user', 'content': content},
          ],
          'temperature': 0.1,
        }),
      );

      final dynamic raw = resp.data;
      final Map<String, dynamic> json =
          (raw is String ? jsonDecode(raw) : raw) as Map<String, dynamic>;

      // 百炼错误形态：{"code":"...","message":"..."}。
      if (json['code'] != null || json['error'] != null) {
        final String msg =
            (json['message'] ?? json['error'] ?? '未知错误').toString();
        return ParseResult(<BillRow>[], <String>['识别服务：$msg']);
      }

      final String text = _extractContent(json);
      final List<dynamic> items = _extractItems(text);

      final List<BillRow> rows = <BillRow>[];
      final List<String> errors = <String>[];
      for (int i = 0; i < items.length; i++) {
        try {
          final dynamic it = items[i];
          if (it is! Map) {
            errors.add('第${i + 1}项：格式不是对象');
            continue;
          }
          // 复用跨语言共用解析器（bill_io.dart:parseOcrItem），保证
          // 与「Swift 已识别、Dart 仅重建」路径语义一致。
          final BillRow? row = parseOcrItem(it.cast<String, dynamic>());
          if (row == null) {
            errors.add('第${i + 1}项：缺少金额 / 类型 / 账户等必要字段');
          } else {
            rows.add(row);
          }
        } catch (e) {
          errors.add('第${i + 1}项解析失败：$e');
        }
      }
      if (rows.isEmpty && errors.isEmpty) {
        errors.add('模型未返回可识别的账单，请换一张更清晰的截图');
      }

      // 截图识别成功后，快速尝试获取 GPS 位置（低精度 + 短超时，不阻塞主流程）。
      // 位置信息附加到每一行账单中（仅当该行没有位置信息时）。
      if (rows.isNotEmpty) {
        try {
          final Position pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 2),
            ),
          ).timeout(const Duration(seconds: 2));
          final String? placeName = await reverseGeocodeSemantic(
            pos.latitude,
            pos.longitude,
          ).timeout(const Duration(seconds: 2));
          for (int i = 0; i < rows.length; i++) {
            final BillRow row = rows[i];
            if (row.placeName == null || row.placeName!.isEmpty) {
              rows[i] = row.copyWith(
                placeName: placeName,
                latitude: pos.latitude,
                longitude: pos.longitude,
              );
            }
          }
        } catch (_) {
          // 定位失败，不阻断识别结果
        }
      }

      return ParseResult(rows, errors);
    } on DioException catch (e) {
      return ParseResult(
        <BillRow>[],
        <String>['识别请求失败：${e.message ?? e.type}'],
      );
    } catch (e) {
      return ParseResult(<BillRow>[], <String>['识别失败：$e']);
    }
  }

  /// 从 OpenAI 兼容响应里取出模型文本（choices[0].message.content）。
  String _extractContent(Map<String, dynamic> json) {
    final dynamic choices = json['choices'];
    if (choices is List && choices.isNotEmpty) {
      final dynamic msg =
          choices.first is Map ? (choices.first as Map)['message'] : null;
      if (msg is Map && msg['content'] is String) {
        return msg['content'] as String;
      }
    }
    // 兜底：部分实现直接把文本放顶层。
    if (json['content'] is String) return json['content'] as String;
    return '';
  }

  /// 从模型文本里稳健地抽取 items 数组（兼容 markdown 围栏 / 包裹对象 / 裸数组）。
  List<dynamic> _extractItems(String text) {
    String s = text.trim();
    final RegExp fence =
        RegExp(r'```(?:json)?\s*([\s\S]*?)```', caseSensitive: false);
    final Match? m = fence.firstMatch(s);
    if (m != null) s = m.group(1)!.trim();

    dynamic decoded;
    try {
      decoded = jsonDecode(s);
    } catch (_) {
      final int open = s.indexOf(RegExp(r'[\{\[]'));
      final int close = s.lastIndexOf(RegExp(r'[\}\]]'));
      if (open >= 0 && close > open) {
        try {
          decoded = jsonDecode(s.substring(open, close + 1));
        } catch (_) {
          decoded = null;
        }
      }
    }
    if (decoded is List) return decoded;
    if (decoded is Map) {
      final dynamic items =
          decoded['items'] ?? decoded['data'] ?? decoded['results'];
      if (items is List) return items;
    }
    return const <dynamic>[];
  }

  // OCR 单条 item 解析已迁移至 bill_io.dart 的 parseOcrItem（跨语言共用）：
  // 「Swift 后台识别、Dart 落库」与「Dart 前台识别」两端共用同一解析真源。

  String _mimeOf(List<int> bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    return 'image/jpeg';
  }
}

const String _systemPrompt = '''
你是一个账单识别助手。用户会发送一张或多张账单 / 收据 / 交易截图。
请逐笔识别其中的交易，并只输出一个 JSON 对象：{"items":[...]}。
每个 item 的字段：
- amount：金额，数字或字符串，如 "12.50"
- direction："income"（收入）/ "expense"（支出）/ "transfer"（转账）
- category：中文分类名，如 餐饮 / 交通 / 工资 / 购物；无法确定可留空字符串
- date：交易日期，格式 "YYYY-MM-DD HH:mm" 或 "YYYY-MM-DD"
- merchant：商户名
- account：付款 / 扣款账户名，如 支付宝 / 微信 / 招商银行；转账时填转出账户
- toAccount：仅转账时填转入账户，其他情况留空字符串
- note：备注
- currency：币种代码，人民币为 "CNY"
- confidence：0~1 的识别置信度，不确定给 0.5
只输出 JSON，不要任何解释文字或 markdown 围栏。
''';

const String _userPrompt = '''
请识别上面图片中的账单交易，按系统指令输出 items JSON 数组。
若某张图看不清或没有交易记录，该图不输出任何 item。
''';
