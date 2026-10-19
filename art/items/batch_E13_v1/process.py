"""Deterministic reduction, palette mapping, native cleanup and review packaging.

Artwork comes exclusively from the retained imagegen paintings. Run this file
from either batch directory; Pillow and numpy are required. No API calls.
"""
from pathlib import Path
import hashlib
import json
import shutil
import sys
import zipfile
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
ITEMS = HERE.parent if HERE.name.startswith('batch_') else HERE
OUTLINE = (11,12,13)
STEEL = '2a2d33 4a5058 7d868e b4bec4 eef3f5'
E13_PALETTE = ('0b0c0d '+STEEL+' 2e2018 5a3d2a 86603f b48a5e 1a1b1e 2e3036 4a4d55 767a84 3a2618 5e3f26 8a6440 3f5a2a 6a8a40 5e4418 9a7428 d0a848 f0d888 8e8470 c8bea6 ece4d0 5e1620 9a2a3a 3e4228 5c6238 4a2a5e 7a4a9a 6e6878 a49cb0 4a2a1d 7d4529 b06a3a d99560').split()
E6_PALETTE = '0b0c0d 15181a 1f2427 2c3236 3d4448 566064 737d82 98a2a6 c3cacc a9b2b3 d4dadb eef2f2 385878 5888a8 78b8e8 6e2f14 b8531f e0782a 0f3a40 2a8a92 5fd0d8 b8f4f6 6b5a1e b89a2a f4d73c'.split()
GROUPS = {k:set(v.split()) for k,v in dict(blue='385878 5888a8 78b8e8',orange='6e2f14 b8531f e0782a',cyan='0f3a40 2a8a92 5fd0d8 b8f4f6',yellow='6b5a1e b89a2a f4d73c').items()}
BG = ['#2c2e30','#142538','#352710','#381b0f']
LOGO_POS = {'rhodes_field_uniform':(58,24),'rhodes_protective_vest':(45,27),'rhodes_beacon':(12,17),'rhodes_medkit':(14,14),'rhodes_badge':(11,16)}
FOOTPRINT = {'family_stiletto':(68,18),'brass_knuckles':(48,27),'wolfhead_knuckles':(56,27),'barber_razor':(47,21),'eraser_curved_blade':(46,22),'butcher_cleaver':(58,27),'rhodes_beacon':(28,26)}
MATERIALS = {
 'family_stiletto':'0b0c0d '+STEEL+' 1a1b1e 4a4d55 5e1620 9a2a3a',
 'brass_knuckles':'0b0c0d 5e4418 9a7428 d0a848 f0d888 ece4d0',
 'switchblade':'0b0c0d '+STEEL+' 5e4418 d0a848 f0d888 8e8470 c8bea6 ece4d0',
 'old_town_crowbar':'0b0c0d '+STEEL+' 4a2a1d 7d4529 b06a3a d99560 8e8470 c8bea6 ece4d0',
 'barber_razor':'0b0c0d '+STEEL+' 8e8470 c8bea6 ece4d0 9a7428 d0a848',
 'cane_sword':'0b0c0d '+STEEL+' 1a1b1e 2e3036 4a4d55 767a84',
 'butcher_cleaver':'0b0c0d '+STEEL+' 3a2618 5e3f26 8a6440 b48a5e 9a7428 d0a848',
 'vineyard_billhook':'0b0c0d '+STEEL+' 3a2618 5e3f26 8a6440 b48a5e d99560 3f5a2a 6a8a40',
 'eraser_curved_blade':'0b0c0d '+STEEL+' 3e4228 5c6238 8e8470 c8bea6 4a2a5e 7a4a9a',
 'lead_cane':'0b0c0d '+STEEL+' 1a1b1e 2e3036 4a4d55 767a84 6e6878 a49cb0',
 'wolfhead_knuckles':'0b0c0d '+STEEL+' 1a1b1e 2e3036 4a4d55 767a84',
 'saluzzo_crest':'0b0c0d 5e4418 9a7428 d0a848 f0d888 ece4d0 5e1620 9a2a3a 4a5058 7d868e',
}

def rgb(h): return tuple(bytes.fromhex(h.lstrip('#')))
def dump(path,data): path.write_text(json.dumps(data,ensure_ascii=False,indent=2,default=lambda o:o.item())+'\n',encoding='utf-8')
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

