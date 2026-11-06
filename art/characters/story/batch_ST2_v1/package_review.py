from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,shutil,hashlib,zipfile
p=Path(r'D:\策划测试题\ST2_v1')
rec=json.loads((p/'generation_records.json').read_text(encoding='utf8'))
for n in ['originals','paintings','comparisons']:(p/n).mkdir(exist_ok=True)
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',24)
small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
overview=Image.new('RGB',(2000,1640),'#b5bdc8');qa=[]
for i,a in enumerate(rec['assets']):
 n=a['id'];original=p/'originals'/f'op_{n}_painting_source.png';shutil.copy2(a['source'],original)
 im=Image.open(original).convert('RGBA');im=im.resize((round(im.width*1024/im.height),1024),Image.Resampling.LANCZOS)
 dest=p/'paintings'/f'op_{n}_painting_1024.png';im.save(dest)
 av=Image.open(p/'input/refs/prts'/f'{n}_avatar.png').convert('RGBA');av.thumbnail((250,250))
 board=Image.new('RGB',(1050,1120),'#b5bdc8');d=ImageDraw.Draw(board);d.text((25,15),n.upper()+' | ST2a painting review',font=font,fill='#151c28');board.paste(im,(10,70),im);board.paste(av,(750,100),av);d.text((740,65),'PRTS avatar',font=small,fill='#151c28')
 face=im.crop((0,0,im.width,round(im.height*.28)));face.thumbnail((320,350));board.paste(face,(710,430),face);d.text((740,395),'Painting detail',font=small,fill='#151c28')
 if n=='raidian':d.text((710,900),'Liberi / cable + plug',font=small,fill='#151c28')
 board.save(p/'comparisons'/f'{n}_vs_prts.png')
 tile=im.copy();tile.thumbnail((470,740));x=i%4*500;y=i//4*820;overview.paste(tile,(x+(500-tile.width)//2,y+50),tile);ImageDraw.Draw(overview).text((x+20,y+15),n.upper(),font=font,fill='#151c28')
 alpha=im.getchannel('A');lo,hi=alpha.getextrema();qa.append({'id':n,'file':str(dest.relative_to(p)),'size':list(im.size),'mode':im.mode,'alpha_range':[lo,hi],'transparent_pixels':alpha.histogram()[0],'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'height_1024':im.height==1024,'has_transparency':lo==0 and hi>0})
overview.save(p/'ST2a_overview.jpg',quality=94)
(p/'qa_report.json').write_text(json.dumps({'stage':'ST2a step 1 review','assets':qa,'visual_acceptance':'pending user review; static checks do not prove likeness or strict one-shadow-step compliance','not_produced':['120x240 pixel portraits','CR4 walk and idle sheets','optional injured idle'],'raidian_correction':'Liberi; no rear-head flowers; trailing electrical cable and plug; feather tufts; two mechanical arms'},ensure_ascii=False,indent=2),encoding='utf8')
(p/'README.md').write_text('''# ST2a v2 立绘审阅包

8 人立绘初稿，由内置 image_gen 绘制。paintings/ 为 1024 像素高透明 PNG；originals/ 为未缩放生成原图；comparisons/ 为逐人 PRTS 头像对照；ST2a_overview.jpg 为八人总览。脚本仅做尺寸转换、拼版、检查和打包。

电弧已按用户纠正：黎博利；移除后脑红白装饰，身后补上电线和末端插头，无毛尾；头顶黑色羽饰，两条粉黑机械臂。Pith 已另行修正朝右。错误旧稿不包含在交付包内。

generation_records.json 保存完整提示词与修正提示词，修正内容优先于原始提示。前七人参考来自用户提供的 ST2_v1.zip；电弧参考来源：
- https://prts.wiki/w/Raidian
- https://prts.wiki/w/文件:立绘_电弧_1.png
- https://prts.wiki/w/文件:头像_电弧.png

qa_report.json 仅检查文件尺寸、透明通道和哈希，不代表美术验收或 Godot 运行验证。部分衣褶与金属细节较多，严格单阶阴影、人物比例和辨识度仍待审阅。

当前停在简报 ST2a Step 1，原文：Send all eight paintings for review before any pixel work。
本包不包含 120×240 像素版、电弧 CR4 行走/待机表或可选受伤待机。八张立绘审阅通过后继续后续阶段。
''',encoding='utf8')
archive=p.parent/'ST2a_v2_review.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
 for folder in ['paintings','originals','comparisons']:
  for f in sorted((p/folder).glob('*')):z.write(f,f.relative_to(p))
 for n in ['README.md','generation_records.json','qa_report.json','ST2a_overview.jpg']:z.write(p/n,n)
 z.write(p/'input/ST2_brief_v1.md','ST2_brief_v1.md')
 for a in rec['assets']:
  f=p/'input/refs/prts'/(a['id']+'_avatar.png');z.write(f,'refs/prts/'+f.name)
with zipfile.ZipFile(archive) as z:assert z.testzip() is None
assert len(qa)==8 and all(a['height_1024'] and a['has_transparency'] for a in qa)
print(json.dumps({'archive':str(archive),'assets':len(qa),'static_checks':'passed','zip_crc':'passed'},ensure_ascii=False))
