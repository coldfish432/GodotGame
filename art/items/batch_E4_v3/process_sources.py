"""Reduce individually painted E4 sources, clean native pixels and package them.

Sources were painted with built-in image_gen. Geometry comes from those PNGs;
value grading and effect-line cleanup operate on the native pixel grid.
"""
from __future__ import annotations

import json
import shutil
import sys
sys.dont_write_bytecode=True
from collections import Counter
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
BASE = ROOT.parent/'batch_E4_v2'
ACCEPTED = {'frozen_relic','lord_blade','twin_fang','ember_fang','moon_edge','vein_core','bash_shield'}
RAMPS = {
    'outline': ['#0b0c0d'],
    'steel': ['#2a2d33', '#4a5058', '#7d868e', '#b4bec4', '#eef3f5'],
    'leather': ['#2e2018', '#5a3d2a', '#86603f', '#b48a5e'],
    'rust': ['#4a2a1d', '#7d4529', '#b06a3a', '#d99560'],
    'canvas': ['#5a4d3a', '#857555', '#b3a27c', '#d6c8a2'],
    'originium': ['#b85a12', '#ee8a24', '#ffb35a', '#ffe0a8'],
    'navy': ['#141f30', '#24395a', '#3d6088', '#6f9cc6', '#b5d2ea'],
    'vermilion': ['#6e1616', '#a82a22', '#d9483a', '#f07a62'],
    'brass': ['#6e5220', '#a8822e', '#dcb85a'],
    'wood': ['#3f2a1a', '#6b4a2e', '#9a7048'],
    'bone': ['#8e8470', '#b9ae95', '#e6dfcc', '#fbf8ee'],
    'ice': ['#3d6a8a', '#5d8fb0', '#9cc8e0', '#e4f4fb'],
}
COLORS = {name: [tuple(bytes.fromhex(c[1:])) for c in ramp] for name, ramp in RAMPS.items()}
OUTLINE = COLORS['outline'][0]
BACKGROUNDS = ('#2c2e30', '#142538', '#352710', '#381b0f')
# id, Chinese name, kind, region, native size, fit size, rotation
ITEMS = [
    ('raw_originium', '未封装源石原矿', 'trinket', 'mine', (32,72), (28,68), 0),
    ('riot_shield', '近卫局暴动盾', 'armor', 'lungmen', (72,72), (50,66), 0),
    ('frozen_relic', '冻土下的旧物', 'weapon', 'sami', (72,32), (70,26), 0),
    ('lord_blade', '领主宽刃', 'weapon', 'lungmen', (72,32), (70,30), 0),
    ('twin_fang', '双生狼牙', 'weapon', 'sami', (72,32), (70,29), 0),
    ('ember_fang', '余烬之牙', 'weapon', 'sami', (72,32), (70,27), 0),
    ('moon_edge', '月下刃', 'weapon', 'sami', (72,32), (70,20), 12),
    ('crystal_edge', '源石结晶刃', 'weapon', 'mine', (72,32), (70,26), 0),
    ('vein_core', '共振矿芯', 'trinket', 'mine', (32,32), (30,25), 0),
    ('shadow_bracer', '残影护腕', 'trinket', 'lungmen', (32,32), (22,30), 0),
    ('spike_plate', '尖刺重铠', 'armor', 'mine', (72,72), (68,66), 0),
    ('bash_shield', '反击塔盾', 'armor', 'lungmen', (72,72), (38,68), 0),
]
EMIT_IDS = {'raw_originium','twin_fang','ember_fang','moon_edge','crystal_edge','vein_core'}
PROTOTYPES = {
    'raw_originium': ['https://prts.wiki/w/源石碎片','https://prts.wiki/w/至纯源石'],
    'riot_shield': ['https://en.wikipedia.org/wiki/Riot_shield'],
    'frozen_relic': ['https://en.wikipedia.org/wiki/Bone_carving'],
    'lord_blade': ['https://en.wikipedia.org/wiki/Zhanmadao', "https://en.wikipedia.org/wiki/Chinese_chef%27s_knife"],
    'twin_fang': ['https://en.wikipedia.org/wiki/Butterfly_sword'],
    'ember_fang': ['https://en.wikipedia.org/wiki/Kukri'],
    'moon_edge': ['https://en.wikipedia.org/wiki/Miao_dao'],
    'crystal_edge': ['https://en.wikipedia.org/wiki/Kindjal','https://prts.wiki/w/源石碎片','https://prts.wiki/w/至纯源石'],
    'vein_core': ['https://en.wikipedia.org/wiki/Crystal_habit'],
    'shadow_bracer': ['https://en.wikipedia.org/wiki/Bracer'],
    'spike_plate': ['https://en.wikipedia.org/wiki/Breastplate'],
    'bash_shield': ['https://en.wikipedia.org/wiki/Shield_boss'],
}


