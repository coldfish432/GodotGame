from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import numpy as np,json,hashlib,zipfile
p=Path(r'D:\策划测试题\MM_minimap_v2');dest=p/'art/ui/minimap';baseline=json.loads((p/'baseline_hashes.json').read_text(encoding='utf8'));changed=[];qa=[];outline=(16,20,24)
for f in sorted(dest.glob('mm_*.png')):
 digest=hashlib.sha256(f.read_bytes()).hexdigest()
 if digest!=baseline[f.name]:changed.append(f.name)
 im=Image.open(f);a=np.array(im);opaque=a[:,:,3]>0;fill=opaque&np.any(a[:,:,:3]!=outline,axis=2);colors={tuple(c) for c in a[:,:,:3][fill]};boundary=[]
 for y,x in zip(*np.where(opaque)):
  if x==0 or y==0 or x==15 or y==15 or not opaque[max(0,y-1):y+2,max(0,x-1):x+2].all():boundary.append(tuple(a[y,x,:3]))
 assert im.size==(16,16) and set(np.unique(a[:,:,3]))=={0,255} and len(colors)<=3 and all(c==outline for c in boundary)
 qa.append({'file':f.name,'sha256':digest,'changed':f.name in changed,'size':[16,16],'alpha':[0,255],'interior_colors':['#%02x%02x%02x'%c for c in sorted(colors)],'outline_pass':True})
assert changed==['mm_route.png','mm_trace.png'],changed
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',14);ground=Image.open(p/'input/refs/minimap_now.png').convert('RGB').crop((1042,124,1110,190))
def bg(w,h):
 im=Image.new('RGB',(w,h))
 for y in range(0,h,ground.height):
  for x in range(0,w,ground.width):im.paste(ground,(x,y))
 return im
comp=bg(800,340);d=ImageDraw.Draw(comp);d.text((10,10),'MM v2: previous -> revised | 1x, 2x, 8x nearest',font=font,fill='#d2dae0')
for row,n in enumerate(['route','trace']):
 y=50+row*145;d.text((10,y+5),n,font=font,fill='#d2dae0')
 for k,folder in enumerate([p/'before',dest]):
  icon=Image.open(folder/f'mm_{n}.png');x=100+k*350;d.text((x,y-5),'BEFORE' if k==0 else 'AFTER',font=font,fill='#b5c1cc')
  for dx,s in [(0,1),(40,2),(105,8)]:
   sp=icon.resize((16*s,16*s),Image.Resampling.NEAREST);comp.paste(sp,(x+dx,y+18),sp)
comp.save(p/'revision_before_after.png')
allpreview=bg(960,420);d=ImageDraw.Draw(allpreview)
for i,f in enumerate(sorted(dest.glob('mm_*.png'))):
 x=i%5*192;y=i//5*105;im=Image.open(f);d.text((x+8,y+8),f.stem.removeprefix('mm_'),font=font,fill='#d2dae0');allpreview.paste(im,(x+20,y+48),im);sp=im.resize((32,32),Image.Resampling.NEAREST);allpreview.paste(sp,(x+65,y+40),sp)
allpreview.save(p/'preview_all_1x_2x.png')
report={'changed':changed,'protected_unchanged':18,'static_checks':'passed','assets':qa,'runtime_tested_after_revision':False,'existing_v1_runtime_evidence':'User review confirms all 20 v1 icons integrated, size/alpha/outline/color pass. v2 has only offline visual review.'};(p/'qa_report.json').write_text(json.dumps(report,indent=2),encoding='utf8')
(p/'README.md').write_text('''# MM v2 局部返工

根据 MM_review_v1.md，只重画 mm_route.png 和 mm_trace.png。
route：浅蓝 #72b8ff，单个向下尖括号，无底块、无向上或侧向箭头。
trace：紫色 #c48cff，一对上下交错鞋印。
其余 18 张（包括 squad）从项目原文件复制，SHA-256 逐一核对不变。

art/ui/minimap/ 含完整 20 张成品；before/ 保留两张旧图作对照。
revision_before_after.png：旧/新，1×、2×、8× nearest；preview_all_1x_2x.png：全套原尺寸/两倍预览。背景取自用户当前小地图地面并平铺，并非新运行时截图。
内置 image_gen 重绘；raw/ 保留新源稿，generation_records.json 为完整提示词。bake_icons.py 做确定性像素烘焙，不重绘其他图标。
静态尺寸、0/255 透明、内部最多三色、#101418 外轮廓、18 张原文件哈希和 ZIP 检查通过。用户反馈已确认 v1 游戏接入；本次 v2 未做游戏内验证，形状辨识待复审。
''',encoding='utf8')
archive=p.parent/'MM_minimap_icons_v2_review.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
 for f in sorted(p.rglob('*')):
  if f.is_file():z.write(f,f.relative_to(p))
with zipfile.ZipFile(archive) as z:assert z.testzip() is None
print(json.dumps({'changed':changed,'protected_unchanged':18,'checks':'passed','zip_crc':'passed','archive':str(archive)},ensure_ascii=False))
