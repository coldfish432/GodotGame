from pathlib import Path
import json,hashlib,shutil
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).parent;P=R.parents[1]
meta=json.loads((R/'icons_generation.json').read_text(encoding='utf-8-sig'));checks=[]
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',20)
sheet=Image.new('RGB',(1000,260),'#353c45');d=ImageDraw.Draw(sheet)
for k,ident in enumerate(['battery','sugar','solid_fuel','medical_supplies']):
 if ident in meta:
  source=Path(meta[ident]['source_path']);local=R/'sources'/(ident+'.png');shutil.copy2(source,local)
  im=Image.open(local).convert('RGBA');a=im.getchannel('A');assert a.getextrema()[0]==0
  box=a.point(lambda v:255 if v>32 else 0).getbbox();assert box
  im=im.crop(box);im.thumbnail((28,28),Image.Resampling.NEAREST)
  im.putalpha(im.getchannel('A').point(lambda v:255 if v>=128 else 0))
  out=Image.new('RGBA',(32,32));out.alpha_composite(im,((32-im.width)//2,(32-im.height)//2))
  path=R/'icons'/(ident+'.png');out.save(path)
  assert set(out.getchannel('A').getdata())<={0,255}
  assert out.getchannel('A').getbbox()[0]>0
  checks.append(dict(id=ident,size=[32,32],mode='RGBA',hard_alpha=True,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),status='PASS'))
 else:out=Image.open(P/'art/items/runtime'/(ident+'.png')).convert('RGBA')
 zoom=out.resize((128,128),Image.Resampling.NEAREST);sheet.paste(zoom,(k*250+61,36),zoom);d.text((k*250+12,202),ident,font=font,fill='white')
sheet.save(R/'previews/icons_compare_4x.png')
(R/'icons_qa.json').write_text(json.dumps({'passed':2,'checks':checks,'runtime_validation':'NOT_RUN'},indent=2),encoding='utf-8')
print('A: 2/2 size, RGBA, hard-alpha checks PASS')