def map_palette(a,mask,palette):
    pal=np.array([rgb(h) for h in palette],dtype=np.int32)
    p=a[:,:,:3].astype(np.int32)
    dist=((p[:,:,None,:]-pal[None,None,:,:])**2).sum(axis=3)
    out=pal[dist.argmin(axis=2)].astype('uint8')
    # Keep at most 23 material colours; reserve one colour for the outline.
    colors,counts=np.unique(out[mask],axis=0,return_counts=True)
    if len(colors)>23:
        keep=colors[np.argsort(-counts)[:23]]
        ix=((out[:,:,None,:].astype(int)-keep[None,None,:,:])**2).sum(3).argmin(2)
        out=keep[ix]
    return out

def rim(mask):
    er=mask.copy()
    for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)]:
        n=np.roll(mask,(dy,dx),(0,1))
        if dy==1:n[0]=False
        if dy==-1:n[-1]=False
        if dx==1:n[:,0]=False
        if dx==-1:n[:,-1]=False
        er &= n
    return mask & ~er

def smooth(a,mask):
    # Remove only isolated interior colour flecks; never change silhouette.
    border=rim(mask)
    for _ in range(4):
        b=a.copy()
        for y,x in zip(*np.where(mask)):
            neighbors=[tuple(a[y+dy,x+dx]) for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)] if 0<=y+dy<a.shape[0] and 0<=x+dx<a.shape[1] and mask[y+dy,x+dx]]
            if not neighbors:continue
            if tuple(a[y,x]) not in neighbors:
                c=min(neighbors,key=lambda n:np.linalg.norm(a[y,x].astype(float)-n)-12*neighbors.count(n))
                if np.linalg.norm(a[y,x].astype(float)-c)<145:b[y,x]=c
        a=b
    return a

def reduce(root,e):
    src=Image.open(root/'sources'/f"{e['id']}_raw.png").convert('RGBA')
    arr=np.array(src); arr[:,:,3]=np.where(arr[:,:,3]>=180,255,0)
    src=Image.fromarray(arr);src=src.crop(src.getbbox())
    w,h=e['native_size']; fw,fh=FOOTPRINT.get(e['id'],(w-4,h-4))
    ratio=min(fw/src.width,fh/src.height)
    sw,sh=max(1,round(src.width*ratio)),max(1,round(src.height*ratio))
    small=src.resize((sw,sh),Image.Resampling.BOX)
    arr=np.array(small);mask=arr[:,:,3]>=112
    # Lift painted highlights before quantization; retain dark source shadows.
    p=arr[:,:,:3].astype(float)
    lum=p@np.array([.2126,.7152,.0722])
    cut=np.percentile(lum[mask],65)
    highlight=mask & (lum>=cut) & (lum>45)
    factor=1.22 if e['id']=='rhodes_field_uniform' else 1.12
    p[highlight]=np.minimum(255,p[highlight]*factor+18)
    if e['id']=='rhodes_field_uniform':p[highlight]=np.minimum(255,p[highlight]*1.32+22)
    arr[:,:,:3]=p.astype('uint8')
    colors=map_palette(arr,mask,E6_PALETTE if root.name=='batch_E6_v1' else MATERIALS[e['id']].split())
    colors=smooth(colors,mask)
    out=np.zeros((h,w,4),dtype=np.uint8)
    x,y=(w-sw)//2,(h-sh)//2
    out[y:y+sh,x:x+sw,:3]=colors
    out[y:y+sh,x:x+sw,3]=mask*255
    mask=out[:,:,3]>0
    # Preserve painting's existing near-black rim; no second outer dark ring.
    dark=mask & (out[:,:,:3].max(2)<34)
    out[dark,:3]=OUTLINE
    return Image.fromarray(out)

