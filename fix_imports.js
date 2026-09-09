const fs = require('fs');
const path = require('path');

const ROOT = process.argv[2];
const DRIFT_IMPORT = "import 'package:drift/drift.dart';";

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === 'database') continue;
      walk(full, out);
    } else if (
      entry.isDirectory() === false &&
      entry.name.endsWith('.dart') &&
      !entry.name.endsWith('.g.dart')
    ) {
      out.push(full);
    }
  }
  return out;
}

const files = walk(path.join(ROOT, 'lib'));
let changed = 0;

for (const file of files) {
  let content = fs.readFileSync(file, 'utf8');
  const original = content;
  const lines = content.split('\n');

  // 1. 去掉完全重复的 import 行
  const seen = new Set();
  const deduped = [];
  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed.startsWith('import ') && trimmed.endsWith(';')) {
      if (seen.has(trimmed)) continue;
      seen.add(trimmed);
    }
    deduped.push(line);
  }
  content = deduped.join('\n');

  // 2. 用到 drift 的 Value() 但没导入 drift 时，按字母序插入
  const usesDriftValue = /\b(Value<|const Value|Value\()/.test(content);
  const hasDriftImport = content.includes("package:drift/drift.dart");
  if (usesDriftValue && !hasDriftImport) {
    const cl = content.split('\n');
    const packageIdx = [];
    cl.forEach((l, i) => {
      if (l.startsWith("import 'package:")) packageIdx.push(i);
    });
    let insertAt = -1;
    for (const i of packageIdx) {
      const uri = cl[i].slice("import '".length);
      if (uri > 'package:drift/drift.dart') {
        insertAt = i;
        break;
      }
    }
    if (insertAt === -1) {
      if (packageIdx.length > 0) insertAt = packageIdx[packageIdx.length - 1] + 1;
      else insertAt = 0;
    }
    cl.splice(insertAt, 0, DRIFT_IMPORT);
    content = cl.join('\n');
  }

  if (content !== original) {
    fs.writeFileSync(file, content);
    changed++;
  }
}

console.log(`processed ${files.length} files, changed ${changed}`);
