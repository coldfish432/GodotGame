"""Deterministic native reduction of retained imagegen paintings; no drawn geometry."""
from pathlib import Path
import json,hashlib,base64,sys
import numpy as np
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parent
OUTLINE=(11,12,13)
BACKGROUNDS=['#2c2e30','#142538','#352710','#341e08']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,v):p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def rim(a):
    inner=a.copy()
    for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)]:
        n=np.roll(a,(dy,dx),(0,1))
        if dy==1:n[0]=False
        if dy==-1:n[-1]=False
        if dx==1:n[:,0]=False
        if dx==-1:n[:,-1]=False
        inner &= n
    return a&~inner
def reduce(j):
    source=Image.open(ROOT/'sources'/(j['id']+'_raw.png')).convert('RGBA')
    alpha=source.getchannel('A').point(lambda v:255 if v>=160 else 0)
    assert alpha.getbbox(),j['id']
    source.putalpha(alpha);source=source.crop(alpha.getbbox())
    w,h=j['native_size'];ratio=min((w-4)/source.width,(h-4)/source.height)
    size=(max(1,round(source.width*ratio)),max(1,round(source.height*ratio)))
    small=np.array(source.resize(size,Image.Resampling.BOX));mask=small[:,:,3]>=115
    # Local contrast expansion is a material-lighting transform, never a
    # silhouette/feature redraw. It makes painted highlights readable at 1:1.
    rgb=small[:,:,:3].astype(float)
    lum=rgb@np.array([.2126,.7152,.0722])
    high=mask&(lum>=np.percentile(lum[mask],70))&(lum>45)
    rgb[high]=np.minimum(255,rgb[high]*1.10+12)
    quant=Image.fromarray(rgb.astype('uint8')).quantize(colors=23,method=Image.Quantize.FASTOCTREE,dither=Image.Dither.NONE).convert('RGB')
    rgb=np.array(quant)
    # Only denoise isolated near-colour interior specks. Do not smooth edges,
    # metallic glints or contrasting intended marks.
    border=rim(mask)
    rgb[border]=OUTLINE
    for _ in range(4):
        out=rgb.copy()
        for y,x in zip(*np.where(mask&~border)):
            ns=[out[y+dy,x+dx] for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)]]
            if not any(np.array_equal(out[y,x],n) for n in ns):
                closest=min(ns,key=lambda n:np.linalg.norm(out[y,x].astype(float)-n.astype(float)))
                if np.linalg.norm(out[y,x].astype(float)-closest.astype(float))<145:out[y,x]=closest
        rgb=out
    rgb[border]=OUTLINE
    # Remap complete highlight colours, not chosen positions: a palette ramp
    # exposure correction preserves every painted feature and colour cluster.
    target=.16*mask.sum()
    existing=int(((rgb.astype(float)@np.array([.2126,.7152,.0722])>=153)&mask).sum())
    if existing<target:
        values,counts=np.unique(rgb[mask&~border],axis=0,return_counts=True)
        order=np.argsort(-(values.astype(float)@np.array([.2126,.7152,.0722])))
        for index in order:
            color=values[index];light=float(color@np.array([.2126,.7152,.0722]))
            if light>=153:continue
            # Mix the upper tone toward pale light while keeping its hue.
            t=max(0,(164-light)/(255-light))
            new=np.round(color+(255-color)*t).clip(0,255).astype('uint8')
            sel=mask&~border&np.all(rgb==color,axis=2);rgb[sel]=new
            existing+=int(sel.sum())
            if existing>=target:break
    result=np.zeros((h,w,4),dtype=np.uint8);x,y=(w-size[0])//2,(h-size[1])//2
    result[y:y+size[1],x:x+size[0],:3]=rgb
    result[y:y+size[1],x:x+size[0],3]=mask*255
    result[result[:,:,3]==0]=0
    im=Image.fromarray(result);im.save(ROOT/(j['id']+'.png'))
    im.resize((w*8,h*8),Image.Resampling.NEAREST).save(ROOT/(j['id']+'_8x.png'))
    return im
def stats(im):
    a=np.array(im);mask=a[:,:,3]>0;rgb=a[:,:,:3];colors=len(np.unique(rgb[mask],axis=0))
    lum=rgb.astype(float)@np.array([.2126,.7152,.0722])/255
    isolated=0
    for y,x in zip(*np.where(mask)):
        ns=[rgb[y+dy,x+dx] for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)] if 0<=y+dy<im.height and 0<=x+dx<im.width and mask[y+dy,x+dx]]
        if not any(np.array_equal(rgb[y,x],n) for n in ns):isolated+=1
    # Lavender diagnostic is hue+chroma classification, not an exact-colour
    # count: reduced/quantized colours need not equal the brief's hex.
    r,g,b=rgb.astype(int).transpose(2,0,1)
    lavender=mask&(b>g+10)&(r>g+8)&(b>=r)&(r>90)
    return {'opaque_pixels':int(mask.sum()),'colors':colors,'bright_pixel_percent':round(float((mask&(lum>=.6)).sum()/mask.sum()*100),2),'isolated_pixel_percent':round(isolated/mask.sum()*100,2),'lavender_pixel_percent':round(float(lavender.sum()/mask.sum()*100),2),'bbox':im.getbbox(),'binary_alpha':bool(set(np.unique(a[:,:,3]))<={0,255})}
