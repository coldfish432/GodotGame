"""Bake the textures the boss effects are drawn with (game/boss_vfx.gd,
用户 2026-10-20: 纹理、翻页动画、着色器、网格、粒子、流体混合使用).

    python tools/fx/bake_boss_fx.py

Writes to art/fx/boss/:
- noise.png        128², tileable fractal noise (R) and a second octave set (G):
                   the shaders' erosion and flow maps.
- slash.png        256×64 crescent mask for a blade arc: bright edge, streaks
                   along it, soft toward the inner side.
- smoke_8x8.png    512², 8×8 flipbook of a puff of smoke rising and curling,
                   from a small 2D fluid simulation (stable fluids: advect,
                   buoyancy, vorticity, pressure projection), alpha in A.
- fire_8x8.png     512², the same sim made hotter and faster, rendered as heat
                   (white core to dark edge) for additive fire balls.
- splash_8x8.png   512², 8×8 flipbook of a liquid splash seen from above,
                   spreading out with fingers and settling (blood, sand, molten
                   originium); alpha in A.
All greyscale: the effects tint them (the way game VFX keep one texture for
many colours). Deterministic (fixed seeds).
"""
from pathlib import Path

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parents[2] / "art" / "fx" / "boss"


# --- Noise ---------------------------------------------------------------------------------

def tile_noise(size: int, seed: int, falloff: float = 1.6) -> np.ndarray:
    """Tileable fractal noise in 0..1: white noise shaped by 1/f^falloff in Fourier space."""
    rng = np.random.default_rng(seed)
    f = np.fft.fft2(rng.standard_normal((size, size)))
    ky = np.fft.fftfreq(size)[:, None]
    kx = np.fft.fftfreq(size)[None, :]
    k = np.sqrt(kx * kx + ky * ky)
    k[0, 0] = 1.0
    f *= 1.0 / k ** falloff
    f[0, 0] = 0.0
    n = np.real(np.fft.ifft2(f))
    n = (n - n.min()) / (n.max() - n.min())
    return n


# --- A small 2D fluid ----------------------------------------------------------------------

def _sample(field: np.ndarray, x: np.ndarray, y: np.ndarray) -> np.ndarray:
    h, w = field.shape
    x = np.clip(x, 0, w - 1.001)
    y = np.clip(y, 0, h - 1.001)
    x0 = x.astype(int)
    y0 = y.astype(int)
    fx = x - x0
    fy = y - y0
    a = field[y0, x0] * (1 - fx) + field[y0, x0 + 1] * fx
    b = field[y0 + 1, x0] * (1 - fx) + field[y0 + 1, x0 + 1] * fx
    return a * (1 - fy) + b * fy


