"""V4 source painting reduction and native detail restoration.

Silhouettes come from individually edited imagegen PNGs. Native traces follow
the painted edges; the armor uses the exact accepted mask and pixels outside
the rust repair. No new procedural item silhouettes are constructed.
"""
from collections import deque
from PIL import Image
import process_sources as b

DETAILS={}
def color(s):return (*bytes.fromhex(s[1:]),255)
BLACK=color('#0b0c0d');WHITE=color('#eef3f5')
DARK=[color(s) for s in ['#0b0c0d','#2a2d33','#4a2a1d']]
GLOW=[color(s) for s in ['#b85a12','#ee8a24','#ffb35a']]

def positions(im):return {(x,y) for y in range(im.height) for x in range(im.width) if im.getpixel((x,y))[3]}
def components(coords):
    mask=Image.new('RGBA',(72,72))
    for p in coords:mask.putpixel(p,BLACK)
    return b.alpha_components(mask)
def nearest(c,ramp):return min(ramp,key=lambda q:b.distance(q[:3],c[:3]))
def square(icon,origin):
    ox,oy=origin
    for y in range(3):
        for x in range(3):
            p=ox+x,oy+y;assert icon.getpixel(p)[3],p
            icon.putpixel(p,BLACK if x==y==1 else GLOW[2 if x==0 or y==0 else 1])
def emit_for(icon):
    emit=Image.new('RGBA',icon.size)
    for p in positions(icon):
        if icon.getpixel(p) in GLOW:emit.putpixel(p,icon.getpixel(p))
    return emit
def clean(im,source,protected=()):
    groups={p:'surface' for p in positions(im)}
    return b.singleton_cleanup(im,source,groups,set(protected))

def edge_trace(src,box,limit):
    x0,y0,x1,y1=box
    candidates={(x,y) for y in range(y0,y1+1) for x in range(x0,x1+1)
                if src.getpixel((x,y))[3]>=128 and b.luminance(src.getpixel((x,y))[:3])>80
                and max(src.getpixel((x,y))[:3])-min(src.getpixel((x,y))[:3])<50}
    group=components(candidates)[0]
    start=min(group,key=lambda p:(p[1],-b.luminance(src.getpixel(p)[:3])))
    goal=max(group,key=lambda p:(p[1],b.luminance(src.getpixel(p)[:3])))
    queue=deque([start]);parents={start:None}
    while queue:
        p=queue.popleft()
        if p==goal:break
        for dx,dy in [(0,1),(-1,1),(1,1),(-1,0),(1,0),(0,-1),(-1,-1),(1,-1)]:
            q=p[0]+dx,p[1]+dy
            if q in group and q not in parents:parents[q]=p;queue.append(q)
    path=[];p=goal
    while p is not None:path.append(p);p=parents[p]
    path.reverse()
    return path[:limit]

def raw(item):
    src=b.reduced_source(item);out=Image.new('RGBA',src.size);glows=[]
    for p in positions(src):
        x,y=p;r,g,bl,a=src.getpixel(p)
        if a<128:continue
        if y>=55:
            ramp=[color(s) for s in ['#2a2d33','#4a5058','#5a4d3a']]
        else:ramp=DARK
        c=nearest((r,g,bl),ramp);out.putpixel(p,c)
        # Broad flat material planes, kept contiguous instead of value-ranking
        # individual pixels. Warm central shadow and cool lit host-rock face.
        if y<48 and y>=4 and 14<=x<24 and c==BLACK:out.putpixel(p,DARK[2])
        if y>=55 and x<24 and c==DARK[1]:out.putpixel(p,color('#4a5058'))
        if 12<=x<=22 and 14<=y<=42 and r>bl+40 and g>65 and r>g*1.35:glows.append(p)
    # Each window identifies one of the five painted large shard facets.
    windows=[((7,1,20,18),14),((0,18,12,38),12),((21,24,31,37),8),
             ((0,39,14,54),12),((20,39,31,51),8)]
    paths=[edge_trace(src,box,n) for box,n in windows]
    for path in paths:
        for p in path:out.putpixel(p,WHITE)
    glows.sort(key=lambda p:b.luminance(src.getpixel(p)[:3]),reverse=True)
    # Core plus two short crack sections, all within the biggest central shard.
    cracks=[[(16,y) for y in range(18,25)],[(17,y) for y in range(31,38)]]
    for path in cracks:
        for p in path:
            if out.getpixel(p)[3]:out.putpixel(p,GLOW[1 if p[1]%3 else 2])
    core=[p for p in glows if 14<=p[0]<=18 and 24<=p[1]<=31][:24]
    for p in core:out.putpixel(p,GLOW[2 if b.luminance(src.getpixel(p)[:3])>145 else 0])
    protected={p for path in paths+cracks for p in path}|set(core)
    out=clean(out,src,protected)
    origin=(15,26);square(out,origin)
    emit=emit_for(out)
    DETAILS['raw_originium']={'status':'five-shard repaint','shard_count':5,
         'white_edge_paths':paths,'white_pixel_count':sum(c==WHITE for c in out.getdata()),
         'hollow_square':{'origin':list(origin),'size':3},'crack_paths':cracks,
         'readability_policy':'E4_revision_v4: 40-60 white pixels in five continuous lines takes precedence over the old 15% bright-pixel floor for this dark specimen'}
    return out,emit

