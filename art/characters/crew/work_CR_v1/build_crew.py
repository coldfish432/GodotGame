"""Deterministic grid assembly and QA; all character painting is imagegen source."""
from pathlib import Path
import hashlib
import json
import random
import zipfile
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
WORK = Path(__file__).resolve().parent
IDS1 = ['doctor','sharp','stormeye','pith','touch','tulip','mechanist','misery']
IDS2 = ['reserve_vanguard','reserve_guard','reserve_defender','reserve_sniper','reserve_caster','reserve_medic','reserve_supporter','reserve_specialist']
DIRS = ['S','SW','W','NW','N','NE','E','SE']

def cells(path, cols, row_count=8):
    im = Image.open(path).convert('RGBA')
    a=np.array(im)
    # Separate adjacent figures at the lowest-coverage horizontal gap near each
    # expected row boundary; generated boots can touch the next row's hood.
    profile=(a[:,:,3]>=64).sum(axis=1)
    cuts=set()
    for row in range(1,row_count):
        centre=im.height*row/row_count
        radius=im.height/row_count*.35
        start=max(1,round(centre-radius)); end=min(im.height-1,round(centre+radius))
        candidates=np.flatnonzero(profile[start:end+1]==profile[start:end+1].min())+start
        cuts.add(int(min(candidates,key=lambda y:abs(y-centre))))
    # Segment the painted figures BEFORE placing them on the uniform final grid.
    # Generated raw spacing is approximate; fixed cuts can amputate boots/hats.
    parents=[]
    runs=[]
    previous=[]
    def find(i):
        while parents[i]!=i:
            parents[i]=parents[parents[i]]
            i=parents[i]
        return i
    for y,line in enumerate(a[:,:,3]>=64):
        if y in cuts: previous=[]
        edges=np.diff(np.r_[False,line,False].astype(int))
        current=[]
        for start,end in zip(np.flatnonzero(edges==1),np.flatnonzero(edges==-1)):
            label=len(parents)
            parents.append(label)
            for ps,pe,pl in previous:
                if pe>=start and ps<=end: parents[find(pl)]=find(label)
            current.append((start,end,label))
            runs.append((y,start,end,label))
        previous=current
    groups={}
    for y,s,e,label in runs:
        root=find(label)
        groups.setdefault(root,[]).append((y,s,e))
    def bounds(rs):
        return (min(s for y,s,e in rs),min(y for y,s,e in rs),max(e for y,s,e in rs),max(y for y,s,e in rs)+1)
    boxes={key:bounds(rs) for key,rs in groups.items()}
    areas={key:sum(e-s for y,s,e in rs) for key,rs in groups.items()}
    main=[key for key,b in boxes.items() if areas[key]>max(200,im.width*im.height/(cols*row_count)*.02) and b[3]-b[1]>im.height/row_count*.45 and b[2]-b[0]>im.width/cols*.15]
    if len(main)!=cols*row_count:
        raise ValueError(f'{path.name}: found {len(main)} full figures; expected {cols*row_count}; reject raw generation')
    main.sort(key=lambda key:(boxes[key][1]+boxes[key][3])/2)
    ordered=[]
    for row in range(row_count):
        ordered.extend(sorted(main[row*cols:(row+1)*cols],key=lambda key:boxes[key][0]))
    assignments={key:[key] for key in main}
    def distance(b,c):
        return max(0,b[0]-c[2],c[0]-b[2])**2+max(0,b[1]-c[3],c[1]-b[3])**2
    for key,b in boxes.items():
        if key in assignments or areas[key]<24: continue
        near=min(main,key=lambda k:distance(b,boxes[k]))
        if distance(b,boxes[near])<24**2: assignments[near].append(key)
    extracted=[]
    for key in ordered:
        rs=[run for k in assignments[key] for run in groups[k]]
        left,top,right,bottom=bounds(rs)
        left=max(0,left-1);top=max(0,top-1);right=min(im.width,right+1);bottom=min(im.height,bottom+1)
        mask=np.zeros((bottom-top,right-left),dtype=np.uint8)
        for y,s,e in rs: mask[y-top,s-left:e-left]=255
        support=np.array(Image.fromarray(mask).filter(ImageFilter.MaxFilter(3)))>0
        crop=a[top:bottom,left:right].copy()
        crop[~support]=0
        extracted.append(Image.fromarray(crop))
    return [extracted[row*cols:(row+1)*cols] for row in range(row_count)]