class Fluid:
    """Stable fluids (Stam 1999) on an n×n grid, closed walls."""

    def __init__(self, n: int):
        self.n = n
        self.u = np.zeros((n, n))
        self.v = np.zeros((n, n))
        self.d = np.zeros((n, n))
        self.t = np.zeros((n, n))
        yy, xx = np.mgrid[0:n, 0:n].astype(float)
        self.xx, self.yy = xx, yy

    def advect(self, field: np.ndarray, dt: float) -> np.ndarray:
        return _sample(field, self.xx - self.u * dt, self.yy - self.v * dt)

    def project(self, iters: int = 30) -> None:
        u, v = self.u, self.v
        div = np.zeros_like(u)
        div[1:-1, 1:-1] = 0.5 * (u[1:-1, 2:] - u[1:-1, :-2] + v[2:, 1:-1] - v[:-2, 1:-1])
        p = np.zeros_like(u)
        for _ in range(iters):
            p[1:-1, 1:-1] = (p[1:-1, 2:] + p[1:-1, :-2] + p[2:, 1:-1] + p[:-2, 1:-1] - div[1:-1, 1:-1]) / 4.0
        u[1:-1, 1:-1] -= 0.5 * (p[1:-1, 2:] - p[1:-1, :-2])
        v[1:-1, 1:-1] -= 0.5 * (p[2:, 1:-1] - p[:-2, 1:-1])
        u[:, 0] = u[:, -1] = 0.0
        v[0, :] = v[-1, :] = 0.0

    def vorticity(self, strength: float, dt: float) -> None:
        u, v = self.u, self.v
        w = np.zeros_like(u)
        w[1:-1, 1:-1] = 0.5 * (v[1:-1, 2:] - v[1:-1, :-2] - u[2:, 1:-1] + u[:-2, 1:-1])
        aw = np.abs(w)
        gx = np.zeros_like(u)
        gy = np.zeros_like(u)
        gx[1:-1, 1:-1] = 0.5 * (aw[1:-1, 2:] - aw[1:-1, :-2])
        gy[1:-1, 1:-1] = 0.5 * (aw[2:, 1:-1] - aw[:-2, 1:-1])
        mag = np.sqrt(gx * gx + gy * gy) + 1e-5
        gx /= mag
        gy /= mag
        self.u += strength * gy * w * dt
        self.v -= strength * gx * w * dt

    def step(self, dt: float, buoyancy: float, vort: float, fade: float, cool: float) -> None:
        self.v -= buoyancy * self.t * dt          # up the image is -y
        self.vorticity(vort, dt)
        self.project()
        self.u, self.v = self.advect(self.u, dt), self.advect(self.v, dt)
        self.project()
        self.d = self.advect(self.d, dt) * fade
        self.t = self.advect(self.t, dt) * cool


def _blob(n: int, cx: float, cy: float, r: float) -> np.ndarray:
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    return np.clip(1.0 - np.hypot(xx - cx, yy - cy) / r, 0.0, 1.0) ** 1.5


