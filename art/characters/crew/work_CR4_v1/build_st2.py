"""ST2a step 2 and CR4's idle, done in house (用户 2026-11-02: 放行，像素化和待机呼吸你来做).

- Portraits: each approved painting is BOX-downsampled to 240 px tall (or 120 wide
  if wider), alpha threshold 128, feet on the bottom edge, centred; no palette
  quantization (as ST1).
- Raidian's idle: per row, the walk's passing frame with the narrowest stance
  stands as column 1; column 2 is the CR breath (build_crew.breathe: upper body
  down 8 px, identical from the knees down).
"""
from pathlib import Path
import sys
import numpy as np
from PIL import Image

WORK = Path(__file__).resolve().parent
CREW = WORK.parent
ROOT = CREW.parents[2]
ST2 = ROOT/'art/characters/story/batch_ST2_v1'
CR4 = CREW/'batch_CR4_v1'
PORTRAITS = ROOT/'art/ui/portraits'
## Too wide at full height (155 px for 120): cropped at the sides instead of
## shrunk whole (用户: 为啥两个明显变矮), so all eight stand 240 tall.
CROP_HEIGHT = {'pith': 240, 'tulip': 240}
IDS = ['sharp', 'stormeye', 'pith', 'touch', 'mechanist', 'tulip', 'misery', 'raidian']
sys.path.insert(0, str(CREW/'work_CR_v1'))
from build_crew import breathe

def threshold(im):
    a = np.array(im)
    a[:, :, 3] = np.where(a[:, :, 3] >= 128, 255, 0)
    a[a[:, :, 3] == 0] = 0
    return Image.fromarray(a)

def portrait(ident):
    im = Image.open(ST2/'paintings'/f'op_{ident}_painting_1024.png').convert('RGBA')
    a = np.array(im.getchannel('A'))
    im = im.crop(Image.fromarray(np.where(a >= 128, 255, 0).astype('uint8')).getbbox())
    tall = CROP_HEIGHT.get(ident, 0)
    if tall:
        # A wide coat or staff: keep the figure tall and crop the sides round the body.
        im = im.resize((round(im.width * tall / im.height), tall), Image.Resampling.BOX)
        im = threshold(im)
        top = np.array(im)[:tall // 2, :, 3] >= 128
        x0 = min(max(int(np.nonzero(top)[1].mean()) - 60, 0), im.width - 120)
        im = im.crop((x0, 0, x0 + 120, tall))
    else:
        scale = min(240 / im.height, 120 / im.width)
        im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.Resampling.BOX)
        im = threshold(im)
        im = im.crop(im.getbbox())
    out = Image.new('RGBA', (120, 240))
    out.paste(im, ((120 - im.width) // 2, 240 - im.height))
    out.save(PORTRAITS/f'op_{ident}.png')
    out.resize((240, 480), Image.Resampling.NEAREST).save(ST2/'stage2'/f'op_{ident}_2x.png')
    assert out.getchannel('A').getbbox()[3] == 240
    return out

def raidian_idle():
    walk = Image.open(CR4/'raidian_walk_source.png').convert('RGBA')
    sheet = Image.new('RGBA', (512, 2048))
    for row in range(8):
        frames = [walk.crop((c * 256, row * 256, c * 256 + 256, row * 256 + 256)) for c in (1, 3)]
        # The stance: opaque width of the lowest 40 px (the feet).
        def stance(f):
            box = Image.fromarray((np.array(f)[200:, :, 3] >= 128).astype('uint8') * 255).getbbox()
            return box[2] - box[0] if box else 999
        stand = min(frames, key=stance)
        sheet.paste(stand, (0, row * 256))
        sheet.paste(breathe(stand), (256, row * 256))
    sheet.save(CR4/'raidian_idle_source.png')

if __name__ == '__main__':
    shots = [portrait(i) for i in IDS]
    board = Image.new('RGBA', (len(shots) * 250, 490), (40, 44, 52, 255))
    for i, s in enumerate(shots):
        board.alpha_composite(s.resize((240, 480), Image.Resampling.NEAREST), (i * 250 + 5, 5))
    board.save(ST2/'stage2'/'ST2a_pixel_overview.png')
    raidian_idle()
    print('PASS: 8 portraits, raidian idle')
