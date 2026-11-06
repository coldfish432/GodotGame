"""Build the export whitelist: only files the game actually reaches.

Roots = main scene + project.godot references. From every reached text file
(.gd/.tscn/.tres/.gdshader/.json/...) we follow:
  * literal res:// file paths and uid:// ids,
  * format paths ("res://a/%s_b.png") -> every file matching the pattern,
  * prefix / directory paths ("res://art/kit/", "res://x/relic_" + id) -> every
    file in that directory whose name starts with the prefix,
  * class_name identifiers used as words.
Writes export_files into export_presets.cfg (export_filter="resources") and a
report to build/_export_manifest.txt.

    python tools/export_manifest.py            # update preset + report
    python tools/export_manifest.py --dry-run  # report only
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEXT_EXT = {".gd", ".tscn", ".tres", ".gdshader", ".gdshaderinc", ".json", ".cfg", ".godot", ".csv", ".txt"}
# never shipped even if a path string mentions them
SKIP_TOP = {".godot", ".git", "tests", "tools", "design", "evidence", "logs", "youtube", "a3", "a5", "build"}
SKIP_PART = re.compile(r"(^|/)(batch_[^/]*|refs(_[^/]*)?|[^/]*_inputs[^/]*|baseline|_to_sol|review_[^/]*|work_[^/]*)(/|$)")
JUNK_EXT = {".import", ".uid", ".md", ".zip", ".py", ".ps1", ".sh", ".blend", ".blend1", ".log", ".mp4", ".psd", ".kra"}


def rel(p):
    return os.path.relpath(p, ROOT).replace("\\", "/")


def scan_files():
    files = set()
    for d, dirs, names in os.walk(ROOT):
        r = rel(d)
        if r == ".":
            dirs[:] = [x for x in dirs if x not in SKIP_TOP]
        if ".gdignore" in names and r != ".":
            dirs[:] = []
            continue
        for n in names:
            p = n if r == "." else r + "/" + n
            if os.path.splitext(n)[1].lower() in JUNK_EXT or n.startswith(".") or SKIP_PART.search(p):
                continue
            files.add(p)
    return files


def uid_map(files):
    m = {}
    pat = re.compile(r'uid="?(uid://[a-z0-9]+)')
    for f in files:
        for side in (f + ".uid", f + ".import"):
            sp = os.path.join(ROOT, side)
            if os.path.exists(sp):
                with open(sp, encoding="utf-8", errors="ignore") as fh:
                    head = fh.read(400)
                g = re.search(r"(uid://[a-z0-9]+)", head)
                if g: m[g.group(1)] = f
        if f.endswith((".tscn", ".tres")):
            with open(os.path.join(ROOT, f), encoding="utf-8", errors="ignore") as fh:
                g = pat.search(fh.readline())
            if g: m[g.group(1)] = f
    return m


def class_names(files):
    out = {}
    for f in files:
        if f.endswith(".gd"):
            with open(os.path.join(ROOT, f), encoding="utf-8", errors="ignore") as fh:
                for line in fh:
                    g = re.match(r"\s*class_name\s+(\w+)", line)
                    if g:
                        out[g.group(1)] = f
                        break
    return out


RES = re.compile(r"res://[^\"'\s)\]]*")
UID = re.compile(r"uid://[a-z0-9]+")
WORD = re.compile(r"[A-Za-z_]\w*")


def main():
    dry = "--dry-run" in sys.argv
    files = scan_files()
    by_dir = {}
    for f in files:
        by_dir.setdefault(f.rsplit("/", 1)[0] if "/" in f else "", []).append(f)
    uids = uid_map(files)
    classes = class_names(files)
    reached, queue, unresolved = set(), ["project.godot"], set()

    extracted = {}

    def is_extracted(f):
        if f not in extracted:
            imp = os.path.join(ROOT, f + ".import")
            extracted[f] = False
            if f.lower().endswith(".png") and os.path.exists(imp):
                with open(imp, encoding="utf-8", errors="ignore") as fh:
                    extracted[f] = "generator_parameters" in fh.read(1200)
        return extracted[f]

    def add(f):
        if f in files and f not in reached:
            reached.add(f); queue.append(f)

    def resolve(path):
        path = path.rstrip(".,;:")
        if path in files:
            add(path); return
        d, _, name = path.rpartition("/")
        if "%" in name or "{" in name or "%" in d:
            rx = re.compile("^" + re.sub(r"%[-0-9.]*[sdif]|\\\{[^}]*\\\}", "[^/]*", re.escape(path)) + "$")
            hits = [f for f in files if rx.match(f)]
        else:
            hits = [f for f in by_dir.get(d, []) if f.rsplit("/", 1)[-1].startswith(name)] if (d or name) else []
            # textures a .glb import extracted come in as that scene's
            # dependencies (Godot adds them), not as loose matches
            hits = [h for h in hits if not is_extracted(h)]
        if not hits:
            unresolved.add(path)
        for h in hits: add(h)

    while queue:
        f = queue.pop()
        if os.path.splitext(f)[1].lower() not in TEXT_EXT:
            continue
        with open(os.path.join(ROOT, f), encoding="utf-8", errors="ignore") as fh:
            text = fh.read()
        for m in RES.findall(text):
            resolve(m[len("res://"):])
        for u in UID.findall(text):
            if u in uids: add(uids[u])
        if f.endswith(".gd") or f.endswith(".tscn"):
            for w in set(WORD.findall(text)) & classes.keys():
                add(classes[w])

    reached.discard("project.godot")
    out = sorted(reached)
    size = sum(os.path.getsize(os.path.join(ROOT, f)) for f in out)
    total = sum(os.path.getsize(os.path.join(ROOT, f)) for f in files)
    os.makedirs(os.path.join(ROOT, "..", "build"), exist_ok=True)
    with open(os.path.join(ROOT, "..", "build", "_export_manifest.txt"), "w", encoding="utf-8") as fh:
        fh.write(f"# {len(out)} files, {size/1e6:.1f} MB source (of {len(files)} files / {total/1e6:.1f} MB candidates)\n")
        fh.write("# unresolved path strings:\n" + "".join(f"#   {u}\n" for u in sorted(unresolved)))
        fh.write("\n".join(out) + "\n")
    print(f"{len(out)} files, {size/1e6:.1f} MB (candidates {len(files)} / {total/1e6:.1f} MB); unresolved {len(unresolved)}")
    if dry:
        return
    cfg_path = os.path.join(ROOT, "export_presets.cfg")
    with open(cfg_path, encoding="utf-8") as fh:
        cfg = fh.read()
    head, sep, rest = cfg.partition("[preset.0.options]")
    lst = ", ".join('"res://%s"' % f for f in out)
    head = re.sub(r'^export_filter=.*$', 'export_filter="resources"', head, flags=re.M)
    head = re.sub(r'^export_files=.*\n', '', head, flags=re.M)
    head = re.sub(r'^include_filter=.*$', 'include_filter=""', head, flags=re.M)
    head = head.replace('export_filter="resources"\n', 'export_filter="resources"\nexport_files=PackedStringArray(%s)\n' % lst, 1)
    with open(cfg_path, "w", encoding="utf-8") as fh:
        fh.write(head + sep + rest)
    print("export_presets.cfg updated")


if __name__ == "__main__":
    main()
