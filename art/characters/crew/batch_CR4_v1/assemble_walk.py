from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,shutil,hashlib,zipfile
p=Path(r'D:\策划测试题\batch_CR4_v1');rec=json.loads((p/'generation_records.json').read_text());(p/'raw').mkdir(exist_ok=True)
ims={}
for a in rec['assets']:
 dst=p/'raw'/(a['key']+'_generated.png');shutil.copy2(a['source'],dst);ims[a['key']]=Image.open(dst).convert('RGBA')
dirs=['S','SW','W','NW','N','NE','E','SE'];out=Image.new('RGBA',(1024,2048));stats=[]
for row,direction in enumerate(dirs):
 key='back' if row in [3,5] else 'walk';im=ims[key];sr=([3,5].index(row) if key=='back' else row);nr=2 if key=='back' else 8
 cells=[];bounds=[]
 for c in range(4):
  cell=im.crop((round(c*im.width/4),round(sr*im.height/nr),round((c+1)*im.width/4),round((sr+1)*im.height/nr)))
  box=cell.getchannel('A').point(lambda x:255 if x>12 else 0).getbbox();assert box
  cells.append(cell);bounds.append(box)
 # Uniform scale within each direction; scripts assemble painted content only.
 scale=min(210/max(b[3]-b[1] for b in bounds),220/max(b[2]-b[0] for b in bounds))
 for c,(cell,b) in enumerate(zip(cells,bounds)):
  sprite=cell.crop(b);sprite=sprite.resize((round(sprite.width*scale),round(sprite.height*scale)),Image.Resampling.LANCZOS)
  # Anchor to head centre; keep the electrical lead inside the 256 px cell.
  upper=sprite.getchannel('A').crop((0,0,sprite.width,round(sprite.height*.45)));hb=upper.point(lambda x:255 if x>12 else 0).getbbox();cx=(hb[0]+hb[2])/2
  x=round(128-cx);x=max(12,min(x,244-sprite.width));y=240-sprite.height
  out.paste(sprite,(c*256+x,row*256+y))
  assembled=out.crop((c*256,row*256,(c+1)*256,(row+1)*256));ab=assembled.getchannel('A').getbbox()
  border=assembled.getchannel('A');edge=max(border.crop((0,0,256,8)).getextrema()[1],border.crop((0,248,256,256)).getextrema()[1],border.crop((0,0,8,256)).getextrema()[1],border.crop((248,0,256,256)).getextrema()[1])
  stats.append({'direction':direction,'frame':c+1,'bbox':ab,'border_alpha_max':edge,'sha256':hashlib.sha256(assembled.tobytes()).hexdigest()})
out.save(p/'raidian_walk_source.png')
small=out.resize((128,256),Image.Resampling.LANCZOS);small.save(p/'raidian_walk_32.png')
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
preview=Image.new('RGB',(1152,2112),'#b5bdc8');preview.paste(out,(100,32),out);draw=ImageDraw.Draw(preview)
for r,d in enumerate(dirs):draw.text((10,32+r*256+115),d,font=font,fill='#152030')
preview.save(p/'walk_grid_preview.jpg',quality=94)
frames=[];tiny_frames=[]
for c in range(4):
 frame=Image.new('RGB',(1024,560),'#b5bdc8');dr=ImageDraw.Draw(frame)
 tiny=Image.new('RGB',(256,64),'#b5bdc8')
 for r,d in enumerate(dirs):
  sp=out.crop((c*256,r*256,(c+1)*256,(r+1)*256));x=(r%4)*256;y=(r//4)*280;frame.paste(sp,(x,y+20),sp);dr.text((x+10,y+4),d,font=font,fill='#152030')
  s=sp.resize((32,32),Image.Resampling.LANCZOS);tiny.paste(s,(r*32,16),s)
 frames.append(frame);tiny_frames.append(tiny)
frames[0].save(p/'walk_preview.gif',save_all=True,append_images=frames[1:],duration=180,loop=0,optimize=False)
tiny_frames[0].save(p/'walk_preview_32.gif',save_all=True,append_images=tiny_frames[1:],duration=180,loop=0,optimize=False)
front=small.crop((0,0,32,32));front.save(p/'preview_32.png')
av=Image.open(r'D:\策划测试题\ST2_v1\input\refs\prts\raidian_avatar.png').convert('RGBA');comp=Image.new('RGB',(600,300),'#b5bdc8');comp.paste(av,(30,50),av);s=front.resize((192,192),Image.Resampling.NEAREST);comp.paste(s,(340,50),s);ImageDraw.Draw(comp).text((20,15),'PRTS avatar          S walk at 32px (6x nearest)',font=font,fill='#152030');comp.save(p/'raidian_vs_prts_32.png')
manifest={'sheets':[{'id':'raidian','kind':'walk','file':'raidian_walk_source.png','cols':4,'rows':8,'cell':256}]};(p/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
assert all(s['border_alpha_max']==0 for s in stats)
assert len(set(s['sha256'] for s in stats))==32
report={'dimensions':list(out.size),'mode':out.mode,'alpha_extrema':out.getchannel('A').getextrema(),'cell':256,'rows':dirs,'frames':stats,'unique_frames':32,'clear_8px_cell_borders':True,'runtime_tested':False,'animation_preview':'four phase 180ms GIF generated; not Godot playback','source_processing':'Generated sheets sliced on uniform grids, NW/NE replaced with generated correction rows; per-direction uniform scale and per-frame head centre/sole placement. No procedural character drawing.'}
(p/'qa_report.json').write_text(json.dumps(report,indent=2),encoding='utf8')
(p/'README.md').write_text('''# CR4 电弧行走表

本批仅补行走：raidian_walk_source.png，1024×2048，4 列×8 行，256×256 单格。
行序 S / SW / W / NW / N / NE / E / SE；列为四帧慢走。
电弧形象沿用修订稿：黎博利黑色羽饰、无后脑红白装饰、两条粉黑机械臂收拢、电线末端带插头，无毛尾。

内置 image_gen 绘制，raw/ 保存生成原图，generation_records.json 保存全部提示词。assemble_walk.py 仅切格、缩放、定位、拼版、预览与检查，不绘制角色。
manifest.json 使用 CR 格式。raidian_walk_32.png 为缩小检查表，不代替下游烘焙。preview_32.png 为 S 行首帧缩小检查图，当前没有 idle，不能视为待机帧。
walk_preview.gif 为八方向四帧预览；walk_preview_32.gif 为原生 32 像素预览。raidian_vs_prts_32.png 提供头像辨识度对照。
静态检查：32 格非空且互异、透明通道、八像素格边留空、尺寸和 ZIP 完整性通过。生成动画预览，不等于 Godot 导入或游戏内播放验证；四相位脚步连续性和辨识度仍待美术审阅。
''',encoding='utf8')
archive=p.parent/'CR4_raidian_walk_v1_review.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
 for f in sorted(p.rglob('*')):
  if f.is_file():z.write(f,f.relative_to(p))
with zipfile.ZipFile(archive) as z:assert z.testzip() is None
print(json.dumps({'archive':str(archive),'size':list(out.size),'frames':32,'clear_cell_borders':True,'crc':'passed'},ensure_ascii=False))
