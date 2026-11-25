"""Cut the raw Gemini downloads in music/ into the runtime files in audio/.

Reproducible: same raw MP3s in -> same files out. Needs ffmpeg on PATH and
numpy + soundfile. Run from the project root:

    python audio/tools/cut_audio.py

Every cut point below was chosen by audio/tools/find_loop.py (spectral
self-similarity) and the spectrogram review logged in SOURCES.md; this
script only applies them.
"""
import hashlib, json, subprocess, tempfile
from pathlib import Path
import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "music"
OUT = ROOT / "audio"
SR = 44100

def decode(name: str) -> np.ndarray:
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "x.wav"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(RAW / name), "-ar", str(SR), "-c:a", "pcm_f32le", str(wav)], check=True)
        x, sr = sf.read(wav, dtype="float32", always_2d=True)
    assert sr == SR
    return x

def zero_cross(x: np.ndarray, t: float, search: float = 0.005) -> int:
    """Nearest sample to t where the mono signal crosses zero upward."""
    i = int(t * SR); r = int(search * SR)
    m = x[max(i - r, 1):i + r].mean(axis=1)
    z = np.where((m[:-1] <= 0) & (m[1:] > 0))[0]
    return max(i - r, 1) + int(z[np.argmin(np.abs(z - r))]) if len(z) else i

def align_end(x: np.ndarray, start: int, end: int, search: float = 0.010, win: float = 0.050) -> int:
    """Move the loop end within +-search so the waveform just before it best
    matches the waveform just before the loop start (what it will flow into)."""
    w = int(win * SR); r = int(search * SR)
    ref = x[start - w:start].mean(axis=1)
    best, best_e = -1e9, end
    for e in range(end - r, end + r):
        c = float(np.dot(ref, x[e - w:e].mean(axis=1)))
        if c > best: best, best_e = c, e
    return best_e

def loop_file(x: np.ndarray, start_s: float, end_s: float, xfade: float = 0.040):
    """Audio from 0 to the loop end. Its last `xfade` seconds blend into the
    audio leading up to the loop start, so jumping back to `start` is seamless.
    Returns (samples, loop_offset_seconds)."""
    s = zero_cross(x, start_s)
    e = align_end(x, s, int(end_s * SR))
    y = x[:e].copy()
    f = int(xfade * SR)
    w = (0.5 - 0.5 * np.cos(np.linspace(0, np.pi, f)))[:, None]
    y[e - f:e] = x[e - f:e] * (1 - w) + x[s - f:s] * w
    return y, s / SR

def onset(x: np.ndarray, t0: float, t1: float, thresh_db: float = -30) -> int:
    m = np.abs(x[int(t0 * SR):int(t1 * SR)]).max(axis=1)
    i = int(np.argmax(20 * np.log10(m + 1e-9) > thresh_db))
    return int(t0 * SR) + max(i - int(0.002 * SR), 0)

def one_shot(x: np.ndarray, at: int, length: float, fade_from: float) -> np.ndarray:
    y = x[at:at + int(length * SR)].copy()
    a = int(0.002 * SR); y[:a] *= np.linspace(0, 1, a)[:, None]
    f0 = int(fade_from * SR)
    y[f0:] *= (np.linspace(1, 0, len(y) - f0) ** 2)[:, None]
    return y

def peak(y: np.ndarray, db: float) -> np.ndarray:
    return y * (10 ** (db / 20) / np.abs(y).max())

def rms_norm(y: np.ndarray, rms_db: float, peak_db: float = -1.0) -> np.ndarray:
    g = 10 ** (rms_db / 20) / np.sqrt((y ** 2).mean())
    g = min(g, 10 ** (peak_db / 20) / np.abs(y).max())
    return y * g

def write_wav(path: Path, y: np.ndarray):
    path.parent.mkdir(parents=True, exist_ok=True)
    sf.write(path, y, SR, subtype="PCM_16")

def write_ogg(path: Path, y: np.ndarray):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "x.wav"
        sf.write(wav, y, SR, subtype="PCM_16")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "6", "-map_metadata", "-1",
                        "-fflags", "+bitexact", "-flags:a", "+bitexact", str(path)], check=True)  # fixed Ogg serial: same input, same bytes

def check_file(path: Path, y: np.ndarray, offset: float, repeats: int = 3):
    """Loop played `repeats` times, for listening to the seam."""
    s = int(offset * SR)
    write_ogg(path, np.concatenate([y] + [y[s:]] * (repeats - 1)))

