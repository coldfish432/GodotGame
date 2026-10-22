"""Deterministic assembly of image_gen source paintings; no art drawn by code.
Outputs: 5 opaque backgrounds + 13 native inventory PNGs, review artifacts.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json,hashlib,math,shutil,sys

B=Path(__file__).resolve().parent
ROOT=B.parents[2]
NEAR=Image.Resampling.NEAREST
FONT=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',19)
SM=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',15)
POTIONS={
 'potion_d':('热能饮剂','thermos','#bc5031'), 'potion_e':('镇静合剂','oval_flask','#b084d2'),
 'potion_f':('战术兴奋剂','angular_injector','#e13b48'), 'potion_g':('急行针剂','slim_syringe','#6cd69e'),
 'potion_h':('源石护盾凝胶','squeeze_tube','#3fd2f2'), 'potion_i':('广谱解毒剂','double_ampoule','#47be64'),
 'potion_j':('静默喷剂','black_spray','#a6a7b3'), 'potion_k':('技艺增幅剂','faceted_cartridge','#ac6de2'),
 'potion_l':('应急强心针','yellow_safety_injector','#e8bd32'),
 'potion_rat':('黑市兴奋剂','cork_vial','#be343b'), 'potion_reunion':('自制抑制剂','cloth_stop_bottle','#9fa990'),
 'potion_ursus':('矿工烈酒','round_hip_flask','#b87b3d'), 'potion_sami':('林地草药茶','herb_flask','#8da34e')}
KEYS={'title':('标题：罗德岛陆行舰',(1280,720)), 'load_mine':('切尔诺伯格矿区',(1280,360)),
      'load_city':('龙门下城区',(1280,360)), 'load_snow':('萨米雪原',(1280,360)),
      'load_siracusa':('叙拉古旧城区',(1280,360))}
SELECT={'potion_d':'potion_d_cap'}

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,obj):p.write_text(json.dumps(obj,ensure_ascii=False,indent=2),encoding='utf-8')
def export(im,rel):
    p=B/'delivery'/rel;p.parent.mkdir(parents=True,exist_ok=True);im.save(p);return p
def native_icon(ident):
    src=B/'source_paintings'/(SELECT.get(ident,ident)+'.png')
    im=Image.open(src).convert('RGBA')
    mask=im.getchannel('A').point(lambda v:255 if v>=128 else 0)
    box=mask.getbbox();assert box
    im=im.crop(box);w,h=im.size;s=min(28/w,28/h)
    im=im.resize((max(1,round(w*s)),max(1,round(h*s))),NEAR)
    im.putalpha(im.getchannel('A').point(lambda v:255 if v>=128 else 0))
    tile=Image.new('RGBA',(32,32));tile.paste(im,((32-im.width)//2,(32-im.height)//2))
    a=tile.getchannel('A');tile=tile.convert('RGB').quantize(colors=24,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE).convert('RGBA');tile.putalpha(a)
    return src,tile,box
def key_art(ident,size):
    src=B/'source_paintings'/(ident+'.png');im=Image.open(src).convert('RGB');w,h=im.size
    ratio=size[0]/size[1]
    # Retain original geometry: crop rather than nonuniformly stretch.
    if w/h<ratio:
        nh=round(w/ratio)
        y=0 if ident in ('load_snow','load_siracusa') else (h-nh)//2
        box=(0,y,w,y+nh)
    else:
        nw=round(h*ratio);x=(w-nw)//2;box=(x,0,x+nw,h)
    im=im.crop(box).resize((size[0]//2,size[1]//2),NEAR)
    # One palette operation and an integer 2x scale establish hard native pixels.
    im=im.quantize(colors=128,method=Image.Quantize.MAXCOVERAGE,dither=Image.Dither.NONE).convert('RGB')
    brightness=1.0 if ident=='title' else .72
    if brightness!=1.0:im=im.point([round(v*brightness) for v in range(256)]*3)
    return src,im.resize(size,NEAR),box,brightness

(B/'previews').mkdir(exist_ok=True)
records=[]
for ident,(name,shape,color) in POTIONS.items():
    src,im,box=native_icon(ident);rel=f'art/items/runtime/{ident}.png';p=export(im,rel)
    im.resize((256,256),NEAR).save(B/'previews'/(ident+'_8x.png'))
    records.append(dict(id=ident,name=name,kind='UF',file=rel,size=[32,32],sha256=sha(p),
      source=src.relative_to(B).as_posix(),source_sha256=sha(src),source_bbox=list(box),
      packaging='Closure shared magenta label' if ident not in ('potion_rat','potion_reunion','potion_ursus','potion_sami') else 'Regional improvised packaging',
      silhouette=shape,accent=color,process='Alpha>=128, trim alpha bbox, nearest-neighbor fit within 28x28, center on32x32,24-color quantize,no dithering'))
for ident,(name,size) in KEYS.items():
    src,im,box,brightness=key_art(ident,size);rel=f'art/ui/key/{ident}.png';p=export(im,rel)
    records.append(dict(id=ident,name=name,kind='UD',file=rel,size=list(size),sha256=sha(p),
      source=src.relative_to(B).as_posix(),source_sha256=sha(src),source_crop=list(box),
      brightness_multiplier=brightness,process='Aspect-preserving crop,nearest-neighbor logical half size,128-color quantize,no dithering,integer2x upscale'))

# Build review contact sheet including immutable baseline A/B/C.
names=[('potion_a','原有 A：标准急救剂'),('potion_b','原有 B：缓释凝胶'),('potion_c','原有 C：抑制喷剂')]+[(k,v[0]) for k,v in POTIONS.items()]
sheet=Image.new('RGB',(1040,960),'#10171b');d=ImageDraw.Draw(sheet)
for i,(ident,name) in enumerate(names):
    x=(i%4)*260;y=(i//4)*240
    if ident in POTIONS:im=Image.open(B/'delivery/art/items/runtime'/(ident+'.png'))
    else:im=Image.open(ROOT/'art/items/runtime'/(ident+'.png')).convert('RGBA')
    d.text((x+12,y+10),name,font=FONT,fill='#edf2f4')
    d.text((x+12,y+37),ident,font=SM,fill='#9aa2a8')
    large=im.resize((128,128),NEAR);sheet.paste(large,(x+64,y+64),large)
    for j,bg in enumerate(('#0e1215','#162a3b','#382b15')):
        tile=Image.new('RGBA',(40,40),bg);tile.alpha_composite(im,(4,4));td=ImageDraw.Draw(tile)
        td.rectangle((27,27,39,39),fill='black');td.text((30,27),'5',fill='white')
        sheet.paste(tile.convert('RGB'),(x+42+j*58,y+196))
sheet.save(B/'previews/UF_contact.png')

ud=Image.new('RGB',(1280,720+4*400),'#10171b');d=ImageDraw.Draw(ud)
for i,(ident,(name,size)) in enumerate(KEYS.items()):
    y=0 if i==0 else 720+(i-1)*400
    im=Image.open(B/'delivery/art/ui/key'/(ident+'.png'));ud.paste(im,(0,y))
    if i:d.text((12,y+364),name+' · '+ident,font=FONT,fill='#edf2f4')
ud.save(B/'previews/UD_contact.png')
title=Image.open(B/'delivery/art/ui/key/title.png').convert('RGBA');d=ImageDraw.Draw(title)
d.rectangle((32,160,392,500),outline='#d8a520',width=2);d.text((48,176),'左侧标题预留',font=FONT,fill='white')
d.rectangle((978,100,1262,610),outline='#3fd2f2',width=2);d.text((990,116),'右侧全息环预留',font=FONT,fill='white')
title.save(B/'previews/title_safe_areas.png')

manifest=dict(batch='UD_UF_v1',asset_count=18,UD=5,UF=13,files=records,
 method='Built-in image_gen paintings; scripts only deterministic crop,resize,palette/alpha normalization,previews,hashing and packaging.',
 acceptance='PENDING_ART_REVIEW',runtime_validation='NOT_RUN')
dump(B/'manifest.json',manifest)
for kind in ('UD','UF'):
    dump(B/(kind+'_manifest.json'),dict(batch=kind+'_v1',files=[r for r in records if r['kind']==kind]))

# Publish only new names or byte-identical already generated results.
if '--stage-only' not in sys.argv:
    for r in records:
        src=B/'delivery'/r['file'];dst=ROOT/r['file']
        if dst.exists() and sha(dst)!=r['sha256']:raise RuntimeError(f'Refusing to overwrite different existing asset: {dst}')
    for r in records:
        src=B/'delivery'/r['file'];dst=ROOT/r['file'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
    for filename,folder in [('UD_manifest.json',ROOT/'art/ui/key'),('UF_manifest.json',ROOT/'art/items/runtime')]:
        shutil.copyfile(B/filename,folder/filename)

links=[]
for r in records:
    pix=' class="icon"' if r['kind']=='UF' else ''
    links.append(f'<article><h2>{r["name"]} <small>{r["id"]}</small></h2><a href="delivery/{r["file"]}"><img{pix} src="delivery/{r["file"]}" alt="{r["name"]}"></a><p>{r["size"][0]} × {r["size"][1]}</p></article>')
html='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><title>UD UF v1 审阅</title><style>body{margin:28px;background:#10171b;color:#edf2f4;font:16px system-ui}a{color:#6fd8e4}img{max-width:100%;height:auto;image-rendering:pixelated}.icon{width:256px;background:repeating-conic-gradient(#253039 0 25%,#202a30 0 50%) 0/24px 24px}article{border-top:1px solid #3a4046;margin:28px 0;padding:12px}h2{font-size:20px}small,p{color:#9aa2a8}</style><h1>UD 主视觉 5 张 · UF 药剂 13 张</h1><p>像素画、无文字；仅素材交付，尚未验证 Godot 接入。</p><p><a href="previews/UD_contact.png">主视觉总览</a> · <a href="previews/UF_contact.png">药剂原生及背景/数量标记预览</a> · <a href="previews/title_safe_areas.png">标题预留区</a> · <a href="README.md">交付说明</a></p>'''+''.join(links)+'</html>'
(B/'review.html').write_text(html,encoding='utf-8')
print('Delivered18 PNGs; source art and review artifacts saved:',B)
