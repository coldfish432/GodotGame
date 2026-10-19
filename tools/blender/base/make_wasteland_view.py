"""Stand-in view out of the bridge windows (基地建模改造案_v1, 基地装饰调研_v1 §6-1):
a Terran wasteland at dusk seen from a moving landship — dusty sky, a band of
Catastrophe cloud, mesas, a mobile city's silhouette with its lights on the
horizon. No stars, no space. Writes art/kit/textures/base_wasteland_view.png
(512 x 160, tiles across its width). Sol's painting replaces it.

    python tools/blender/base/make_wasteland_view.py
"""
import math
import os
import random
from PIL import Image

W, H = 512, 160
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "..", "art", "kit", "textures", "base_wasteland_view.png")


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def main():
    random.seed(11)
    im = Image.new("RGB", (W, H))
    px = im.load()
    horizon = 104
    for y in range(H):
        for x in range(W):
            if y < horizon:
                t = y / horizon
                c = lerp((70, 78, 96), (196, 150, 104), t ** 1.6)
                # the Catastrophe cloud band, darker and rolling
                band = math.exp(-((y - 34 - 8 * math.sin(x / 47.0)) / 11.0) ** 2)
                c = lerp(c, (48, 44, 56), 0.55 * band)
            else:
                t = (y - horizon) / (H - horizon)
                c = lerp((112, 88, 66), (58, 48, 40), t ** 0.7)
                if random.random() < 0.06:
                    c = lerp(c, (40, 34, 30), 0.5)
            px[x, y] = c
    # mesas on the horizon, tiling
    for x in range(W):
        h = 10 + 9 * math.sin(x / 29.0) + 6 * math.sin(x / 11.0 + 1.3)
        h = max(0, h) if (x // 90) % 2 == 0 else max(0, h * 0.4)
        for y in range(int(horizon - h), horizon):
            px[x, y] = (86, 70, 60)
    # a mobile city's silhouette with lit windows
    cx = 330
    for x in range(cx - 60, cx + 60):
        top = horizon - 14 - int(18 * math.exp(-((x - cx) / 28.0) ** 2)) - (6 if (x // 7) % 3 == 0 else 0)
        for y in range(top, horizon):
            px[x, y] = (52, 50, 58)
            if (x * 7 + y * 13) % 23 == 0 and y < horizon - 3:
                px[x, y] = (238, 190, 110)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    im.save(OUT)
    print("wrote", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
