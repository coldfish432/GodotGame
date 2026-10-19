"""Reduce retained paintings; preserve proportions and add a true 1px outline."""
from pathlib import Path
import sys,json,hashlib,math
import numpy as np
from PIL import Image,ImageDraw,ImageFont,ImageFilter
HERE=Path(__file__).resolve().parent
if not HERE.name.startswith('batch_'):sys.path.insert(0,str(HERE/'batch_E14_v1'))
from pixel_support import metrics,smooth,rgb,map_palette,E6_PALETTE,GROUPS

OUTLINE=(11,12,13)
BASE='0b0c0d 2a2d33 4a5058 7d868e b4bec4 eef3f5 2e2018 5a3d2a 86603f b48a5e'
PALETTES={
 'mine':BASE+' 4a2a1d 7d4529 b06a3a d99560 5a4d3a 857555 b3a27c d6c8a2 d9d6cc f4f1e8 d8a520 424738 72775a a0a787',
 'lungmen':BASE+' 141f30 24395a 3d6088 6f9cc6 b5d2ea 6e1616 a82a22 d9483a f07a62 6e5220 a8822e dcb85a c8d860 ece4d0',
 'sami':BASE+' 3f2a1a 6b4a2e 9a7048 8e8470 b9ae95 e6dfcc fbf8ee 6e5a45 a68c6c d8cbb5 3d6a8a 5d8fb0 9cc8e0 e4f4fb b03a2e d9a43a 3f6fa8',
 'siracusa':BASE+' 1a1b1e 2e3036 4a4d55 767a84 3a2618 5e3f26 8a6440 5e4418 9a7428 d0a848 f0d888 8e8470 c8bea6 ece4d0 5e1620 9a2a3a',
 'rhodes':' '.join(E6_PALETTE),
}
EXTRA={
 'mi_fallen_snowpriest_29':'0b0c0d 34251c 554030 806348 b48a5e d6b98b c7d3dc eef3f5 3d215c 6a3a94 ae78db',
 'mi_ice_hunter_20':'0b0c0d 2e2018 5a3d2a 86603f b48a5e d6b98b 8e8470 b9ae95 e6dfcc fbf8ee',
 'scrap_casting_staff':PALETTES['mine']+' 0f3a40 2a8a92 5fd0d8 b8f4f6',
 'reunion_caster_staff':PALETTES['mine']+' b85a12 ee8a24 ffb35a ffe0a8',
 'lawyer_casting_cane':PALETTES['siracusa']+' 3d215c 6a3a94 ae78db d8bcff',
}
BG=['#2c2e30','#142538','#352710']
LOGOS={'rhodes_crossbow':(10,17),'rhodes_staff':(46,11)}
ACTUAL_LOGOS={}

def dump(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2,default=lambda x:x.item())+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dilate(mask):
    out=mask.copy();h,w=mask.shape
    out[1:]|=mask[:-1];out[:-1]|=mask[1:];out[:,1:]|=mask[:,:-1];out[:,:-1]|=mask[:,1:]
    return out

def components(mask,diagonal=False):
    seen=np.zeros(mask.shape,bool);groups=[];h,w=mask.shape
    dirs=[(1,0),(-1,0),(0,1),(0,-1)]+([(1,1),(1,-1),(-1,1),(-1,-1)] if diagonal else [])
    for yy,xx in zip(*np.where(mask)):
        if seen[yy,xx]:continue
        todo=[(yy,xx)];seen[yy,xx]=True;group=[]
        while todo:
            y,x=todo.pop();group.append((y,x))
            for dy,dx in dirs:
                ny,nx=y+dy,x+dx
                if 0<=ny<h and 0<=nx<w and mask[ny,nx] and not seen[ny,nx]:seen[ny,nx]=True;todo.append((ny,nx))
        groups.append(group)
    return sorted(groups,key=len,reverse=True)