def breathe(cell):
    # Exact same knees/boots; displace upper body 8px, taper displacement at hips.
    a = np.array(cell)
    yy = np.arange(256)
    shift = np.where(yy < 160, 8, np.maximum(0, np.rint((192-yy)/4))).astype(int)
    src = yy-shift
    out = a[np.clip(src,0,255)].copy()
    out[src < 0] = 0
    assert np.array_equal(a[192:], out[192:])
    return Image.fromarray(out)

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def build_one(ident, batch):
    raw = WORK/'raw'
    dedicated = [raw/f'{ident}_walk.png',raw/f'{ident}_idle.png']
    if all(p.exists() for p in dedicated):
        paths = dedicated
        walk = cells(paths[0],4)
        if ident=='reserve_sniper' and (raw/f'{ident}_rear_atlas.png').exists():
            source=cells(paths[1],2,7)
            # Inspected raw has S,SW,W,NW,N,E,SE; missing NE is supplied by patch.
            idle=[[source[i][0]] for i in [0,1,2,3,4,4,5,6]]
        else:
            idle = [[row[0]] for row in cells(paths[1],2)]
    else:
        paths = [raw/f'{ident}_atlas.png']
        if not paths[0].exists(): return None
        atlas = cells(paths[0],6)
        walk = [row[:4] for row in atlas]
        idle = [[row[4]] for row in atlas]
        if (raw/f'{ident}_walk.png').exists():
            paths.append(raw/f'{ident}_walk.png')
            walk=cells(paths[-1],4)
        if (raw/f'{ident}_idle.png').exists():
            paths.append(raw/f'{ident}_idle.png')
            idle=[[row[0]] for row in cells(paths[-1],2)]
    shared_patch=raw/f'{ident}_rear_atlas.png'
    if shared_patch.exists():
        paths.append(shared_patch)
        repaired=cells(shared_patch,5,4 if ident=='reserve_specialist' else 2)
        for kind,base in [('walk',walk),('idle',idle)]:
            if kind=='idle' and ident in ['reserve_caster','reserve_medic']: continue
            old_h=max(c.getbbox()[3]-c.getbbox()[1] for row in base for c in row)
            selected=[row[:4] if kind=='walk' else [row[4]] for row in repaired]
            new_h=max(c.getbbox()[3]-c.getbbox()[1] for row in selected for c in row)
            for direction,row in zip([3,5,6,7],selected):
                if kind=='idle' and ident=='reserve_specialist' and direction in [3,5]: continue
                base[direction]=[c.resize((round(c.width*old_h/new_h),round(c.height*old_h/new_h)),Image.Resampling.LANCZOS) for c in row]
    for kind,base in [('walk',walk),('idle',idle)]:
        n_patch=raw/f'{ident}_n_idle.png'
        if kind=='idle' and n_patch.exists():
            paths.append(n_patch)
            corrected=cells(n_patch,1,1)[0][0]
            old_h=max(c.getbbox()[3]-c.getbbox()[1] for row in base for c in row)
            b=corrected.getbbox()
            scale=old_h/(b[3]-b[1])
            base[4]=[corrected.resize((round(corrected.width*scale),round(corrected.height*scale)),Image.Resampling.LANCZOS)]
        sw_patch=raw/f'{ident}_sw_idle.png'
        if kind=='idle' and sw_patch.exists():
            paths.append(sw_patch)
            corrected=cells(sw_patch,1,1)[0][0]
            old_h=max(c.getbbox()[3]-c.getbbox()[1] for row in base for c in row)
            b=corrected.getbbox()
            scale=old_h/(b[3]-b[1])
            base[1]=[corrected.resize((round(corrected.width*scale),round(corrected.height*scale)),Image.Resampling.LANCZOS)]
        patch=raw/f'{ident}_rear_{kind}.png'
        if patch.exists():
            paths.append(patch)
            repaired=cells(patch,4,2) if kind=='walk' else [[c] for c in cells(patch,2,1)[0]]
            old_h=max(c.getbbox()[3]-c.getbbox()[1] for row in base for c in row)
            new_h=max(c.getbbox()[3]-c.getbbox()[1] for row in repaired for c in row)
            order=[5,3] if ident=='misery' and kind=='idle' else [3,5]
            for direction,row in zip(order,repaired):
                base[direction]=[c.resize((round(c.width*old_h/new_h),round(c.height*old_h/new_h)),Image.Resampling.LANCZOS) for c in row]
    all_cells = [c for row in walk+idle for c in row]
    boxes = [c.getbbox() for c in all_cells]
    if any(b is None for b in boxes): raise ValueError(f'{ident}: empty source cell')
    # Generations may have different native sizes. Match the two sheets' maximum
    # figure heights, using one UNIFORM scale per source grid, no frame stretching.
    def limits(rows):
        bb=[c.getbbox() for row in rows for c in row]
        return max(b[3]-b[1] for b in bb),max(b[2]-b[0] for b in bb)
    wh,ww=limits(walk)
    ih,iw=limits(idle)
    target_height=min(224,224/max(ww/wh,iw/ih))
    def fit(c,scale):
        b = c.getbbox()
        sprite = c.crop(b)
        sprite = sprite.resize((max(1,round(sprite.width*scale)),max(1,round(sprite.height*scale))),Image.Resampling.LANCZOS)
        sprite = sprite.crop(sprite.getbbox())
        out = Image.new('RGBA',(256,256))
        out.alpha_composite(sprite,((256-sprite.width)//2,240-sprite.height))
        return out
    walk = [[fit(c,target_height/wh) for c in row] for row in walk]
    idle = [[fit(row[0],target_height/ih)] for row in idle]
    for row in idle: row.append(breathe(row[0]))
    sheets=[]
    checks=[]
    for kind, rows in [('walk',walk),('idle',idle)]:
        cols = len(rows[0])
        sheet = Image.new('RGBA',(256*cols,2048))
        for r,row in enumerate(rows):
            for c,cell in enumerate(row):
                sheet.paste(cell,(c*256,r*256))
                a=np.array(cell)
                b=cell.getbbox()
                assert b and b[0]>=8 and b[1]>=8 and b[2]<=248 and b[3]==240,(ident,kind,r,c,b)
                checks.append({'kind':kind,'row':DIRS[r],'col':c,'bbox':b})
        name=f'{ident}_{kind}_source.png'
        sheet.save(batch/name)
        sheets.append({'id':ident,'kind':kind,'file':name,'cols':cols,'rows':8,'cell':256})
    for row in idle:
        assert np.array_equal(np.array(row[0])[192:],np.array(row[1])[192:])
    return {'sheets':sheets,'checks':checks,'source':[{'file':str(p.relative_to(ROOT)),'sha256':sha(p)} for p in paths]}

def build(part):
    ids=IDS1 if part==1 else IDS2
    batch=ROOT/f'batch_CR{part}_v1'
    batch.mkdir(exist_ok=True)
    records={}
    for ident in ids:
        result=build_one(ident,batch)
        if result: records[ident]=result
    sheets=[s for result in records.values() for s in result['sheets']]
    (batch/'manifest.json').write_text(json.dumps({'sheets':sheets},indent=2),encoding='utf-8')
    (batch/'qa_report.json').write_text(json.dumps({'complete_count':len(records),'expected_count':8,'static_checks':'PASS for available characters','manual_direction_review':'PENDING','blind_identity_acceptance':'PENDING; requires independent reviewer','engine_import':'NOT TESTED','records':records},indent=2),encoding='utf-8')
    if not records: return
    preview=Image.new('RGBA',(32*len(records),32))
    for i,ident in enumerate(records):
        cell=Image.open(batch/f'{ident}_idle_source.png').crop((0,0,256,256))
        preview.paste(cell.resize((32,32),Image.Resampling.LANCZOS),(i*32,0))
    preview.save(batch/'preview_32.png')
    preview.resize((preview.width*6,192),Image.Resampling.NEAREST).save(batch/'preview_32_enlarged.png')
    # Anonymous, reproducible shuffled sprites and PRTS avatars; answer stored separately.
    shuffled=list(records)
    random.Random(7370+part).shuffle(shuffled)
    panel=Image.new('RGB',(128*len(records),292),(47,51,60))
    draw=ImageDraw.Draw(panel)
    for i,ident in enumerate(records):
        ref=(ROOT/'refs/prts'/f'{ident}_avatar.png') if part==1 else (ROOT/'refs/reserve'/f'{ident.removeprefix("reserve_")}_4star_avatar.png')
        if ref.exists():
            av=Image.open(ref).convert('RGBA')
            av.thumbnail((120,120))
            panel.paste(av,(i*128+(128-av.width)//2,0),av)
        else: draw.text((i*128+10,44),'No supplied avatar',fill='white')
        draw.text((i*128+56,122),str(i+1),fill='white')
    for i,ident in enumerate(shuffled):
        sprite=Image.open(batch/f'{ident}_idle_source.png').crop((0,0,256,256)).resize((32,32),Image.Resampling.LANCZOS).resize((128,128),Image.Resampling.NEAREST)
        panel.paste(sprite,(i*128,146),sprite)
        draw.text((i*128+56,276),chr(65+i),fill='white')
    panel.save(batch/'identity_blind_review.png')
    (batch/'identity_blind_key.json').write_text(json.dumps({'avatar_order':list(records),'shuffled_sprites':dict(zip('ABCDEFGH',shuffled))},indent=2),encoding='utf-8')
    contact=Image.new('RGB',(256*len(records),8*256),(47,51,60))
    for i,ident in enumerate(records):
        sh=Image.open(batch/f'{ident}_idle_source.png').convert('RGBA')
        for r in range(8):
            cell=sh.crop((0,r*256,256,(r+1)*256))
            contact.paste(cell,(i*256,r*256),cell)
    contact.save(batch/'directions_review.png')
    print(f'CR{part}: {len(records)}/8 characters, {len(sheets)}/16 sheets assembled; independent identity review pending')

if __name__=='__main__':
    import sys
    build(int(sys.argv[1]) if len(sys.argv)>1 else 1)
