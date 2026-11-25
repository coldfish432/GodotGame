"""Build media/BXX.mp4 for the pitch film.

Capture beats: contiguous windows cut from the raw Movie Maker AVIs (never
retimed), each with a corner label naming the source, the commit and any setup
shortcut. Graphic beats: still boards drawn here, labelled CONSTRUCTED.

    python tools/make_media.py [B00 B01 ...]
"""
from pathlib import Path
import json, math, subprocess, sys, tempfile
from PIL import Image, ImageDraw, ImageFont

REEL = Path(__file__).resolve().parents[1]
ROOT = REEL.parents[2]                      # D:/CSYE 7370
RAW = ROOT / "build" / "pitch-raw"
COURSE = ROOT / "csye-7270-course/fall-2026/jingyao-y"
A5 = ROOT / "downfall-godot/evidence/a5/use-it"
A6 = COURSE / "assignment-6/walker-downfall/youtube/claude-liam-downfall-a6-particles-gamedev/capture/a_play"
A7 = COURSE / "assignment-7/walker-downfall/youtube/claude-liam-downfall-a7-animation-gamedev/capture/wave_dodges"
OUT = REEL / "media"
W, H, FPS = 3840, 2160, 30
SANS, SANSB, MONO = "C:/Windows/Fonts/segoeui.ttf", "C:/Windows/Fonts/segoeuib.ttf", "C:/Windows/Fonts/consola.ttf"
PAPER, INK, SOFT, ACCENT, RULE, GOOD = "#F4F1EA", "#26231f", "#6a645a", "#C8553D", "#d6d0c3", "#3d7a4f"

sheet = json.loads((REEL / "beat_sheet.json").read_text(encoding="utf-8"))
BEAT = {b["beat_id"]: b for b in sheet["beats"]}
PROV = {}

def dur(k):
    return math.ceil(BEAT[k]["actual_duration_s"] * FPS) / FPS

def F(path, size): return ImageFont.truetype(path, size)

def run(args): subprocess.run(args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

COMMIT = "commit 1fbc309a"
CAP = "REAL CAPTURE · " + COMMIT + " · scripted input (AiDriver) · Godot Movie Maker 30 fps"

def label_png(lines, path, accent=ACCENT):
    """Top-centre label strip on a transparent 4K canvas."""
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    f1, f2 = F(SANSB, 44), F(SANS, 38)
    widths = [d.textlength(lines[0], font=f1)] + [d.textlength(t, font=f2) for t in lines[1:]]
    bw = int(max(widths)) + 80
    bh = 30 + 58 + 50 * (len(lines) - 1) + 20
    x0 = (W - bw) // 2; y0 = 150
    d.rectangle([x0, y0, x0 + bw, y0 + bh], fill=(14, 14, 16, 215))
    d.rectangle([x0, y0, x0 + 10, y0 + bh], fill=accent)
    d.text((x0 + 40, y0 + 24), lines[0], font=f1, fill="#ffffff")
    for i, t in enumerate(lines[1:]):
        d.text((x0 + 40, y0 + 88 + 50 * i), t, font=f2, fill="#f0c9a0")
    img.save(path)

def cut(src, start, length, lines, out, *, image_seq=False, still=False, scale_nearest=False):
    """One window of a source, labelled, at 4K/30, no audio, never retimed."""
    lab = Path(tempfile.mkdtemp()) / "label.png"
    label_png(lines, lab)
    if still:
        inp = ["-loop", "1", "-t", f"{length}", "-i", str(src)]
    elif image_seq:
        inp = ["-framerate", "30", "-start_number", str(int(start * FPS)), "-t", f"{length}", "-i", str(src)]
    else:
        inp = ["-ss", f"{start}", "-t", f"{length}", "-i", str(src)]
    sc = f"scale={W}:{H}:flags=neighbor" if scale_nearest else f"scale={W}:{H}"
    run(["ffmpeg", "-y", *inp, "-i", str(lab), "-filter_complex",
         f"[0:v]{sc},fps={FPS},setsar=1[v];[v][1:v]overlay=0:0,format=yuv420p",
         "-an", "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-r", str(FPS), str(out)])

def concat(parts, key):
    lst = Path(tempfile.mkdtemp()) / "list.txt"
    lst.write_text("".join(f"file '{p.as_posix()}'\n" for p in parts), encoding="utf-8")
    out = OUT / f"{key}.mp4"
    run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(lst), "-c", "copy", str(out)])
    return out

