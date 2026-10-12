/// 备注元信息行的不断行处理工具。
library;

/// 把备注里「·」分隔的元信息行（如「份额 1000 · 单价 ¥25.00 · 手续费 ¥0.00」）
/// 做不断行处理：
/// - 每个单元内部的普通空格换成不断行空格（\u00A0）；
/// - 并在单元内**逐字**插入 WORD JOINER（\u2060）——CJK 相邻汉字默认允许断行，
///   仅靠 NBSP 锁不住「手续费」这类连续汉字（会在任意两汉字间断行），
///   逐字加 WJ 才能保证整个单元永不拆行；
/// - 换行机会只保留在「·」分隔符两侧，一行放不下时整个单元落到下一行
///   （右对齐场景由调用方 Text 的 textAlign end 保证）。
///
/// 仅改显示文案，不动数据库里存储的备注原文，历史流水同样生效。
String keepNoteUnitsUnbroken(String text) {
  const String wj = '\u2060'; // WORD JOINER：禁止在此断行
  final List<String> outLines = <String>[];
  for (final String line in text.split('\n')) {
    if (!line.contains('·')) {
      outLines.add(line);
      continue;
    }
    outLines.add(
      line
          .split('·')
          .map(
            (String p) => p.trim().replaceAll(' ', '\u00A0').split('').join(wj),
          )
          .join(' · '),
    );
  }
  return outLines.join('\n');
}