def blade_bounds(x):
    # Native trace of the clean Kindjal steel envelope in the edited painting.
    if x==70:return 16,18
    if x<=35:return round(9-(x-26)/9),24
    if x<=52:return round(8+(x-35)*.29),round(24-(x-35)*.29)
    return round(13+(x-52)*.19),round(19-(x-52)*.13)

def blade(item):
    src=b.reduced_source(item);old=Image.open(b.BASE/'crystal_edge.png').convert('RGBA')
    out=Image.new('RGBA',src.size);ore=set();cleanpaths=[[],[]]
    for y in range(32):
        for x in range(26):out.putpixel((x,y),old.getpixel((x,y)))
    upperore=set(range(30,34))|set(range(53,70))
    lowerore=set(range(30,34))|set(range(53,70))
    for x in range(26,71):
        top,bottom=blade_bounds(x)
        for y in range(32):
            r,g,bl,a=src.getpixel((x,y));is_ore=((x in upperore and y<=top+2) or
                      (x in lowerore and y>=bottom-2) or x>=63 and x<=69)
            if is_ore and a>=128:
                ramp=DARK
                if r>bl+35 and r>g*1.4 and g>65:ramp=GLOW
                elif max(r,g,bl)-min(r,g,bl)<45 and b.luminance((r,g,bl))>130:ramp=[WHITE]
                out.putpixel((x,y),nearest((r,g,bl),ramp));ore.add((x,y))
            elif top<=y<=bottom:
                out.putpixel((x,y),nearest((r,g,bl),[(*c,255) for c in b.COLORS['steel'][1:4]]))
        # Continuous cold steel highlights on both exposed cutting segments.
        for side,y in enumerate((top,bottom)):
            if x not in (upperore if side==0 else lowerore):
                out.putpixel((x,y),BLACK)
                p=x,y+1 if side==0 else y-1
                out.putpixel(p,WHITE);cleanpaths[side].append(p)
        # Keep the long visible steel spine from the source, even below ore.
        if x<=61:
            y=17 if x<52 else 16
            if out.getpixel((x,y))[3]:out.putpixel((x,y),(*b.COLORS['steel'][1],255))
    origin=(64,13);square(out,origin)
    DETAILS['crystal_edge']={'status':'partial edge crust repaint','hollow_square':{'origin':list(origin),'size':3},
         'edge_span':[26,70],'ore_columns':{'upper':sorted(upperore),'lower':sorted(lowerore)},
         'ore_edge_coverage_percent':round(100*(len(upperore)+len(lowerore))/(2*45),2),
         'ore_mask':'layers/crystal_edge_ore_mask.png','clean_highlight_paths':cleanpaths,
         'preserved_hilt_columns':[0,25],'steel_spine_columns':[26,61]}
    (b.ROOT/'layers').mkdir(exist_ok=True)
    mask=Image.new('RGBA',out.size)
    for p in ore:mask.putpixel(p,BLACK)
    mask.save(b.ROOT/'layers/crystal_edge_ore_mask.png')
    return out,emit_for(out)

def armor(item):
    src=b.reduced_source(item);old=Image.open(b.BASE/'spike_plate.png').convert('RGBA');out=old.copy()
    rust=set(b.COLORS['rust']);oldrust={p for p in positions(old) if old.getpixel(p)[:3] in rust}
    for x,y in oldrust:
        if 24<=x<=48 and y<=13:c=color('#5a4d3a')
        else:c=color('#b4bec4') if b.luminance(src.getpixel((x,y))[:3])>=110 else color('#7d868e')
        out.putpixel((x,y),c)
    warm=set()
    for x,y in positions(old):
        r,g,bl,_=src.getpixel((x,y))
        if y>13 and r>g*1.35 and r>bl+25 and r>65 and g>30 and old.getpixel((x,y))[:3] not in b.COLORS['canvas']:
            warm.add((x,y))
    patches=[];highlights=[]
    for group in components(warm):
        xs=[p[0] for p in group];ys=[p[1] for p in group]
        if len(group)<2 or max(xs)-min(xs)>3 or max(ys)-min(ys)>3:continue
        patches.append(sorted(group))
        for p in group:
            c=color('#7d4529') if b.luminance(src.getpixel(p)[:3])>75 else color('#4a2a1d')
            out.putpixel(p,c)
        if len(highlights)<5:
            p=max(group,key=lambda p:b.luminance(src.getpixel(p)[:3]))
            out.putpixel(p,color('#b06a3a'));highlights.append(p)
    DETAILS['spike_plate']={'status':'rust lines replaced by compact patches','preserved_alpha':'exact v3',
         'rust_patches':patches,'rust_highlight_points':highlights,
         'repair_mask':sorted([list(p) for p in oldrust|{p for patch in patches for p in patch}]),
         'outside_repair_mask':'exact v3 pixels'}
    return out,Image.new('RGBA',out.size)

def revise(item):
    if item[0]=='raw_originium':return raw(item)
    if item[0]=='crystal_edge':return blade(item)
    if item[0]=='spike_plate':return armor(item)
    raise ValueError(item[0])
