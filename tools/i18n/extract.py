"""Collect every Chinese string the game can show, for i18n/en.json.

Scans the game's .gd files (not tests) for string literals with CJK text
(lines marked "# i18n: skip" are data that is never shown),
and the base room data (art/rhodes_runtime/room_*.json) for station names.
Format templates are split at their placeholders (%s, %d, %.1f, %+d ...), so
"合同开始：%s。" gives the key "合同开始：" — I18n translates displayed text
piece by piece with the longest keys first, so a formatted message is
covered by its fragments plus the names filled into it.

Writes i18n/keys.json: {key: [first "file:line", source line]}, sorted, and
reports keys that i18n/en.json does not have yet.

Run: python tools/i18n/extract.py
"""
import json
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SKIP = (".godot", "tests", "addons", "tools", "i18n")
STRING = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
PLACEHOLDER = re.compile(r"%[-+ 0#]*\d*(?:\.\d+)?[sdifxXc%]")


def has_cjk(s):
    return any("\u4e00" <= c <= "\u9fff" or "\u3000" <= c <= "\u303f" or "\uff00" <= c <= "\uffef" for c in s)


def pieces(literal):
    text = literal.encode("utf-8").decode("unicode_escape").encode("latin-1").decode("utf-8") if "\\" in literal else literal
    for part in PLACEHOLDER.split(text):
        for line in part.split("\n"):
            line = line.strip()
            if has_cjk(line): yield line


def main():
    keys = {}
    for root, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in SKIP]
        for name in sorted(files):
            if not name.endswith(".gd"): continue
            path = os.path.join(root, name)
            rel = os.path.relpath(path, ROOT).replace("\\", "/")
            for number, line in enumerate(open(path, encoding="utf-8"), 1):
                code = line.lstrip()
                if code.startswith("#"): continue
                # Match tables that never reach the screen (MarketLinks keywords).
                if "i18n: skip" in line: continue
                for literal in STRING.findall(line):
                    try:
                        found = list(pieces(literal))
                    except UnicodeError:
                        found = [literal] if has_cjk(literal) else []
                    for key in found:
                        keys.setdefault(key, [f"{rel}:{number}", line.strip()[:200]])
    # Station names come from the base room data, not code.
    import glob
    for path in sorted(glob.glob(os.path.join(ROOT, "art", "rhodes_runtime", "room_*.json"))):
        rel = os.path.relpath(path, ROOT).replace("\\", "/")
        def walk(node):
            if isinstance(node, dict): [walk(v) for v in node.values()]
            elif isinstance(node, list): [walk(v) for v in node]
            elif isinstance(node, str) and has_cjk(node):
                for key in pieces(node): keys.setdefault(key, [rel, node])
        walk(json.load(open(path, encoding="utf-8")))
    out = dict(sorted(keys.items()))
    json.dump(out, open(os.path.join(ROOT, "i18n", "keys.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    table_path = os.path.join(ROOT, "i18n", "en.json")
    table = json.load(open(table_path, encoding="utf-8")) if os.path.exists(table_path) else {}
    missing = [k for k in out if k not in table]
    print(f"{len(out)} keys, {len(missing)} not in en.json")


if __name__ == "__main__":
    main()
