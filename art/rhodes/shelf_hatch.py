"""个人仓库货架的地面闸门：闭合 → 打开的逐帧图（引擎在进入仓储区时播放，见 world/room_reveal.gd）。

两扇盖板从中缝向两侧滑进地板下，按整像素移动，保持像素网格。
优先用 Sol 交付的 H5 正式图（warehouse_shelf_hatch_closed/open_84x18）；还没交付时用这里画的
占位图，颜色全部取自 pixel_kit.COLORS 色板。H5 到货后把 batch_H5_warehouse_v1 加进
assemble_lib.index() 的目录列表，重新导出即可替换，引擎不用改。"""
from PIL import Image

from pixel_kit import canvas, rect, rgba

W, H = 84, 18
FRAMES = 6          # 第 0 帧闭合，最后一帧全开
RIM = 3             # 两端导轨的宽度：盖板滑进这里下面，看不见
EDGE = 2            # 上下两条警示边，始终可见


def _hazard_edges(img):
    for y0 in (0, H - EDGE):
        rect(img, (0, y0, W - 1, y0 + EDGE - 1), 'K')
        for x in range(1, W - 1, 6):
            rect(img, (x, y0, min(x + 2, W - 2), y0 + EDGE - 1), 'Y2')
    rect(img, (0, 0, 0, H - 1), 'K')
    rect(img, (W - 1, 0, W - 1, H - 1), 'K')


def placeholder_closed():
    img = canvas(W, H, 'S1')
    rect(img, (1, EDGE, W - 2, H - EDGE - 1), 'S2')
    rect(img, (1, EDGE, W - 2, EDGE), 'S3')                 # 盖板上沿的受光行
    rect(img, (W // 2, EDGE, W // 2, H - EDGE - 1), 'K')    # 中缝
    for x in (18, W - 20):                                   # 吊装孔
        rect(img, (x, 7, x + 1, 8), 'S0')
    _hazard_edges(img)
    return img


def placeholder_open():
    img = canvas(W, H, 'K')
    rect(img, (1, H - EDGE - 2, W - 2, H - EDGE - 2), 'O2')  # 前沿灯带
    rect(img, (1, H - EDGE - 3, W - 2, H - EDGE - 3), 'O0')
    for x in (1, W - RIM - 1):                               # 两端导轨
        rect(img, (x, EDGE, x + RIM - 1, H - EDGE - 1), 'S1')
        rect(img, (x + 1, EDGE, x + 1, H - EDGE - 1), 'S3')
    _hazard_edges(img)
    return img


def frames(closed, opened):
    """闭合到打开的 FRAMES 帧。盖板 = 闭合图中间的可滑动部分，在导轨之间按整像素外移。"""
    inner = (RIM + 1, EDGE, W - RIM - 1, H - EDGE)          # 盖板可见的范围（左上含，右下不含）
    half = (inner[2] - inner[0]) // 2
    left = closed.crop((inner[0], inner[1], inner[0] + half, inner[3]))
    right = closed.crop((inner[0] + half, inner[1], inner[2], inner[3]))
    out = []
    for k in range(FRAMES):
        shift = round(half * k / (FRAMES - 1))
        f = opened.copy()
        slot = Image.new('RGBA', (inner[2] - inner[0], inner[3] - inner[1]), (0, 0, 0, 0))
        slot.paste(left, (-shift, 0))
        slot.paste(right, (half + shift, 0))
        f.alpha_composite(slot, (inner[0], inner[1]))
        # 导轨和警示边画在盖板上面：盖板是滑进它们下面的
        rails = opened.copy()
        rails.paste((0, 0, 0, 0), (inner[0], inner[1], inner[2], inner[3]))
        f.alpha_composite(rails)
        out.append(f)
    return out


def hatch_frames(load):
    """load 是 assemble_lib.load；正式图不在索引里时退回占位图。"""
    try:
        closed = load('warehouse_shelf_hatch_closed_84x18')[0]
        opened = load('warehouse_shelf_hatch_open_84x18')[0]
        assert closed.size == opened.size == (W, H)
    except (FileNotFoundError, OSError, AssertionError):
        closed, opened = placeholder_closed(), placeholder_open()
    return frames(closed, opened)


if __name__ == '__main__':
    import os
    from assemble_lib import load
    fs = hatch_frames(load)
    sheet = Image.new('RGBA', (W * len(fs) + 4 * (len(fs) - 1), H), rgba('S2'))
    for i, f in enumerate(fs):
        sheet.alpha_composite(f, (i * (W + 4), 0))
    out = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'evidence', 'rhodes-assembly', 'shelf_hatch_frames_8x.png')
    sheet.resize((sheet.width * 8, sheet.height * 8), Image.NEAREST).save(out)
    print(out)
