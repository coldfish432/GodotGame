# Touch up Sol's E11 set_inspectors_1: clear the isolated flecks (a pixel unlike
# all four neighbours takes their majority), lift the body toward navy, and
# add a light rim just inside the outline on the top and left edges.
from PIL import Image
from collections import Counter
SRC = '../batch_E11_v1/set_inspectors_1.png'
OUTLINE = (11, 12, 13)
RIM = (111, 156, 198)
im = Image.open(SRC).convert('RGBA'); w, h = im.size
for _ in range(2):
    src = im.copy(); sp = src.load(); px = im.load()
    for x in range(1, w - 1):
        for y in range(1, h - 1):
            c = sp[x, y]
            if not c[3] or c[:3] == OUTLINE: continue
            n = [sp[x + dx, y + dy] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if sp[x + dx, y + dy][3] and sp[x + dx, y + dy][:3] != OUTLINE]
            if len(n) == 4 and all(m[:3] != c[:3] for m in n):
                r, g, b = c[:3]
                if r > 150 and g < 110: continue  # the vermilion band stays
                px[x, y] = Counter(n).most_common(1)[0][0]
px = im.load()
for x in range(w):
    for y in range(h):
        c = px[x, y]
        if not c[3] or c[:3] == OUTLINE: continue
        r, g, b = c[:3]
        if r > 150 and g < 110: continue
        # cool the browns toward navy so the vest reads as police navy
        px[x, y] = (int(r * 0.8), int(g * 0.9), min(255, int(b * 1.15 + 10)), 255)
src = im.copy(); sp = src.load()
for x in range(1, w):
    for y in range(1, h):
        c = sp[x, y]
        if not c[3] or c[:3] == OUTLINE: continue
        if sp[x, y - 1][:3] == OUTLINE or sp[x - 1, y][:3] == OUTLINE or not sp[x, y - 1][3] or not sp[x - 1, y][3]:
            px[x, y] = RIM + (255,)
im.save('set_inspectors_1.png')
im.resize((w * 8, h * 8), Image.NEAREST).save('set_inspectors_1_8x.png')
