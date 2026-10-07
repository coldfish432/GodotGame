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
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-c:a", "libvorbis", "-q:a", "6", "-map_metadata", "-1", str(path)], check=True)

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
    y = peak(one_shot(on, at, 0.70, 0.35), -3)
    p = OUT / "sfx" / "lights_on.wav"; write_wav(p, y)
    record(p, source="music/开灯.mp3", start=round(at / SR, 4), length=0.70, fade="squared from 0.35 s", gain="peak -3 dBFS")

    off = decode("关灯.mp3")
    at = onset(off, 49.1, 49.6, -20)  # the breaker is ~20 dB over the music rumble before it
    y = peak(one_shot(off, at, 1.10, 0.50), -3)
    p = OUT / "sfx" / "lights_off.wav"; write_wav(p, y)
    record(p, source="music/关灯.mp3", start=round(at / SR, 4), length=1.10, fade="squared from 0.50 s", gain="peak -3 dBFS")

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

    for k in ("开灯.mp3", "关灯.mp3", "基地背景音乐.mp3", "矿洞外勤音乐.mp3", "撤离.mp3", "失败.mp3"):
        log["music/" + k] = {"raw": True, "sha256": hashlib.sha256((RAW / k).read_bytes()).hexdigest()}
    (OUT / "asset_log.json").write_text(json.dumps(log, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(log, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
