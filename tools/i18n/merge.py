"""Merge the translators' parts into i18n/en.json.

i18n/parts/<group>.json are the per-group tables (zh -> en); i18n/overrides.json
wins over them: whole-sentence templates (keys with %s / %d, see i18n.gd)
and names made consistent across groups. VALUE_FIXES rename a term inside every
value. Prints keys from i18n/keys.json still without English.

Run: python tools/i18n/merge.py
"""
import glob
import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
VALUE_FIXES = {"Safe Bag": "Secure Pouch", "Wolf Soul": "Wolf Spirit"}


def main():
    table = {}
    for path in sorted(glob.glob(os.path.join(ROOT, "i18n", "parts", "*.json"))):
        if path.endswith("_uncertain.json"): continue
        table.update(json.load(open(path, encoding="utf-8")))
    for key, value in table.items():
        for old, new in VALUE_FIXES.items(): value = value.replace(old, new)
        table[key] = value
    # The code also shows pieces of names ("切尔诺伯格 · 坍塌矿区".split(" · ")[0],
    # route details with " / " shown as " · ", a text up to its "（"): a key whose English splits into
    # as many pieces gives each piece its own entry, unless one is already there.
    for key, value in list(table.items()):
        for sep, en_sep in ((" · ", " · "), (" / ", " / "), ("（", " (")):
            zh, en = key.split(sep), value.split(en_sep)
            if len(zh) > 1 and len(zh) == len(en):
                for a, b in zip(zh, en):
                    if a.strip() and a not in table: table[a] = b
    overrides = json.load(open(os.path.join(ROOT, "i18n", "overrides.json"), encoding="utf-8"))
    table.update({k: v for k, v in overrides.items() if not k.startswith("//")})
    json.dump(dict(sorted(table.items())), open(os.path.join(ROOT, "i18n", "en.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    keys = json.load(open(os.path.join(ROOT, "i18n", "keys.json"), encoding="utf-8"))
    missing = [k for k in keys if k not in table]
    print(f"en.json: {len(table)} entries; {len(missing)} extracted keys missing")
    for k in missing[:40]: print("  missing:", k)


if __name__ == "__main__":
    main()