def reduce(root,e):
    src=Image.open(root/'sources'/f"{e['id']}_raw.png").convert('RGBA')
    a=np.array(src);a[:,:,3]=np.where(a[:,:,3]>=160,255,0);src=Image.fromarray(a);src=src.crop(src.getbbox())
    rotation=0.;angle=None
    if e['form']=='staff':
        mask=np.array(src)[:,:,3]>0
        xs=np.arange(int(src.width*.12),int(src.width*.45));ys=np.array([np.where(mask[:,x])[0].mean() if mask[:,x].any() else np.nan for x in xs]);good=~np.isnan(ys)
        slope=np.polyfit(xs[good],ys[good],1)[0];angle=-math.degrees(math.atan(slope))
        rotation=8-angle
        if abs(rotation)>1:src=src.rotate(rotation,Image.Resampling.NEAREST,expand=True);src=src.crop(src.getbbox())
    w,h=e['native_size'];fw,fh=(w-4,h-4)
    # Preserve the size hierarchy: hand crossbows are compact; the imperial
    # crank crossbow remains the largest and heaviest silhouette of the group.
    fw,fh={'reunion_hand_crossbow':(60,26),'lgd_hand_crossbow':(58,24),'modified_nail_gun':(64,26),'rhodes_crossbow':(64,26)}.get(e['id'],(fw,fh))
    if e['id']=='folding_sleeve_crossbow':fw,fh=46,24
    scale=min(fw/src.width,fh/src.height);sw,sh=round(src.width*scale),round(src.height*scale)
    small=src.resize((sw,sh),Image.Resampling.BOX);a=np.array(small);mask=a[:,:,3]>=96
    p=a[:,:,:3].astype(float);lum=p@np.array([.2126,.7152,.0722]);bright=mask&(lum>=np.percentile(lum[mask],60))
    p[bright]=np.minimum(255,p[bright]*1.1+13);a[:,:,:3]=p.astype('uint8')
    palette=EXTRA.get(e['id'],PALETTES[e['region']]).split()
    colors=map_palette(a,mask,palette)
    # Use the artwork's own clustered tones; no procedural surface noise.
    colors=smooth(colors,mask)
    out=np.zeros((h,w,4),dtype=np.uint8);x,y=(w-sw)//2,(h-sh)//2
    out[y:y+sh,x:x+sw,:3]=colors;out[y:y+sh,x:x+sw,3]=mask*255
    mask=out[:,:,3]>0
    # Retain large source components, remove only isolated dust pixels.
    for group in components(mask,True)[1:]:
        if len(group)<=2:
            for yy,xx in group:mask[yy,xx]=False;out[yy,xx]=0
    # Existing dark boundary belongs to the painted outline. Remove it before
    # rebuilding one outside layer, avoiding the previous double-dark fringe.
    inside=mask.copy();inside[1:]&=mask[:-1];inside[:-1]&=mask[1:];inside[:,1:]&=mask[:,:-1];inside[:,:-1]&=mask[:,1:]
    trim=mask&~inside&(out[:,:,:3].max(2)<37)
    core=mask&~trim
    # A 1px native closing joins tiny reduction gaps in attached source details.
    closed=np.array(Image.fromarray((core*255).astype('uint8')).filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.MinFilter(3)))>0
    added=closed&~core
    for yy,xx in zip(*np.where(added)):
        ns=[out[ny,nx,:3] for ny,nx in [(yy-1,xx),(yy+1,xx),(yy,xx-1),(yy,xx+1)] if 0<=ny<h and 0<=nx<w and core[ny,nx]]
        if ns:out[yy,xx,:3]=ns[0]
    core|=added
    # Art-directed material highlight ramps, keeping the painted shadow shapes.
    maps={
      'mine':{'7d868e':'b4bec4','857555':'b3a27c','72775a':'a0a787','b48a5e':'d6c8a2'},
      'lungmen':{'7d868e':'b4bec4','6f9cc6':'b5d2ea','a8822e':'dcb85a'},
      'siracusa':{'7d868e':'b4bec4','9a7428':'d0a848'},
    }.get(e['region'],{})
    if e['id'].startswith('mi_'):maps={'b48a5e':'d6b98b'}
    for old,new in maps.items():
        sel=core & np.all(out[:,:,:3]==rgb(old),2);out[sel,:3]=rgb(new)
    # Native cluster pairing is sequential to avoid oscillating colour swaps.
    for _ in range(3):
        for yy,xx in zip(*np.where(core)):
            ns=[out[ny,nx,:3] for ny,nx in [(yy-1,xx),(yy+1,xx),(yy,xx-1),(yy,xx+1)] if 0<=ny<h and 0<=nx<w and core[ny,nx]]
            if ns and not any(np.array_equal(out[yy,xx,:3],n) for n in ns):
                near=min(ns,key=lambda n:np.linalg.norm(out[yy,xx,:3].astype(float)-n.astype(float)))
                if np.linalg.norm(out[yy,xx,:3].astype(float)-near.astype(float))<145:out[yy,xx,:3]=near
    # Light on the exposed top-left surface, inside the separate black outline.
    # Do not apply this to the pale Sami or Rhodes materials.
    if e['region'] in ['mine','lungmen','siracusa']:
        up=np.zeros_like(core);up[1:]=core[:-1]
        left=np.zeros_like(core);left[:,1:]=core[:,:-1]
        exposed=core&(~up|~left)
        candidates=np.array([rgb(v) for v in palette if np.array(rgb(v))@np.array([.2126,.7152,.0722])>=153],dtype=int)
        for yy,xx in zip(*np.where(exposed)):
            c=out[yy,xx,:3].astype(int)
            if c@np.array([.2126,.7152,.0722])<153 and len(candidates):
                out[yy,xx,:3]=candidates[((candidates-c)**2).sum(1).argmin()]
    if e['id']=='mi_fallen_snowpriest_29':
        # Native-grid restoration of the painted bell's defining small parts.
        # Open the loop visually, separate the clapper below the flared lip,
        # and keep the three frost patches on the upper dome only.
        out[3:5,15:17,:3]=OUTLINE
        core[28:]=False;out[28:]=0
        for yy,xx in [(26,16),(27,16),(28,16),(29,15),(29,16),(29,17)]:
            core[yy,xx]=True;out[yy,xx,:3]=rgb('d6b98b')
        for yy,xx in [(10,21),(10,22),(11,10),(11,11)]:out[yy,xx,:3]=rgb('eef3f5')
    if e['id']=='mi_ice_hunter_20':
        # Seven painted knots and the bone toggle are restored on the native
        # grid where reduction merged their faces into the leather strand.
        for cx,cy in [(8,6),(5,12),(16,16),(23,21),(15,27),(6,23),(19,4)]:
            core[cy-1:cy+2,cx-1:cx+2]=True
            out[cy-1:cy+2,cx-1:cx+2,:3]=rgb('b48a5e')
            out[cy-1:cy+1,cx-1:cx+2,:3]=rgb('d6b98b')
        core[4:7,23:29]=True
        out[4,23:29,:3]=rgb('fbf8ee');out[5,23:29,:3]=rgb('e6dfcc');out[6,23:29,:3]=rgb('b9ae95')
    mask=dilate(core);out[:,:,3]=mask*255;out[mask&~core,:3]=OUTLINE
    out[~mask]=0
    return Image.fromarray(out),core,dict(source_shaft_angle=round(angle,2) if angle is not None else None,source_rotation_degrees=round(rotation,2))

