"""Validate native sprites, exact previews, material policy and emit geometry."""
from __future__ import annotations
import hashlib
import json
import sys
from pathlib import Path
from PIL import Image, ImageChops

sys.dont_write_bytecode=True
import process_sources as build

ROOT=Path(__file__).resolve().parent


def components(points):
    remaining=set(points);result=[]
    while remaining:
        seed=remaining.pop();group={seed};queue=[seed]
        while queue:
            x,y=queue.pop()
            for dx in (-1,0,1):
                for dy in (-1,0,1):
                    p=x+dx,y+dy
                    if p in remaining:
                        remaining.remove(p);group.add(p);queue.append(p)
        result.append(group)
    return sorted(result,key=len,reverse=True)


def points(im):
    return {(x,y) for y in range(im.height) for x in range(im.width) if im.getpixel((x,y))[3]}


def main():
    manifest=json.loads((ROOT/'manifest.json').read_text(encoding='utf-8'))
    assert manifest['version']==3 and len(manifest['items'])==12
    assert manifest['slot_backgrounds']==list(build.BACKGROUNDS)
    expected={i[0]:i for i in build.ITEMS}
    assert {r['id'] for r in manifest['items']}==set(expected)
    palette={c for ramp in build.COLORS.values() for c in ramp}
    report=[]
    for row in manifest['items']:
        key=row['id'];icon=Image.open(ROOT/row['file']).convert('RGBA')
        assert icon.size==expected[key][4]==tuple(row['native_size']),key
        rgba=list(icon.getdata());opaque={p[:3] for p in rgba if p[3]}
        assert set(p[3] for p in rgba)<={0,255},key
        assert opaque<=palette and len(opaque)<=24,key
        actual=build.metrics(icon)
        assert all(row[k]==v for k,v in actual.items()),key
        assert actual['bright_pixel_percent']>=15,key
        assert actual['largest_color_percent']<=25,key
        assert actual['interior_isolated_pixel_percent']<=10,key
        if key in {'raw_originium','riot_shield','spike_plate','bash_shield'}:
            assert actual['isolated_pixel_percent']<=10,key
        if key not in {'raw_originium','crystal_edge','vein_core'}:
            assert not opaque.intersection(build.COLORS['originium']),key
        preview=Image.open(ROOT/row['preview']).convert('RGBA')
        assert preview.size==(icon.width*8,icon.height*8),key
        assert ImageChops.difference(preview,icon.resize(preview.size,Image.Resampling.NEAREST)).getbbox() is None,key
        assert (ROOT/row['source']).exists(),key
        emit_sizes=[]
        if row['has_emit']:
            assert key in build.EMIT_IDS,key
            emit=Image.open(ROOT/row['emit_file']).convert('RGBA')
            assert emit.size==icon.size,key
            assert all(p[3] in (0,255) for p in emit.getdata()),key
            assert all(e[3]==0 or e==b for e,b in zip(emit.getdata(),rgba)),key
            p=points(emit);assert len(p)==row['emit_pixel_count']>0,key
            comps=components(p);emit_sizes=[len(c) for c in comps]
            if key=='twin_fang':assert emit_sizes==[3,3],emit_sizes
            if key=='moon_edge':
                assert len(comps)==1,key
                assert min(x for x,y in p)==20 and max(x for x,y in p)==70,key
            if key in {'ember_fang','vein_core'}:assert len(comps)==1,key
            if key=='raw_originium':assert 30<=len(p)<=60,key
            if key in {'raw_originium','crystal_edge'}:
                origin=row['revision']['hollow_square']['origin'];sx,sy=origin
                ring={(sx+x,sy+y) for x in range(3) for y in range(3) if (x,y)!=(1,1)}
                assert ring<=p and (sx+1,sy+1) not in p,key
                assert icon.getpixel((sx+1,sy+1))[:3]==build.OUTLINE,key
                glowpoints={pos for pos in points(icon) if icon.getpixel(pos)[:3] in build.COLORS['originium']}
                assert glowpoints==p,'all originium orange pixels belong to emit'
                assert not opaque.intersection(build.COLORS['originium'][3:]),'no pale orange crystal surface'
        else:
            assert key not in build.EMIT_IDS and not(ROOT/f'{key}_emit.png').exists(),key
        if key=='vein_core':
            comps=components(points(icon))
            assert len(comps)==7,'core frame plus six separate side arcs'
            for arc in comps[1:]:
                assert len({icon.getpixel(p) for p in arc})==1,'arcs are solid strokes'
        if key in build.ACCEPTED:
            files=[row['file'],row['preview'],row['source']]+([row['emit_file']] if row['has_emit'] else [])
            assert all((ROOT/f).read_bytes()==(build.BASE/f).read_bytes() for f in files),('accepted item changed',key)
        if key=='spike_plate':
            prior=Image.open(build.BASE/row['file']).convert('RGBA')
            assert icon.getchannel('A').tobytes()==prior.getchannel('A').tobytes(),'armor silhouette changed'
            allowed={tuple(p) for p in row['revision']['white_allowed_points']}
            white={p for p in points(icon) if icon.getpixel(p)[:3]==build.COLORS['steel'][4]}
            assert white<=allowed,'white outside tips/glints'
            assert not opaque.intersection({build.COLORS['steel'][3]}),'silver face planes returned'
        if key=='riot_shield':
            prior=Image.open(build.BASE/row['file']).convert('RGBA');x0,y0,x1,y1=row['revision']['changed_roi']
            assert icon.getchannel('A').tobytes()==prior.getchannel('A').tobytes()
            for y in range(icon.height):
                for x in range(icon.width):
                    if not(x0<=x<=x1 and y0<=y<=y1):assert icon.getpixel((x,y))==prior.getpixel((x,y))
            paths=row['revision']['scratch_paths'];assert 4<=len(paths)<=6
            for path in paths:
                assert all(icon.getpixel(tuple(p))[:3]==build.COLORS['navy'][3] for p in path)
                assert all(tuple(b)==(a[0]+1,a[1]+1) for a,b in zip(path,path[1:]))
            assert len(components({tuple(p) for path in paths for p in path}))==5,'scratch clusters'
        if key=='shadow_bracer':
            main=Image.open(ROOT/row['revision']['main_layer']).convert('RGBA')
            echo=Image.open(ROOT/row['revision']['echo_layer']).convert('RGBA')
            assert points(echo)=={(x+5,y+1) for x,y in points(main)},'echo is not a full duplicate'
            assert {c[:3] for c in echo.getdata() if c[3]}<=set(build.COLORS['navy'][:2])
            assert ImageChops.difference(icon,Image.alpha_composite(echo,main)).getbbox() is None
            assert max(x for x,y in points(icon))==max(x for x,y in points(main))+5
            assert 18<=main.getchannel('A').getbbox()[2]-main.getchannel('A').getbbox()[0]<=20
        if key=='crystal_edge':
            # Both jagged ore edges cover the whole blade, with a steel spine.
            dark={build.OUTLINE,build.COLORS['steel'][0],build.COLORS['rust'][0],build.COLORS['vermilion'][0]}
            for x in range(26,69):
                ys=[y for xx,y in points(icon) if xx==x]
                top=[(x,y) for y in ys if y<=min(ys)+4]
                bottom=[(x,y) for y in ys if y>=max(ys)-4]
                assert any(icon.getpixel(p)[:3] in dark for p in top),('upper ore crust gap',x)
                assert any(icon.getpixel(p)[:3] in dark for p in bottom),('lower ore crust gap',x)
        report.append({'id':key,**actual,'emit_component_sizes':emit_sizes,
                       'sha256':hashlib.sha256((ROOT/row['file']).read_bytes()).hexdigest()})
    assert len(list(ROOT.glob('*_emit.png')))==6
    sheet=Image.open(ROOT/'contact_sheet.png')
    twice=Image.open(ROOT/'contact_sheet_2x.png')
    assert twice.size==(sheet.width*2,sheet.height*2)
    assert ImageChops.difference(twice,sheet.resize(twice.size,Image.Resampling.NEAREST)).getbbox() is None
    for name in ('silhouette_check.png','generation_prompts.md','process_sources.py'):
        assert (ROOT/name).exists(),name
    out={'result':'PASS','item_count':12,'emit_count':6,'checks':[
        'native sizes','binary alpha','approved palette, <=24 colors',
        '>=15% bright pixels','<=25% largest color','<=10% isolated pixels in broad interiors',
        'exact nearest-neighbor 8x and 2x','emit pixels equal base pixels',
        'effect continuity and mineral-only originium ramp',
        'seven accepted items byte-identical to v2 including sources, previews and emits',
        'armor alpha identical; shield unchanged outside lower panel',
        'full bracer echo offset [5,1] in exactly two navy tones',
        'raw emit 30-60 pixels; 3px hollow squares; black crust on both blade edges'],
        'thin_detail_note':'Twin fang and ember fang exceed 10% across all pixels because of thin outlines, guards and ember details; their broad interiors are below 10%.',
        'items':report}
    (ROOT/'qa_report.json').write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf-8')
    print('PASS: 12 icons, 6 emit masks, native dimensions, palette, binary alpha, exact previews and effect geometry')


if __name__=='__main__':main()