def luminance(c):
    return .2126*c[0] + .7152*c[1] + .0722*c[2]


def distance(a,b):
    return 2*(a[0]-b[0])**2 + 4*(a[1]-b[1])**2 + 3*(a[2]-b[2])**2


def material(key,x,y,c):
    r,g,b = c
    warm = r>b+25 and g>b+10 and r>g+5
    orange = warm and r>g+20
    blue = b>r+18 and b>g+4
    if key=='raw_originium': return 'originium' if warm else 'steel'
    if key=='riot_shield': return 'navy' if blue else 'steel'
    if key=='frozen_relic':
        return 'bone' if x>=38 or (r>b+6 and g>b+5) else 'ice'
    if key=='lord_blade':
        if x<33 and warm: return 'vermilion' if r>1.65*g else 'brass'
        return 'steel'
    if key=='twin_fang': return 'bone' if x<25 and r>b+10 else 'steel'
    if key=='ember_fang':
        if x>=27: return 'vermilion' if r>g+30 and r>b+30 else 'steel'
        return 'wood' if warm and luminance(c)<145 else 'bone'
    if key=='moon_edge':
        if x<20: return 'wood' if warm and luminance(c)<145 else 'bone'
        return 'ice' if blue else 'steel'
    if key=='crystal_edge':
        if x>=25 and warm: return 'originium'
        if x<25 and warm: return 'canvas'
        return 'steel'
    if key=='vein_core':
        if ((x-15.5)/7.4)**2+((y-15.5)/7.8)**2<=1 and r>b+15: return 'originium'
        return 'rust' if orange else 'steel'
    if key=='shadow_bracer': return 'navy' if blue or x>=22 else 'steel'
    if key=='spike_plate':
        if warm:
            return 'rust' if r>1.4*g else 'canvas'
        return 'steel'
    if key=='bash_shield':
        if warm: return 'vermilion' if r>1.65*g else 'brass'
        return 'navy' if blue else 'steel'
    raise ValueError(key)


def reduced_source(item):
    key,_,_,_,size,fit,rotation = item
    src = Image.open(ROOT/'sources'/f'{key}_source.png').convert('RGBA')
    # Remove generated semitransparent halo before determining the object bounds.
    src.putalpha(src.getchannel('A').point(lambda a:255 if a>=128 else 0))
    if rotation:
        src = src.rotate(rotation,Image.Resampling.BICUBIC,expand=True)
    src = src.crop(src.getchannel('A').getbbox())
    reduced = src.resize(fit,Image.Resampling.LANCZOS)
    out = Image.new('RGBA',size)
    out.paste(reduced,((size[0]-fit[0])//2,(size[1]-fit[1])//2))
    return out


def singleton_cleanup(icon,source,groups,protected,merge_frame=False):
    for _ in range(5):
        px=icon.load(); target=icon.copy(); dst=target.load();changes=0
        for y in range(icon.height):
            for x in range(icon.width):
                cur=px[x,y]
                if not cur[3] or (x,y) in protected: continue
                neighbors=[(nx,ny) for nx,ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1))
                           if 0<=nx<icon.width and 0<=ny<icon.height]
                if len(neighbors)!=4 or any(not px[n][3] for n in neighbors): continue
                if any(px[n]==cur for n in neighbors): continue
                group=groups.get((x,y))
                options=Counter(px[n] for n in neighbors
                                if (groups.get(n)==group or (merge_frame and group in {'steel','rust'}
                                    and groups.get(n) in {'steel','rust'})) and n not in protected)
                if not options: continue
                choice=min(options,key=lambda c:distance(source.getpixel((x,y))[:3],c[:3])-900*options[c])
                if choice!=cur: dst[x,y]=choice;changes+=1
        icon=target
        if not changes:break
    return icon