def emit_and_marks(im,e,root,core):
    item=e['id'];a=np.array(im);h,w=a.shape[:2];yy,xx=np.indices((h,w));mask=a[:,:,3]>0
    # Restoring the exact tiny mark is a native finishing step, not source art.
    if item in LOGOS:
        tx,ty=LOGOS[item];logo=Image.open(root/'sources'/'rhodes_logo_S_9.png').convert('RGBA')
        options=[(x,y) for y in range(h-8) for x in range(w-8) if core[y:y+9,x:x+9].all()]
        x,y=min(options,key=lambda p:(p[0]-tx)**2+(p[1]-ty)**2) if options else (tx,ty)
        ACTUAL_LOGOS[item]=[x,y]
        d=ImageDraw.Draw(im);d.rectangle((x,y,x+8,y+8),fill='#737d82');im.alpha_composite(logo,(x,y));a=np.array(im);mask=a[:,:,3]>0
    keep=np.zeros((h,w),bool)
    if item=='mi_fallen_snowpriest_29':keep=(yy>=21)&(a[:,:,2]>a[:,:,0]*1.12)&(a[:,:,2]>a[:,:,1]*1.2)
    if item=='scrap_casting_staff':keep=(xx>=50)&(a[:,:,1]>a[:,:,0]*1.25)&(a[:,:,2]>a[:,:,0]*1.25)
    if item=='reunion_caster_staff':keep=(xx>=49)&(a[:,:,0]>150)&(a[:,:,0]>a[:,:,1]*1.15)&(a[:,:,1]>65)
    if item=='lawyer_casting_cane':keep=(xx>=57)&(a[:,:,2]>a[:,:,0]*1.12)&(a[:,:,2]>a[:,:,1]*1.25)
    if item=='rhodes_crossbow':keep=(xx>=27)&(xx<=55)&(a[:,:,2]>a[:,:,0]*1.15)&(a[:,:,2]>a[:,:,1]*1.1)
    if item=='rhodes_staff':keep=(xx>=58)&(a[:,:,1]>a[:,:,0]*1.15)&(a[:,:,2]>a[:,:,0]*1.15)
    keep &= mask
    emit=np.zeros_like(a);emit[keep]=a[keep]
    return im,Image.fromarray(emit),int(keep.sum())

