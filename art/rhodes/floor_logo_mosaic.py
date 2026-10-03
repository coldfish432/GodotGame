"""用地板钢板拼出罗德岛标志（大厅地面视觉中心）。
每块 30×30 的钢板是标志的一个“像素”：三角形内的钢板提亮，塔身的钢板压暗，其余保持原地板。
钢板纹理取自已通过的地板 rhodes_floor_v1.png（4×4 块），只做色阶映射，颜色全部在色板内。"""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, 'assembly_generated')
os.makedirs(OUT_DIR, exist_ok=True)

H = lambda s: tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))
LIGHT = {H(a): H(b) for a, b in (('0b0c0d', '3d4448'), ('15181a', '566064'), ('1f2427', '737d82'), ('2c3236', '98a2a6'),
                                 ('3d4448', 'a9b2b3'), ('566064', 'c3cacc'), ('737d82', 'd4dadb'), ('98a2a6', 'eef2f2'))}
DARK = {H(a): H(b) for a, b in (('15181a', '0b0c0d'), ('1f2427', '0b0c0d'), ('2c3236', '15181a'), ('3d4448', '1f2427'),
                                ('566064', '2c3236'), ('737d82', '3d4448'), ('98a2a6', '566064'))}
PLATE = 30


def mask(n):
    """把已通过的标志 L（64×64）按整格平均缩到 n×n：'.' 背景、'o' 三角形、'#' 塔身与底线。"""
    logo = Image.open(os.path.join(HERE, 'batch2_v2', 'rhodes_logo_L_gray_v2.png')).convert('RGBA')
    small = logo.resize((n, n), Image.BOX)
    rows = []
    for y in range(n):
        row = ''
        for x in range(n):
            r, g, b, a = small.getpixel((x, y))
            row += '.' if a < 110 else ('#' if (r + g + b) / 3 < 120 else 'o')
        rows.append(row)
    return rows


# 16×16 手修蒙版：自动缩小会丢掉城垛，这里按标志 L 的结构手工对齐（三个城垛、收颈、锥形塔身、底线）
HAND_16 = [
    '................',
    '.......oo.......',
    '.......oo.......',
    '......oooo......',
    '......oooo......',
    '.....oooooo.....',
    '.....oooooo.....',
    '....o#o##o#o....',
    '....o######o....',
    '...ooo####ooo...',
    '...oooo##oooo...',
    '..oooo####oooo..',
    '..ooo######ooo..',
    '.ooo########ooo.',
    'oooooooooooooooo',
    'o##############o',
]


def build(n=16, col0=0, row0=0):
    """col0, row0：拼色板左上角在大厅地板钢板网格中的行列号，用来对齐原地板的板块排列。"""
    floor = Image.open(os.path.join(HERE, 'rhodes_floor_v1.png')).convert('RGB')
    plates = [floor.crop((x, y, x + PLATE, y + PLATE)) for y in range(0, 120, PLATE) for x in range(0, 120, PLATE)]
    rows = HAND_16 if n == 16 else mask(n)
    out = Image.new('RGBA', (n * PLATE, n * PLATE), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c == '.':
                continue
            src = plates[((x + col0) % 4) + 4 * ((y + row0) % 4)]   # 与大厅地板原排列一致，板缝自然连续
            table = LIGHT if c == 'o' else DARK
            tile = Image.new('RGBA', (PLATE, PLATE))
            tile.putdata([table.get(p, p) + (255,) for p in src.get_flattened_data()])
            out.alpha_composite(tile, (x * PLATE, y * PLATE))
    path = os.path.join(OUT_DIR, f'hall_floor_logo_mosaic_{n}x{n}_v1.png')
    out.save(path)
    out.resize((out.width * 2, out.height * 2), Image.NEAREST).save(path.replace('.png', '_2x.png'))
    return path, rows


if __name__ == '__main__':
    p, rows = build(16, col0=24, row0=6)
    print(p)
    print('\n'.join(rows))
