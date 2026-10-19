from pathlib import Path
import hashlib
import json
import random
import zipfile
import shutil
from PIL import Image,ImageDraw
from build_crew import ROOT,WORK,IDS1,IDS2,DIRS

def tile(ident,kind='idle',r=0,c=0):
    batch=ROOT/('batch_CR1_v1' if ident in IDS1 else 'batch_CR2_v1')
    return Image.open(batch/f'{ident}_{kind}_source.png').convert('RGBA').crop((c*256,r*256,(c+1)*256,(r+1)*256))

def avatar(ident):
    return ROOT/('refs/prts' if ident in IDS1 else 'refs/reserve')/(f'{ident}_avatar.png' if ident in IDS1 else f'{ident.removeprefix("reserve_")}_4star_avatar.png')

def main():
    review=ROOT/'review_CR_v1'
    review.mkdir(exist_ok=True)
    ids=IDS1+IDS2
    overview=Image.new('RGB',(1536,2*192),(55,60,68))
    for row,group in enumerate([IDS1,IDS2]):
        for i,ident in enumerate(group):
            sprite=tile(ident).resize((32,32),Image.Resampling.LANCZOS).resize((192,192),Image.Resampling.NEAREST)
            overview.paste(sprite,(i*192,row*192),sprite)
    overview.save(review/'overview_32_enlarged.png')
    # Fifteen supplied PRTS avatars; Doctor has no supplied PRTS avatar.
    prts_ids=[i for i in ids if avatar(i).exists()]
    shuffled=prts_ids.copy()
    random.Random(737016).shuffle(shuffled)
    panel=Image.new('RGB',(128*len(prts_ids),292),(55,60,68))
    draw=ImageDraw.Draw(panel)
    for i,ident in enumerate(prts_ids):
        ref=Image.open(avatar(ident)).convert('RGBA')
        ref.thumbnail((120,120))
        panel.paste(ref,(i*128+(128-ref.width)//2,0),ref)
        draw.text((i*128+54,123),str(i+1),fill='white')
    for i,ident in enumerate(shuffled):
        sprite=tile(ident).resize((32,32),Image.Resampling.LANCZOS).resize((128,128),Image.Resampling.NEAREST)
        panel.paste(sprite,(i*128,146),sprite)
        draw.text((i*128+54,276),chr(65+i),fill='white')
    panel.save(review/'identity_blind_all_prts.png')
    (review/'identity_blind_key.json').write_text(json.dumps({'avatar_order':prts_ids,'sprite_letters':dict(zip('ABCDEFGHIJKLMNO',shuffled)),'doctor':'No PRTS avatar supplied; separate hood/coat/face/no-red review required'},indent=2),encoding='utf-8')
    pairs=[('reserve_vanguard','reserve_supporter'),('reserve_sniper','reserve_defender'),('stormeye','sharp'),('pith','reserve_specialist')]
    compare=Image.new('RGB',(768,192*4),(55,60,68))
    for row,pair in enumerate(pairs):
        for side,ident in enumerate(pair):
            ref=Image.open(avatar(ident)).convert('RGBA')
            ref.thumbnail((160,160))
            compare.paste(ref,(side*384+16,row*192+16),ref)
            sprite=tile(ident).resize((32,32),Image.Resampling.LANCZOS).resize((192,192),Image.Resampling.NEAREST)
            compare.paste(sprite,(side*384+192,row*192),sprite)
    compare.save(review/'lookalike_pairs.png')
    for part,group in [(1,IDS1),(2,IDS2)]:
        batch=ROOT/f'batch_CR{part}_v1'
        for kind,count,duration in [('walk',4,220),('idle',2,650)]:
            frames=[]
            for c in range(count):
                board=Image.new('RGB',(512,512),(55,60,68))
                for i,ident in enumerate(group):
                    for r in range(8):
                        sprite=tile(ident,kind,r,c).resize((32,32),Image.Resampling.LANCZOS).resize((64,64),Image.Resampling.NEAREST)
                        board.paste(sprite,(i*64,r*64),sprite)
                frames.append(board)
            frames[0].save(batch/f'{kind}_preview.gif',save_all=True,append_images=frames[1:],duration=duration,loop=0,disposal=2)
        records=json.loads((batch/'qa_report.json').read_text(encoding='utf-8'))['records']
        provenance={'date':'2026-10-18','art_source':'built-in image_gen; PRTS costume and colour reference, fresh redraw','processing':'Segment complete painted figures; preserve real alpha and full colour; uniformly rescale per source sheet; centre foreground and set foreground bottom to y240. No palette quantization of source PNGs. Idle upper body shifted by 8 px with a taper above y192; lower legs y192..255 copied pixel-identically. Existing raw atlas standing breath columns discarded in favour of deterministic breath. Direction-specific generated repairs assembled only in selected rows.','reference_brief':'../CR_brief_v1.md','source_assets':{key:record['source'] for key,record in records.items()},'deduplication':{'lord_sharp':'sharp','covenant_supporter':'reserve_supporter'},'acceptance':'Independent blind identification and in-engine playback pending. Technical validation does not establish anatomical foot registration or final artistic acceptance.'}
        (batch/'provenance.json').write_text(json.dumps(provenance,indent=2),encoding='utf-8')
        for filename in ['prompts.json','generation_prompts_dedicated.json','generation_prompts_final_repairs.json']:
            if (WORK/filename).exists(): shutil.copy2(WORK/filename,batch/filename)
        readme=f'''# CR{part} v1 review delivery

8 characters, 16 source PNGs, 384 frames. Walk: 4x8, 1024x2048. Idle: 2x8, 512x2048. Cells 256x256. Rows: S, SW, W, NW, N, NE, E, SE. Real transparent alpha, full-colour source PNGs. No combat assets.

`preview_32.png`: anonymous S idle row in manifest order. `identity_blind_review.png`: supplied avatars and shuffled sprites; answer is separate. Cross-batch blind review and all four lookalike pairs are in `../review_CR_v1/`. Doctor has no supplied PRTS avatar.

`directions_review.png`: idle directions in row order. `walk_preview.gif` and `idle_preview.gif`: 32px sprites enlarged 2x, directions in rows and characters in columns. GIF palette reduction applies only to previews.

`validation.json` records independent final-file technical validation. `qa_report.json` records source processing. `provenance.json` records source hashes and assembly. Raw generated sources and reproducible scripts remain under `../work_CR_v1/`.

STATUS: REVIEW DELIVERY, NOT ART ACCEPTED. Independent blind identity testing, precise anatomical foot/body registration, walk passing-pose review, and Godot animation playback remain for acceptance. Foreground bounds are aligned; weapon tips can differ from anatomical soles. Review direction foreshortening and costume consistency across separately generated sources. No runtime integration was performed.
'''
        (batch/'README.md').write_text(readme,encoding='utf-8')
        archive=ROOT/f'CR{part}_v1_review.zip'
        with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
            z.write(ROOT/'CR_brief_v1.md','CR_brief_v1.md')
            for p in sorted(batch.iterdir()):
                if p.is_file(): z.write(p,f'{batch.name}/{p.name}')
            for p in sorted(review.iterdir()):
                if p.is_file(): z.write(p,f'review_CR_v1/{p.name}')
        with zipfile.ZipFile(archive) as z: assert z.testzip() is None
        print(f'{archive.name}: ZIP CRC PASS, {archive.stat().st_size} bytes')

if __name__=='__main__': main()
