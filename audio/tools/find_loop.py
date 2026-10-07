"""Find loop points: where the audio around the loop end best matches the audio around the loop start."""
import sys, numpy as np, soundfile as sf

HOP = 1024
N = 4096

def features(x, sr):
    m = x.mean(axis=1)
    frames = (len(m) - N) // HOP
    idx = np.arange(N)[None, :] + HOP * np.arange(frames)[:, None]
    spec = np.abs(np.fft.rfft(m[idx] * np.hanning(N), axis=1))
    freqs = np.fft.rfftfreq(N, 1 / sr)
    edges = np.geomspace(40, 16000, 49)
    bands = np.stack([spec[:, (freqs >= a) & (freqs < b)].sum(axis=1) for a, b in zip(edges[:-1], edges[1:])], axis=1)
    f = np.log(bands + 1e-6)
    f -= f.mean(axis=1, keepdims=True)
    f /= np.linalg.norm(f, axis=1, keepdims=True) + 1e-9
    return f

def search(path, s_lo, s_hi, l_lo, l_hi, end_max, win=2.0):
    x, sr = sf.read(path, dtype='float32')
    f = features(x, sr)
    fps = sr / HOP
    w = int(win * fps)
    S = f @ f.T
    best = []
    for L in range(int(l_lo * fps), int(l_hi * fps)):
        d = np.diagonal(S, L)  # d[i] = sim(frame i, frame i+L)
        c = np.concatenate([[0], np.cumsum(d)])
        for s in range(max(int(s_lo * fps), w), int(s_hi * fps)):
            e = s + L
            if e + w >= len(f) or e / fps > end_max: continue
            best.append(((c[s + w] - c[s - w]) / (2 * w), s / fps, L / fps))
    best.sort(reverse=True)
    out, seen = [], []
    for sc, s, L in best:
        if any(abs(s - s2) < 1 and abs(L - L2) < 1 for s2, L2 in seen): continue
        seen.append((s, L)); out.append((sc, s, L))
        if len(out) == 8: break
    for sc, s, L in out:
        print(f"  score {sc:.4f}  start {s:7.3f}s  len {L:7.3f}s  end {s+L:7.3f}s")

if __name__ == '__main__':
    p = sys.argv[1]; a = [float(v) for v in sys.argv[2:]]
    search(p, *a)
