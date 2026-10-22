"""Assemble existing painted R1/R4 art and native pixel UI geometry. No AI generation.
Run from any directory; only writes this batch and its 36 named delivery files.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import hashlib, json, math, shutil, zipfile

B = Path(__file__).resolve().parent
UI = B.parent
NEAR = Image.Resampling.NEAREST
WHITE = '#ffffff'
GRAY = '#9aa2a8'
files = []
FIXED = B/'feedback/fixed'
FIXED_HASHES = json.loads((B/'feedback/fixed_sha256.json').read_text(encoding='utf-8'))
for name, digest in FIXED_HASHES.items():
    if hashlib.sha256((FIXED/name).read_bytes()).hexdigest() != digest:
        raise ValueError(f'Authoritative reviewed source changed: {name}')

def canvas(w, h): return Image.new('RGBA', (w, h))

def save(im, folder, name, margin=0, **meta):
    dest = UI / folder / (name + '.png')
    dest.parent.mkdir(exist_ok=True)
    # The six accepted Claude touchups are authoritative. Copy exact source bytes
    # during every rebuild, before any generated predecessor can reach delivery.
    if dest.name in FIXED_HASHES:
        shutil.copyfile(FIXED/dest.name, dest)
        meta['reviewed_override']='feedback/fixed/'+dest.name
    else:
        im.save(dest)
    files.append(dict(file=f'{folder}/{name}.png', size=list(im.size),
                      nine_patch_margin=margin, **meta))

def shape(w, h, c, both=False, inset=0):
    x,y,r,b = inset,inset,w-1-inset,h-1-inset
    return [(x+c,y),(r,y),(r,b-c),(r-c,b),(x,b),(x,y+c)] if both else [(x,y),(r,y),(r,b-c),(r-c,b),(x,b)]

def plate(w,h,c,both=False,mode='normal',rivets=False):
    im=canvas(w,h); d=ImageDraw.Draw(im)
    colors = {'normal':('#2a2f33','#7d868d','#1a1e22'),
              'hover':('#3a4046','#6fd8e4','#1f5f70'),
              'press':('#1a1e22','#3a4046','#6a737a'),
              'disabled':('#2a2f33','#4a5258','#1a1e22'),
              'go':('#0098dc','#9cecff','#2c5880')}
    fill,hi,lo=colors[mode]
    d.polygon(shape(w,h,c,both),fill=fill)
    # Reuse accepted painted deck material, preserving nearest-neighbour hard pixels.
    if mode in ('normal','hover'):
        src=Image.open(B/'sources/base_deck.png').convert('RGB')
        palette=['#1a1e22','#2a2f33','#3a4046'] if mode=='normal' else ['#2a2f33','#3a4046','#4a5258']
        for y in range(3,h-3):
            for x in range(3,w-3):
                if im.getpixel((x,y))[3]:
                    v=sum(src.getpixel(((x+41)%src.width,(y+37)%src.height)))/3
                    d.point((x,y),fill=palette[0 if v<43 else 1 if v<88 else 2])
    d.line(shape(w,h,c,both)+[shape(w,h,c,both)[0]],fill=lo,width=2)
    if both:
        d.line([(0,h-2),(0,c),(c,0),(w-2,0)],fill=hi,width=1)
    else:
        d.line([(0,h-2),(0,0),(w-2,0)],fill=hi,width=1)
    d.line([(3,3 if not both else c+2),(3,h-5)],fill='#3a4046')
    if rivets:
        for x,y in [(13,13),(w-9,8),(8,h-9),(w-14,h-14)]:
            d.rectangle((x-2,y-2,x+2,y+2),fill='#1a1e22')
            d.rectangle((x-1,y-1,x+1,y+1),fill='#5c656b')
            d.point((x-1,y-1),fill='#b8c0c4')
            d.line((x-1,y+1,x+1,y-1),fill='#2a2f33')
    return im

save(plate(96,96,12,True,rivets=True),'kit','panel_plate',16)
glass=plate(96,96,12,True,rivets=True)
ImageDraw.Draw(glass).rectangle((16,16,79,79),fill=(14,42,52,204))
save(glass,'kit','panel_glass',16,alpha_exception='Center rectangle alpha=204/255=0.8; frame opaque.')
header=plate(256,48,12,True)
haz=Image.open(B/'sources/base_hazard.png').convert('RGBA')
header.paste(haz.resize((72,36),NEAR).crop((0,10,72,16)),(16,3))
ImageDraw.Draw(header).line((2,47,241,47),fill='#6fd8e4')
save(header,'kit','header_strip',0,stretch_margins=[32,0,32,0],hazard_rect=[16,3,72,6])
for state in ('normal','hover','press','disabled'):
    save(plate(48,48,7,mode=state),'kit','btn_'+state,10)
save(plate(96,48,12,mode='go'),'kit','btn_go',16)
stripe=canvas(32,48)
for y in range(48):
    for x in range(32):
        if (x+y)%16<5: stripe.putpixel((x,y),(255,255,255,255))
save(stripe,'kit','btn_go_stripes',repeat_x=True,repeat_y=True,runtime_opacity=0.12)
slot=plate(48,48,0,mode='press'); ds=ImageDraw.Draw(slot)
ds.rectangle((5,5,42,42),fill='#1a1e22',outline='#3a4046',width=1)
ds.line((7,5,40,5),fill='#7d868d')
save(slot,'kit','slot_frame',8)
save(plate(48,48,7),'kit','tip_frame',10)

# Rings have exactly the same pivot; keep the original three radii separate.
for kind in ('ticks','dash','arc'):
    im=canvas(256,256); d=ImageDraw.Draw(im)
    def point(r,a): return (round(127.5+r*math.cos(a)),round(127.5+r*math.sin(a)))
    if kind=='ticks':
        for i in range(72):
            a=i*math.tau/72
            d.line([point(112 if i%6==0 else 119,a),point(123,a)],fill=WHITE,width=2 if i%6==0 else 1)
    else:
        r=99 if kind=='dash' else 79
        spans=[(i,i+22) for i in range(0,360,30)] if kind=='dash' else [(7,33),(177,192)]
        for a,b in spans: d.arc((127.5-r,127.5-r,127.5+r,127.5+r),a,b,fill=WHITE,width=2 if kind=='dash' else 3)
    save(im,'kit','holo_ring_'+kind,pivot=[127.5,127.5],tintable=True)

def glyph(kind,size=24,color=WHITE):
    im=canvas(24,24); d=ImageDraw.Draw(im)
    def rect(box): d.rectangle(box,fill=color)
    def poly(points): d.polygon(points,fill=color)
    def line(points,width=2): d.line(points,fill=color,width=width)
    if kind=='head':
        poly([(5,13),(5,9),(7,5),(10,3),(14,3),(17,5),(19,9),(19,15),(5,15)])
        rect((6,17,18,19))
    elif kind=='chest': poly([(3,7),(7,3),(10,5),(14,5),(17,3),(21,7),(18,12),(16,11),(16,21),(8,21),(8,11),(6,12)])
    elif kind=='hands':
        poly([(5,13),(7,13),(7,5),(9,5),(9,12),(10,12),(10,3),(12,3),(12,12),(13,12),(13,4),(15,4),(15,12),(16,12),(16,7),(18,7),(18,16),(15,21),(9,21),(5,17)])
    elif kind=='legs': poly([(6,3),(18,3),(17,21),(13,21),(12,10),(11,21),(7,21)])
    elif kind=='feet': poly([(7,3),(13,3),(13,14),(20,17),(20,21),(5,21),(5,15),(7,14)])
    elif kind=='amulet':
        line([(5,3),(6,9),(9,12),(15,12),(18,9),(19,3)])
        poly([(12,11),(16,16),(12,22),(8,16)])
    elif kind=='ring':
        d.ellipse((5,8,19,22),outline=color,width=3)
        poly([(9,2),(15,2),(18,6),(12,11),(6,6)])
    elif kind=='weapon':
        poly([(11,2),(14,2),(14,15),(12,17),(11,15)])
        rect((7,16,18,18)); rect((11,19,14,22))
    elif kind in ('bag','equipment'):
        d.rectangle((4,8,20,21),outline=color,width=2)
        line([(8,8),(8,3),(16,3),(16,8)]); line([(5,13),(19,13)])
    elif kind in ('operator','person'):
        d.ellipse((8,3,16,11),fill=color)
        poly([(4,21),(5,16),(9,13),(15,13),(19,16),(20,21)])
    elif kind=='box':
        d.rectangle((3,3,20,20),outline=color,width=2); rect((4,11,19,12))
    elif kind=='plus': rect((3,9,20,14)); rect((9,3,14,20))
    elif kind=='arrow':
        rect((3,10,15,13)); poly([(13,4),(21,12),(13,20),(13,15),(17,12),(13,9)])
    elif kind=='flask':
        rect((9,2,15,3)); line([(10,4),(10,10),(4,19),(4,21),(20,21),(20,19),(14,10),(14,4)])
        poly([(8,15),(16,15),(19,20),(5,20)])
    elif kind=='bridge':
        # Base hall uses the Rhodes tower mark; no bridge hanging-sign exists.
        poly([(4,21),(5,9),(8,9),(8,5),(10,5),(10,2),(14,2),(14,5),(16,5),(16,9),(19,9),(20,21)])
        d.rectangle((10,10,13,20),fill=(0,0,0,0))
    elif kind=='relic':
        poly([(12,2),(21,11),(12,22),(3,11)])
        d.polygon([(12,7),(16,11),(12,16),(8,11)],fill=(0,0,0,0))
    elif kind=='map':
        line([(3,6),(8,3),(15,6),(21,3),(21,19),(15,22),(8,19),(3,22),(3,6)])
        line([(8,4),(8,18)]); line([(15,7),(15,21)])
    elif kind=='contract':
        line([(5,2),(15,2),(20,7),(20,21),(5,21),(5,2)])
        line([(15,2),(15,7),(20,7)]); rect((8,11,16,12)); rect((8,15,13,16))
    elif kind=='lmd':
        line([(3,7),(17,3),(21,7),(21,17),(7,21),(3,17),(3,7)])
        line([(4,8),(8,11),(20,7)]); line([(8,11),(8,19)])
        rect((12,11,16,13))
    elif kind=='gold':
        poly([(6,6),(17,6),(22,17),(2,17)])
        d.line([(6,6),(8,13),(20,13)],fill=(0,0,0,0),width=2)
    elif kind=='pollution':
        poly([(12,2),(18,11),(15,21),(8,22),(3,16),(7,9)])
        line([(12,5),(10,13),(13,17),(10,20)],width=2)
        d.line([(13,5),(11,12),(14,16)],fill=(0,0,0,0),width=2)
    else: raise ValueError(kind)
    return im.resize((size,size),NEAR)

for name in ('head','chest','hands','legs','feet','amulet','ring','weapon'):
    save(glyph(name,48,GRAY),'kit','sil_'+name)
for name,kind in dict(bridge='bridge',warehouse='box',logistics='arrow',medical='plus',research='flask',store='bag').items():
    save(glyph(kind),'kit','dept_'+name,tintable=True,base_pictogram=kind)
for name in ('equipment','operator','relic','map','contract','lmd','gold','pollution'):
    save(glyph(name),'icons',name,tintable=True)

for entry in files:
    p=UI/entry['file']; im=Image.open(p)
    entry['sha256']=hashlib.sha256(p.read_bytes()).hexdigest()
    entry['alpha_values']=sorted(set(im.getchannel('A').get_flattened_data()))
manifest=dict(batch='UC_UE_v1',asset_count=len(files),files=files,
              provenance='Existing painted R1/R4 surfaces and native pixel geometry; six authoritative accepted Claude touchups from U_v1_feedback.zip copied byte-for-byte on every rebuild.',
              review=dict(result='Accepted with six touchups',source='feedback/review_claude.md',fixed_sha256=FIXED_HASHES),
              sources=[dict(file='sources/'+n,sha256=hashlib.sha256((B/'sources'/n).read_bytes()).hexdigest()) for n in ('base_deck.png','base_hazard.png')])
(B/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
for folder in ('kit','icons'):
    (UI/folder/'manifest.json').write_text(json.dumps(dict(batch='UC_UE_v1',files=[f for f in files if f['file'].startswith(folder+'/')]),indent=2),encoding='utf-8')

# Labelled review sheet; labels never enter delivered PNGs.
sheet=Image.new('RGB',(1200,math.ceil(len(files)/6)*200),'#10171b'); d=ImageDraw.Draw(sheet)
for i,e in enumerate(files):
    x=(i%6)*200; y=(i//6)*200
    for yy in range(y,y+170,10):
        for xx in range(x,x+196,10):
            d.rectangle((xx,yy,xx+9,yy+9),fill='#202a30' if ((xx-x)//10+(yy-y)//10)%2 else '#182127')
    im=Image.open(UI/e['file']); scale=min(3,160/im.width,152/im.height)
    im=im.resize((round(im.width*scale),round(im.height*scale)),NEAR)
    sheet.paste(im,(x+(196-im.width)//2,y+(168-im.height)//2),im)
    d.text((x+6,y+174),Path(e['file']).stem,fill='#e4eef4')
    d.text((x+6,y+188),' x '.join(map(str,e['size'])),fill='#9aa2a8')
sheet.save(B/'contact_sheet.png')
print(f'Built {len(files)} assets: {B}')
