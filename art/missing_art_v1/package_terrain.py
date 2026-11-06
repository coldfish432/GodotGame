"""Palette/size packaging and QA only. Texture painting is done with image_gen."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,shutil,hashlib
import numpy as np
R=Path(__file__).parent;P=R.parents[1]
PLAN=json.loads((R/'terrain_plan.json').read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def rgb(h):return tuple(int(h[i:i+2],16) for i in (0,2,4))
def package():
 meta=json.loads((R/'terrain_generation.json').read_text(encoding='utf-8-sig'));checks=[]
 for row in PLAN:
  ident=row['id'];m=meta[ident];source=Path(m['source_path']);local=R/'sources'/(ident+'.png');shutil.copy2(source,local)
  im=Image.open(local).convert('RGB');assert im.width==im.height
  # Discrete nearest sampling + no-dither palette mapping, no terrain drawing.
  im=im.resize((256,256),Image.Resampling.NEAREST)
  colors=[rgb(c) for c in row['palette']]
  samples=np.asarray(im,dtype=np.int32);palette=np.asarray(colors,dtype=np.int32)
  # Exact RGB nearest palette: Pillow's cached lookup can collapse close specified browns.
  indices=((samples[:,:,None,:]-palette[None,None,:,:])**2).sum(axis=3).argmin(axis=2)
  im=Image.fromarray(palette[indices].astype(np.uint8))
  out=R/'terrain'/(ident+'.png');im.save(out)
  actual=im.getcolors(65536);used={c for n,c in actual};assert used<=set(colors)
  assert 8<=len(used)<=12,f'{ident}: only {len(used)} colors, needs 8-12'
  a=np.asarray(im,dtype=np.float32);dx=np.abs(a[:,1:]-a[:,:-1]).mean(axis=(0,2));dy=np.abs(a[1:]-a[:-1]).mean(axis=(1,2))
  edge_x=float(np.abs(a[:,0]-a[:,-1]).mean());edge_y=float(np.abs(a[0]-a[-1]).mean())
  luma=float((a@np.array([0.2126,0.7152,0.0722])).mean())
  orange=float(sum(n for n,c in actual if c in [rgb('d07a2c'),rgb('f29a26')])/65536)
  tile=Image.new('RGB',(768,768))
  for y in range(3):
   for x in range(3):tile.paste(im,(x*256,y*256))
  tile.save(R/'previews'/(ident+'_tile_3x3.png'))
  checks.append(dict(id=ident,size=[256,256],mode='RGB',colors=len(used),palette_exact=True,world_m=row['world_m'],luma_mean=round(luma,2),orange_fraction=round(orange,5),seam_x_mean=round(edge_x,3),seam_y_mean=round(edge_y,3),internal_x_p95=round(float(np.percentile(dx,95)),3),internal_y_p95=round(float(np.percentile(dy,95)),3),sha256=sha(out),source_sha256=sha(local),status='PASS'))
 font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',18)
 overview=Image.new('RGB',(900,640),'#202832');d=ImageDraw.Draw(overview)
 for k,row in enumerate(PLAN):
  x,y=(k%3)*300,(k//3)*320;im=Image.open(R/'terrain'/(row['id']+'.png'));overview.paste(im,(x+22,y+12));d.text((x+12,y+278),row['code']+' '+row['id'],font=font,fill='white')
 overview.save(R/'previews/terrain_contact_sheet.png')
 by={c['id']:c for c in checks};relative={'mine_top_brighter_than_floor':by['mine_rock_top']['luma_mean']>by['mine_floor']['luma_mean'],'snow_top_brighter_than_floor':by['snow_rock_top']['luma_mean']>by['snow_floor']['luma_mean'],'snow_face_darker_than_floor':by['snow_rock_face']['luma_mean']<by['snow_floor']['luma_mean']}
 report=dict(passed=6,checks=checks,relative_brightness=relative,tiling_visual_review='PENDING',runtime_validation='NOT_RUN',integration='Deferred to user as required by brief')
 (R/'terrain_qa.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(report,ensure_ascii=False))
if __name__=='__main__':package()
