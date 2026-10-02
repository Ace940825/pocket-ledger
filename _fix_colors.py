#!/usr/bin/env python3
# 一次性脚本：把本轮硬编码颜色改为 AppColors 令牌。仅作用于下列 14 个文件。
import re, os

ROOT = "C:/Users/l9408/WorkBuddy/2026-09-08-12-33-42/pocket_ledger"

FILES = [
    "lib/features/report/presentation/report_page.dart",
    "lib/shared/widgets/calendar_sheet.dart",
    "lib/features/ledger/presentation/ledger_filter_page.dart",
    "lib/features/ledger/presentation/bill_manage_page.dart",
    "lib/features/ledger/presentation/bill_import_page.dart",
    "lib/features/ledger/presentation/bill_screenshot_page.dart",
    "lib/features/ledger/presentation/bill_clean_page.dart",
    "lib/features/settings/presentation/me_page.dart",
    "lib/features/ledger/presentation/bill_export_page.dart",
    "lib/shared/widgets/day_pick_sheet.dart",
    "lib/features/savings/presentation/savings_mode_create_page.dart",
    "lib/features/savings/presentation/savings_goal_detail_page.dart",
    "lib/features/ledger/presentation/bill_list_page.dart",
    "lib/features/record/presentation/bill_selection_page.dart",
]

HEX_MAP = {
    "0xFFE3F0FD": "AppColors.blueTintBg",
    "0xFF3B82D6": "AppColors.blueTint",
    "0xFFEFE9FB": "AppColors.purpleTintBg",
    "0xFF8B5CF6": "AppColors.purpleTint",
    "0xFFE6F4EA": "AppColors.greenTintBg",
    "0xFFFDE9E7": "AppColors.redSoftBg",
    "0xFF7A8CA0": "AppColors.transferBlueGray",
    "0xFFF6F7F9": "AppColors.graySurface",
    "0x33000000": "AppColors.scrimBlack20",
    "0xFFF5C542": "AppColors.goldStar",
    "0xFF5F9A6E": "AppColors.sageRibbon",
    "0xFFF0A24B": "AppColors.apricot",
    "0xFF5B8DEF": "AppColors.mistBlue",
    "0xFF9B6DF3": "AppColors.orchid",
    "0xFFE56D9C": "AppColors.peachPink",
    "0xFF3FB8B0": "AppColors.tealJade",
    "0x52141E18": "AppColors.scrimDarkGreen32",
    "0xFFE1ECFB": "AppColors.pillBlueBg",
    "0xFFFBE3DF": "AppColors.pillRedBg",
    "0xFF3F72C9": "AppColors.pillBlue",
    "0xFFC9473B": "AppColors.pillRed",
}

hex_re = re.compile(r"Color\((0x[0-9A-Fa-f]{8})\)")
white_re = re.compile(r"\bColors\.white\b")
black54_re = re.compile(r"\bColors\.black54\b")
black_re = re.compile(r"\bColors\.black\b")
import_re = re.compile(r"import\s+['\"].*theme/(app_colors|theme)\.dart['\"]")

total = 0
for rel in FILES:
    p = os.path.join(ROOT, rel)
    with open(p, "r", encoding="utf-8") as f:
        src = f.read()
    out = src
    cnt = 0
    # 1) 先确保 import（基于原始 import 行，避免漏加）
    inserted = False
    if not import_re.search(out):
        up = "../" * len(rel.split("/")[:-1])
        imp = f"import '{up}theme/app_colors.dart';"
        m = re.search(r"import 'package:flutter/material\.dart';\n", out)
        if m:
            out = out[:m.end()] + imp + "\n" + out[m.end():]
        else:
            out = imp + "\n" + out
        inserted = True
    # 2) hex
    ctr = [0]
    def hex_sub(m, _ctr=ctr):
        tok = HEX_MAP.get(m.group(1))
        if tok is None:
            return m.group(0)
        _ctr[0] += 1
        return tok
    out = hex_re.sub(hex_sub, out)
    cnt += ctr[0]; total += ctr[0]
    # 3) white / black54 / black
    out, nw = white_re.subn("AppColors.cream", out); total += nw; cnt += nw
    out, nb = black54_re.subn("AppColors.ink2", out); total += nb; cnt += nb
    out, nk = black_re.subn("AppColors.ink", out); total += nk; cnt += nk

    if out != src:
        with open(p, "w", encoding="utf-8") as f:
            f.write(out)
        print(f"[changed {cnt:2d}{' +import' if inserted else '        '}] {rel}")
    else:
        print(f"[  noop            ] {rel}")

print(f"\nTOTAL replacements = {total}")