def capture_beat(key, pieces):
    """pieces: (source, start, length, extra_label_lines, kind) — lengths are
    scaled so they sum to the beat; the last piece takes the rounding."""
    total = dur(key)
    want = sum(p[2] for p in pieces)
    tmp = Path(tempfile.mkdtemp())
    parts, used, rec = [], 0.0, []
    for i, (src, start, length, extra, kind) in enumerate(pieces):
        L = round(length * total / want * FPS) / FPS if i < len(pieces) - 1 else round((total - used) * FPS) / FPS
        used += L
        lines = extra
        p = tmp / f"p{i}.mp4"
        cut(src, start, L, lines, p, image_seq=(kind == "seq"), still=(kind == "still"), scale_nearest=(kind in ("seq", "still")))
        parts.append(p)
        rec.append({"source": str(src), "start_s": start, "length_s": L, "kind": kind, "label": lines})
    concat(parts, key)
    PROV[key] = {"kind": "real capture windows, not retimed", "duration": total, "pieces": rec}

# ---------------- graphic boards ----------------

def board(title=None):
    img = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(img)
    d.text((210, 150), "CONSTRUCTED  ·  diagram drawn for this pitch, not game footage", font=F(SANSB, 40), fill=ACCENT)
    if title:
        d.text((210, 220), title, font=F(SANSB, 120), fill=INK)
        d.rectangle([210, 380, 410, 392], fill=ACCENT)
    return img, d

def box(d, xy, head, body=(), fill="#ffffff", edge=RULE, hs=64, bs=50, hc=INK):
    x0, y0, x1, y1 = xy
    d.rectangle(xy, fill=fill, outline=edge, width=5)
    d.text((x0 + 50, y0 + 40), head, font=F(SANSB, hs), fill=hc)
    for i, t in enumerate(body):
        d.text((x0 + 50, y0 + 60 + hs + 30 + i * (bs + 22)), t, font=F(SANS, bs), fill=SOFT)

def still(img, key, note):
    p = Path(tempfile.mkdtemp()) / "b.png"
    img.save(p)
    run(["ffmpeg", "-y", "-loop", "1", "-t", f"{dur(key)}", "-i", str(p), "-vf", f"fps={FPS},format=yuv420p",
         "-c:v", "libx264", "-preset", "medium", "-crf", "16", "-r", str(FPS), str(OUT / f"{key}.mp4")])
    PROV[key] = {"kind": "constructed still board", "duration": dur(key), "note": note}

def b01():
    img, d = board("Rhodes Daily")
    d.text((210, 450), "A single-player PC extraction action RPG.", font=F(SANS, 72), fill=INK)
    d.text((210, 550), "One-way floors. Every floor: push deeper, or get out.", font=F(SANS, 72), fill=INK)
    d.text((210, 760), "WILL EXIST WHEN DONE", font=F(SANSB, 46), fill=ACCENT)
    for i, (h, b) in enumerate([("Windows build", ["desktop export"]),
                               ("Test suite", ["headless, rerunnable", "from a fresh clone"]),
                               ("Test report", ["what ran, what passed"])]):
        x = 210 + i * 1160
        box(d, (x, 840, x + 1080, 1380), h, b)
    d.text((210, 1520), "Godot 4.7.2  ·  GDScript  ·  Forward+ on D3D12  ·  Windows export  ·  Claude Code", font=F(MONO, 58), fill=SOFT)
    still(img, "B01", "artifact card")

def b07():
    img, d = board("Push or extract")
    for i in range(6):
        y = 520 + i * 230
        x = 300 + i * 110
        d.rectangle([x, y, x + 1100, y + 170], fill="#ffffff", outline=RULE, width=5)
        d.text((x + 40, y + 45), f"Floor {i + 1}", font=F(SANSB, 64), fill=INK)
        d.rectangle([x + 420, y + 70, x + 420 + 90 * (i + 1), y + 105], fill=ACCENT)
        d.line([x + 1100, y + 85, 2350, 1180], fill=GOOD, width=6)
    d.text((1720, 470), "danger grows with depth", font=F(SANS, 50), fill=ACCENT)
    box(d, (2350, 820, 3620, 1560), "Base economy", ["factions · exchange", "research · ship voyage", "scaled real time"], edge=GOOD)
    d.text((1650, 1880), "an extract choice on every floor", font=F(SANS, 54), fill=GOOD)
    still(img, "B07", "floors / danger / extract diagram")

