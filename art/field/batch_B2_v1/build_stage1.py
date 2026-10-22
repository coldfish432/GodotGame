"""Deterministic reduction and review assembly; artwork comes from imagegen."""
from pathlib import Path
import hashlib
import json
import math
import shutil
import sys

import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent
INPUT = OUT.parents[1] / '_to_sol' / 'B2_stage1_inputs'
NEAREST = Image.Resampling.NEAREST


def save(im, name):
    im.save(OUT / name)


def place(canvas, fig, cx, baseline):
    canvas.alpha_composite(fig, (cx - fig.width // 2, baseline - fig.height))


def main(source):
    (OUT / 'source_paintings').mkdir(exist_ok=True)
    target = OUT / 'source_paintings' / 'civilian_generated.png'
    if Path(source).resolve() != target.resolve():
        shutil.copy2(source, target)
    original = Image.open(target).convert('RGBA')
    a = np.asarray(original.getchannel('A'))
    ys, xs = np.where(a > 140)
    crop = original.crop((int(xs.min()), int(ys.min()), int(xs.max()+1), int(ys.max()+1)))
    small = crop.resize((round(crop.width * 26 / crop.height), 26), Image.Resampling.BOX)
    arr = np.array(small)
    arr[..., 3] = np.where(arr[..., 3] > 140, 255, 0)
    small = Image.fromarray(arr).quantize(colors=24, method=Image.Quantize.FASTOCTREE,
                                         dither=Image.Dither.NONE).convert('RGBA')
    # Match reduce_n1.py's one-pixel inner outline; no silhouette expansion.
    pixels = np.array(small)
    mask = pixels[..., 3] > 0
    pad = np.pad(mask, 1)
    interior = pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:]
    pixels[mask & ~interior] = (11, 12, 13, 255)
    small = Image.fromarray(pixels)
    small = small.crop(small.getbbox())
    assert small.height == 26, 'Reduction changed target height; inspect before delivery'
    native = Image.new('RGBA', (64, 64))
    place(native, small, 32, 52)
    save(native, 'identity_native_64.png')
    # Identity is the actual pixel design enlarged without smoothing.
    identity = Image.new('RGBA', (256, 256))
    place(identity, small.resize((small.width*8, 208), NEAREST), 128, 232)
    save(identity, 'identity.png')
    soldiercell = Image.open(INPUT / 'enemy_dir_family_soldier_64.png').convert('RGBA').crop((64, 0, 128, 64))
    soldier = soldiercell.crop(soldiercell.getbbox())
    sheet = Image.open(INPUT / 'batch_N1_claude/identity_sheet.png').convert('RGBA')
    figures = [small, soldier]
    for row in range(6):
        for col in range(3):
            cell = sheet.crop((col*416, row*416, (col+1)*416, (row+1)*416))
            box = cell.getbbox()
            if box:
                fig = cell.crop(box)
                figures.append(fig.resize((round(fig.width/8), round(fig.height/8)), NEAREST))
    cast = Image.new('RGBA', (7*64, math.ceil(len(figures)/7)*64), (49, 52, 53, 255))
    for i, fig in enumerate(figures):
        place(cast, fig, (i%7)*64+32, (i//7)*64+52)
    save(cast.resize((cast.width*6, cast.height*6), NEAREST), 'identity_with_cast.png')
    compare = Image.new('RGBA', (576, 224), (49, 52, 53, 255))
    portrait = Image.open(INPUT / 'refs_B2/prts/enemy_civilian.png').convert('RGBA')
    compare.alpha_composite(portrait, (17, 33))
    place(compare, small.resize((small.width*6, small.height*6), NEAREST), 288, 202)
    place(compare, soldier.resize((soldier.width*6, soldier.height*6), NEAREST), 480, 202)
    save(compare, 'identity_vs_prts.png')
    ground = Image.open(INPUT / 'refs_B2/siracusa_arena_ingame.png').convert('RGBA')
    # A clear, unoccupied patch. Retain all existing screenshot content.
    place(ground, small, 520, 400)
    save(ground, 'identity_on_ground.png')
    detail = ground.crop((448, 328, 592, 424))
    save(detail.resize((864, 576), NEAREST), 'identity_on_ground_detail_x6.png')
    files = {}
    for f in sorted(OUT.rglob('*')):
        if f.is_file() and f.name not in ('manifest.json', 'qa_report.json'):
            files[f.relative_to(OUT).as_posix()] = {'bytes': f.stat().st_size,
                'sha256': hashlib.sha256(f.read_bytes()).hexdigest()}
    report = {'stage': 1, 'approval': 'PENDING_USER_REVIEW',
        'checks': {'native_height_26': small.height == 26,
                   'hard_native_alpha': set(np.unique(np.array(native)[...,3])).issubset({0,255}),
                   'identity_transparent': identity.getpixel((0,0))[3] == 0,
                   'required_images_present': all((OUT/n).exists() for n in
                     ['identity.png','identity_with_cast.png','identity_on_ground.png','identity_vs_prts.png'])},
        'native_figure_size': list(small.size), 'native_canvas': [64,64],
        'accepted_soldier_actual_height': soldier.height,
        'cast_order': 'civilian, accepted SW soldier, then N1 row-major (empty cells omitted)',
        'ground_placement_feet': [520,400],
        'limitations': ['Scene is a static composite, not a Godot capture.',
          'Recognisability and final art acceptance require user review.',
          'Brief says soldier 28 px; supplied accepted board actually measures 30 px in SW idle. It is preserved unchanged.',
          'No action or walk boards generated; stage 2 requires approval.']}
    assert all(report['checks'].values())
    (OUT/'qa_report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    (OUT/'manifest.json').write_text(json.dumps({'generator':'built-in image_gen',
        'source_zip_sha256':hashlib.sha256((INPUT.parent/'B2_siracusa_civilian.zip').read_bytes()).hexdigest(),
        'files':files}, indent=2), encoding='utf-8')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main(sys.argv[1])
