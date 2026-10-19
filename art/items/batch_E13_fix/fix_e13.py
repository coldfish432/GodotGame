# Touch up Sol's E13 v1 weapons in place: lift the darks, add the 1 px #0b0c0d
# outline, top-left rim light. Output: art/items/batch_E13_fix/.
import sys, os
from PIL import Image
SRC = 'batch_E13_v1'; OUT = 'batch_E13_fix'
os.makedirs(OUT, exist_ok=True)
OUTLINE = (11, 12, 13, 255)
def lum(c): return 0.2126*c[0] + 0.7152*c[1] + 0.0722*c[2]
def lift(c, floor):
    # raise dark tones toward `floor` keeping hue
    l = lum(c)
    if l >= floor: return c
    k = floor / max(l, 1)
    return tuple(min(255, int(v * k + (floor - l) * 0.35)) for v in c[:3]) + (255,)
def fix(name, floor=0, rim=False, fills=()):
    im = Image.open(f'{SRC}/{name}.png').convert('RGBA'); w, h = im.size; px = im.load()
    for (x, y, col) in fills: px[x, y] = col
    if floor:
        for x in range(w):
            for y in range(h):
                if px[x, y][3] and px[x, y][:3] != OUTLINE[:3]: px[x, y] = lift(px[x, y], floor)
    if rim:
        src = im.copy(); sp = src.load()
        for x in range(w):
            for y in range(h):
                if not sp[x, y][3]: continue
                up = y == 0 or not sp[x, y-1][3]; left = x == 0 or not sp[x-1, y][3]
                if up or left:
                    c = sp[x, y]; px[x, y] = tuple(min(255, int(v*1.35 + 40)) for v in c[:3]) + (255,)
    # outer outline
    src = im.copy(); sp = src.load()
    for x in range(w):
        for y in range(h):
            if sp[x, y][3]: continue
            if any(0 <= x+dx < w and 0 <= y+dy < h and sp[x+dx, y+dy][3] for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))):
                px[x, y] = OUTLINE
    im.save(f'{OUT}/{name}.png')
    im.resize((w*8, h*8), Image.NEAREST).save(f'{OUT}/{name}_8x.png')
fix('family_stiletto')
fix('old_town_crowbar', rim=True)
fix('barber_razor')
fix('cane_sword', floor=70, rim=True)
fix('vineyard_billhook')
fix('eraser_curved_blade')
fix('lead_cane', floor=60, rim=True)
fix('wolfhead_knuckles', floor=80, rim=True)
print('done')