def b08():
    img, d = board("Compared with")
    box(d, (210, 520, 1880, 1700), "Escape from Duckov", ["a raid is one map", "", "Rhodes Daily:", "a run is a stack of one-way floors,", "so the choice returns every floor"])
    box(d, (1960, 520, 3630, 1700), "Greedy Cave", ["the one-way descent", "", "Rhodes Daily adds:", "real-time combat read from telegraphs,", "a nine-faction trade economy"])
    d.text((210, 1830), "Text only — no footage or art from either game.   More fun?  Not claimed: playtests will decide.", font=F(SANS, 52), fill=SOFT)
    still(img, "B08", "two comparison cards; Greedy Cave title rendered with a CJK-capable font fallback")

def b10():
    img, d = board("What it proves")
    rows = [("Shaders", "A5 fire: predicted pixels = measured, at 30 / 60 / 144 fps", "tag a5 · 4327a7f5"),
            ("Particles", "A6 GPU particles: hits, rain, snow", "tag a6 · f92a3cf3"),
            ("Animation", "A7 idle loop + sword-wave rig, state machine", "tag a7 · 171a5830"),
            ("Profiling", "Vulkan → D3D12: mine ~9 → ~150 fps, RTX 4060 Laptop", "measured once · log WILL be committed"),
            ("Verification", "headless suite · fixed seeds · test_flow · human checks · Claude briefs", "tests/run_all.ps1")]
    for i, (a, b, c) in enumerate(rows):
        y = 500 + i * 300
        d.rectangle([210, y, 3630, y + 250], fill="#ffffff", outline=RULE, width=4)
        d.text((260, y + 80), a, font=F(SANSB, 66), fill=INK)
        d.text((900, y + 55), b, font=F(SANS, 54), fill=INK)
        d.text((900, y + 145), c, font=F(MONO, 44), fill=ACCENT if "WILL" in c else SOFT)
    still(img, "B10", "skill to evidence table")

def b11():
    img, d = board("Done · Will · Out")
    box(d, (210, 520, 1300, 1800), "Done", ["core loop", "four regions", "the base", "exchange, contracts,", "research", "A5 – A7 work"], edge=GOOD, hc=GOOD)
    box(d, (1375, 520, 2465, 1800), "Will", ["music", "cross-system", "optimisation", "bug testing"], edge=ACCENT, hc=ACCENT)
    box(d, (2540, 520, 3630, 1800), "Out", ["multiplayer"], edge=SOFT, hc=SOFT)
    still(img, "B11", "scope columns")

def b12():
    img, d = board("Interlocking systems")
    import math as m
    names = ["economy", "exchange", "research", "contracts", "time scale", "voyage"]
    cx, cy, r = 1350, 1250, 600
    pts = [(cx + r * m.cos(2 * m.pi * i / 6 - m.pi / 2), cy + r * m.sin(2 * m.pi * i / 6 - m.pi / 2)) for i in range(6)]
    for i in range(6):
        for j in range(i + 1, 6):
            d.line([pts[i], pts[j]], fill=RULE, width=5)
    for i, (x, y) in enumerate(pts):
        col = ACCENT if i == 0 else "#ffffff"
        d.ellipse([x - 170, y - 95, x + 170, y + 95], fill=col, outline=INK, width=5)
        tw = d.textlength(names[i], font=F(SANSB, 50))
        d.text((x - tw / 2, y - 32), names[i], font=F(SANSB, 50), fill="#ffffff" if i == 0 else INK)
    box(d, (2300, 560, 3630, 1380), "test_flow simulation", ["LMD a bottleneck everywhere", "first voyage ≈ 1.08 million", "", "simulated, not playtested"])
    box(d, (2300, 1460, 3630, 1960), "After every change", ["economy probe + test_flow,", "balance log, playtests"], edge=GOOD)
    still(img, "B12", "system graph; figures from test_flow")