def finish(im,root,e):
    """Art-directed native colour corrections and exact retained logo placement."""
    a=np.array(im);mask=a[:,:,3]>0;item=e['id'];h,w=mask.shape;yy,xx=np.indices(mask.shape)
    def recolor(old,new,region=None):
        sel=mask & np.all(a[:,:,:3]==rgb(old),2)
        if region is not None:sel &= region
        a[sel,:3]=rgb(new)
    maps={
      'old_town_crowbar':{'d99560':'ece4d0','7d868e':'b4bec4'},
      'cane_sword':{'7d868e':'b4bec4'},
      'vineyard_billhook':{'b48a5e':'d99560','7d868e':'b4bec4','8a6440':'d99560'},
      'eraser_curved_blade':{'7d868e':'b4bec4','8e8470':'c8bea6'},
      'lead_cane':{'7d868e':'b4bec4','a49cb0':'b4bec4'},
      'wolfhead_knuckles':{'7d868e':'b4bec4','767a84':'b4bec4'},
    }
    for old,new in maps.get(item,{}).items():recolor(old,new)
    if item=='lead_cane':
        # Lavender belongs only on the narrow band; the wolf pommel is silver.
        recolor('6e6878','7d868e',xx>54)
    if item=='rhodes_dual_blades':
        # Keep blue on the middle one-pixel inset of each painted blade.
        region=(xx>=32)&(xx<=59)&(((yy==9)|(yy==18)))
        for old in GROUPS['blue']|GROUPS['cyan']:
            recolor(old,'98a2a6',~region)
        for old in GROUPS['orange']|GROUPS['yellow']:recolor(old,'3d4448')
        # Light strips follow the two straight blade cores; labels stay neutral.
        for y,x0,x1 in [(9,34,57),(18,34,57)]:
            for x in range(x0,x1):
                if mask[y,x]:a[y,x,:3]=rgb('78b8e8' if x>49 else '5888a8')
    if item.startswith('rhodes_'):
        # Remove stray hue contamination: blue piping and cyan lamps have
        # distinct jobs. Retain cyan exclusively in the specified status lights.
        if item not in ['rhodes_protective_vest','rhodes_beacon']:
            for old in GROUPS['cyan']:recolor(old,'c3cacc')
        if item=='rhodes_field_uniform':
            for old in GROUPS['yellow']:recolor(old,'98a2a6')
            a[34:36,35,:3]=rgb('e0782a')
        if item=='rhodes_badge':
            for old in GROUPS['blue']:recolor(old,'566064',xx<14)
        if item=='rhodes_beacon':
            a[12,23]=(*rgb('5fd0d8'),255)
            a[12,24]=(*rgb('b8f4f6'),255)
        if item=='rhodes_protective_vest':
            a[26,22:26,:3]=rgb('5fd0d8')
    # Colour-cluster cleanup after the material correction.
    a[:,:,:3]=smooth(a[:,:,:3],mask)
    if item in ['barber_razor','lead_cane']:
        a[:,:,:3]=smooth(a[:,:,:3],mask)
    if item=='barber_razor':
        # Sequential pairing avoids synchronous colour swaps along a narrow
        # diagonal edge. Retain the shape and choose the closest painted tone.
        for y,x in zip(*np.where(mask)):
            ns=[a[y+dy,x+dx,:3] for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)] if 0<=y+dy<h and 0<=x+dx<w and mask[y+dy,x+dx]]
            if ns and not any(np.array_equal(a[y,x,:3],n) for n in ns):
                a[y,x,:3]=min(ns,key=lambda n:np.linalg.norm(a[y,x,:3].astype(float)-n.astype(float)))
    im=Image.fromarray(a)
    if item in LOGO_POS:
        logo=Image.open(root/'sources'/'rhodes_logo_S_9.png').convert('RGBA')
        x,y=LOGO_POS[item]
        # Clear the model's placeholder mark before placing one exact logo.
        d=ImageDraw.Draw(im);d.rectangle((x,y,x+8,y+8),fill=(*rgb('3d4448' if item in ['rhodes_field_uniform','rhodes_beacon'] else '98a2a6'),255))
        im.alpha_composite(logo,(x,y))
    # Restore tiny lamps after cluster cleanup so that their emit masks survive.
    if item=='rhodes_beacon':
        im.putpixel((23,12),(*rgb('5fd0d8'),255));im.putpixel((24,12),(*rgb('b8f4f6'),255))
    if item=='rhodes_protective_vest':
        for x in range(22,26):im.putpixel((x,26),(*rgb('5fd0d8'),255))
    return im

