"""Normalize imagegen paintings, assemble review sheets, run static asset checks.
No procedural equipment drawing; preserve source alpha and material colors.
"""
from pathlib import Path
import json,hashlib,sys
import numpy as np
from PIL import Image,ImageDraw,ImageFont
B=Path(__file__).resolve().parent
OUTLINE=(11,12,13);BG=['#2c2e30','#142538','#352710'];SLOTS=['head','hands','legs','feet','ring']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def boundary(m):
    p=np.pad(m,1,constant_values=False)
    return m&~(p[1:-1,1:-1]&p[:-2,1:-1]&p[2:,1:-1]&p[1:-1,:-2]&p[1:-1,2:])
def quantize(rgb,n):
    # Preserve painted highlight planes instead of averaging them into midtones.
    # Every palette color is the average of its own source class; no brightening.
    lit=(rgb@[.2126,.7152,.0722])/255>=.6
    if lit.any() and (~lit).any() and n>=2:
        out=np.empty_like(rgb);nl=max(1,n//3);nd=n-nl
        for m,k in [(lit,nl),(~lit,nd)]:
            p=Image.fromarray(rgb[m].reshape(1,-1,3),'RGB').quantize(colors=k,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
            out[m]=np.array(p.convert('RGB')).reshape(-1,3)
        return out
    p=Image.fromarray(rgb.reshape(1,-1,3),'RGB').quantize(colors=n,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
    return np.array(p.convert('RGB')).reshape(-1,3)
def normalize(src,j):
    im=Image.open(src).convert('RGBA');al=im.getchannel('A').point(lambda x:255 if x>=128 else 0);im.putalpha(al);im=im.crop(al.getbbox())
    n=j['size'];edge=round(n*(.85 if j['slot'] in ['legs','ring'] else .8));s=edge/max(im.size)
    im=im.resize((max(1,round(im.width*s)),max(1,round(im.height*s))),Image.Resampling.NEAREST)
    out=Image.new('RGBA',(n,n));out.paste(im,((n-im.width)//2,(n-im.height)//2));a=np.array(out);m=a[:,:,3]>0;rgb=a[:,:,:3].copy()
    r,g,b=[rgb[:,:,i].astype(int) for i in range(3)]
    # Keep rare painted red trims and the blue ice core distinct from gray material.
    red=m&(r>70)&(r>g*1.6)&(r>b*1.6)
    ice=m&(b>g*1.06)&(g>r*1.1)&(b>100) if j['id']=='snow_ring_3' else np.zeros_like(m)
    expedition=j['id'] in ['snow_head_2','snow_hands_3','snow_legs_3']
    orange=m&(r>g*1.2)&(g>b*1.2)&(r>100)
    accent=ice if j['id']=='snow_ring_3' else orange if expedition else red if j['cloth'] else np.zeros_like(m)
    material=m&~accent;a[:,:,:3]=0
    a[material,:3]=quantize(rgb[material],(4 if expedition else 5) if j['cloth'] else 20)
    if accent.any():a[accent,:3]=quantize(rgb[accent],4 if expedition else 3 if j['id']=='snow_ring_3' else 2)
    a[:,:,3]=m.astype(np.uint8)*255;a[boundary(m),:3]=OUTLINE
    return Image.fromarray(a,'RGBA')
def font(n):
    p=Path('C:/Windows/Fonts/msyh.ttc');return ImageFont.truetype(str(p),n) if p.exists() else ImageFont.load_default()
def sheets(rows,batch):
    positions={};count={s:0 for s in SLOTS}
    for row in rows:positions[row['id']]=(SLOTS.index(row['slot']),count[row['slot']]);count[row['slot']]+=1
    cols=max(count.values());cw=246;ch=728
    sheet=Image.new('RGB',(cols*cw+32,5*ch+64),'#191b1e');d=ImageDraw.Draw(sheet)
    d.text((16,10),f"{batch} · {len(rows)}件 · 装备3× / 戒指5×",font=font(14 if cols==1 else 23),fill='#eee8db');d.text((16,38),'每格自上向下: #2c2e30 / #142538 / #352710',font=font(8 if cols==1 else 13),fill='#bdb4a2')
    overview=Image.new('RGB',(cols*248+32,1210),'#2c2e30');od=ImageDraw.Draw(overview)
    od.text((16,10),f'{batch} · '+{'E15b':'龙门','E15c':'萨米','E15d':'罗德岛'}[batch]+f' · {len(rows)}件',font=font(25),fill='#eee8db')
    sil=Image.new('RGB',overview.size,'#c8c4bb');sd=ImageDraw.Draw(sil);sd.text((16,10),f'{batch} · head / hands / legs / feet / ring',font=font(12 if cols==1 else 22),fill='#17191c')
    native=Image.new('RGB',(cols*177+16,580),'#2c2e30');nd=ImageDraw.Draw(native);nd.text((10,8),f'{batch} native 72px / ring32px',font=font(10 if cols==1 else 16),fill='#eee8db')
    for row in rows:
        si,col=positions[row['id']];x=16+col*cw;y=60+si*ch
        im=Image.open(B/row['file']).convert('RGBA');f=5 if row['slot']=='ring' else 3;scaled=im.resize((im.width*f,im.height*f),Image.Resampling.NEAREST)
        d.text((x,y),row['id'],font=font(14),fill='#eee8db');d.text((x,y+22),row['name'],font=font(16),fill='#bdb4a2')
        for k,bg in enumerate(BG):
            top=y+48+k*224;d.rectangle((x,top,x+231,top+219),fill=bg);sheet.paste(scaled,(x+(232-scaled.width)//2,top+(220-scaled.height)//2),scaled)
        ox=16+col*248;oy=58+si*230
        preview=im.resize((160,160) if row['slot']=='ring' else (180,180),Image.Resampling.NEAREST);overview.paste(preview,(ox+(236-preview.width)//2,oy),preview)
        od.text((ox,oy+185),row['name'],font=font(16),fill='#eee8db');od.text((ox,oy+206),row['id'],font=font(13),fill='#aba89e')
        solid=Image.new('RGBA',im.size,OUTLINE+(0,));solid.putalpha(im.getchannel('A'));solid=solid.resize(preview.size,Image.Resampling.NEAREST);sil.paste(solid,(ox+(236-solid.width)//2,oy),solid)
        sd.text((ox,oy+185),row['name'],font=font(16),fill='#17191c');sd.text((ox,oy+206),row['id'],font=font(13),fill='#444444')
        nx=8+col*177;ny=40+si*106;native.paste(im,(nx+(160-im.width)//2,ny),im);nd.text((nx,ny+75),row['id'],font=font(12),fill='#eee8db')
    if batch=='E15c':
        # Existing winter helmet stays unchanged; show only as an explicitly reused reference.
        im=Image.open(B/'refs/snow_x14.png').convert('RGBA');p=im.resize((180,180),Image.Resampling.NEAREST)
        overview.paste(p,(16+3*248+28,58),p);od.text((16+3*248,243),'冬牙角盔 · 沿用原图',font=font(16),fill='#eee8db');od.text((16+3*248,264),'snow_x14 [existing]',font=font(13),fill='#aba89e')
        ss=Image.new('RGBA',im.size,OUTLINE+(0,));ss.putalpha(im.getchannel('A'));ss=ss.resize((180,180),Image.Resampling.NEAREST);sil.paste(ss,(16+3*248+28,58),ss);sd.text((16+3*248,243),'冬牙角盔 · 沿用原图',font=font(16),fill='#17191c')
    sheet.save(B/'contact_sheet.png');overview.save(B/'overview.png');sil.save(B/'silhouette_check.png');native.save(B/'native_check.png')
def validate(row):
    p=B/row['file'];im=Image.open(p);a=np.array(im.convert('RGBA'));m=a[:,:,3]>0;lum=(a[:,:,:3]@[.2126,.7152,.0722])/255;bright=float(np.mean(lum[m]>=.6));colors=len(np.unique(a[m,:3],axis=0))
    isolated=eligible=0
    for y,x in zip(*np.where(m)):
        if tuple(a[y,x,:3])==OUTLINE:continue
        eligible+=1;sub=a[max(0,y-1):y+2,max(0,x-1):x+2];same=(sub[:,:,:3]==a[y,x,:3]).all(axis=2)&(sub[:,:,3]>0);isolated+=int(same.sum()==1)
    noise=isolated/max(1,eligible)
    checks=dict(size=list(im.size)==row['size'],rgba=im.mode=='RGBA',binary_alpha=set(np.unique(a[:,:,3])).issubset({0,255}),colors_le24=colors<=24,bright_ge15pct=bright>=.15,outline=bool(np.all(a[boundary(m),:3]==OUTLINE)),padding=not(m[0].any()or m[-1].any()or m[:,0].any()or m[:,-1].any()),cloth_noise_le10pct=noise<=.1 if row['cloth'] else True,source_hash=sha(B/row['source'])==row['source_sha256'],output_hash=sha(p)==row['sha256'])
    yy,xx=np.where(m)
    return dict(id=row['id'],pass_=all(checks.values()),checks=checks,colors=colors,bright_fraction=round(bright,4),isolated_fraction=round(noise,4),cloth_noise_enforced=row['cloth'],bbox=[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)])
def main():
    batch=json.loads((B/'generations.json').read_text(encoding='utf-8'))[0]['batch'];jobs=json.loads((B/'generations.json').read_text(encoding='utf-8'));edits=json.loads((B/'edits.json').read_text(encoding='utf-8'));edited={e['id']:e for e in edits};rows=[];missing=[]
    for j in jobs:
        id=j['id'];src=B/'sources'/(id+('_edited.png' if id in edited else '_raw.png'))
        if not src.exists():missing.append(id);continue
        im=normalize(src,j);p=B/(id+'.png');im.save(p)
        rows.append(dict(id=id,name=j['name'],slot=j['slot'],layer=j['layer'],file=p.name,size=[j['size']]*2,cloth=j['cloth'],source=src.relative_to(B).as_posix(),source_sha256=sha(src),sha256=sha(p),emit=id=='snow_ring_3'))
    em=[]
    if any(r['id']=='snow_ring_3' for r in rows):
        a=np.array(Image.open(B/'snow_ring_3.png').convert('RGBA'));rr,gg,bb=[a[:,:,i].astype(int) for i in range(3)];lum=(a[:,:,:3]@[.2126,.7152,.0722])/255;m=(a[:,:,3]>0)&(bb>gg*1.06)&(gg>rr*1.1)&(bb>100)&(lum>=.6);e=np.zeros_like(a);e[m]=a[m];Image.fromarray(e).save(B/'snow_ring_3_emit.png')
        em=[dict(id='snow_ring_3',pixels=int(m.sum()),nonempty=bool(m.any()),same_rgb_as_base=bool(np.all(e[m]==a[m])),localized=int(m.sum())<int((a[:,:,3]>0).sum())*.25,binary_alpha=set(np.unique(e[:,:,3])).issubset({0,255}))]
    manifest=dict(batch=batch,status='art_review_pending',tool='built-in imagegen',normalization='alpha128; nearest fit; median-cut without dithering, highlights and shadows quantized separately without brightening: cloth5 plus2 red or expedition4 gray+4 orange; other20 plus3 ice; exact1px inner outline',items=rows,expected_count=len(jobs),missing=missing,backgrounds=BG,emission_files=['snow_ring_3_emit.png'] if em else [],reused_assets=[dict(id='snow_x14',reference='refs/snow_x14.png',reason='Existing accepted winter helmet preserved; not a newly delivered icon')] if batch=='E15c' else [],runtime_verified=False)
    (B/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    results=[validate(r) for r in rows];qa=dict(scope='static files and review sheets; no engine acceptance',runtime_verified=False,expected_count=len(jobs),actual_count=len(rows),missing=missing,items=results,emit=em)
    qa['pass']=not missing and all(r['pass_'] for r in results) and all(e['nonempty']and e['same_rgb_as_base']and e['localized']and e['binary_alpha'] for e in em)
    if batch=='E15c' and not em:qa['pass']=False
    (B/'qa_report.json').write_text(json.dumps(qa,ensure_ascii=False,indent=2),encoding='utf-8')
    if rows:sheets(rows,batch)
    for r in results:
        print(f"{r['id']} {'PASS' if r['pass_'] else 'FAIL'} bright={r['bright_fraction']:.1%} noise={r['isolated_fraction']:.1%} colors={r['colors']}",','.join(k for k,v in r['checks'].items() if not v))
    print(batch,'PASS' if qa['pass'] else 'FAIL',f'{len(rows)}/{len(jobs)}',em)
    return 0 if qa['pass'] else 1
if __name__=='__main__':sys.exit(main())
