"""Reduce imagegen art and assemble B2 v2 review evidence. No character drawing."""
from pathlib import Path
import hashlib
import json
import shutil
import sys
import zipfile
import numpy as np
from PIL import Image

OUT = Path(__file__).resolve().parent
FIELD = OUT.parent
INPUT = FIELD.parent / '_to_sol' / 'B2_revision_v2_inputs'
NN = Image.Resampling.NEAREST
PALETTE = ['#0b0c0d', '#292623', '#3e3a36', '#4a4038', '#5a4a3c',
           '#6a5038', '#7a5a3c', '#a09888', '#c8bca4', '#e2dac6',
           '#d8ac88', '#efd0ad', '#a88060', '#8a8070']


def save(im, name):
    im.save(OUT / name)


def place(canvas, fig, cx, baseline):
    canvas.alpha_composite(fig, (cx-fig.width//2, baseline-fig.height))


def rectangles(mask):
    """Report the largest contiguous solid rectangle; native coordinate evidence."""
    best = {'area':0,'xywh':[0,0,0,0]}
    h,w = mask.shape
    for y in range(h):
        for x in range(w):
            width = w-x
            for bottom in range(y,h):
                run = 0
                while run<width and mask[bottom,x+run]:run+=1
                width = min(width,run)
                area = width*(bottom-y+1)
                if area>best['area']:best={'area':area,'xywh':[x,y,width,bottom-y+1]}
                if width==0:break
    return best


def contains_rect(mask, width, height):
    return any(mask[y:y+height,x:x+width].all()
               for y in range(mask.shape[0]-height+1)
               for x in range(mask.shape[1]-width+1))


def feature_checks(idx, mask):
    return {
        'patch_2x2': contains_rect(((idx==8)&mask)[:6],2,2),
        'face_2x3': contains_rect((((idx==10)|(idx==11))&mask)[:10],2,3),
        'bag_3x3': contains_rect(((idx==6)&mask)[14:22,:8],3,3),
        'shirt_3px_wide': contains_rect(((idx==9)&mask)[8:18],3,3),
        'left_ear_2px_wide': contains_rect(((idx==7)&mask)[:4,:8],2,1),
        'right_ear_2px_wide': contains_rect(((idx==7)&mask)[:4,8:],2,1),
    }


def build(source):
    target = OUT / 'source_paintings/civilian_generated.png'
    target.parent.mkdir(exist_ok=True)
    if Path(source).resolve() != target.resolve():
        shutil.copy2(source, target)
    im = Image.open(target).convert('RGBA')
    a = np.array(im)[...,3]
    ys,xs = np.where(a > 140)
    crop = im.crop((int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)))
    palette = np.array([tuple(bytes.fromhex(c[1:])) for c in PALETTE],dtype=np.int32)
    # Align a single global nearest-neighbour sampling grid to painted clusters.
    # This never adds, draws, moves or recolours an individual costume feature.
    width = round(crop.width*26/crop.height)
    sx,sy = crop.width/width,crop.height/26
    best = None
    for dy in [0,-.15,.15,-.3,.3,-.45,.45]:
        for dx in [0,-.15,.15,-.3,.3,-.45,.45]:
            sampled = crop.transform((width,26),Image.Transform.AFFINE,
                       (sx,0,dx*sx,0,sy,dy*sy),NN)
            arr = np.array(sampled)
            mask = arr[...,3] > 140
            idx = ((arr[...,:3,None].astype(np.int32)-palette.T)**2).sum(axis=2).argmin(axis=2)
            checks = feature_checks(idx,mask)
            score = (sum(checks.values()),-abs(dx)-abs(dy))
            if mask[0].any() and mask[-1].any() and (best is None or score>best[0]):
                arr[...,:3] = palette[idx].astype(np.uint8)
                arr[...,3] = np.where(mask,255,0)
                best = (score,arr.copy(),checks,[dx,dy])
    assert best is not None
    _,arr,features,phase = best
    # Keep the painted outline; a second outline would consume narrow ears/sleeves.
    small = Image.fromarray(arr).crop(Image.fromarray(arr).getbbox())
    assert small.height == 26
    native = Image.new('RGBA',(64,64));place(native,small,32,52)
    save(native,'identity_native_64.png')
    identity = Image.new('RGBA',(256,256))
    place(identity,small.resize((small.width*8,208),NN),128,232)
    save(identity,'identity.png')
    old = Image.open(FIELD/'batch_B2_v1/identity_native_64.png').convert('RGBA')
    beforeafter = Image.new('RGBA',(256,80),(49,52,53,255))
    place(beforeafter,old.crop(old.getbbox()),64,60)
    place(beforeafter,small,192,60)
    save(beforeafter.resize((1536,480),NN),'before_after_x6.png')
    soldierboard = Image.open(INPUT/'refs_B2/family_soldier_board_x4.png').convert('RGBA')
    soldiercell = soldierboard.crop((256,0,512,256)).resize((64,64),NN)
    soldier = soldiercell.crop(soldiercell.getbbox())
    compare = Image.new('RGBA',(576,224),(49,52,53,255))
    portrait = Image.open(INPUT/'refs_B2/prts/enemy_civilian.png').convert('RGBA')
    compare.alpha_composite(portrait,(17,33))
    place(compare,small.resize((small.width*6,156),NN),288,202)
    place(compare,soldier.resize((soldier.width*6,soldier.height*6),NN),480,202)
    save(compare,'identity_vs_prts.png')
    ground = Image.open(INPUT/'refs_B2/siracusa_arena_ingame.png').convert('RGBA')
    place(ground,small,520,400);save(ground,'identity_on_ground.png')
    save(ground.crop((448,328,592,424)).resize((864,576),NN),'identity_on_ground_detail_x6.png')
    (OUT/'palette.json').write_text(json.dumps(PALETTE,indent=2),encoding='utf-8')
    qa = {'stage':1,'approval':'PENDING_USER_REVIEW','native_figure_size':list(small.size),
          'sampling_phase_native_pixels':phase,'feature_checks':features,
          'checks':{'height_26':small.height==26,'transparent_identity':identity.getpixel((0,0))[3]==0,
                    'hard_native_alpha':set(np.unique(np.array(native)[...,3])).issubset({0,255})},
          'palette_pixel_counts':{color:int(np.all(np.array(small)[...,:3]==pal,axis=2)[np.array(small)[...,3]>0].sum())
                                  for color,pal in zip(PALETTE,palette)},
          'largest_solid_color_rectangles':{color:rectangles(np.all(np.array(small)[...,:3]==pal,axis=2)&(np.array(small)[...,3]>0))
                                           for color,pal in zip(PALETTE,palette)},
          'limitations':['Static arena composite only; no Godot runtime verification.',
                        'Pixel area totals alone do not prove spatial feature dimensions or recognisability.',
                        'Stage 2 remains gated on user identity approval.']}
    (OUT/'qa_report.json').write_text(json.dumps(qa,indent=2),encoding='utf-8')
    print(json.dumps(qa,indent=2))


def package():
    manifest = {'generator':'built-in image_gen',
                'revision_zip_sha256':hashlib.sha256((INPUT.parent/'B2_revision_v2.zip').read_bytes()).hexdigest(),
                'files':{}}
    for f in sorted(OUT.rglob('*')):
        if f.is_file() and f.name!='manifest.json':
            manifest['files'][f.relative_to(OUT).as_posix()]={
                'bytes':f.stat().st_size,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    archive = FIELD/'batch_B2_v2_stage1_review.zip'
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
        for f in sorted(OUT.rglob('*')):
            if f.is_file():z.write(f,f.relative_to(FIELD))
    with zipfile.ZipFile(archive) as z:assert z.testzip() is None
    print('ZIP CRC PASS:',archive)


if __name__=='__main__':
    build(sys.argv[1])
    package()