def metrics(im):
    a=np.array(im);mask=a[:,:,3]>0;n=int(mask.sum());p=a[:,:,:3]
    same=np.zeros(mask.shape,bool)
    for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)]:
        m=np.roll(mask,(dy,dx),(0,1));c=np.roll(p,(dy,dx),(0,1))
        same |= m & np.all(p==c,axis=2)
    bright=p.astype(float)@np.array([.2126,.7152,.0722])>=153
    unique,count=np.unique(p[mask],axis=0,return_counts=True)
    # Largest 4-connected region of one colour, rather than total colour usage.
    seen=np.zeros(mask.shape,bool);largest=0
    for yy,xx in zip(*np.where(mask)):
        if seen[yy,xx]:continue
        todo=[(yy,xx)];seen[yy,xx]=True;num=0;c=p[yy,xx]
        while todo:
            y,x=todo.pop();num+=1
            for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)]:
                ny,nx=y+dy,x+dx
                if 0<=ny<mask.shape[0] and 0<=nx<mask.shape[1] and mask[ny,nx] and not seen[ny,nx] and np.array_equal(p[ny,nx],c):seen[ny,nx]=True;todo.append((ny,nx))
        largest=max(largest,num)
    accents={k:round(100*sum(int(t) for c,t in zip(unique,count) if bytes(c).hex() in group)/n,2) for k,group in GROUPS.items()}
    return dict(opaque_pixel_count=n,colour_count=len(unique),isolated_pixel_percent=round(100*(mask & ~same).sum()/n,2),bright_pixel_percent=round(100*(mask & bright).sum()/n,2),largest_flat_region_percent=round(100*largest/n,2),accent_percent=accents,accent_total_percent=round(sum(accents.values()),2),binary_alpha=set(np.unique(a[:,:,3]).tolist())<={0,255},bbox=list(im.getbbox()))

