from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageChops
import json,shutil,hashlib,numpy as np
R=Path(__file__).parent;B=R.parent;P=B.parents[1]
m=json.loads((R/'generation.json').read_text(encoding='utf-8-sig'));source=Path(m['source_path']);shutil.copy2(source,R/'source.png')
plan=next(x for x in json.loads((B/'terrain_plan.json').read_text(encoding='utf-8-sig')) if x['id']=='snow_floor')
pal=np.array([tuple(int(c[i:i+2],16) for i in (0,2,4)) for c in plan['palette']],dtype=np.int32)
im=Image.open(source).convert('RGB').resize((256,256),Image.Resampling.NEAREST);a=np.asarray(im,dtype=np.int32)
idx=((a[:,:,None,:]-pal[None,None,:,:])**2).sum(axis=3).argmin(axis=2);im=Image.fromarray(pal[idx].astype(np.uint8))
if m.get('offset_back'): im=ImageChops.offset(im,*m['offset_back'])
im.save(R/'snow_floor.png')
used=im.getcolors(65536);assert 8<=len(used)<=12
old=Image.open(R/'before/snow_floor.png').convert('RGB');gray={(76,77,87),(107,109,120),(138,140,150)}
def gray_count(i):return sum(n for n,c in i.getcolors(65536) if c in gray)
before=gray_count(old);after=gray_count(im)
a=np.asarray(im,dtype=np.float32);luma=float((a@np.array([.2126,.7152,.0722])).mean())
rock=Image.open(P/'art/kit/textures/painted/snow_rock_top.png').convert('RGB');rock_luma=float((np.asarray(rock,dtype=np.float32)@np.array([.2126,.7152,.0722])).mean())
dx=np.abs(a[:,1:]-a[:,:-1]).mean(axis=(0,2));dy=np.abs(a[1:]-a[:-1]).mean(axis=(1,2))
sx=float(np.abs(a[:,0]-a[:,-1]).mean());sy=float(np.abs(a[0]-a[-1]).mean())
tile=Image.new('RGB',(768,768))
for y in range(3):
 for x in range(3):tile.paste(im,(x*256,y*256))
tile.save(R/'snow_floor_tile_3x3.png')
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18)
sheet=Image.new('RGB',(560,312),'#202832');d=ImageDraw.Draw(sheet)
for x,title,img in [(16,f'修改前  灰斑 {before/65536:.1%}',old),(288,f'修改后  灰斑 {after/65536:.1%}',im)]:
 d.text((x,10),title,font=font,fill='white');sheet.paste(img,(x,42))
sheet.save(R/'before_after.png')
wide=Image.new('RGB',(1568,816),'#202832');d=ImageDraw.Draw(wide)
d.text((12,10),'修改前 · 3×3',font=font,fill='white');d.text((800,10),'修改后 · 3×3',font=font,fill='white')
wide.paste(Image.open(R/'before/snow_floor_tile_3x3.png'),(8,40));wide.paste(tile,(792,40));wide.save(R/'tiling_before_after.png')
q={'id':'snow_floor','version':2,'size':[256,256],'colors':len(used),'palette_exact':True,'gray_before_pixels':before,'gray_after_pixels':after,'gray_ratio_to_v1':round(after/before,4),'gray_coverage_before':round(before/65536,5),'gray_coverage_after':round(after/65536,5),'luma_mean':round(luma,2),'snow_top_luma':round(rock_luma,2),'floor_darker_than_top':luma<rock_luma,'seam_x_mean':round(sx,3),'seam_y_mean':round(sy,3),'internal_x_p95':round(float(np.percentile(dx,95)),3),'internal_y_p95':round(float(np.percentile(dy,95)),3),'sha256':hashlib.sha256((R/'snow_floor.png').read_bytes()).hexdigest(),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'runtime_validation':'NOT_RUN'}
(R/'qa_report.json').write_text(json.dumps(q,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(q,ensure_ascii=False))