def b13():
    img, d = board("Why this project")
    box(d, (210, 520, 1880, 1800), "Already had", ["systems & numbers design", "", "evidence: design docs,", "economy probe, test_flow", "in the repo"])
    box(d, (1960, 520, 3630, 1800), "New this course", ["Blender  ·  tag a3", "shaders  ·  tag a5", "GPU particles  ·  tag a6", "animation rigs  ·  tag a7", "Godot itself"], edge=ACCENT)
    still(img, "B13", "had vs new")

def b14():
    img = Image.new("RGB", (W, H), "#121214")
    d = ImageDraw.Draw(img)
    d.rectangle([300, 260, 3540, 1900], outline="#8a8478", width=8)
    t = "Rhodes Daily"
    d.text(((W - d.textlength(t, font=F(SANSB, 240))) / 2, 760), t, font=F(SANSB, 240), fill="#ffffff")
    s = "Final Project Pitch  ·  Jingyao Y  ·  CSYE 7270"
    d.text(((W - d.textlength(s, font=F(SANS, 84))) / 2, 1110), s, font=F(SANS, 84), fill="#c9c4b8")
    still(img, "B14", "end card, silent")

# ---------------- capture beats ----------------

def captures():
    R = lambda n: RAW / f"{n}.avi"
    capture_beat("B00", [(R("mine"), 20.0, 11.3, [CAP], "avi")])
    capture_beat("B02", [
        (R("regions"), 2.0, 3.0, [CAP, "Lungmen · Upper City"], "avi"),
        (R("regions"), 16.0, 3.0, [CAP, "Sami · Permafrost Treeline"], "avi"),
        (R("regions"), 30.0, 3.0, [CAP, "Siracusa · Old Volsini Quarter"], "avi"),
        (R("bridge"), 1.0, 3.5, [CAP, "Setup: teleported to the bridge end, field cleared — then she walks across"], "avi")])
    capture_beat("B03", [(R("mine"), 40.0, 9.1, [CAP, "enemy telegraph → dodge → strike / sword wave"], "avi")])
    capture_beat("B04", [
        (R("route"), 11.5, 6.5, [CAP, "Setup: teleported beside the descent marker (stands in for clearing the floor)"], "avi"),
        (R("camp"), 9.4, 6.2, [CAP, "Setup: camp 10|11 unlocked in memory · extraction via GameManager.camp_extract()"], "avi")])
    capture_beat("B05", [
        (R("base"), 2.0, 2.0, [CAP], "avi"),
        (R("base"), 7.3, 3.5, [CAP, "Setup: screens opened by code (what the station hotkey does)"], "avi"),
        (R("base"), 12.5, 3.3, [CAP, "Setup: exchange & research set built in memory"], "avi"),
        (R("base"), 17.5, 2.4, [CAP, "Setup: exchange & research set built in memory"], "avi")])
    capture_beat("B06", [
        (A6 / "frame%08d.png", 0.0, 4.0, ["A6 GPU PARTICLES · tag a6 f92a3cf3 · scripted-input Movie Maker capture, 1280×720 ×3"], "seq"),
        (A7 / "frame%08d.png", 3.0, 4.0, ["A7 SWORD-WAVE RIG · tag a7 171a5830 · film fixture scene, scripted input, 1280×720 ×3"], "seq")])
    capture_beat("B09", [(R("title"), 0.0, 17.5, ["REAL CAPTURE · " + COMMIT + " · scripted clicks · title → new save → base", "Not a timing measurement: the first sixty seconds WILL be timed"], "avi")])

def main():
    OUT.mkdir(exist_ok=True)
    only = set(sys.argv[1:])
    jobs = {"B01": b01, "B07": b07, "B08": b08, "B10": b10, "B11": b11, "B12": b12, "B13": b13, "B14": b14}
    for k, fn in jobs.items():
        if not only or k in only:
            fn(); print("made", k)
    if not only or only & {"B00", "B02", "B03", "B04", "B05", "B06", "B09"}:
        captures(); print("made captures")
    p = REEL / "media-provenance.json"
    old = json.loads(p.read_text(encoding="utf-8")) if p.exists() else {}
    old.update(PROV)
    p.write_text(json.dumps(old, indent=1, ensure_ascii=False), encoding="utf-8")

if __name__ == "__main__":
    main()