def previews(jobs,images):
    # Each owner gets one row of9. Kind-specific native canvases centered
    # inside fixed slots make actual relative inventory sizes visible.
    for scale,name in [(1,'contact_sheet.png')]:
        out=Image.new('RGB',(9*80*scale,4*100*scale),'#22272b');d=ImageDraw.Draw(out)
        for i,j in enumerate(jobs):
            col=i%9;row=i//9;im=images[j['id']];bg=BACKGROUNDS[row]
            x,y=col*80*scale,row*100*scale
            d.rectangle((x,y,x+80*scale-1,y+80*scale-1),fill=bg)
            big=im.resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST)
            out.paste(big,(x+(80*scale-big.width)//2,y+(80*scale-big.height)//2),big)
            d.text((x+2,y+82*scale),j['id'].replace('bg_',''),fill='#d5d9df')
        out.save(ROOT/name)
        out.resize((out.width*2,out.height*2),Image.Resampling.NEAREST).save(ROOT/'contact_sheet_2x.png')
        out.resize((out.width*4,out.height*4),Image.Resampling.NEAREST).save(ROOT/'art_preview.png')
    native=Image.new('RGB',(9*80,4*80*4),'#22272b')
    for b,bg in enumerate(BACKGROUNDS):
        for i,j in enumerate(jobs):
            im=images[j['id']];x=(i%9)*80;y=b*320+(i//9)*80
            ImageDraw.Draw(native).rectangle((x,y,x+79,y+79),fill=bg)
            native.paste(im,(x+(80-im.width)//2,y+(80-im.height)//2),im)
    native.save(ROOT/'rarity_backgrounds_1x.png')
    out=Image.new('RGB',(9*80*3,4*80*3),'#d4d7da')
    for i,j in enumerate(jobs):
        im=images[j['id']];sil=Image.new('RGBA',im.size,'#0b0c0d');sil.putalpha(im.getchannel('A'))
        sil=sil.resize((im.width*3,im.height*3),Image.Resampling.NEAREST)
        out.paste(sil,((i%9)*240+(240-sil.width)//2,(i//9)*240+(240-sil.height)//2),sil)
    out.save(ROOT/'silhouette_check.png')
def main():
    for p in (ROOT/'sources').glob('*.b64'):
        target=p.with_suffix('');target.write_bytes(base64.b64decode(p.read_text()));p.unlink()
    jobs=json.loads((ROOT/'generation_specs.json').read_text(encoding='utf-8'))
    available=[j for j in jobs if (ROOT/'sources'/(j['id']+'_raw.png')).exists()]
    images={j['id']:reduce(j) for j in available}
    records=[]
    for j in available:
        rec={k:v for k,v in j.items() if k!='prompt'}
        rec.update(file=j['id']+'.png',preview=j['id']+'_8x.png',has_emit=False,source='sources/'+j['id']+'_raw.png',source_sha256=sha(ROOT/'sources'/(j['id']+'_raw.png')),statistics=stats(images[j['id']]))
        records.append(rec)
    dump(ROOT/'manifest.json',records)
    followups='\n\n'.join('## Follow-up: '+p.stem+'\n\n'+p.read_text(encoding='utf-8') for p in (ROOT/'sources').glob('*_prompt.txt'))
    (ROOT/'generation_prompts.md').write_text('# Built-in image_gen.imagegen prompts\n\n'+'\n\n'.join('## '+j['id']+'\n\n'+j['prompt'] for j in jobs)+'\n\n'+followups,encoding='utf-8')
    if len(available)==36:previews(jobs,images)
    else:
        partial=Image.new('RGB',(720,max(1,(len(available)+5)//6)*130),'#292e32')
        d=ImageDraw.Draw(partial)
        for i,j in enumerate(available):
            im=images[j['id']];im=im.resize((im.width*min(2,100//im.width),im.height*min(2,100//im.width)),Image.Resampling.NEAREST)
            x=(i%6)*120;y=(i//6)*130;partial.paste(im,(x+(120-im.width)//2,y+(104-im.height)//2),im);d.text((x,y+108),j['id'].replace('bg_',''),fill='white')
        partial.save(ROOT/'partial_preview.png')
    print(json.dumps({'processed':len(records),'bright_below15':[r['id'] for r in records if r['statistics']['bright_pixel_percent']<15],'isolated_above10':[r['id'] for r in records if r['statistics']['isolated_pixel_percent']>10]}))
if __name__=='__main__':main()
