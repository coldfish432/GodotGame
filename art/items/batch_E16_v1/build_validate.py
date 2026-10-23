"""Deterministic E16 imagegen-art reduction, palette mapping, logo placement and QA."""
from pathlib import Path
from collections import Counter,deque
import json,hashlib,zipfile,shutil
import numpy as np
from PIL import Image,ImageDraw,ImageFont

B=Path(__file__).resolve().parent
ROOT=B.parents[2]
OUTLINE='0b0c0d'
NEUTRAL='0b0c0d 15181a 1f2427 2c3236 3d4448 566064 737d82 98a2a6 c3cacc a9b2b3 d4dadb eef2f2'.split()
GROUPS={k:v.split() for k,v in dict(blue='385878 5888a8 78b8e8',orange='6e2f14 b8531f e0782a',cyan='0f3a40 2a8a92 5fd0d8 b8f4f6',yellow='6b5a1e b89a2a f4d73c').items()}
PALETTE=NEUTRAL+sum(GROUPS.values(),[])
BG=['#2c2e30','#142538','#352710','#381b0f']
SPECS=[
 dict(id='rhodes_head_heavy',name='罗德岛制式防护头盔',slot='head',size=72,has_emit=True,extent=58,logo_position=[51,21]),
 dict(id='rhodes_hands_heavy',name='罗德岛制式防护臂甲',slot='hands',size=72,has_emit=False,extent=58),
 dict(id='rhodes_legs_heavy',name='罗德岛制式防护护腿',slot='legs',size=72,has_emit=False,extent=61),
 dict(id='rhodes_feet_heavy',name='罗德岛制式防护战靴',slot='feet',size=72,has_emit=False,extent=58),
 dict(id='rhodes_ring_monitor',name='罗德岛生体监测环',slot='ring',size=32,has_emit=True,extent=27),
]

def rgb(h):return tuple(bytes.fromhex(h.lstrip('#')))
def dump(p,x):p.write_text(json.dumps(x,ensure_ascii=False,indent=2,default=lambda o:o.item())+'\n',encoding='utf-8')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def boundary(m):
 p=np.pad(m,1,constant_values=False)
 return m&~(p[1:-1,1:-1]&p[:-2,1:-1]&p[2:,1:-1]&p[1:-1,:-2]&p[1:-1,2:])

def map_rgb(p,palette):
 pal=np.array([rgb(h) for h in palette],dtype=np.int32)
 ix=((p.astype(np.int32)[:,:,None,:]-pal[None,None,:,:])**2).sum(3).argmin(2)
 return pal[ix].astype('uint8')

def cleanup_clusters(colors,mask,protected):
 # Remove isolated interior palette flecks without changing alpha, outline,
 # lighting planes or intentional blue/cyan pixels. This is the same bounded
 # native color-cluster cleanup used for earlier painted icon deliveries.
 for _ in range(4):
  result=colors.copy()
  for y,x in zip(*np.where(mask&~protected)):
   near=[tuple(colors[y+dy,x+dx]) for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)] if 0<=y+dy<mask.shape[0] and 0<=x+dx<mask.shape[1] and mask[y+dy,x+dx] and not protected[y+dy,x+dx]]
   if not near or tuple(colors[y,x]) in near:continue
   best=min(set(near),key=lambda c:np.linalg.norm(colors[y,x].astype(float)-c)-12*near.count(c))
   if np.linalg.norm(colors[y,x].astype(float)-best)<145:result[y,x]=best
  colors=result
 return colors

