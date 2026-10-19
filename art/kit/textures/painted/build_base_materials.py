"""Reduce painted R1-R10 sources, repair wrap seams, and retain review evidence.

All material marks and structures come from imagegen paintings. This script is
limited to uniform resampling, exposure/palette conversion and edge finishing.
"""
from pathlib import Path
import json,hashlib,shutil,sys
import numpy as np
from PIL import Image,ImageDraw,ImageFont
HERE=Path(__file__).resolve().parent
WORK=HERE if (HERE/'generation_specs.json').exists() else HERE/'base_materials_v1'
ROOT=WORK.parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2,default=lambda x:x.item())+'\n',encoding='utf-8')
def lab(rgb):
    x=np.asarray(rgb,dtype=np.float32)/255
    x=np.where(x<=.04045,x/12.92,((x+.055)/1.055)**2.4)
    xyz=x@np.array([[.4124564,.2126729,.0193339],[.3575761,.7151522,.1191920],[.1804375,.0721750,.9503041]],dtype=np.float32)
    xyz/=np.array([.95047,1.,1.08883],dtype=np.float32)
    f=np.where(xyz>.008856,np.cbrt(xyz),7.787*xyz+16/116)
    return np.stack((116*f[...,1]-16,500*(f[...,0]-f[...,1]),200*(f[...,1]-f[...,2])),axis=-1)

def wrap(a,axes,band):
    a=a.astype(float).copy();h,w=a.shape[:2]
    if 'x' in axes:
        for i in range(band):
            l=a[:,i].copy();r=a[:,w-1-i].copy();j=(l+r)*.5;t=i/band
            a[:,i]=j*(1-t)+l*t;a[:,w-1-i]=j*(1-t)+r*t
    if 'y' in axes:
        for i in range(band):
            t=a[i].copy();b=a[h-1-i].copy();j=(t+b)*.5;k=i/band
            a[i]=j*(1-k)+t*k;a[h-1-i]=j*(1-k)+b*k
    return np.uint8(np.clip(np.rint(a),0,255))

def index(a,palette):
    pal=np.array([tuple(bytes.fromhex(h)) for h in palette],dtype=np.uint8)
    d=lab(a)[:,:,None,:]-lab(pal)[None,None,:,:];d[:,:,:,1:]*=.8
    return pal[(d*d).sum(3).argmin(2)]

def protected_snapshot():
    paths=[p for p in ROOT.glob('*.png') if not p.name.startswith('base_')]
    paths += list(ROOT.parent.glob('base_*.png'))
    paths += list(ROOT.parent.parent.glob('base_*.glb'))
    dump(WORK/'protected_assets.json',{p.relative_to(ROOT.parent.parent.parent.parent).as_posix():sha(p) for p in paths})
    if (ROOT/'manifest.json').exists():
        shutil.copy2(ROOT/'manifest.json',WORK/'previous_painted_manifest.json')
    print('Protected existing assets',len(paths))

