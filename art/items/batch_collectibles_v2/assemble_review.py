from pathlib import Path
import json, hashlib
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).parent
rows=json.loads((R/'references.json').read_text(encoding='utf-8'))
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',23)
small=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',17)
colors=['#68b978']*2+['#58a9dd']*4+['#b78ade']*6+['#f16b73']*6
panels=[]
for g in range(3):
 im=Image.open(R/f'rough_group_{g+1}.png').convert('RGB')
 p=Image.new('RGB',(im.width,im.height+84),'#e6e9ed');p.paste(im,(0,0));d=ImageDraw.Draw(p)
 for j in range(6):
  k=g*6+j;x=round(j*im.width/6)+12
  d.text((x,im.height+8),f'{k+1:02d} '+rows[k]['name'],font=font,fill='#151a22')
  d.text((x,im.height+42),rows[k]['id'],font=small,fill='#303a48')
  d.rectangle((x,im.height+71,x+150,im.height+76),fill=colors[k])
 panels.append(p)
# Layout only: generated art is pasted intact, with no retouching or character extraction.
line=Image.new('RGB',(sum(p.width for p in panels),max(p.height for p in panels)),'#e6e9ed')
x=0
for p in panels:line.paste(p,(x,0));x+=p.width
line.save(R/'figurines_18_rough_lineup_v1.png')
grid=Image.new('RGB',(max(p.width for p in panels),sum(p.height for p in panels)),'#e6e9ed')
y=0
for p in panels:grid.paste(p,(0,y));y+=p.height
grid.save(R/'figurines_18_rough_readable_v1.jpg',quality=95)
manifest={'stage':'rough_identity_review_pending','generator':'built-in image_gen','characters':rows,'runtime_assets_delivered':0,'files':[],'checks':{'reference_originals_readable':len(rows),'groups':3,'ordered_character_slots':18,'single_row_canvas':list(line.size),'readable_canvas':list(grid.size)},'review_notes':['Green prize bases should be simplified further in final pass.','Camera yaw and body scale need closer matching to Blender template in final pass.','Mon3tr is currently abstract and needs clearer creature anatomy.','32x64 recognition, alpha and 512x1024 final asset QA have not been performed; these are concept boards only.']}
for f in sorted(R.glob('*.png')):
 with Image.open(f) as im:info={'file':f.name,'size':list(im.size),'mode':im.mode,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()}
 manifest['files'].append(info)
(R/'qa_report.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(manifest['checks']))
