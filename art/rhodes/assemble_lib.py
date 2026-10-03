"""罗德岛基地静态拼装工具：按 1:1 原生像素把已通过资产拼成场景预览。"""
import json, os
from PIL import Image, ImageChops

ROOT = os.path.dirname(os.path.abspath(__file__))
PX_X = 15.0          # 横向 像素/单位
PX_Y = 12.7          # 地面纵向 像素/单位（约 15×sin58°）
BLACK = (11, 12, 13, 255)

_index = None
def index():
    """读取所有已通过批次的 manifest，建立 id -> (路径, 元数据)。"""
    global _index
    if _index: return _index
    _index = {}
    for d in ['batch1_v5', 'batch2_v1', 'batch2_v2', 'batch_L0_logo_v1', 'batch_H1_bridge_hall_v2',
              'batch_H1b_wayfinding_v1', 'batch_H2_warehouse_v2', 'batch_H3_store_v4',
              'batch_H3_armory_v4', 'batch_H3_medical_v4', 'batch_H3b_expansion_v1',
              'batch_H4_warehouse_v2', 'batch_H4_medical_v2', 'batch_H4b_overhead_v1',
              'batch_H4_warehouse_v1', 'batch_H4_medical_v1']:
        mp = os.path.join(ROOT, d, 'manifest.json')
        if not os.path.exists(mp): continue
        for a in json.load(open(mp, encoding='utf-8'))['assets']:
            _index.setdefault(a['id'], (os.path.normpath(os.path.join(ROOT, d, a['file'])), a))
    return _index

def load(name):
    """name 可以是 manifest id，也可以是相对 art/rhodes 的文件路径。"""
    idx = index()
    if name in idx:
        p, meta = idx[name]
    else:
        p, meta = os.path.join(ROOT, name), {}
    return Image.open(p).convert('RGBA'), meta

class Scene:
    def __init__(self, w=640, h=360):
        self.base = Image.new('RGBA', (w, h), BLACK)
        self.items = []          # (sort_y, order, image, x, y)
        self.decals = []
        self.lights = []
        self._n = 0
    def paste_now(self, img, x, y):
        self.base.alpha_composite(img, (int(x), int(y)))
    def tile(self, name, x0, y0, w, h):
        t, _ = load(name)
        region = Image.new('RGBA', (w, h))
        for yy in range(0, h, t.height):
            for xx in range(0, w, t.width):
                region.alpha_composite(t, (xx, yy))
        self.base.alpha_composite(region, (x0, y0))
    def floor_under(self, name, floor_x0, floor_y0, x, y, w, h):
        """在 (x, y, w, h) 处补一块地板，纹理与从 (floor_x0, floor_y0) 开始铺的地板对齐（用于侧门缺口的门槛）。"""
        t, _ = load(name)
        ox, oy = (x - floor_x0) % t.width, (y - floor_y0) % t.height
        region = Image.new('RGBA', (w + ox + t.width, h + oy + t.height))
        for yy in range(0, region.height, t.height):
            for xx in range(0, region.width, t.width):
                region.alpha_composite(t, (xx, yy))
        self.base.alpha_composite(region.crop((ox, oy, ox + w, oy + h)), (int(x), int(y)))
    def decal(self, name, cx, cy):
        img, meta = load(name)
        ax, ay = meta.get('anchor_px', [img.width // 2, img.height // 2])
        self.decals.append((img, cx - ax, cy - ay))
    def wall(self, name, x, top_y):
        """贴在北墙立面上：x 为左边缘，top_y 为挂件上沿。"""
        img, _ = load(name)
        self.base.alpha_composite(img, (int(x), int(top_y)))
    def prop(self, name, fx, fy, layer_bias=0):
        """立牌：fx, fy 为脚底锚点在画布上的位置。"""
        img, meta = load(name)
        ax, ay = meta.get('anchor_px', [img.width // 2, img.height - 1])
        self._n += 1
        self.items.append((fy + layer_bias, self._n, img, fx - ax, fy - ay))
    def light(self, name, cx, cy, strength=0.45):
        img, meta = load(name)
        ax, ay = meta.get('anchor_px', [img.width // 2, img.height // 2])
        self.lights.append((img, cx - ax, cy - ay, strength))
    def render(self, lit=True):
        out = self.base.copy()
        for img, x, y in self.decals:
            out.alpha_composite(img, (int(x), int(y)))
        if lit:
            for img, x, y, s in self.lights:
                l = img.convert('RGB').point(lambda v: int(v * s))
                layer = Image.new('RGB', out.size, (0, 0, 0)); layer.paste(l, (int(x), int(y)))
                rgb = ImageChops.add(out.convert('RGB'), layer)
                out = Image.merge('RGBA', (*rgb.split(), out.getchannel('A')))
        for _, _, img, x, y in sorted(self.items, key=lambda t: (t[0], t[1])):
            out.alpha_composite(img, (int(x), int(y)))
        return out