def build():
    (WORK/'textures').mkdir(parents=True,exist_ok=True)
    if not (WORK/'protected_assets.json').exists():protected_snapshot()
    specs=json.loads((WORK/'generation_specs.json').read_text(encoding='utf-8'));manifest={};reports=[]
    for e in specs:
        source=WORK/'sources'/f"{e['name']}_raw.png"
        im=Image.open(source).convert('RGB')
        # Every source matches its intended aspect. Crop only if generated
        # dimensions differ by rounding, never stretch a material pattern.
        target=e['size'];aspect=target[0]/target[1]
        if abs(im.width/im.height-aspect)>.01:
            if im.width/im.height>aspect:
                width=round(im.height*aspect);x=(im.width-width)//2;im=im.crop((x,0,x+width,im.height))
            else:
                height=round(im.width/aspect);y=(im.height-height)//2;im=im.crop((0,y,im.width,y+height))
        a=np.array(im.resize(tuple(target),Image.Resampling.BOX))
        before=a.copy()
        if e['id'] in ['R2','R3']:
            # Remove broad per-panel exposure slopes from the generated source;
            # the game supplies illumination. Retain local paint and scratches.
            n=4 if e['id']=='R2' else 6
            edges=np.rint(np.linspace(0,target[0],n+1)).astype(int)
            af=a.astype(float)
            for row in range(n):
                for col in range(n):
                    x0,x1=edges[col]+3,edges[col+1]-3;y0,y1=edges[row]+3,edges[row+1]-3
                    patch=af[y0:y1,x0:x1];yy,xx=np.indices(patch.shape[:2]);xx=xx-xx.mean();yy=yy-yy.mean()
                    design=np.stack([xx.ravel(),yy.ravel(),np.ones(xx.size)],1)
                    low,high=np.percentile(patch.reshape(-1,3),[5,95],axis=0)
                    fit=np.linalg.lstsq(design,np.clip(patch,low,high).reshape(-1,3),rcond=None)[0]
                    af[y0:y1,x0:x1]-=xx[:,:,None]*fit[0]+yy[:,:,None]*fit[1]
            if e['id']=='R2':af+=3
            a=np.uint8(np.clip(np.rint(af),0,255))
        if e['neutral_tinted']:
            # Remove hue contamination before prescribed neutral mapping.
            v=np.rint(a@np.array([.2126,.7152,.0722])).astype('uint8');a=np.repeat(v[:,:,None],3,2)
            if e['id']=='R2':
                # A dead band in the paint-face ramp avoids quantization
                # turning tiny source grain into apparent chipped paint.
                face=(v>=175)&(v<=208);a[face]=200
        if e['id'] in ['R3','R5']:
            # Preserve the painted tonal ordering while opening up the very
            # narrow source range. Sparse pre-existing wheel marks / rubbed
            # steel patches take the extra tones; no new marks are drawn.
            value=a@np.array([.2126,.7152,.0722])
            if e['id']=='R3':
                q=[0,.01,.03,.1,.3,98,99.8,100];levels=[93,114,132,161,191,207,227,242]
            else:
                q=[0,8,35,60,82,95,99.7,100];levels=[29,47,63,79,99,114,132,161]
            knots=np.percentile(value,q)
            target_value=np.interp(value,knots,np.array(levels))
            a=np.uint8(np.clip(a.astype(float)+(target_value-value)[:,:,None],0,255))
        a=wrap(a,e['seam_axes'],max(2,min(target)//32))
        indexed=index(a,e['palette'])
        if e['id'] in ['R2','R7','R8']:
            # Pair isolated quantization flecks, retaining straight seam lines.
            for _ in range(2):
                b=indexed.copy()
                for y in range(1,indexed.shape[0]-1):
                    for x in range(1,indexed.shape[1]-1):
                        ns=[tuple(indexed[y+dy,x+dx]) for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)]]
                        c=max(set(ns),key=ns.count)
                        if ns.count(c)>=3 and tuple(indexed[y,x]) not in ns:b[y,x]=c
                indexed=b
        if 'x' in e['seam_axes']:indexed[:,-1]=indexed[:,0]
        if 'y' in e['seam_axes']:indexed[-1]=indexed[0]
        image=Image.fromarray(indexed,'RGB');image.save(WORK/'textures'/e['file'])
        preview=Image.new('RGB',(target[0]*3,target[1]*3))
        for y in range(3):
            for x in range(3):preview.paste(image,(x*target[0],y*target[1]))
        preview.save(WORK/'textures'/f"{e['name']}_tile_3x3.png")
        used=np.unique(indexed.reshape(-1,3),axis=0)
        luma=indexed@np.array([.2126,.7152,.0722])
        quadrants=[float(x.mean()) for x in [luma[:target[1]//2,:target[0]//2],luma[:target[1]//2,target[0]//2:],luma[target[1]//2:,:target[0]//2],luma[target[1]//2:,target[0]//2:]]]
        v=dict(id=e['id'],file=e['file'],size=target,colors=len(used),palette=['#'+h for h in e['palette']],used_palette=['#'+bytes(c).hex() for c in used],world_size_m=e['world_size_m'],source='sources/'+source.name,source_sha256=sha(source),file_sha256=sha(WORK/'textures'/e['file']),neutral_tinted=e['neutral_tinted'],seam_axes=e['seam_axes'],mean_luma=round(float(luma.mean()),2),quadrant_mean_luma=[round(x,2) for x in quadrants],quadrant_spread=round(max(quadrants)-min(quadrants),2),seam_exact_x=bool(np.array_equal(indexed[:,0],indexed[:,-1])),seam_exact_y=bool(np.array_equal(indexed[0],indexed[-1])),notes='Specialized neutral ramp has six colors, overriding generic 8–12.' if e['neutral_tinted'] else '')
        manifest[e['name']]=v
        checks=dict(size=image.size==tuple(target),opaque=image.mode=='RGB',color_count=(1<=len(used)<=6 if e['neutral_tinted'] else e['color_range'][0]<=len(used)<=e['color_range'][1]),palette=True,seams=all(v['seam_exact_'+axis] for axis in e['seam_axes']))
        if e['neutral_tinted']:checks['neutral']=bool(np.all(indexed[:,:,0]==indexed[:,:,1]) and np.all(indexed[:,:,1]==indexed[:,:,2]))
        reports.append(dict(id=e['id'],checks=checks))
        print(e['id'],e['name'],len(used),'colors','mean',v['mean_luma'],'quadrant spread',v['quadrant_spread'],[k for k,x in checks.items() if not x])
    dump(WORK/'manifest.json',manifest);dump(WORK/'qa_report.json',dict(status='PASS' if all(all(r['checks'].values()) for r in reports) else 'REVIEW_REQUIRED',checks=reports,semantic_review='No baked lights/no text/detail scale and visible seams require visual review; numeric seam equality alone is insufficient.'))
    overview(manifest)

def overview(manifest):
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',14)
    canvas=Image.new('RGB',(5*272,2*304),'#20252a');d=ImageDraw.Draw(canvas)
    for i,(name,e) in enumerate(manifest.items()):
        im=Image.open(WORK/'textures'/e['file']);x=(i%5)*272;y=(i//5)*304
        ratio=min(256/im.width,256/im.height);display=im.resize((round(im.width*ratio),round(im.height*ratio)),Image.Resampling.NEAREST)
        canvas.paste(display,(x+(272-display.width)//2,y+24+(256-display.height)//2))
        d.text((x+8,y+5),e['id']+' '+name,font=font,fill='#d9dfe2')
        d.text((x+8,y+283),f"{e['size'][0]}x{e['size'][1]} / {e['colors']} colors",font=font,fill='#aebac1')
    canvas.save(WORK/'base_materials_contact.png')

if __name__=='__main__':build()
