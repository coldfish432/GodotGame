"""E4 v3 native cleanup of the five individually repainted source PNGs.

All geometry is painted source geometry except the explicitly preserved v2
shield/armor masks and the exact full-copy bracer assembly. No procedural item
silhouettes are drawn. The hollow core marks and five scratch paths are native
detail restoration after reduction.
"""
from collections import Counter
from PIL import Image, ImageDraw
import process_sources as b

DETAILS = {}

def rgba(hexcolor):return (*bytes.fromhex(hexcolor[1:]),255)
BLACK=rgba('#0b0c0d')
DARK=[rgba(c) for c in ['#0b0c0d','#2a2d33','#4a2a1d','#6e1616']]
GLOW=[rgba(c) for c in ['#b85a12','#ee8a24','#ffb35a']]
WHITE=rgba('#eef3f5')

def native_source(item):
    return b.reduced_source(item)

def finish(icon,source,protected=()):
    groups={(x,y):'surface' for y in range(icon.height) for x in range(icon.width) if icon.getpixel((x,y))[3]}
    return b.singleton_cleanup(icon,source,groups,set(protected))

def square(icon,emit,origin):
    x,y=origin
    for dy in range(3):
        for dx in range(3):
            p=x+dx,y+dy
            assert icon.getpixel(p)[3],('square outside painted shard',p)
            c=BLACK if dx==dy==1 else GLOW[2 if dy==0 or dx==0 else 1]
            icon.putpixel(p,c)
            emit.putpixel(p,c if dx!=1 or dy!=1 else (0,0,0,0))

