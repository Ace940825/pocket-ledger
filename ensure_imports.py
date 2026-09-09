"""按文件确保指定 import 存在：去重 + 按字母序插入正确的分区。

用法：确保当前目录为 pocket_ledger，运行 `python ensure_imports.py`
（幂等，可重复执行）
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# 文件 -> 需要确保存在的 import 列表
NEEDS: dict[str, list[str]] = {
    "lib/app.dart": [
        "import 'package:go_router/go_router.dart';",
    ],
    "lib/database/connection/connection_native.dart": [
        "import 'package:drift/drift.dart';",
        "import 'package:sqlite3/sqlite3.dart';",
    ],
    "lib/database/daos/transactions_dao.dart": [
        "import '../../domain/enums.dart';",
    ],
    "lib/features/accounts/providers/accounts_providers.dart": [
        "import '../../../domain/enums.dart';",
    ],
    "lib/features/budget/presentation/budget_page.dart": [
        "import '../../../domain/enums.dart';",
    ],
    "lib/features/home/presentation/home_page.dart": [
        "import '../../../database/app_database.dart';",
    ],
    "lib/features/ledger/presentation/edit_transaction_page.dart": [
        "import '../data/transaction_repository.dart';",
    ],
}

DART_RE = re.compile(r"^(library|import|export|part)\b")


def split_header(lines: list[str]) -> tuple[int, int]:
    """返回 (第一个指令/注释开始的下标, 指令区结束的下标)。"""
    first = 0
    while first < len(lines) and lines[first].strip() == "":
        first += 1
    last = first
    while last < len(lines) and (
        DART_RE.match(lines[last]) or lines[last].lstrip().startswith("//")
    ):
        last += 1
    return first, last


def directive_sort_key(line: str) -> tuple[int, str]:
    s = line.strip()
    if s.startswith("import 'dart:"):
        return (0, s)
    if s.startswith("export "):
        return (3, s)
    if s.startswith("part "):
        return (4, s)
    if s.startswith("import 'package:"):
        return (1, s)
    return (2, s)


def ensure(path_str: str, imports: list[str]) -> bool:
    path = Path(path_str)
    if not path.exists():
        print(f"[skip] 文件不存在: {path}")
        return False

    text = path.read_text(encoding="utf-8")
    lines = text.split("\n")

    first, last = split_header(lines)
    header = [ln for ln in lines[first:last] if ln.strip()]

    changed = False
    for imp in imports:
        if any(ln.strip() == imp for ln in header):
            continue
        header.append(imp)
        changed = True

    if not changed:
        return False

    header.sort(key=directive_sort_key)

    # 分区之间插空行：dart / package / relative / export / part
    out: list[str] = []
    prev_group = -1
    for ln in header:
        grp = directive_sort_key(ln)[0]
        if out and grp != prev_group:
            out.append("")
        out.append(ln)
        prev_group = grp

    new_lines = lines[:first] + out + [""] + lines[last:]
    path.write_text("\n".join(new_lines), encoding="utf-8")
    print(f"[ok] {path} 补充 / 整理导入")
    return True


def main() -> int:
    n = 0
    for f, imps in NEEDS.items():
        if ensure(f, imps):
            n += 1
    print(f"共修改 {n} 个文件")
    return 0


if __name__ == "__main__":
    sys.exit(main())
