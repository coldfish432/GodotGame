"""H3b expansion asset kit: native locked modules and generated small hardware."""
from __future__ import annotations

import hashlib
import shutil
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent
ART = ROOT.parent
sys.path.insert(0, str(ART))
from pixel_kit import (COLORS, canvas, dependency, draw_text, emit_from_colors,
                       line, load, paste, poly, rect, rgba, save_native, write_json)
from h3_source_pipeline import reduce_source

B1 = ART / 'batch1_v5'
H1 = ART / 'batch_H1_bridge_hall_v2'
H1B = ART / 'batch_H1b_wayfinding_v1'
L0 = ART / 'batch_L0_logo_v1'
FLOOR = ART / 'batch2_v2/rhodes_floor_v1.png'
ASSETS = []
DEPS = {}
IMAGES = {}


def dep(path: Path, use: str) -> None:
    DEPS[str(path.resolve())] = dependency(path, ROOT, use)


def add(stem, image, kind, footprint, notes, coverage, *, state='default',
        states=None, anchor=None, emit=(), source=None, locked=None):
    save_native(image, ROOT, stem)
    if locked:
        shutil.copyfile(locked, ROOT / (stem + '.png'))
        dep(locked, notes)
    emit_name = None
    if emit:
        mask = emit if isinstance(emit, Image.Image) else emit_from_colors(image, emit)
        emit_name = save_native(mask, ROOT, stem + '_emit')
    anchor = anchor or ([image.width // 2, image.height // 2] if kind in ('tile', 'decal')
                        else [image.width // 2, 0] if kind == 'wall'
                        else [image.width // 2, image.height - 1])
    ASSETS.append(dict(id=stem, file=stem+'.png', emit=emit_name, kind=kind,
                       size_px=list(image.size), anchor_px=anchor,
                       footprint_units=footprint, wall_mounted=kind == 'wall',
                       state=state, states=states or [state], notes=notes,
                       coverage_35=coverage, source=source,
                       locked_source=DEPS[str(locked.resolve())]['file'] if locked else None))
    IMAGES[stem] = image
    return image


def generated(name, factor, footprint, emit=()):
    src = ROOT / 'sources' / (name + '_source.png')
    image = reduce_source(src, factor)
    if name == 'engineering_drone':
        # Small status lights, no broad glowing rotor bands.
        table = {rgba('T0'): rgba('S2'), rgba('T1'): rgba('S3')}
        image.putdata([table.get(p, p) for p in image.get_flattened_data()])
    source = dict(source='sources/'+src.name,
                  source_size_px=list(load(src).size),
                  source_sha256=hashlib.sha256(src.read_bytes()).hexdigest(),
                  integer_reduction=factor, quantization='Rhodes palette, CIELAB nearest; no dithering',
                  alpha='binary 112/255 after uniform nearest reduction',
                  postprocess='T0/T1 mapped to local steel shades' if name=='engineering_drone' else 'none')
    return add(name, image, 'billboard', footprint,
               'Generated front-facing object; uniform integer reduction only. No yaw or section stretching.',
               ['A: shaded top/front material planes', 'C: construction colour and light'],
               emit=emit, source=source)


def dim(image):
    names = {'K':'D', 'D':'D', 'S0':'D', 'S1':'S0', 'S2':'S1', 'S3':'S2',
             'G0':'S3', 'G1':'G0', 'G2':'G1', 'W0':'G0', 'W1':'G1', 'W2':'W0',
             'Y2':'Y1', 'Y1':'Y0', 'O2':'O1', 'O1':'O0', 'B2':'B1', 'B1':'B0',
             'L2':'L1', 'L1':'L0', 'T3':'T2', 'T2':'T1'}
    table = {rgba(a):rgba(b) for a,b in names.items()}
    result = image.copy()
    result.putdata([table.get(p,p) for p in image.get_flattened_data()])
    return result


def warning(size=16):
    im = canvas(size, size)
    poly(im, [(size//2,0),(size-1,size-2),(0,size-2)], 'S0')
    poly(im, [(size//2,2),(size-3,size-3),(2,size-3)], 'Y2')
    rect(im, (size//2-1,5,size//2,9), 'D')
    rect(im, (size//2-1,11,size//2,12), 'D')
    return im


def frame(width, height, words=False):
    im = canvas(width,height)
    for x in range(2,width-3,8):
        rect(im,(x,2,min(x+4,width-3),2),'Y1')
        rect(im,(x,height-3,min(x+4,width-3),height-3),'Y1')
    for y in range(2,height-3,8):
        rect(im,(2,y,2,min(y+4,height-3)),'Y1')
        rect(im,(width-3,y,width-3,min(y+4,height-3)),'Y1')
    for x,y,sx,sy in [(1,1,1,1),(width-2,1,-1,1),(1,height-2,1,-1),(width-2,height-2,-1,-1)]:
        line(im,[(x+sx*5,y),(x,y),(x,y+sy*5)],'Y2')
    if words:
        draw_text(im,'PENDING',(width-41)//2,18,5,'G1')
        draw_text(im,'BUILD',(width-29)//2,29,5,'Y1')
    else:
        cx,cy=width//2,height//2
        rect(im,(cx-4,cy-1,cx+4,cy+1),'Y1')
        rect(im,(cx-1,cy-4,cx+1,cy+4),'Y1')
    return im


def main():
    wall=load(B1/'wall_straight_60x46_v5.png')
    floor=load(FLOOR)
    tarp=load(L0/'rhodes_logo_tarp_print_v1.png')
    lap=load(B1/'lappland_frame0_64.png')
    for path,use in [(FLOOR,'Accepted dark-steel floor pixels'),
                     (B1/'lappland_frame0_64.png','Unscaled frame 0 character'),
                     (L0/'rhodes_logo_tarp_print_v1.png','Accepted folded tarp, pasted at 1:1'),
                     (H1/'wing_construction_barrier_uncleared_128x56.png','Accepted fence/tarp language'),
                     (H1/'light_pool_circle_warm_60x40.png','Optional additive work-light pool; black is zero light')]:
        dep(path,use)

    drone=generated('engineering_drone',48,[1.8,0.7],('T2','T3'))
    lamp=generated('construction_work_lamp',40,[1.5,0.6],('W2','L2'))
    debris=generated('corridor_debris',34,[3.5,0.9])
    dark_debris=add('corridor_debris_dimmed',dim(debris),'billboard',[3.5,0.9],
                    'Palette-step dimming of the same generated debris; identical alpha.',
                    ['A: crates and panels','D: disconnected orange cables'])
    warn=add('uncleared_warning_16x16',warning(),'wall',[0,0],
             'Native warning triangle attached to blocked access.', ['B: warning pictogram','C: safety yellow'])

    # Locked geometry is copied, never scaled or redrawn.
    locked=[('wall_straight_60x46_v5','wall', [4,0]),('wall_rib_6x46_v5','wall',[0.4,0]),
            ('wall_top_6_plus2_v5','tile',[0.53,4.71]),('corner_left_L_v5','wall',[0,0]),
            ('corner_right_L_v5','wall',[0,0]),('door_side_gap38_v5','tile',[0.53,4.71])]
    for name,kind,fp in locked:
        p=B1/(name+'.png')
        add('accepted_'+name,load(p),kind,fp,'Batch 1 v5 pixels and geometry, unchanged.',
            ['A: locked shell geometry'],locked=p)

    north=canvas(90,46)
    for x in (0,60): paste(north,wall,(x,0))
    add('corridor_north_wall_90x46',north,'wall',[6,0],
        'Six-unit repeat, 40px face +4px cap +2px baseboard, no end ribs.', ['A: dark-steel wall'])
    dep(B1/'wall_straight_60x46_v5.png','Locked wall source for six-unit segment')
    socket=north.copy()
    socket.paste((0,0,0,0),(22,0,67,46))
    add('corridor_door_socket_90x46',socket,'wall',[6,0],
        'Swap for north wall; insert a 45x46 door at [22,0]. No rib beside jambs.', ['A: standard room slot'])
    ground=canvas(90,51)
    for y in range(51):
        for x in range(90): ground.putpixel((x,y),floor.getpixel(((x+110)%120,y)))
    add('corridor_floor_90x51',ground,'tile',[6,4],
        'E-W segment floor, 6x4 units. Accepted floor pixels at cyclic phase 110, no resampling; matching X edges.', ['A: 4-unit clear depth'])
    south=canvas(90,6)
    rect(south,(0,0,89,1),'D')
    paste(south,north.crop((0,0,90,4)),(0,2))
    add('corridor_south_cap_90x6',south,'tile',[6,0],
        'Optional foreground top-cap: 4px cap and 2px contact shadow, outside the 51px clear floor.', ['A: foreground wall-top'])
    clear=canvas(90,103)
    paste(clear,north,(0,0));paste(clear,ground,(0,46));paste(clear,south,(0,97))
    add('corridor_straight_cleared',clear,'tile',[6,4],
        'Ready native E-W module; north wall at y0, floor y46..96, optional south cap y97..102. Connectors x0/x90.',
        ['A: standard six-unit segment','C: readable open access'],state='cleared',states=['uncleared','cleared'],anchor=[0,46])
    uncleared=dim(clear)
    paste(uncleared,dark_debris,(18,75));paste(uncleared,warn,(8,20))
    add('corridor_straight_uncleared',uncleared,'tile',[6,4],
        'Same shell geometry, one palette step dimmer, debris and attached warning. Block traversal in assembly.',
        ['A: standard segment','B: warning','D: debris'],state='uncleared',states=['uncleared','cleared'],anchor=[0,46])

    # A front-facing four-unit fence; accepted tarp remains exactly 40x40.
    fence=canvas(60,46)
    paste(fence,dark_debris,(3,12))
    for y in (26,36):
        rect(fence,(0,y-1,59,y+5),'S0');rect(fence,(1,y,58,y+3),'Y1')
        for x in range(-3,60,8): line(fence,[(x,y),(x+3,y+3)],'S0',2)
    for x in (2,28,56):
        rect(fence,(x,22,x+2,44),'S0');rect(fence,(x+1,23,x+1,42),'G0')
    rect(fence,(0,44,59,45),'D')
    poly(fence,[(16,3),(25,1),(36,3),(47,1),(59,5),(59,43),(53,45),(43,43),(31,45),(17,42)],'B0')
    paste(fence,tarp,(18,3));paste(fence,warn,(0,5))
    add('corridor_end_fence_60x46',fence,'billboard',[4,0.6],
        'Front-facing transverse fence; H1 yellow-black language, dim debris and accepted tarp at [18,3].',
        ['A: construction fence','B: accepted tarp identity and warning','D: abandoned materials'])
    sign=canvas(60,12,'S0');rect(sign,(1,1,58,10),'S2')
    draw_text(sign,'UNCLEARED',3,3,5,'Y1')
    add('uncleared_zone_sign_60x12',sign,'wall',[0,0],
        'Accepted 5x7 glyphs; hang above the end fence.', ['B: uncleared zone label'])
    cap=canvas(60,58);paste(cap,sign,(0,0));paste(cap,fence,(0,12))
    add('corridor_dead_end_uncleared',cap,'billboard',[4,0.6],
        'Ready front-facing end cap: 46px fence plus 12px attached sign. World span 4 units; billboard always faces camera.',
        ['A: closed expansion edge','B: warning and tarp mark','C: hazard fence','D: debris'],state='uncleared')

    overlay=canvas(90,103);light=canvas(90,103)
    for pos in ((10,48),(45,50)):
        paste(overlay,drone,pos);paste(light,load(ROOT/'engineering_drone_emit.png'),pos)
    paste(overlay,lamp,(63,65));paste(light,load(ROOT/'construction_work_lamp_emit.png'),(63,65))
    add('corridor_clearing_overlay',overlay,'billboard',[6,4],
        'Optional overlay on uncleared segment at the same top-left; two hovering drones over debris and one work lamp.',
        ['A: active engineering','C: cyan cameras and warm work light','D: maintenance activity'],
        state='clearing',anchor=[0,46],emit=light)

    pending=add('pending_build_floor_90x51',frame(90,51,True),'decal',[6,4],
                'Native dashed construction reservation, accepted 5x7 PENDING BUILD text. Repeat/compose frames, never stretch lettering.',
                ['B: pending build label','C: construction zone frame'])
    compact=add('pending_build_floor_compact_28x18',frame(28,18),'decal',[1.87,1.41],
                'Compact frame and build cross for the visible portion of an empty doorway.', ['B: compact pending icon'])
    insert=canvas(32,36)
    for y in range(36):
        for x in range(32): insert.putpixel((x,y),floor.getpixel((x+30,y+30)))
    paste(insert,compact,(2,15))
    add('room_slot_empty_backing_32x36',insert,'wall',[0,0],
        'Separate bare-room floor backing behind the opening at door-local [6,9]. Does not replace alpha/collision clearance.',
        ['A: visible bare room','B: pending build frame'],anchor=[0,0])
    for state,old,emit in [('sealed','sealed',('R0',)),('empty','open',('T2',)),('built','closed',('T2',))]:
        p=B1/f'door_{old}_45x46_v5.png'
        add('room_slot_door_'+state,load(p),'billboard',[3,0.5],
            'Locked 45x46 frame, 3px chamfers. '+{'sealed':'Accepted hazard tape and red status lamp.',
            'empty':'Transparent 32x36 opening; add bare-room backing underneath.',
            'built':'Normal closed door; attach supplied B1-05 plate separately.'}[state],
            ['A: locked door frame','B: room slot state','C: status light'],state=state,
            states=['sealed','empty','built'],emit=emit,locked=p)
        ASSETS[-1]['wall_mounted']=True
        ASSETS[-1]['clearance_px']=[32,36]
    plate_path=H1B/'small_number_plate_B1_05.png'
    plate=add('room_slot_number_plate_B1_05',load(plate_path),'wall',[0,0],
              'Accepted B1-05 number plate; separate from the locked door dimensions.', ['B: standard room number'],locked=plate_path)

    # Scale/contact gallery only. It is not a scene blockout or gameplay layout.
    preview=canvas(480,300,'S0')
    characters=[]
    for index,(label,asset) in enumerate([('CLEARED','corridor_straight_cleared'),('UNCLEARED','corridor_straight_uncleared'),
                                         ('CLEARING','corridor_straight_uncleared'),('DEAD END',None)]):
        ox=index*120
        draw_text(preview,label,ox+5,4,5,'W0')
        if asset: paste(preview,IMAGES[asset],(ox+15,18))
        else:
            for y in range(20,135):
                for x in range(15,105): preview.putpixel((ox+x,y),floor.getpixel((x%120,y%120)))
            paste(preview,cap,(ox+30,30))
        if index==2:paste(preview,overlay,(ox+15,18))
        if index==0:characters.append([ox+20,65])
    for index,state in enumerate(['sealed','empty','built']):
        ox=index*120;oy=150
        draw_text(preview,state.upper(),ox+5,oy+4,5,'W0')
        for y in range(78,145):
            for x in range(15,105):preview.putpixel((ox+x,oy+y),floor.getpixel((x%120,y%120)))
        paste(preview,socket,(ox+15,oy+32))
        if state=='empty':paste(preview,insert,(ox+43,oy+41))
        paste(preview,IMAGES['room_slot_door_'+state],(ox+37,oy+32))
        if state=='built':
            paste(preview,plate,(ox+60-plate.width//2,oy+17))
            characters.append([ox+63,oy+70])
    draw_text(preview,'PENDING',365,154,5,'W0')
    for y in range(180,290):
        for x in range(375,465):preview.putpixel((x,y),floor.getpixel((x%120,y%120)))
    paste(preview,pending,(375,198))
    for pos in characters:paste(preview,lap,tuple(pos))
    preview.save(ROOT/'H3b_expansion_lappland_1x.png')
    preview.resize((1920,1200),Image.Resampling.NEAREST).save(ROOT/'H3b_expansion_lappland_4x.png')

    assemblies={
        'corridor_straight':{'uncleared':'corridor_straight_uncleared','cleared':'corridor_straight_cleared',
                             'clearing':['corridor_straight_uncleared','corridor_clearing_overlay']},
        'room_slot':{'sealed':[{'id':'room_slot_door_sealed','offset_px':[0,0]}],
                     'empty':[{'id':'room_slot_empty_backing_32x36','offset_px':[6,9]},
                              {'id':'room_slot_door_empty','offset_px':[0,0]}],
                     'built':[{'id':'room_slot_door_built','offset_px':[0,0]},
                              {'id':'room_slot_number_plate_B1_05','offset_px':[(45-plate.width)//2,-plate.height-2]}]},
        'room_slot_wall':{'wall':'corridor_door_socket_90x46','door_offset_px':[22,0]}}
    write_json(ROOT/'manifest.json',dict(batch='H3b expansion v1',spec='v2.0 sections 2.4, 3.5, 3.7, 4.4',
        pixel_scale=1,projection={'pixels_per_unit':15,'ground_y_scale':0.85,'yaw_degrees':0,
        'corridor_orientation':'east-west','corridor_units':[6,4],'floor_px':[90,51],
        'wall_px':46,'door_px':[45,46],'clear_opening_rect_px':[6,9,32,36]},
        assets=ASSETS,assemblies=assemblies,external_dependencies=list(DEPS.values()),
        build_script='build_h3b.py',validation_script='validate_h3b.py',
        preview={'file':'H3b_expansion_lappland_1x.png','review_4x':'H3b_expansion_lappland_4x.png',
                 'size_px':[480,300],'character_origins_px':characters,'purpose':'native-scale asset contact gallery only'},
        layout_notes=['Clear floor is 4 units; the wall face and optional south cap lie outside that floor rectangle.',
                      'Only cleared corridor tiles are traversable. Clearing overlay does not unlock collision.',
                      'Repeat corridors in 90px X steps. Doors use six-unit pitch and center offset [22,0].',
                      'Do not place a rib directly beside a door frame.',
                      'End fence is a camera-facing 4-unit billboard; set its world collision across the corridor at assembly.',
                      'Empty door backing is behind the frame and excluded from door collision; leave 32x36 clearance.',
                      'One accepted tarp logo per dead-end. Keep total logos at or below six per screen.',
                      'Work-light pool is an accepted additive texture on black, with intensity tuned in engine.']))
    (ROOT/'validation.txt').write_text('H3b expansion v1 build complete. Independent validation follows.\n',encoding='utf-8')
    print(f'H3b: {len(ASSETS)} assets, {sum(bool(a["emit"]) for a in ASSETS)} emit masks.')


if __name__=='__main__':main()