def reduce(spec):
 source=B/'sources'/(spec['id']+'_redraw.png')
 if not source.exists():source=B/'sources'/(spec['id']+'_raw.png')
 spec['source']=source
 src=Image.open(source).convert('RGBA')
 alpha=src.getchannel('A').point(lambda v:255 if v>=128 else 0);src.putalpha(alpha);src=src.crop(alpha.getbbox())
 factor=spec['extent']/max(src.size)
 src=src.resize((round(src.width*factor),round(src.height*factor)),Image.Resampling.NEAREST)
 a=np.array(src);m=a[:,:,3]>=128;p=a[:,:,:3];r,g,b=[p[:,:,i].astype(int) for i in range(3)]
 # Map material families separately so neutral visor shading cannot become
 # spurious blue accents. Generated bands/lights retain their source positions.
 blue=m&(b-r>24)&(b-g>9)&(b>70)
 cyan=m&(g-r>45)&(b-r>45)&(np.abs(b-g)<=20)&(b>150) if spec['has_emit'] else np.zeros_like(m)
 if spec['slot']=='ring':blue=np.zeros_like(m)
 blue&=~cyan
 colors=map_rgb(p,NEUTRAL)
 # Keep source interior near-black as ship steel; reserve exact outline black
 # for the one-pixel silhouette, including the ring's inner-hole boundary.
 colors[(colors==rgb(OUTLINE)).all(2)]=rgb('15181a')
 lum=p@[.2126,.7152,.0722]
 if spec['slot']=='hands':
  # The redraw has distinct 230-ish midplanes and 245-ish highlight planes.
  # Preserve that tonal separation rather than collapsing both into one white.
  colors[(colors==rgb('eef2f2')).all(2)&(lum<235)]=rgb('d4dadb')
 if spec['slot']=='ring':
  colors[(colors==rgb('d4dadb')).all(2)&(lum<212)]=rgb('c3cacc')
 if blue.any():colors[blue]=map_rgb(p,GROUPS['blue'])[blue]
 if cyan.any():colors[cyan]=map_rgb(p,GROUPS['cyan'])[cyan]
 colors=cleanup_clusters(colors,m,blue|cyan|boundary(m)|(colors==rgb(OUTLINE)).all(2))
 n=spec['size'];out=np.zeros((n,n,4),np.uint8);x=(n-src.width)//2;y=(n-src.height)//2
 out[y:y+src.height,x:x+src.width,:3]=colors;out[y:y+src.height,x:x+src.width,3]=m.astype('uint8')*255
 out[out[:,:,3]==0]=0;out[boundary(out[:,:,3]>0),:3]=rgb(OUTLINE)
 im=Image.fromarray(out)
 if 'logo_position' in spec:
  # Exact native 9x9 mark, never reduced from an enlarged illustration.
  logo=Image.open(B/'refs/logo_S_9.png').convert('RGBA');assert logo.size==(9,9)
  im.alpha_composite(logo,tuple(spec['logo_position']))
 return im

def largest_flat(a,m):
 seen=np.zeros(m.shape,bool);largest=0
 for y,x in zip(*np.where(m)):
  if seen[y,x]:continue
  color=a[y,x,:3];q=deque([(int(y),int(x))]);seen[y,x]=True;area=0
  while q:
   yy,xx=q.popleft();area+=1
   for ny,nx in [(yy-1,xx),(yy+1,xx),(yy,xx-1),(yy,xx+1)]:
    if 0<=ny<m.shape[0] and 0<=nx<m.shape[1] and m[ny,nx] and not seen[ny,nx] and np.array_equal(a[ny,nx,:3],color):
     seen[ny,nx]=True;q.append((ny,nx))
  largest=max(largest,area)
 return largest

def metrics(im):
 a=np.array(im);m=a[:,:,3]>0;n=int(m.sum());unique,count=np.unique(a[m,:3],axis=0,return_counts=True)
 isolated=0
 for y,x in zip(*np.where(m)):
  same=any(0<=y+dy<im.height and 0<=x+dx<im.width and m[y+dy,x+dx] and np.array_equal(a[y,x,:3],a[y+dy,x+dx,:3]) for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)])
  isolated+=not same
 accent={key:100*sum(int(c) for col,c in zip(unique,count) if bytes(col).hex() in group)/n for key,group in GROUPS.items()}
 return dict(opaque_pixels=n,colors=len(unique),isolated_pixel_percent=round(100*isolated/n,3),
  bright_pixel_percent=round(100*float(((a[:,:,:3]@[.2126,.7152,.0722])[m]>=153).mean()),3),
  max_single_color_percent=round(100*int(count.max())/n,3),largest_flat_region_percent=round(100*largest_flat(a,m)/n,3),
  accent_percent={k:round(v,3) for k,v in accent.items()},accent_total_percent=round(sum(accent.values()),3),
  binary_alpha=set(np.unique(a[:,:,3]))<={0,255},palette_valid=all(bytes(col).hex() in PALETTE for col in unique),
  outline_exact=bool(np.all(a[boundary(m),:3]==rgb(OUTLINE))),bbox=list(im.getbbox()))