def main():
    log = {}
    def record(path: Path, **info):
        log[str(path.relative_to(ROOT)).replace("\\", "/")] = {**info, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}

    # --- SFX ---------------------------------------------------------------
    on = decode("开灯.mp3")
    at = onset(on, 0.0, 0.5)
    y = peak(one_shot(on, at, 3.00, 2.00), -3)  # long tail: each bank rings on under the next
    p = OUT / "sfx" / "lights_on.wav"; write_wav(p, y)
    record(p, source="music/开灯.mp3", start=round(at / SR, 4), length=3.00, fade="squared from 2.00 s", gain="peak -3 dBFS")

    # Listening copy: the four banks as the warehouse plays them, BANK_PAUSE apart
    # (read from world/room_reveal.gd so the two never disagree).
    import re
    bank_pause = float(re.search(r"const BANK_PAUSE := ([0-9.]+)", (ROOT / "world" / "room_reveal.gd").read_text(encoding="utf-8")).group(1))
    gap = int(bank_pause * SR)
    banks = np.zeros((len(y) + 3 * gap, 2), dtype=np.float32)
    for k in range(4): banks[k * gap:k * gap + len(y)] += y * 10 ** (-8 / 20)  # FieldAudio plays it at -8 dB
    write_ogg(OUT / "_check" / "lights_on_4banks.ogg", banks)

    off = decode("关灯.mp3")
    at = onset(off, 49.1, 49.6, -20)  # the breaker is ~20 dB over the music rumble before it
    y = peak(one_shot(off, at, 1.10, 0.50), -3)
    p = OUT / "sfx" / "lights_off.wav"; write_wav(p, y)
    record(p, source="music/关灯.mp3", start=round(at / SR, 4), length=1.10, fade="squared from 0.50 s", gain="peak -3 dBFS")

    # ElevenLabs sounds come as single takes: keep the whole take, fade its tail.
    # Peaks are normalized (the door's MP3 decodes 2.6 dB over full scale but has
    # no flattened runs, so it was not clipped at the source).
    for raw, out, fade_s in (("开门.mp3", "hatch.wav", 0.30), ("货架升起.wav", "shelf.wav", 0.15)):
        x = decode(raw)
        at = onset(x, 0.0, 0.5)
        y = x[at:].copy()
        y = peak(one_shot(x, at, len(y) / SR, len(y) / SR - fade_s), -3)
        p = OUT / "sfx" / out; write_wav(p, y)
        record(p, source="music/" + raw, start=round(at / SR, 4), length=round(len(y) / SR, 4),
               fade=f"squared over the last {fade_s:.2f} s", gain="peak -3 dBFS")

    # --- Music -------------------------------------------------------------
    base = decode("基地背景音乐.mp3")
    y, off_s = loop_file(base, 40.171, 40.171 + 75.302)
    y = rms_norm(y, -18)
    p = OUT / "music" / "base_loop.ogg"; write_ogg(p, y)
    record(p, source="music/基地背景音乐.mp3", cut=f"0 – {len(y)/SR:.4f} s", loop_offset=round(off_s, 4),
           loop_length=round(len(y) / SR - off_s, 4), crossfade="40 ms raised-cosine into the audio before loop_offset",
           gain="RMS -18 dBFS, peak <= -1 dBFS", format="OGG Vorbis q6")
    check_file(OUT / "_check" / "base_loop_x3.ogg", y, off_s)

    mine = decode("矿洞外勤音乐.mp3")
    y, off_s = loop_file(mine, 13.305, 13.305 + 31.997)
    g = 10 ** (-18 / 20) / np.sqrt((y ** 2).mean())
    g = min(g, 10 ** (-1 / 20) / np.abs(y).max())
    y = y * g
    p = OUT / "music" / "mine_loop.ogg"; write_ogg(p, y)
    record(p, source="music/矿洞外勤音乐.mp3", cut=f"0 – {len(y)/SR:.4f} s", loop_offset=round(off_s, 4),
           loop_length=round(len(y) / SR - off_s, 4), bars="intro 0–loop_offset; loop = 10 bars of 3.2 s",
           crossfade="40 ms raised-cosine into the audio before loop_offset",
           gain="RMS -18 dBFS, peak <= -1 dBFS", format="OGG Vorbis q6")
    check_file(OUT / "_check" / "mine_loop_x3.ogg", y, off_s)

    # Ending: one bar after the loop end to the file's end, same gain as the loop.
    s = zero_cross(mine, 13.305 + 31.997 + 3.2)
    end = mine[s:].copy() * g
    a = int(0.010 * SR); end[:a] *= np.linspace(0, 1, a)[:, None]
    p = OUT / "music" / "mine_end.ogg"; write_ogg(p, end)
    record(p, source="music/矿洞外勤音乐.mp3", cut=f"{s/SR:.4f} s – end ({len(mine)/SR:.4f} s)",
           fade="10 ms fade-in", gain="same as mine_loop", format="OGG Vorbis q6")

    # --- Stings: the first take in each file, up to where the next take starts.
    for raw, out, first, nxt in (("撤离.mp3", "sting_extract.ogg", (0.0, 1.5), (5.9, 6.6)),
                                 ("失败.mp3", "sting_fail.ogg", (0.0, 0.5), (11.3, 12.3))):
        x = decode(raw)
        s = onset(x, *first)
        e = onset(x, *nxt) - int(0.020 * SR)
        y = x[s:e].copy()
        a = int(0.002 * SR); y[:a] *= np.linspace(0, 1, a)[:, None]
        f = int(0.5 * SR); y[-f:] *= (np.linspace(1, 0, f) ** 2)[:, None]
        y = rms_norm(y, -18)
        p = OUT / "music" / out; write_ogg(p, y)
        record(p, source="music/" + raw, cut=f"{s/SR:.4f} – {e/SR:.4f} s (first take; next take starts {e/SR + 0.02:.4f} s)",
               fade="2 ms in, squared 0.5 s out", gain="RMS -18 dBFS, peak <= -1 dBFS", format="OGG Vorbis q6")

    # Listening copy of the whole warehouse sequence, at the cue times the game
    # produced (audio/tools/record_reveal_times.gd) and FieldAudio's volumes.
    times = OUT / "_check" / "warehouse_times.json"
    if times.exists():
        level = {"lights_on": -8, "lights_off": -8, "hatch": -14, "shelf": -16}
        cue = {k: sf.read(OUT / "sfx" / f"{k}.wav", dtype="float32", always_2d=True)[0] for k in level}
        events = [e for e in json.loads(times.read_text(encoding="utf-8")) if e[0] in level]
        end = max(int(t * SR) + len(cue[c]) for c, t in events)
        mix = np.zeros((end, 2), dtype=np.float32)
        for c, t in events:
            i = int(t * SR); mix[i:i + len(cue[c])] += cue[c] * 10 ** (level[c] / 20)
        write_ogg(OUT / "_check" / "warehouse_sequence.ogg", mix)
        print(f"warehouse_sequence.ogg: peak {20 * np.log10(np.abs(mix).max()):.1f} dBFS")

    cut_elevenlabs(record)
    for k in ("开灯.mp3", "关灯.mp3", "开门.mp3", "货架升起.wav", "基地背景音乐.mp3", "矿洞外勤音乐.mp3", "撤离.mp3", "失败.mp3"):
        log["music/" + k] = {"raw": True, "sha256": hashlib.sha256((RAW / k).read_bytes()).hexdigest()}
    for k in [v[0] for v in FIELD.values()] + [v[0] for v in BOSS.values()] + list(BOSS_STINGS.values()):
        log["music/" + k] = {"raw": True, "source": "ElevenLabs agent (Eleven Music)", "sha256": hashlib.sha256((RAW / k).read_bytes()).hexdigest()}
    (OUT / "asset_log.json").write_text(json.dumps(log, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(log, ensure_ascii=False, indent=2))

# --- ElevenLabs music (2026-11-24, audio/ELEVENLABS_AGENT_BRIEF.md) -------------
# Bar lengths measured by flux autocorrelation (all came out at whole BPM); the
# sections sit on the bar grid from 0 s, found by per-bar loudness and novelty
# (see audio/PROMPTS.md, P-FIELD-* and P-BOSS-*).
#   field: (raw, bar s, loop start bar, loop end bar)
FIELD = {
    "city":     ("field/field_city.mp3",     2.66667, 4, 28),   # 90 BPM: intro 4 bars, main 24 bars
    "snow":     ("field/field_snow.mp3",     3.33333, 4, 20),   # 72 BPM: intro 4, main 16
    "siracusa": ("field/field_siracusa.mp3", 3.0,     8, 20),   # 80 BPM: main builds from bar 4; loop only the full bars 8-20
}
#   boss: (raw, bar s, A start bar, B start bar, ending bar, silent bars to drop at the head)
BOSS = {
    "mine":     ("boss/boss_mine.mp3",     2.4,     2, 10, 18, 1),  # 100 BPM; bar 0 is silence
    "city":     ("boss/boss_city.mp3",     2.22222, 2, 10, 18, 0),  # 108 BPM
    "snow":     ("boss/boss_snow.mp3",     2.82353, 2, 10, 18, 0),  # 85 BPM
    "siracusa": ("boss/boss_siracusa.mp3", 2.5,     2, 10, 18, 0),  # 96 BPM
}
BOSS_STINGS = {"down": "boss/down_sting.mp3", "win": "boss/win_stin.mp3"}

def cut_elevenlabs(record):
    for key, (raw, bar, a, b) in FIELD.items():
        x = decode(raw)
        y, off_s = loop_file(x, a * bar, b * bar)
        y = rms_norm(y, -18)
        p = OUT / "music" / f"{key}_loop.ogg"; write_ogg(p, y)
        record(p, source="music/" + raw, cut=f"0 – {len(y)/SR:.4f} s", loop_offset=round(off_s, 4),
               loop_length=round(len(y) / SR - off_s, 4), bars=f"bar {bar} s; intro bars 0–{a}, loop bars {a}–{b}",
               crossfade="40 ms raised-cosine into the audio before loop_offset",
               gain="RMS -18 dBFS, peak <= -1 dBFS", format="OGG Vorbis q6")
        check_file(OUT / "_check" / f"{key}_loop_x3.ogg", y, off_s)
    for key, (raw, bar, a, b, e, head) in BOSS.items():
        x = decode(raw)
        y1, off1 = loop_file(x, a * bar, b * bar)            # intro + A, loops back to A
        h = int(round(head * bar * SR)); y1 = y1[h:]; off1 -= h / SR  # whole bars: the grid stays on 0
        y2, off2 = loop_file(x, b * bar, e * bar)            # ... + B; keep only B
        s2 = int(round(off2 * SR)); y2 = y2[s2:]
        body = x[:int(e * bar * SR)]                          # one gain for both parts
        g = 10 ** (-18 / 20) / np.sqrt((body ** 2).mean())
        g = min(g, 10 ** (-1 / 20) / max(np.abs(y1).max(), np.abs(y2).max()))
        y1 = y1 * g; y2 = y2 * g
        common = dict(source="music/" + raw, bar=bar, gain=f"{20*np.log10(g):+.2f} dB (intro+A+B at RMS -18 dBFS, peak <= -1 dBFS)",
                      crossfade="40 ms raised-cosine into the audio before the loop start", format="OGG Vorbis q6")
        p = OUT / "music" / f"boss_{key}_p1.ogg"; write_ogg(p, y1)
        record(p, cut=f"{h/SR:.4f} – {h/SR + len(y1)/SR:.4f} s", loop_offset=round(off1, 4), loop_length=round(len(y1) / SR - off1, 4),
               bars=f"intro bars {head}–{a}, A bars {a}–{b} (file starts at bar {head})", **common)
        p = OUT / "music" / f"boss_{key}_p2.ogg"; write_ogg(p, y2)
        record(p, cut=f"{s2/SR:.4f} – {s2/SR + len(y2)/SR:.4f} s", loop_offset=0.0, loop_length=round(len(y2) / SR, 4),
               bars=f"B bars {b}–{e}", **common)
        # Listening copy: A twice, then B from the next bar line twice (what the game does).
        a2 = np.concatenate([y1, y1[int(off1 * SR):]])
        write_ogg(OUT / "_check" / f"boss_{key}_A2_B2.ogg", np.concatenate([a2, y2, y2]))
    for kind, raw in BOSS_STINGS.items():
        x = decode(raw)
        s = onset(x, 0.0, 1.0, -40)
        y = x[s:].copy()
        a = int(0.002 * SR); y[:a] *= np.linspace(0, 1, a)[:, None]
        f = int(0.3 * SR); y[-f:] *= (np.linspace(1, 0, f) ** 2)[:, None]
        y = rms_norm(y, -18)
        p = OUT / "music" / f"sting_boss_{kind}.ogg"; write_ogg(p, y)
        record(p, source="music/" + raw, cut=f"{s/SR:.4f} s – end ({len(x)/SR:.4f} s)",
               fade="2 ms in, squared 0.3 s out", gain="RMS -18 dBFS, peak <= -1 dBFS", format="OGG Vorbis q6")

def main_elevenlabs():
    """Cut only the ElevenLabs music and merge it into the existing asset log,
    leaving the earlier files (and their bytes) untouched."""
    path = OUT / "asset_log.json"
    log = json.loads(path.read_text(encoding="utf-8"))
    def record(p: Path, **info):
        log[str(p.relative_to(ROOT)).replace("\\", "/")] = {**info, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
    cut_elevenlabs(record)
    raws = [v[0] for v in FIELD.values()] + [v[0] for v in BOSS.values()] + list(BOSS_STINGS.values())
    for k in raws:
        log["music/" + k] = {"raw": True, "source": "ElevenLabs agent (Eleven Music)", "sha256": hashlib.sha256((RAW / k).read_bytes()).hexdigest()}
    path.write_text(json.dumps(log, ensure_ascii=False, indent=2), encoding="utf-8")

if __name__ == "__main__":
    import sys
    if sys.argv[1:] == ["eleven"]:
        main_elevenlabs()   # python audio/tools/cut_audio.py eleven
    else:
        main()
