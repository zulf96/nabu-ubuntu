#!/usr/bin/env python3
"""فحص الروابط والمراسي في ملفات Markdown داخل المستودع.

- يتحقّق من أن كل رابط نسبي (ملف أو مجلد) موجود.
- يتحقّق من أن كل مرساة (#...) تقابل عنواناً في الملف الهدف.
- يتجاهل http/https/mailto وأي مخطط غير ملفي.

الاستخدام:
    python3 tools/check-links.py [مسار الجذر]
كود الخروج: 0 سليم، 1 توجد مشاكل.
"""
from __future__ import annotations

import re
import sys
import unicodedata
from pathlib import Path

SKIP_DIRS = {".git", "node_modules", ".github/workflows"}
LINK_RE = re.compile(r"!?\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.*)$", re.MULTILINE)
FENCE_RE = re.compile(r"```.*?```|~~~.*?~~~", re.DOTALL)


def slugify(text: str) -> str:
    """تقريب جيد لقاعدة github-slugger مع دعم العربية."""
    text = re.sub(r"<[^>]+>", "", text)
    text = text.strip().lower()
    out = []
    for ch in text:
        if ch.isalnum() or ch in "-_ ":
            out.append(ch)
        elif ch == "_":
            out.append(ch)
    s = "".join(out).strip()
    return re.sub(r"\s+", "-", s)


def headings(path: Path) -> set[str]:
    try:
        raw = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return set()
    raw = FENCE_RE.sub("", raw)
    slugs = set()
    for m in HEADING_RE.finditer(raw):
        slugs.add(slugify(m.group(2)))
    return slugs


def check(root: Path) -> int:
    problems = 0
    md_files = sorted(root.rglob("*.md"))
    cache: dict[Path, set[str]] = {}

    for md in md_files:
        if any(part in SKIP_DIRS for part in md.parts):
            continue
        try:
            text = md.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            print(f"[ERR ] {md}: لا يمكن القراءة ({exc})")
            problems += 1
            continue
        text = FENCE_RE.sub("", text)

        for match in LINK_RE.finditer(text):
            target = match.group(1).strip()
            if target.startswith(("http://", "https://", "mailto:", "tel:", "ftp:")):
                continue
            if target.startswith("#"):
                path_part, anchor = str(md), target[1:]
            elif "#" in target:
                path_part, anchor = target.split("#", 1)
            else:
                path_part, anchor = target, ""

            dest = (md.parent / path_part).resolve() if path_part else md.resolve()
            if path_part and not dest.exists():
                print(f"[MISS] {md.relative_to(root)} -> {target} (الملف غير موجود)")
                problems += 1
                continue
            if dest.is_dir():
                continue
            if anchor and dest.suffix.lower() == ".md":
                if dest not in cache:
                    cache[dest] = headings(dest)
                if anchor not in cache[dest]:
                    print(f"[ANCH] {md.relative_to(root)} -> {target} (لا يوجد عنوان بهذا المرساة)")
                    problems += 1

    if problems == 0:
        print(f"✔ سليم: {len(md_files)} ملف Markdown، لا روابط أو مراسي مكسورة.")
    return 0 if problems == 0 else 1


if __name__ == "__main__":
    root_dir = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent)
    sys.exit(check(root_dir.resolve()))