def font(n):return ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',n)

def previews(items):
 # Four backgrounds, exact requested display scales for the inventory review.
 cw,ch=244,284;contact=Image.new('RGB',(5*cw,4*ch+66),'#191b1e');d=ImageDraw.Draw(contact)
 d.text((18,10),'E16 · 罗德岛制式防护系列 · 装备3× / 监测环5×',font=font(22),fill='#eef2f2')
 for col,s in enumerate(items):
  im=Image.open(B/s['file']).convert('RGBA');f=5 if s['slot']=='ring' else 3
  scaled=im.resize((im.width*f,im.height*f),Image.Resampling.NEAREST)
  for row,bg in enumerate(BG):
   x=col*cw;y=66+row*ch;d.rectangle((x,y,x+cw-1,y+ch-1),fill=bg)
   d.text((x+8,y+6),s['name'],font=font(16),fill='#eef2f2');d.text((x+8,y+28),bg,font=font(12),fill='#a9b2b3')
   contact.paste(scaled,(x+(cw-scaled.width)//2,y+54+(216-scaled.height)//2),scaled)
 contact.save(B/'contact_sheet.png')
 # Field uniform and protective vest anchor the two ends of the pairing row.
 pair=Image.new('RGB',(2600,350),BG[0]);d=ImageDraw.Draw(pair)
 columns=[('外勤制服','rhodes_field_uniform',None)]
 for s in items:
  columns.extend([('外勤款',f"rhodes_{s['slot']}",None),('防护款',s['id'],s)])
 columns.append(('防护背心','rhodes_protective_vest',None))
 for col,(label,ident,s) in enumerate(columns):
  path=B/s['file'] if s else B/'refs'/(ident+'.png');im=Image.open(path).convert('RGBA')
  f=5 if im.width==32 else 3;scaled=im.resize((im.width*f,im.height*f),Image.Resampling.NEAREST)
  x=col*216;d.text((x+10,16),label,font=font(18),fill='#eef2f2')
  pair.paste(scaled,(x+(216-scaled.width)//2,54+(216-scaled.height)//2),scaled)
  d.text((x+6,286),ident.replace('rhodes_',''),font=font(11),fill='#d4dadb')
 pair.save(B/'pairing_check.png')
 overview=Image.new('RGB',(5*244,320),BG[0]);od=ImageDraw.Draw(overview)
 native=Image.new('RGB',(5*180,150),BG[0]);nd=ImageDraw.Draw(native)
 sil=Image.new('RGB',overview.size,'#d4dadb')
 for col,s in enumerate(items):
  im=Image.open(B/s['file']).convert('RGBA');f=5 if s['slot']=='ring' else 3;large=im.resize((im.width*f,im.height*f),Image.Resampling.NEAREST)
  x=col*244;overview.paste(large,(x+(244-large.width)//2,52+(216-large.height)//2),large)
  od.text((x+8,12),s['name'],font=font(16),fill='#eef2f2');od.text((x+8,286),s['id'].replace('rhodes_',''),font=font(12),fill='#c3cacc')
  native.paste(im,(col*180+(180-im.width)//2,30),im);nd.text((col*180+5,112),s['slot']+' '+str(im.size),font=font(12),fill='#eef2f2')
  solid=Image.new('RGBA',large.size,'#0b0c0d');solid.putalpha(large.getchannel('A'));sil.paste(solid,(x+(244-large.width)//2,52+(216-large.height)//2),solid)
 overview.save(B/'overview.png');native.save(B/'native_check.png');sil.save(B/'silhouette_check.png')

def main():
 records=[];reports=[];emission=[]
 for spec in SPECS:
  ident=spec['id'];im=reduce(spec);path=B/(ident+'.png');im.save(path)
  im.resize((im.width*8,im.height*8),Image.Resampling.NEAREST).save(B/(ident+'_8x.png'))
  m=metrics(im);checks=dict(size=im.size==(spec['size'],spec['size']),binary_alpha=m['binary_alpha'],colors_le24=m['colors']<=24,palette=m['palette_valid'],outline=m['outline_exact'],bright_ge15=m['bright_pixel_percent']>=15,isolated_le10=m['isolated_pixel_percent']<=10,accent_total_le10=m['accent_total_percent']<=10,accent_single_le6=max(m['accent_percent'].values())<=6,single_flat_color_le25=m['max_single_color_percent']<=25,padding=all(v>=1 for v in m['bbox'][:2]) and m['bbox'][2]<im.width and m['bbox'][3]<im.height)
  record=dict(id=ident,name=spec['name'],slot=spec['slot'],file=path.name,native_size=[spec['size']]*2,has_emit=spec['has_emit'],isolated_pixel_percent=m['isolated_pixel_percent'],accent_percent=m['accent_percent'],accent_total_percent=m['accent_total_percent'],source=spec['source'].relative_to(B).as_posix(),source_sha256=sha(spec['source']),sha256=sha(path))
  if 'logo_position' in spec:
   x,y=spec['logo_position'];logo=Image.open(B/'refs/logo_S_9.png').convert('RGBA');sample=np.array(im)[y:y+9,x:x+9];la=np.array(logo);checks['logo_exact']=bool(np.array_equal(sample[la[:,:,3]>0],la[la[:,:,3]>0]));record['logo_position']=spec['logo_position']
  if spec['has_emit']:
   a=np.array(im);cm=np.zeros(a.shape[:2],bool)
   for c in GROUPS['cyan']:cm|=(a[:,:,:3]==rgb(c)).all(2)&(a[:,:,3]>0)
   em=np.zeros_like(a);em[cm]=a[cm];ep=B/(ident+'_emit.png');Image.fromarray(em).save(ep)
   emission.append(dict(file=ep.name,pixels=int(cm.sum()),subset_of_base=bool(np.all(em[cm]==a[cm])),localized=bool(cm.sum()<=m['opaque_pixels']*.06),nonempty=bool(cm.any())))
   checks['emit_nonempty']=bool(cm.any());record['emit_file']=ep.name
  records.append(record);reports.append(dict(id=ident,pass_=all(checks.values()),checks=checks,**m))
 protected=json.loads((B/'protected_before.json').read_text());changed=[p for p,h in protected.items() if not (ROOT/p).is_file() or sha(ROOT/p)!=h]
 report=dict(status='PASS' if all(x['pass_'] for x in reports) and not changed else 'REVIEW_REQUIRED',items=reports,emission=emission,protected_files=len(protected),protected_changed=changed,runtime_verified=False,art_accepted=False,definitions=dict(isolated='Opaque pixels with no identical RGB among four orthogonal opaque neighbors.',bright='Rec709 weighted sRGB code values >=153.',flat='Maximum total share of any one RGB, stricter than connected-region-only checks.'))
 dump(B/'manifest.json',dict(batch='E16_v1',tool='built-in image_gen',items=records,backgrounds=BG,runtime_verified=False,art_accepted=False))
 dump(B/'qa_report.json',report);previews(records)
 for item in reports:print(item['id'],'PASS' if item['pass_'] else 'FAIL', 'colors',item['colors'],'bright',item['bright_pixel_percent'],'isolated',item['isolated_pixel_percent'],'maxcolor',item['max_single_color_percent'],'accent',item['accent_total_percent'],'failed',[k for k,v in item['checks'].items() if not v])
 print('Protected',len(protected),'changed',len(changed),'emission',emission)
 return 0 if report['status']=='PASS' else 1

if __name__=='__main__':raise SystemExit(main())
