import 'package:flutter_test/flutter_test.dart';

import 'package:pocket_ledger/shared/widgets/attachment_viewer.dart';

/// [attachment_viewer] 中纯函数的回归测试（不依赖网络 / 文件系统）。
///
/// 这些函数决定一条附件地址是「本机路径」还是「云端 URL」、以及如何拼接
/// baseUrl，直接关系多端能否查看原图，必须锁死行为。
void main() {
  group('isRemoteAttachmentUrl', () {
    test('Worker 代理的相对地址判定为远程', () {
      expect(isRemoteAttachmentUrl('/api/file/abc-123.jpg'), isTrue);
    });

    test('绝对 https 地址判定为远程', () {
      expect(isRemoteAttachmentUrl('https://cdn.example.com/x.png'), isTrue);
      expect(isRemoteAttachmentUrl('http://cdn.example.com/x.png'), isTrue);
    });

    test('本机绝对路径判定为本机', () {
      expect(isRemoteAttachmentUrl(r'C:\Users\me\a.jpg'), isFalse);
      expect(isRemoteAttachmentUrl('/data/user/0/app/files/a.jpg'), isFalse);
    });
  });

  group('resolveAttachmentUrl', () {
    test('绝对地址原样返回', () {
      const String url = 'https://cdn.example.com/x.png';
      expect(resolveAttachmentUrl(url, 'https://sync.dev'), url);
    });

    test('相对地址拼接 baseUrl（自动去掉末尾斜杠）', () {
      expect(
        resolveAttachmentUrl('/api/file/k', 'https://sync.example.dev'),
        'https://sync.example.dev/api/file/k',
      );
      expect(
        resolveAttachmentUrl('/api/file/k', 'https://sync.example.dev/'),
        'https://sync.example.dev/api/file/k',
      );
    });

    test('本机路径原样返回（交予 FileImage）', () {
      const String local = r'C:\Users\me\a.jpg';
      expect(resolveAttachmentUrl(local, 'https://sync.dev'), local);
    });
  });

  group('parseAttachmentUrls', () {
    test('合法 JSON 数组解码为列表', () {
      expect(
        parseAttachmentUrls('["/api/file/a","/api/file/b"]'),
        <String>['/api/file/a', '/api/file/b'],
      );
    });

    test('null / 空串 / 非数组 / 脏数据一律返回 null', () {
      expect(parseAttachmentUrls(null), isNull);
      expect(parseAttachmentUrls(''), isNull);
      expect(parseAttachmentUrls('not json'), isNull);
      expect(parseAttachmentUrls('123'), isNull);
      expect(parseAttachmentUrls('{"a":1}'), isNull);
    });
  });
}