def _sheet(frames: list, cell: int = 64) -> Image.Image:
    sheet = Image.new("RGBA", (cell * 8, cell * 8))
    for i, f in enumerate(frames[:64]):
        sheet.paste(f.resize((cell, cell), Image.LANCZOS), ((i % 8) * cell, (i // 8) * cell))
    return sheet


def bake_puff(seed: int, hot: bool) -> Image.Image:
    """A puff rising: smoke (soft white, alpha) or fire (heat ramp, additive)."""
    n = 96
    rng = np.random.default_rng(seed)
    f = Fluid(n)
    noise = tile_noise(n, seed + 7, 1.2)
    frames = []
    steps_per = 2
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    for i in range(64 * steps_per):
        if i < 16:
            src = _blob(n, n / 2 + rng.normal(0, 1.0), n * 0.66, n * 0.24) * (0.55 + 0.45 * noise)
            f.d = np.maximum(f.d, src)
            f.t = np.maximum(f.t, src * (1.4 if hot else 1.0))
            # Thrown out round the source as well as up: a puff, not a plume.
            ox, oy = xx - n / 2, yy - n * 0.66
            r = np.hypot(ox, oy) + 1.0
            f.u += src * (ox / r * 1.6 + (noise - 0.5) * 0.8)
            f.v += src * (oy / r * 1.0 - (1.6 if hot else 0.9))
        f.step(dt=1.0, buoyancy=0.22 if hot else 0.1, vort=0.8 if hot else 0.5, fade=0.996 if hot else 0.998, cool=0.985 if hot else 0.995)
        if i % steps_per == 0:
            k = i // steps_per / 63.0
            d = np.clip(f.d * 1.6, 0.0, 1.0)
            # Fade the edges of the cell so a frame never shows its square.
            yy, xx = np.mgrid[0:n, 0:n] / (n - 1.0)
            vign = np.clip(1.0 - (np.hypot(xx - 0.5, yy - 0.5) / 0.5) ** 3, 0.0, 1.0)
            d *= vign
            if hot:
                heat = np.clip(f.t * (1.3 - 0.8 * k), 0.0, 1.0) * vign
                lum = np.clip(heat * 1.4, 0, 1)
                a = np.clip(d * 1.3, 0, 1) * np.clip((1.0 - k) / 0.5, 0, 1)
                rgb = np.stack([lum, lum ** 1.4, lum ** 2.4], -1)
            else:
                a = np.clip(d, 0, 1) * np.clip((1.0 - k) / 0.45, 0, 1)
                shade = 0.65 + 0.35 * np.clip(1.0 - np.roll(d, 2, axis=0) + d, 0, 1)
                rgb = np.stack([shade] * 3, -1)
            img = np.dstack([rgb, a]) * 255.0
            frames.append(Image.fromarray(np.uint8(np.clip(img, 0, 255)), "RGBA"))
    return _sheet(frames)


def bake_splash(seed: int) -> Image.Image:
    """A liquid splash from above: thrown out in fingers, then settling and fading."""
    n = 96
    rng = np.random.default_rng(seed)
    f = Fluid(n)
    c = n / 2.0
    yy, xx = np.mgrid[0:n, 0:n].astype(float)
    ang = np.arctan2(yy - c, xx - c)
    rad = np.hypot(xx - c, yy - c)
    fingers = 0.6 + 0.4 * np.cos(ang * rng.integers(7, 10) + rng.uniform(0, 6)) * np.cos(ang * 3 + 1.3)
    frames = []
    for i in range(64 * 2):
        if i < 5:
            src = _blob(n, c, c, n * 0.14)
            f.d = np.maximum(f.d, src)
            push = src * 9.0 * fingers
            f.u += push * np.cos(ang)
            f.v += push * np.sin(ang)
        f.step(dt=1.0, buoyancy=0.0, vort=0.25, fade=0.999, cool=1.0)
        f.u *= 0.955
        f.v *= 0.955
        if i % 2 == 0:
            k = i / 2 / 63.0
            d = np.clip(f.d * 2.2, 0, 1)
            edge = np.clip(d - np.clip(np.roll(d, 1, 0) * 0.5 + np.roll(d, 1, 1) * 0.5, 0, 1), 0, 1)
            lum = np.clip(0.75 + edge * 2.0, 0, 1)
            a = np.clip((d - 0.12) * 3.0, 0, 1) * np.clip(1.0 - (k - 0.6) / 0.4, 0, 1)
            a *= np.clip(1.0 - rad / (n * 0.49), 0, 1)
            img = np.dstack([lum, lum, lum, a]) * 255.0
            frames.append(Image.fromarray(np.uint8(np.clip(img, 0, 255)), "RGBA"))
    return _sheet(frames)


def bake_slash() -> Image.Image:
    """A blade arc's mask, U along the arc and V across it (V=1 the outer edge)."""
    w, h = 256, 64
    u = np.linspace(0, 1, w)[None, :]
    v = np.linspace(0, 1, h)[:, None]
    body = np.clip(np.sin(u * np.pi), 0, 1) ** 0.6
    across = v ** 2.2
    streaks = tile_noise(256, 11, 1.1)[:h, :] * 0.6 + 0.4
    edge = np.exp(-((1.0 - v) * 9.0) ** 2)
    lum = np.clip(across * streaks + edge, 0, 1)
    a = np.clip(body * (across * streaks * 1.3 + edge), 0, 1)
    img = np.dstack([lum, lum, lum, a]) * 255.0
    return Image.fromarray(np.uint8(np.clip(img, 0, 255)), "RGBA")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    r = tile_noise(128, 1, 1.5)
    g = tile_noise(128, 2, 1.0)
    b = tile_noise(128, 3, 2.2)
    Image.fromarray(np.uint8(np.dstack([r, g, b]) * 255), "RGB").save(OUT / "noise.png")
    bake_slash().save(OUT / "slash.png")
    bake_puff(5, hot=False).save(OUT / "smoke_8x8.png")
    bake_puff(9, hot=True).save(OUT / "fire_8x8.png")
    bake_splash(13).save(OUT / "splash_8x8.png")
    print("baked", OUT)


if __name__ == "__main__":
    main()
