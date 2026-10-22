"""Normalize painted imagegen sources; build native icons and review sheets.
No procedural object drawing. Requires Pillow and numpy.
"""
from pathlib import Path
import json, hashlib
import numpy as np
from PIL import Image, ImageDraw, ImageFont

B = Path(__file__).resolve().parent
OUTLINE = (11,12,13)
SLOTS = ['head','hands','legs','feet','ring']
NAMES = [
 '矿工安全帽','整合运动兜帽','纠察队毛皮帽','重装防爆头盔',
 '帆布劳保手套','整合运动缠手布','矿镐护腕','纠察队铁指护手',
 '矿工工装裤','整合运动束腿裤','游击队绑腿','复合护腿',
 '钢头劳保靴','整合运动帆布鞋','游击队行军靴','纠察队毛毡靴',
 '铁丝绕成的指环','源石碎粒戒','矿车铆钉戒','整合运动誓约环']
BG = ['#2c2e30','#142538','#352710']

def boundary(mask):
    pad=np.pad(mask,1,constant_values=False)
    inside=pad[1:-1,1:-1]&pad[:-2,1:-1]&pad[2:,1:-1]&pad[1:-1,:-2]&pad[1:-1,2:]
    return mask&~inside

def normalize(src, size, fill):
    im=Image.open(src).convert('RGBA')
    # Ignore faint model cutout fringe when measuring the painted object.
    alpha=im.getchannel('A').point(lambda x:255 if x>=128 else 0)
    box=alpha.getbbox()
    im.putalpha(alpha)
    im=im.crop(box)
    edge=round(size*fill)
    scale=edge/max(im.size)
    im=im.resize((max(1,round(im.width*scale)),max(1,round(im.height*scale))),Image.Resampling.NEAREST)
    canvas=Image.new('RGBA',(size,size))
    canvas.paste(im,((size-im.width)//2,(size-im.height)//2))
    a=np.array(canvas)
    mask=a[:,:,3]>=128
    # Palette computed only from opaque material, no dithering.
    rr,gg,bb=[a[:,:,i].astype(int) for i in range(3)]
    orange=mask&(rr>120)&(rr>gg*1.25)&(gg>bb*1.35)&(gg>40)
    has_red=any(t in src.stem for t in ['head_2','hands_2','feet_2'])
    red=mask&(rr>70)&(rr>gg*1.6)&(rr>bb*1.6)
    accent=orange if 'ring_2' in src.stem else red if has_red else np.zeros_like(mask)
    material=mask&~accent
    source_rgb=a[:,:,:3].copy()
    pixels=Image.fromarray(a[:,:,:3][material].reshape(1,-1,3),'RGB')
    cloth=any(t in src.stem for t in ['head_2','hands_1','hands_2','legs_1','legs_2','legs_3','feet_2','feet_4'])
    pal=pixels.quantize(colors=(5 if has_red else 6) if cloth else 20,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
    rgb=np.array(pal.convert('RGB')).reshape(-1,3)
    a[:,:,:3]=0
    a[material,:3]=rgb
    if accent.any():
        # Preserve existing painted rare orange fissure or vermilion cloth trims.
        ap=Image.fromarray(source_rgb[accent].reshape(1,-1,3),'RGB').quantize(colors=2,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
        a[accent,:3]=np.array(ap.convert('RGB')).reshape(-1,3)
    a[:,:,3]=mask.astype(np.uint8)*255
    # Native 1px inner silhouette outline, reserved exact color.
    a[boundary(mask),:3]=OUTLINE
    return Image.fromarray(a,'RGBA')

def font(n):
    for p in ['C:/Windows/Fonts/msyh.ttc','C:/Windows/Fonts/arial.ttf']:
        if Path(p).exists(): return ImageFont.truetype(p,n)
    return ImageFont.load_default()

def sheets(rows):
    # Main sheet: 5 slot rows x 4 item columns, each has three vertically stacked swatches.
    cellw,cellh=246,728
    sheet=Image.new('RGB',(4*cellw+32,5*cellh+64),'#191b1e');d=ImageDraw.Draw(sheet)
    d.text((16,12),'E15a · 矿区20件 · 装备3× / 戒指5× · 三背景',font=font(22),fill='#e7e0d0')
    d.text((16,38),'每格自上向下: #2c2e30 / #142538 / #352710',font=font(13),fill='#bdb4a2')
    for idx,row in enumerate(rows):
        si,col=divmod(idx,4);x=16+col*cellw;y=60+si*cellh
        d.text((x,y),row['id'],font=font(15),fill='#eee8db')
        d.text((x,y+22),row['name'],font=font(16),fill='#bdb4a2')
        im=Image.open(B/row['file']).convert('RGBA'); f=5 if row['slot']=='ring' else 3
        scaled=im.resize((im.width*f,im.height*f),Image.Resampling.NEAREST)
        for k,bg in enumerate(BG):
            top=y+48+k*224
            d.rectangle((x,top,x+231,top+219),fill=bg)
            sheet.paste(scaled,(x+(232-scaled.width)//2,top+(220-scaled.height)//2),scaled)
    sheet.save(B/'contact_sheet.png')
    # Compact visual overview, separately labelled; no resampling of final art.
    overview=Image.new('RGB',(1008,1210),'#2c2e30');d=ImageDraw.Draw(overview)
    d.text((20,12),'E15a · 矿区装备首批20件',font=font(25),fill='#ede8db')
    sil=Image.new('RGB',(1008,1210),'#c8c4bb');sd=ImageDraw.Draw(sil)
    sd.text((20,12),'E15a · 按 head / hands / legs / feet / ring 排列',font=font(22),fill='#17191c')
    native=Image.new('RGB',(720,580),'#2c2e30');nd=ImageDraw.Draw(native)
    nd.text((10,8),'E15a native 72px / rings32px',font=font(20),fill='#ede8db')
    for idx,row in enumerate(rows):
        si,col=divmod(idx,4);x=16+col*248;y=58+si*230
        im=Image.open(B/row['file']).convert('RGBA');f=5 if row['slot']=='ring' else 3
        scaled=im.resize((im.width*f,im.height*f),Image.Resampling.NEAREST)
        # Compact equipment preview 216px; labels within each 230px slot row.
        if row['slot']!='ring':
            scaled=im.resize((180,180),Image.Resampling.NEAREST)
        overview.paste(scaled,(x+(236-scaled.width)//2,y),scaled)
        d.text((x,y+185),row['name'],font=font(16),fill='#e7e0d0')
        d.text((x,y+206),row['id'],font=font(13),fill='#aba89e')
        solid=Image.new('RGBA',im.size,OUTLINE+(0,));solid.putalpha(im.getchannel('A'))
        ss=solid.resize(scaled.size,Image.Resampling.NEAREST)
        sil.paste(ss,(x+(236-ss.width)//2,y),ss)
        sd.text((x,y+185),row['name'],font=font(16),fill='#17191c')
        sd.text((x,y+206),row['id'],font=font(13),fill='#444444')
        nx=12+col*177;ny=40+si*106
        native.paste(im,(nx+(160-im.width)//2,ny),im)
        nd.text((nx,ny+75),row['id'],font=font(13),fill='#e7e0d0')
    overview.save(B/'overview.png');sil.save(B/'silhouette_check.png');native.save(B/'native_check.png')

def main():
    gens=json.loads((B/'generations.json').read_text(encoding='utf-8'))
    edits=json.loads((B/'edits.json').read_text(encoding='utf-8'))
    edited={x['id']:x for x in edits}
    rows=[]
    for idx,g in enumerate(gens):
        id=g['id'];slot=g['slot'];n=32 if slot=='ring' else 72
        fill=.85 if slot in ['legs','ring'] else .80
        src=B/'sources'/(id+('_edited.png' if id in edited else '_raw.png'))
        im=normalize(src,n,fill);im.save(B/(id+'.png'))
        rows.append(dict(id=id,name=NAMES[idx],slot=slot,layer=[0,0,1,2][idx%4],file=id+'.png',size=[n,n],source=str(src.relative_to(B)).replace('\\','/'),source_sha256=hashlib.sha256(src.read_bytes()).hexdigest(),sha256=hashlib.sha256((B/(id+'.png')).read_bytes()).hexdigest(),emit=id=='mine_ring_2'))
    im=Image.open(B/'mine_ring_2.png').convert('RGBA');a=np.array(im);r,g,b=a[:,:,0].astype(int),a[:,:,1].astype(int),a[:,:,2].astype(int)
    orange=(a[:,:,3]>0)&(r>120)&(r>g*1.25)&(g>b*1.35)&(g>40)
    e=np.zeros_like(a);e[orange]=a[orange]
    Image.fromarray(e).save(B/'mine_ring_2_emit.png')
    (B/'manifest.json').write_text(json.dumps({'batch':'E15a_v1','status':'style_review_pending','tool':'built-in imagegen','normalization':'alpha threshold128; crop; nearest fit; cloth6 colors or5+2 red; other20 colors; originium2 reserved orange colors; median cut without dithering; exact native inner silhouette outline','items':rows,'emission_files':['mine_ring_2_emit.png'],'backgrounds':BG,'approval_gate':'E15a style acceptance before E15b/c/d','runtime_verified':False},ensure_ascii=False,indent=2),encoding='utf-8')
    sheets(rows)
    print('Built20 icons +1 localized emit; review sheets ready.')

if __name__=='__main__':main()