def reviews(root,entries):
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',11)
    sheet=Image.new('RGB',(500,24+40*len(entries)),'#17191b');d=ImageDraw.Draw(sheet)
    for i,bg in enumerate(BG):d.text((264+80*i,6),bg,font=font,fill='#cccaca')
    for i,e in enumerate(entries):
        y=24+i*40;im=Image.open(root/e['file']).convert('RGBA');d.text((4,y+14),e['id'],font=font,fill='#e0e0e0')
        for j,bg in enumerate(BG):
            x=260+80*j;d.rectangle((x,y,x+79,y+39),fill=bg);sheet.paste(im,(x+(80-im.width)//2,y+4),im)
    sheet.save(root/'contact_sheet.png');sheet.resize((sheet.width*2,sheet.height*2),Image.Resampling.NEAREST).save(root/'contact_sheet_2x.png')
    cols=4;tw,th=192,112;preview=Image.new('RGB',(cols*tw,((len(entries)+cols-1)//cols)*th),'#24282b');d=ImageDraw.Draw(preview)
    for i,e in enumerate(entries):
        im=Image.open(root/e['file']).convert('RGBA');scale=2 if im.width==72 else 3;im=im.resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST)
        x,y=(i%cols)*tw,(i//cols)*th;preview.paste(im,(x+(tw-im.width)//2,y+(94-im.height)//2),im);d.text((x+4,y+96),e['id'],font=font,fill='#dddcdc')
    preview.save(root/'art_preview.png')
    if (root/'sources'/'polearms.json').exists():
        refs=json.loads((root/'sources'/'polearms.json').read_text(encoding='utf-8'));ss=Image.new('RGB',(1000,5*108),'#babdbf');d=ImageDraw.Draw(ss)
        for row,region in enumerate(['mine','lungmen','sami','siracusa','rhodes']):
            d.text((4,row*108+2),region.upper(),font=font,fill='#222222')
            rowitems=[(e['id'],root/e['file']) for e in entries if e['region']==region]+[(r['id'],root/'sources'/r['file']) for r in refs if r['region']==region]
            for col,(name,p) in enumerate(rowitems):
                im=Image.open(p).convert('RGBA');black=Image.new('RGBA',im.size,(*OUTLINE,255));black.putalpha(im.getchannel('A'));x=col*165;y=row*108+20
                d.text((x+2,y),name,font=font,fill='#222222');ss.paste(black,(x+5,y+18),black);ss.paste(im,(x+85,y+18),im)
        ss.save(root/'silhouette_check.png')
    else:
        ss=Image.new('RGB',(240,80*len(entries)),'#babdbf');d=ImageDraw.Draw(ss)
        for i,e in enumerate(entries):
            im=Image.open(root/e['file']).convert('RGBA');black=Image.new('RGBA',im.size,(*OUTLINE,255));black.putalpha(im.getchannel('A'));d.text((3,i*80+3),e['id'],font=font,fill='#222222');ss.paste(black,(30,i*80+25),black);ss.paste(im,(110,i*80+25),im)
        ss.save(root/'silhouette_check.png')

def build(root):
    specs=json.loads((root/'generation_specs.json').read_text(encoding='utf-8'));entries=[];reports=[]
    for e in specs:
        if not (root/'sources'/f"{e['id']}_raw.png").exists():continue
        im,core,geo=reduce(root,e);im,emit,count=emit_and_marks(im,e,root,core)
        item=e['id'];im.save(root/f'{item}.png');im.resize((im.width*8,im.height*8),Image.Resampling.NEAREST).save(root/f'{item}_8x.png')
        (root/'qa'/'core_masks').mkdir(parents=True,exist_ok=True)
        Image.fromarray((core*255).astype('uint8')).save(root/'qa'/'core_masks'/f'{item}.png')
        if e['has_emit']:emit.save(root/f'{item}_emit.png')
        m=metrics(im);groups=components(np.array(im)[:,:,3]>0,True)
        m['component_sizes']=[len(g) for g in groups];m['opaque_canvas_percent']=round(m['opaque_pixel_count']/(im.width*im.height)*100,2)
        entry={k:v for k,v in e.items() if k!='prompt'};entry.update(file=f'{item}.png',source=f'sources/{item}_raw.png',source_sha256=sha(root/'sources'/f'{item}_raw.png'),file_sha256=sha(root/f'{item}.png'),emit_pixels=count if e['has_emit'] else 0,**m,**geo)
        if item in ACTUAL_LOGOS:entry['logo_position']=ACTUAL_LOGOS[item]
        checks=dict(size=im.size==tuple(e['native_size']),binary_alpha=m['binary_alpha'],colours=m['colour_count']<=24,isolated=m['isolated_pixel_percent']<=10,bright=m['bright_pixel_percent']>=15,connected=len(groups)==1)
        outline=np.array(im)[:,:,:3][dilate(core)&~core]
        checks['outline_1px']=bool(np.all(outline==OUTLINE))
        if e['has_emit']:checks['emit_nonempty']=count>0
        if e['region']=='rhodes':checks.update(accent_total=m['accent_total_percent']<=10,accent_single=max(m['accent_percent'].values())<=6,flat=m['largest_flat_region_percent']<=25,palette=all(bytes(c).hex() in E6_PALETTE for c in np.unique(np.array(im)[:,:,:3][np.array(im)[:,:,3]>0],axis=0)))
        reports.append(dict(id=item,checks=checks,metrics=m));entries.append(entry)
    dump(root/'manifest.json',entries);dump(root/'qa_report.json',dict(status='PASS' if all(all(r['checks'].values()) for r in reports) and len(entries)==len(specs) else 'REVIEW_REQUIRED',items=reports,runtime='Godot import and backpack UI untested'))
    reviews(root,entries);print(root.name,[(r['id'],[k for k,v in r['checks'].items() if not v]) for r in reports])

if __name__=='__main__':
    roots=[HERE] if HERE.name.startswith('batch_') else [HERE/'batch_E12_v2',HERE/'batch_E14_v1']
    for root in roots:build(root)