def reviews(root,entries):
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',11)
    heights=[80 if e['form']=='armour' else 40 for e in entries]
    sheet=Image.new('RGB',(244+4*80,24+sum(heights)),'#17191b');d=ImageDraw.Draw(sheet)
    for i,bg in enumerate(BG if root.name=='batch_E6_v1' else BG[:3]+['#341e08']):d.text((248+80*i,6),bg,font=font,fill='#bbbbbb')
    y=24
    for e,height in zip(entries,heights):
        d.text((5,y+height//2-6),e['id'],font=font,fill='#dddddd')
        im=Image.open(root/e['file']).convert('RGBA')
        for i,bg in enumerate(BG if root.name=='batch_E6_v1' else BG[:3]+['#341e08']):
            x=244+i*80;d.rectangle((x,y,x+79,y+height-1),fill=bg)
            sheet.paste(im,(x+(80-im.width)//2,y+(height-im.height)//2),im)
        y+=height
    sheet.save(root/'contact_sheet.png');sheet.resize((sheet.width*2,sheet.height*2),Image.Resampling.NEAREST).save(root/'contact_sheet_2x.png')
    silhouettes=[(e['id'],root/e['file']) for e in entries]
    if root.name=='batch_E13_v1':
        silhouettes=silhouettes[:-1]
        data=json.loads((root/'sources'/'lungmen_index.json').read_text(encoding='utf-8'))
        for e in data:silhouettes.append((e['id'],root/'sources'/'lungmen'/f"{e['id']}.png"))
    row_heights=[max(56,max(Image.open(path).height+22 for _,path in silhouettes[i:i+2])) for i in range(0,len(silhouettes),2)]
    ss=Image.new('RGB',(560,sum(row_heights)),'#b8bbbd');d=ImageDraw.Draw(ss)
    comparisons=[]
    for i,(name,path) in enumerate(silhouettes):
        im=Image.open(path).convert('RGBA');black=Image.new('RGBA',im.size,(*OUTLINE,255));black.putalpha(im.getchannel('A'))
        x,y=(i%2)*280,sum(row_heights[:i//2]);d.text((x+4,y+2),name,font=font,fill='#202225')
        # Native-size silhouette alongside its colour counterpart.
        ss.paste(black,(x+5,y+18),black);ss.paste(im,(x+95,y+18),im)
        comparisons.append(str(path.relative_to(root)))
    ss.save(root/'silhouette_check.png');dump(root/'silhouette_sources.json',comparisons)
    # Compact enlarged art-only preview, additional to mandatory native slots.
    tiles=Image.new('RGB',(4*160,((len(entries)+3)//4)*176),'#24282b');d=ImageDraw.Draw(tiles)
    for i,e in enumerate(entries):
        im=Image.open(root/e['file']).convert('RGBA');scale=2 if im.width==72 else 4
        im=im.resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST)
        x,y=(i%4)*160,(i//4)*176
        tiles.paste(im,(x+(160-im.width)//2,y+10+(136-im.height)//2),im)
        d.text((x+3,y+153),e['id'],font=font,fill='#e1e2e3')
    tiles.save(root/'art_preview.png')

def build(root):
    specs=json.loads((root/'generation_specs.json').read_text(encoding='utf-8'))
    prior={e['id']:e for e in json.loads((root/'manifest.json').read_text(encoding='utf-8'))} if (root/'manifest.json').exists() else {}
    manifest=[];report=[]
    for spec in specs:
        im=finish(reduce(root,spec),root,spec)
        # Optional native cleanup patches are explicit retained review artifacts.
        patch=root/'sources'/f"{spec['id']}_cleanup.png"
        if patch.exists():
            p=Image.open(patch).convert('RGBA');im.alpha_composite(p)
        im.save(root/f"{spec['id']}.png")
        im.resize((im.width*8,im.height*8),Image.Resampling.NEAREST).save(root/f"{spec['id']}_8x.png")
        m=metrics(im)
        e={k:v for k,v in spec.items() if k!='prompt'}
        for key in ['reference_urls','prototype_refs','processing','logo_position']:
            if key in prior.get(spec['id'],{}):e[key]=prior[spec['id']][key]
        e.update(file=f"{spec['id']}.png",source=f"sources/{spec['id']}_raw.png",source_sha256=sha(root/'sources'/f"{spec['id']}_raw.png"),**m)
        if spec['has_emit']:
            arr=np.array(im);keep=np.zeros(arr.shape[:2],bool)
            groups=GROUPS['blue'] if spec['id']=='rhodes_dual_blades' else GROUPS['cyan']
            for h in groups:keep|=np.all(arr[:,:,:3]==rgb(h),axis=2)
            keep &= arr[:,:,3]>0
            emit=np.zeros_like(arr);emit[keep]=arr[keep]
            Image.fromarray(emit).save(root/f"{spec['id']}_emit.png")
            e['emit_pixels']=int(keep.sum())
        checks=dict(size=im.size==tuple(spec['native_size']),binary_alpha=m['binary_alpha'],colours=m['colour_count']<=24,isolated=m['isolated_pixel_percent']<=10,bright=m['bright_pixel_percent']>=15)
        if root.name=='batch_E6_v1':checks.update(accent_total=m['accent_total_percent']<=10,accent_single=max(m['accent_percent'].values())<=6,flat=m['largest_flat_region_percent']<=25,palette=all(bytes(c).hex() in E6_PALETTE for c in np.unique(np.array(im)[:,:,:3][np.array(im)[:,:,3]>0],axis=0)))
        if spec['has_emit']:checks['emit_nonempty']=e['emit_pixels']>0
        e['file_sha256']=sha(root/e['file']);manifest.append(e)
        report.append(dict(id=spec['id'],checks=checks,metrics=m))
    dump(root/'manifest.json',manifest)
    dump(root/'qa_report.json',dict(status='PASS' if all(all(r['checks'].values()) for r in report) else 'REVIEW_REQUIRED',definitions=dict(isolated='Opaque pixels sharing their RGB with none of four opaque orthogonal neighbors.',luminance='Rec.709 weighted sRGB code values >=153/255; no linear-light conversion.',flat='Largest four-connected region of exactly one RGB, divided by total opaque pixels.',runtime='Godot import and backpack/UI display not tested.'),items=report))
    reviews(root,manifest)
    print(root.name,[(r['id'],[k for k,v in r['checks'].items() if not v]) for r in report])

if __name__=='__main__':
    roots=[HERE] if HERE.name.startswith('batch_') else [ITEMS/'batch_E13_v1',ITEMS/'batch_E6_v1']
    for root in roots:build(root)
