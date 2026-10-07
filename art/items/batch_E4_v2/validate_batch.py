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
    assert manifest['version']==2 and len(manifest['items'])==12
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
            if key=='crystal_edge':assert len(comps)==3,key
        else:
            assert key not in build.EMIT_IDS and not(ROOT/f'{key}_emit.png').exists(),key
        if key=='vein_core':
            comps=components(points(icon))
            assert len(comps)==7,'core frame plus six separate side arcs'
            for arc in comps[1:]:
                assert len({icon.getpixel(p) for p in arc})==1,'arcs are solid strokes'
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
        'effect continuity and mineral-only originium ramp'],
        'thin_detail_note':'Twin fang and ember fang exceed 10% across all pixels because of thin outlines, guards and ember details; their broad interiors are below 10%.',
        'items':report}
    (ROOT/'qa_report.json').write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf-8')
    print('PASS: 12 icons, 6 emit masks, native dimensions, palette, binary alpha, exact previews and effect geometry')


if __name__=='__main__':main()