def alpha_components(icon):
    remaining={(x,y) for y in range(icon.height) for x in range(icon.width)
               if icon.getpixel((x,y))[3]}
    result=[]
    while remaining:
        seed=remaining.pop();component={seed};queue=[seed]
        while queue:
            x,y=queue.pop()
            for dx in (-1,0,1):
                for dy in (-1,0,1):
                    p=x+dx,y+dy
                    if p in remaining:
                        remaining.remove(p);component.add(p);queue.append(p)
        result.append(component)
    return sorted(result,key=len,reverse=True)


def quantize(source,key):
    out=Image.new('RGBA',source.size);dst=out.load();src=source.load()
    groups={};protected=set();effects=set()
    for y in range(source.height):
        for x in range(source.width):
            r,g,b,a=src[x,y]
            if a<128:continue
            group=material(key,x,y,(r,g,b));groups[x,y]=group
            ramp=COLORS[group]
            if key=='shadow_bracer' and x>=22:ramp=COLORS['navy'][:2]
            c=min(ramp,key=lambda c:distance(c,(r,g,b)))
            if max(r,g,b)<30:c=OUTLINE
            if key=='ember_fang' and x>=27 and group=='vermilion':
                if r>205 and g>145:c=COLORS['bone'][3]  # warm ivory fire core, no originium orange
                effects.add((x,y));protected.add((x,y))
            if group=='originium' and key!='vein_core': protected.add((x,y))
            dst[x,y]=(*c,255)
    # Recover broad painted value planes when several source values quantize to
    # one swatch. Rank by source value within the same physical material only.
    for group in set(groups.values()):
        if group in {'vermilion','brass','wood'} or (group=='originium' and key!='vein_core'):continue
        coords=[p for p,g in groups.items() if g==group and (p not in protected or key=='vein_core')
                and dst[p][:3]!=OUTLINE and not(key=='shadow_bracer' and p[0]>=22)]
        if not coords:continue
        cnt=Counter(dst[p][:3] for p in coords)
        if (max(cnt.values())>len(groups)*.24
                or (group=='steel' and key in {'spike_plate','lord_blade','twin_fang','ember_fang','shadow_bracer'})
                or (key=='shadow_bracer' and group=='navy')
                or (key=='vein_core' and group=='originium')):
            coords.sort(key=lambda p:(luminance(src[p][:3]),-(p[0]+p[1])))
            ramp=COLORS[group]
            for i,p in enumerate(coords):
                c=ramp[min(len(ramp)-1,len(ramp)*i//len(coords))]
                dst[p]=(*c,255)
    out=singleton_cleanup(out,source,groups,protected,merge_frame=key=='vein_core')
    dst=out.load();a=out.getchannel('A').load()
    for x,y in groups:
        n=[(x-1,y),(x+1,y),(x,y-1),(x,y+1)]
        edge=any(nx<0 or ny<0 or nx>=out.width or ny>=out.height or not a[nx,ny] for nx,ny in n)
        if not edge or (x,y) in protected:continue
        top=y==0 or not a[x,y-1]
        if top:
            group=groups[x,y]
            if key=='shadow_bracer' and x>=22:continue
            ramp=COLORS[group]
            if luminance(dst[x,y][:3])<100:
                dst[x,y]=(*ramp[len(ramp)//2],255)
            continue
        left=x==0 or not a[x-1,y]
        if left and luminance(src[x,y][:3])>=105:continue
        dst[x,y]=(*OUTLINE,255)
    emit=Image.new('RGBA',out.size);ep=emit.load()
    if key=='raw_originium':
        effects={p for p,g in groups.items() if g=='originium' and dst[p][:3] in COLORS['originium'][2:]}
    elif key in {'crystal_edge','vein_core'}:
        effects={p for p,g in groups.items() if g=='originium' and dst[p][:3] in COLORS['originium']}
    elif key=='twin_fang':
        # Select the painted white tip on each separate sword component.
        swords=alpha_components(out)
        assert len(swords)==2, 'paired swords must remain separate'
        for coords in swords:
            tipx=max(p[0] for p in coords)
            for x in range(tipx-2,tipx+1):
                at=[p for p in coords if p[0]==x]
                if at:
                    p=min(at,key=lambda p:p[1]);dst[p]=(*COLORS['ice'][3],255);effects.add(p)
    elif key=='moon_edge':
        # The painted full-length edge is restored to one uninterrupted native
        # path where downsampling removed an occasional white pixel.
        previous_y=None
        for x in range(20,out.width):
            ys=[y for y in range(out.height) if a[x,y]]
            if ys:
                y=max(ys)-1 if len(ys)>1 else max(ys)
                bridge=range(min(y,previous_y),max(y,previous_y)+1) if previous_y is not None else [y]
                for by in bridge:
                    if a[x,by]:
                        dst[x,by]=(*COLORS['ice'][3],255);effects.add((x,by))
                previous_y=y
    if key=='vein_core':
        # Trace the six painted side arcs into continuous solid native strokes,
        # with a clear gap between the cage and each stroke.
        for component in alpha_components(out)[1:]:
            for p in component:dst[p]=(0,0,0,0)
        arcs=[[(2,10),(2,11),(1,11),(1,12)],
              [(1,14),(1,15),(1,16)],
              [(1,18),(1,19),(2,19),(2,20)],
              [(29,10),(29,11),(30,11),(30,12)],
              [(30,14),(30,15),(30,16)],
              [(30,18),(30,19),(29,19),(29,20)]]
        for path in arcs:
            for p in path:dst[p]=(*COLORS['steel'][3],255)
    for p in effects:
        if dst[p][3]:ep[p]=dst[p]
    return out,emit


def metrics(icon):
    px=icon.load();opaque=[p[:3] for p in icon.getdata() if p[3]]
    isolated=interior_isolated=interior=0
    for y in range(icon.height):
        for x in range(icon.width):
            if not px[x,y][3]:continue
            neighbors=[(nx,ny) for nx,ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1))
                       if 0<=nx<icon.width and 0<=ny<icon.height]
            single=not any(px[n]==px[x,y] for n in neighbors)
            isolated+=single
            if len(neighbors)==4 and all(px[n][3] for n in neighbors):
                interior+=1;interior_isolated+=single
    n=len(opaque)
    return {'color_count':len(set(opaque)),
            'isolated_pixel_percent':round(100*isolated/n,2),
            'interior_isolated_pixel_percent':round(100*interior_isolated/max(1,interior),2),
            'bright_pixel_percent':round(100*sum(luminance(c)>=153 for c in opaque)/n,2),
            'largest_color_percent':round(100*max(Counter(opaque).values())/n,2)}


def contact():
    heights=[90 if item[4][1]==72 else 50 for item in ITEMS]
    sheet=Image.new('RGB',(586,sum(heights)+30),'#20242b');d=ImageDraw.Draw(sheet)
    d.text((5,6),'E4 v3 / 1x / common, fine, rare, special',fill='#eef3f5')
    y=30
    for item,height in zip(ITEMS,heights):
        key=item[0];icon=Image.open(ROOT/f'{key}.png').convert('RGBA')
        cw=80 if icon.width==72 else 40;ch=80 if icon.height==72 else 40
        d.text((5,y+3),key,fill='#eef3f5')
        for j,bg in enumerate(BACKGROUNDS):
            x=154+j*106
            d.rectangle((x,y,x+cw-1,y+ch-1),fill=bg,outline='#7d868e')
            if cw==80:d.line((x+40,y+1,x+40,y+ch-2),fill='#34404c')
            if ch==80:d.line((x+1,y+40,x+cw-2,y+40),fill='#34404c')
            sheet.paste(icon,(x+(cw-icon.width)//2,y+(ch-icon.height)//2),icon)
        y+=height
    sheet.save(ROOT/'contact_sheet.png')
    sheet.resize((sheet.width*2,sheet.height*2),Image.Resampling.NEAREST).save(ROOT/'contact_sheet_2x.png')
    heights=[152 if i[4][1]==72 else 72 for i in ITEMS]
    sheet=Image.new('RGB',(310,sum(heights)+16),'#d9d6cc');d=ImageDraw.Draw(sheet);y=8
    for item,height in zip(ITEMS,heights):
        icon=Image.open(ROOT/f'{item[0]}.png').convert('RGBA')
        black=Image.new('RGBA',icon.size,(*OUTLINE,255));black.putalpha(icon.getchannel('A'))
        black=black.resize((icon.width*2,icon.height*2),Image.Resampling.NEAREST)
        sheet.paste(black,(4,y+(height-black.height)//2),black)
        d.text((154,y+height//2-4),item[0],fill='#0b0c0d');y+=height
    sheet.save(ROOT/'silhouette_check.png')


def main():
    from revise_native import revise, DETAILS
    rows=[]
    for item in ITEMS:
        key,name,kind,region,size,_,_=item
        if key in ACCEPTED:
            for file in (f'{key}.png',f'{key}_8x.png',f'sources/{key}_source.png'):
                shutil.copyfile(BASE/file,ROOT/file)
            if key in EMIT_IDS:shutil.copyfile(BASE/f'{key}_emit.png',ROOT/f'{key}_emit.png')
            icon=Image.open(ROOT/f'{key}.png').convert('RGBA')
            emit=Image.open(ROOT/f'{key}_emit.png').convert('RGBA') if key in EMIT_IDS else Image.new('RGBA',size)
        else:
            icon,emit=revise(item)
            icon.save(ROOT/f'{key}.png')
            icon.resize((size[0]*8,size[1]*8),Image.Resampling.NEAREST).save(ROOT/f'{key}_8x.png')
        has_emit=key in EMIT_IDS
        if has_emit and key not in ACCEPTED:emit.save(ROOT/f'{key}_emit.png')
        rows.append({'id':key,'name':name,'kind':kind,'region':region,
                     'category':'regional_exclusive' if key in {'raw_originium','riot_shield','frozen_relic'} else 'special',
                     'file':f'{key}.png','preview':f'{key}_8x.png','native_size':list(size),
                     'has_emit':has_emit,'emit_file':f'{key}_emit.png' if has_emit else None,
                     'emit_pixel_count':sum(bool(p[3]) for p in emit.getdata()) if has_emit else 0,
                     'source':f'sources/{key}_source.png','prototype_urls':PROTOTYPES[key],
                     'revision':{'status':'copied unchanged from v2'} if key in ACCEPTED else DETAILS[key],**metrics(icon)})
    contact()
    (ROOT/'manifest.json').write_text(json.dumps({
        'batch':'E4','version':3,'source_brief':'../E4_brief_v1.md','revision_brief':'../E4_revision_v3.md',
        'reference_board':'../E_reference_board.md','display_scale':1,'preview_scale':8,
        'palette':RAMPS,'slot_backgrounds':list(BACKGROUNDS),
        'contact_sheet':'contact_sheet.png','contact_sheet_2x':'contact_sheet_2x.png',
        'generator_metadata':'generation_metadata.json','reference_provenance':'references/provenance.json',
        'processing_scripts':['process_sources.py','revise_native.py'],'validation_script':'validate_batch.py',
        'silhouette_check':'silhouette_check.png','generation_prompts':'generation_prompts.md',
        'isolated_pixel_definition':'Opaque pixels with no equal RGBA orthogonal neighbor / all opaque pixels',
        'interior_isolated_pixel_definition':'Same test restricted to pixels with four opaque orthogonal neighbors; checks broad areas separately from thin contours and effects',
        'items':rows},ensure_ascii=False,indent=2),encoding='utf-8')
    for row in rows:print(row['id'],{k:row[k] for k in ('color_count','bright_pixel_percent','largest_color_percent','isolated_pixel_percent','emit_pixel_count')})


if __name__=='__main__': main()