def originium(item):
    key=item[0];src=native_source(item);out=Image.new('RGBA',src.size)
    points={(x,y) for y in range(src.height) for x in range(src.width) if src.getpixel((x,y))[3]>=128}
    # Remove detached source flecks; the painted shard/star silhouette remains.
    alpha=Image.new('RGBA',src.size)
    for p in points:alpha.putpixel(p,BLACK)
    points=set().union(*(c for c in b.alpha_components(alpha) if len(c)>=3))
    is_raw=key=='raw_originium';body=[];glows=[];white=[];protected=set();hosts=[];spine=[]
    for x,y in points:
        r,g,bl,_=src.getpixel((x,y));v=b.luminance((r,g,bl))
        if is_raw:
            host=y>=55
            ore=not host
        else:
            ys=[yy for xx,yy in points if xx==x]
            ore=x>=25 and (y<min(ys)+5 or y>max(ys)-5 or x>=62)
            host=False
        if not is_raw and x<25:
            # Preserve the accepted taped grip directly at the native grid.
            old=Image.open(b.BASE/f'{key}.png').convert('RGBA')
            if old.getpixel((x,y))[3]:out.putpixel((x,y),old.getpixel((x,y)));continue
            group='canvas' if r>bl+15 else 'steel'
            out.putpixel((x,y),(*min(b.COLORS[group],key=lambda c:b.distance(c,(r,g,bl))),255));continue
        if host:
            hosts.append((x,y))
            ramp=[rgba(c) for c in ['#2a2d33','#4a5058','#5a4d3a']]
            c=min(ramp,key=lambda c:b.distance(c,(r,g,bl)))
        elif not ore:
            spine.append((x,y))
            c=(*min(b.COLORS['steel'],key=lambda c:b.distance(c,(r,g,bl))),255)
        else:
            body.append((x,y))
            c=min(DARK,key=lambda c:b.distance(c[:3],(r,g,bl)))
            if r>bl+32 and r>g*1.4 and g>65:
                glows.append((x,y))
            if max(r,g,bl)-min(r,g,bl)<60 and v>(60 if is_raw else 75):
                white.append((x,y))
        out.putpixel((x,y),c)
    # The dark crystal planes remain four dark swatches, rather than grading
    # them through silver. Hard white marks follow the brightest painted facets.
    white.sort(key=lambda p:b.luminance(src.getpixel(p)[:3]),reverse=True)
    white=white[:round(len(points)*(.20 if is_raw else .10))]
    for p in white:out.putpixel(p,WHITE)
    nonwhite=[p for p in body if p not in set(white)]
    # Keep each broad dark plane under the material-area swatch limit.
    nonwhite.sort(key=lambda p:(b.luminance(src.getpixel(p)[:3]),p[1],p[0]))
    for i,p in enumerate(nonwhite):
        tone=min(3,4*i//max(1,len(nonwhite)))
        out.putpixel(p,DARK[tone])
    hosts.sort(key=lambda p:b.luminance(src.getpixel(p)[:3]))
    hostramp=[rgba(c) for c in ['#2a2d33','#5a4d3a','#4a5058']]
    for i,p in enumerate(hosts):out.putpixel(p,hostramp[min(2,3*i//len(hosts))])
    spine.sort(key=lambda p:b.luminance(src.getpixel(p)[:3]))
    for i,p in enumerate(spine):out.putpixel(p,(*b.COLORS['steel'][1+min(2,3*i//len(spine))],255))
    emit=Image.new('RGBA',src.size)
    glows.sort(key=lambda p:(src.getpixel(p)[0]-src.getpixel(p)[2],b.luminance(src.getpixel(p)[:3])),reverse=True)
    glowcoords=glows[:40] if is_raw else glows
    for i,p in enumerate(glowcoords):
        c=GLOW[min(2,3*(len(glowcoords)-1-i)//max(1,len(glowcoords)))]
        out.putpixel(p,c);emit.putpixel(p,c);protected.add(p)
    # Retain the highest-value facet clusters during singleton cleanup.
    out=finish(out,src,protected|set(white))
    origin=(10,18) if is_raw else (63,13)
    for p in list(glowcoords):
        emit.putpixel(p,out.getpixel(p))
    square(out,emit,origin)
    # Square centre is a deliberate dark hole even if it intersected a crack.
    emit.putpixel((origin[0]+1,origin[1]+1),(0,0,0,0))
    DETAILS[key]={'status':'repainted from imagegen source','hollow_square':{'origin':list(origin),'size':3},
                  'material':'black faceted ore with white glints and internal orange fissures',
                  'emit_policy':'internal cracks and hollow square only'}
    return out,emit

def bracer(item):
    spec=(*item[:4],(32,32),(19,28),0)
    source=native_source(spec)
    # Fit at x=6 in reduction, then reposition main to x=4 to leave echo room.
    source=source.crop((6,2,25,30))
    main=Image.new('RGBA',(32,32));echo=Image.new('RGBA',(32,32))
    for y in range(28):
        for x in range(19):
            r,g,bl,a=source.getpixel((x,y))
            if a<128:continue
            group='navy' if bl>r+18 else 'steel'
            ramp=b.COLORS[group]
            c=min(ramp,key=lambda c:b.distance(c,(r,g,bl)))
            main.putpixel((x+4,y+1),(*c,255))
    steel=[(x,y) for y in range(32) for x in range(32) if main.getpixel((x,y))[:3] in b.COLORS['steel'] and main.getpixel((x,y))[3]]
    steel.sort(key=lambda p:b.luminance(main.getpixel(p)[:3]))
    for i,p in enumerate(steel):main.putpixel(p,(*b.COLORS['steel'][min(4,5*i//len(steel))],255))
    main=finish(main,main)
    # Restore the painted pointed upper cuff lost to subpixel reduction. Its
    # two-row peak exposes a second displaced peak in the union silhouette.
    for x in range(32):
        if x not in {13,14,15}:main.putpixel((x,1),(0,0,0,0))
    main.putpixel((14,0),WHITE)
    for x in (13,14,15):main.putpixel((x,1),(*b.COLORS['steel'][3],255))
    # Every main opaque pixel has a dark duplicate, including the cuffs/straps.
    for y in range(32):
        for x in range(32):
            c=main.getpixel((x,y))
            if c[3]:echo.putpixel((x+5,y+1),(*b.COLORS['navy'][1 if x>=20 or y<7 or y>24 else 0],255))
    out=Image.alpha_composite(echo,main)
    (b.ROOT/'layers').mkdir(exist_ok=True)
    main.save(b.ROOT/'layers/shadow_bracer_main.png');echo.save(b.ROOT/'layers/shadow_bracer_echo.png')
    DETAILS['shadow_bracer']={'status':'repainted main and full-copy assembly','main_width':19,'offset':[5,1],
                              'native_detail_restoration':'two-row pointed upper cuff; duplicate peaks visible in black silhouette',
                              'main_layer':'layers/shadow_bracer_main.png','echo_layer':'layers/shadow_bracer_echo.png',
                              'echo_palette':['#141f30','#24395a']}
    return out,Image.new('RGBA',out.size)

def shield(item):
    out=Image.open(b.BASE/'riot_shield.png').convert('RGBA')
    # Lower panel only, alpha/rim/viewport/reflective band are the v2 pixels.
    roi=(15,41,57,65)
    for y in range(roi[1],roi[3]+1):
        for x in range(roi[0],roi[2]+1):
            if not out.getpixel((x,y))[3]:continue
            k=2 if x<27+(y-41)//3 else 1 if x<43+(y-41)//4 else 0
            out.putpixel((x,y),(*b.COLORS['navy'][k],255))
    paths=[[(20+i,44+i) for i in range(4)],[(30+i,45+i) for i in range(4)],
           [(40+i,49+i) for i in range(4)],[(23+i,57+i) for i in range(4)],
           [(47+i,58+i) for i in range(4)]]
    for path in paths:
        for p in path:out.putpixel(p,rgba('#6f9cc6'))
    DETAILS['riot_shield']={'status':'local native scratch cleanup from repainted source',
                            'changed_roi':list(roi),'scratch_paths':paths,'outside_roi':'unchanged v2 pixels'}
    return out,Image.new('RGBA',out.size)

def plate(item):
    src=native_source(item);old=Image.open(b.BASE/'spike_plate.png').convert('RGBA')
    out=Image.new('RGBA',src.size);groups={};protected=set();steel=[];straps=[]
    for y in range(src.height):
        for x in range(src.width):
            if not old.getpixel((x,y))[3]:continue
            r,g,bl,_=src.getpixel((x,y));warm=r>bl+18 and g>bl+8
            if warm and r<g*1.5:
                group='canvas';straps.append((x,y));ramp=b.COLORS['canvas']
            elif warm:
                group='rust';ramp=b.COLORS['rust'][1:3]
            else:
                group='steel';ramp=b.COLORS['steel'][:3];steel.append((x,y))
            groups[x,y]=group;c=min(ramp,key=lambda c:b.distance(c,(r,g,bl)))
            out.putpixel((x,y),(*c,255))
    # Recover three dark planes from the painted iron, with no white body face.
    steel.sort(key=lambda p:b.luminance(src.getpixel(p)[:3]))
    for i,p in enumerate(steel):out.putpixel(p,(*b.COLORS['steel'][min(2,3*i//len(steel))],255))
    # Canvas catches the light across the exposed straps.
    for p in straps:
        v=b.luminance(src.getpixel(p)[:3]);out.putpixel(p,(*b.COLORS['canvas'][3 if v>175 else 2 if v>75 else 1],255))
    # White only at the accepted outer spike tips and a few rim glints.
    tips={(x,y) for x,y in steel if (x<14 or x>57 or (y<13 and (x<25 or x>46)))
          and b.luminance(src.getpixel((x,y))[:3])>145}
    glints={(33,5),(34,5),(35,5),(20,19),(52,18)}
    protected=tips|{p for p in glints if old.getpixel(p)[3]}
    for p in protected:out.putpixel(p,WHITE)
    out=b.singleton_cleanup(out,src,groups,protected)
    # The original contour is deliberate. Darken underside/side boundaries.
    a=old.getchannel('A')
    for y in range(out.height):
        for x in range(out.width):
            if not a.getpixel((x,y)) or (x,y) in protected:continue
            if any(nx<0 or nx>=72 or ny>=72 or (ny>=0 and not a.getpixel((nx,ny)))
                   for nx,ny in [(x-1,y),(x+1,y),(x,y+1)]):out.putpixel((x,y),BLACK)
    DETAILS['spike_plate']={'status':'material repaint with exact v2 alpha',
                            'body_palette':['#2a2d33','#4a5058','#7d868e'],
                            'white_pixel_policy':'spike tips and five short rim glints','white_allowed_points':sorted([list(p) for p in protected])}
    return out,Image.new('RGBA',out.size)

def revise(item):
    key=item[0]
    if key in {'raw_originium','crystal_edge'}:return originium(item)
    if key=='shadow_bracer':return bracer(item)
    if key=='riot_shield':return shield(item)
    if key=='spike_plate':return plate(item)
    raise ValueError(key)
