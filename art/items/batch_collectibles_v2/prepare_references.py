from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import json,re,html,requests
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).parent
NAMES=list(zip('fang kroos dobermann gummy vigna matterhorn amiya texas lappland ptilopsis blue_poison nearl exusiai silverash chen eyjafjalla skadi kaltsit'.split(),'芬 克洛丝 杜宾 古米 红豆 角峰 阿米娅 德克萨斯 拉普兰德 白面鸮 蓝毒 临光 能天使 银灰 陈 艾雅法拉 斯卡蒂 凯尔希'.split()))
def fetch(pair):
 ident,name=pair
 page='https://prts.wiki/w/文件:立绘_'+name+'_1.png'
 r=requests.get(page,timeout=45);r.raise_for_status()
 m=re.search(r'class="fullImageLink".*?<a href="([^"]+)"',r.text,re.S)
 if not m: raise RuntimeError('No original '+name)
 url=html.unescape(m[1])
 if url.startswith('//'):url='https:'+url
 data=requests.get(url,timeout=60);data.raise_for_status()
 path=ROOT/'references'/('fig_'+ident+'_prts_e0.png');path.write_bytes(data.content)
 with Image.open(path) as im:im.verify()
 return dict(id='fig_'+ident,name=name,page=page,image=url,file=str(path.relative_to(ROOT)))
rows=list(ThreadPoolExecutor(max_workers=6).map(fetch,NAMES))
(ROOT/'references.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',22)
for group in range(3):
 sheet=Image.new('RGB',(1800,660),'#e6e9ed');d=ImageDraw.Draw(sheet)
 for col,row in enumerate(rows[group*6:group*6+6]):
  im=Image.open(ROOT/row['file']).convert('RGBA');im=im.crop(im.getbbox());im.thumbnail((286,560))
  sheet.paste(im,(col*300+(300-im.width)//2,30+(560-im.height)//2),im)
  d.text((col*300+10,600),row['name']+' / '+row['id'],font=font,fill='#111111')
 sheet.save(ROOT/'references'/f'prts_e0_group_{group+1}.jpg')
print('Fetched and verified 18 PRTS E0 originals.')
