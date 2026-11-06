from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,shutil,hashlib,zipfile
p=Path(r'D:\策划测试题\batch_CR4_v1');rec=json.loads((p/'idle_generation_records.json').read_text());src=p/'raw/idle_generated.png';shutil.copy2(rec['source'],src);im=Image.open(src).convert('RGBA');out=Image.new('RGBA',(512,2048));dirs=['S','SW','W','NW','N','NE','E','SE'];qa=[]
walkhash=hashlib.sha256((p/'raidian_walk_source.png').read_bytes()).hexdigest()
for row,d in enumerate(dirs):
 sr=row//2;sc=(row%2)*2;cells=[]
 for j in range(2):
  cell=im.crop((round((sc+j)*im.width/4),round(sr*im.height/4),round((sc+j+1)*im.width/4),round((sr+1)*im.height/4)))
  box=cell.getchannel('A').point(lambda x:255 if x>12 else 0).getbbox();cells.append(cell.crop(box))
 scale=min(210/cells[0].height,216/max(c.width for c in cells));normal=Image.new('RGBA',(256,256));breath=Image.new('RGBA',(256,256));top=240-round(cells[0].height*scale)
 for j,cell in enumerate(cells):
  cell=cell.resize((round(cell.width*scale),round(cell.height*scale)),Image.Resampling.LANCZOS)
  hb=cell.getchannel('A').crop((0,0,cell.width,round(cell.height*.45))).point(lambda x:255 if x>12 else 0).getbbox();cx=(hb[0]+hb[2])/2;x=max(12,min(round(128-cx),244-cell.width));y=top+(8 if j else 0)
  (breath if j else normal).paste(cell,(x,y))
 # Technical invariant from CR brief: knees and all pixels below remain unchanged.
 knee_y=198;breath.paste(normal.crop((0,knee_y,256,256)),(0,knee_y))
 assert normal.crop((0,knee_y,256,256)).tobytes()==breath.crop((0,knee_y,256,256)).tobytes()
 for j,cell in enumerate([normal,breath]):out.paste(cell,(j*256,row*256))
 normal_top=normal.getchannel('A').point(lambda x:255 if x>12 else 0).getbbox()[1];breath_top=breath.getchannel('A').point(lambda x:255 if x>12 else 0).getbbox()[1]
 qa.append({'direction':d,'knee_y':knee_y,'identical_below_knees':True,'head_top_delta_px':breath_top-normal_top,'feet_baseline':240,'body_center':128})
out.save(p/'raidian_idle_source.png');small=out.resize((64,256),Image.Resampling.LANCZOS);small.save(p/'raidian_idle_32.png');small.crop((0,0,32,32)).save(p/'preview_32.png')
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18);board=Image.new('RGB',(640,2112),'#b5bdc8');board.paste(out,(100,32),out);draw=ImageDraw.Draw(board)
for row,d in enumerate(dirs):draw.text((10,row*256+145),d,font=font,fill='#152030')
board.save(p/'idle_grid_preview.jpg',quality=94)
frames=[]
for col in range(2):
 frame=Image.new('RGB',(1024,560),'#b5bdc8');dr=ImageDraw.Draw(frame)
 for row,d in enumerate(dirs):
  cell=out.crop((col*256,row*256,(col+1)*256,(row+1)*256));x=row%4*256;y=row//4*280;frame.paste(cell,(x,y+20),cell);dr.text((x+8,y+3),d,font=font,fill='#152030')
 frames.append(frame)
frames[0].save(p/'idle_preview.gif',save_all=True,append_images=frames[1:],duration=[700,700],loop=0,optimize=False)
av=Image.open(r'D:\策划测试题\ST2_v1\input\refs\prts\raidian_avatar.png').convert('RGBA');comp=Image.new('RGB',(600,300),'#b5bdc8');comp.paste(av,(30,50),av);s=small.crop((0,0,32,32)).resize((192,192),Image.Resampling.NEAREST);comp.paste(s,(340,50),s);ImageDraw.Draw(comp).text((20,15),'PRTS avatar           S idle at 32px (6x nearest)',font=font,fill='#152030');comp.save(p/'raidian_idle_vs_prts_32.png')
manifest=json.loads((p/'manifest.json').read_text());manifest['sheets']=[s for s in manifest['sheets'] if s['kind']!='idle'];manifest['sheets'].append({'id':'raidian','kind':'idle','file':'raidian_idle_source.png','cols':2,'rows':8,'cell':256});(p/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
for row in range(8):
 for col in range(2):
  a=out.crop((col*256,row*256,(col+1)*256,(row+1)*256)).getchannel('A')
  assert max(a.crop((0,0,256,8)).getextrema()[1],a.crop((0,248,256,256)).getextrema()[1],a.crop((0,0,8,256)).getextrema()[1],a.crop((248,0,256,256)).getextrema()[1])==0
assert hashlib.sha256((p/'raidian_walk_source.png').read_bytes()).hexdigest()==walkhash
report={'size':list(out.size),'cell':256,'frames':16,'rows':dirs,'checks':qa,'clear_8px_cell_borders':True,'walk_unchanged_sha256':walkhash,'runtime_tested':False,'assembly':'Generated standing and breath poses; same per-direction scale, head centred x128, normal sole y240, breath top +8px, original lower knee band composited into breath. No character art drawn by script.'};(p/'idle_qa_report.json').write_text(json.dumps(report,indent=2),encoding='utf8')
(p/'README.md').write_text('''# CR4 电弧行走与站立待机

raidian_walk_source.png：1024×2048，4 列×8 行，每格 256×256，四帧慢走。
raidian_idle_source.png：512×2048，2 列×8 行，每格 256×256，第一列站立，第二列呼吸。
统一行序 S / SW / W / NW / N / NE / E / SE。身体中心 x128，脚底线 y240，与行走表一致。
待机呼吸头肩下沉约 8px；每格 y198 起的膝盖以下区域与首列逐像素一致。

形象沿用用户修正：黎博利黑色羽饰，无后脑红白装饰，粉黑双机械臂收拢，电线末端带插头，无毛尾。
内置 image_gen 绘制。raw/ 保存生成原图；generation_records.json、idle_generation_records.json 保存完整提示词。脚本仅切格、缩放、定位、拼版、锁定膝下像素、制作预览和检查。
manifest.json 已包含 walk 与 idle。preview_32.png 为 S 站立首帧；32 像素检查表不代替正式下游烘焙。附 PRTS 头像与 32px 站立帧对照。
walk_preview.gif 与 idle_preview.gif 为离线预览。静态尺寸、透明背景、格边留空、膝下像素一致和 ZIP 检查通过，行走表保持原哈希。尚未验证 Godot 导入或游戏内动画播放；美术验收待审阅。
''',encoding='utf8')
archive=p.parent/'CR4_raidian_walk_idle_v1_review.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
 for f in sorted(p.rglob('*')):
  if f.is_file():z.write(f,f.relative_to(p))
with zipfile.ZipFile(archive) as z:assert z.testzip() is None
print(json.dumps({'archive':str(archive),'idle_size':list(out.size),'head_top_deltas':[a['head_top_delta_px'] for a in qa],'identical_lower_legs':True,'walk_unchanged':True,'zip_crc':'passed'},ensure_ascii=False))
