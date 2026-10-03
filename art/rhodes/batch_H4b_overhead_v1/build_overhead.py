"""Build reusable ceiling-layer modules from generated source art."""
from __future__ import annotations

import sys
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parent
ART=ROOT.parent
sys.path.insert(0,str(ART))
from h3_source_pipeline import reduce_source
from h4_kit import H4Kit
from pixel_kit import canvas, load, rect, rgba

B1=ART/"batch1_v5"
H3=ART/"batch_H3_armory_v4"
LIGHT=ART/"batch3_equipment_v3"
kit=H4Kit(ROOT,"overhead",(0,0),version=1,
          spec="罗德岛基地美术策划案_v2_0.md §3.8, §§3.5/4.4; ceiling layer for armory, warehouse, hall and medical",
          method="Each hardware source is image-generated, uniformly integer-reduced and quantized to the Rhodes 31-color palette. Native-grid crop/pad and seam repair make straight modules tile exactly; the crossed gusset uses generated art on matching native beams. The engine stretches the hoist cable between separate trolley and hook sprites.")


def pad_center(im:Image.Image,size:tuple[int,int])->Image.Image:
    assert im.width<=size[0] and im.height<=size[1]
    out=canvas(*size)
    out.alpha_composite(im,((size[0]-im.width)//2,(size[1]-im.height)//2))
    return out


def tiling_strip(source:str,factor:int,height:int)->Image.Image:
    """Uniform source reduction, central crop, then native-grid seam repair."""
    reduced=reduce_source(ROOT/"sources"/source,factor)
    assert reduced.width>=60 and reduced.height<=height
    x=(reduced.width-60)//2
    out=pad_center(reduced.crop((x,0,x+60,reduced.height)),(60,height))
    for y in range(height):
        seam=out.getpixel((3,y))
        for xx in (0,1,2,57,58,59):
            out.putpixel((xx,y),seam)
    return out


beam=tiling_strip("beam_source.png",18,14)
kit.add("overhead_ibeam_straight_ew_60x14",beam,kind="beam",zone="all",
        layer="overhead",source="beam_source.png",factor=18,
        note="Repeat end-to-end. Edge columns identical; generated steel surface, native seam repair. No end pillars or stripes on straight section.")
beam_ns=beam.transpose(Image.Transpose.ROTATE_270)
kit.add("overhead_ibeam_straight_ns_14x60",beam_ns,kind="beam",zone="all",
        layer="overhead",source="beam_source.png",factor=18,
        note="Exact 90-degree native turn of straight beam; tile vertically; no interpolation.")

bracket=pad_center(reduce_source(ROOT/"sources"/"bracket_source.png",25),(28,28))
for side,im in (("right",bracket),("left",bracket.transpose(Image.Transpose.FLIP_LEFT_RIGHT))):
    kit.add(f"overhead_ibeam_wall_bracket_{side}_28x28",im,kind="support",zone="all",
            layer="overhead",source="bracket_source.png",factor=25,
            note="Separate wall support; yellow-black marking at exposed end. Attach straight beam at saddle height.")

# Generated center gusset sits on two exactly matched native straight arms.
cross=canvas(36,36)
cross.alpha_composite(beam.crop((12,0,48,14)),(0,11))
cross.alpha_composite(beam_ns.crop((0,12,14,48)),(11,0))
gusset=reduce_source(ROOT/"sources"/"junction_source.png",40)
core=gusset.crop(((gusset.width-20)//2,(gusset.height-20)//2,
                  (gusset.width+20)//2,(gusset.height+20)//2))
cross.alpha_composite(core,(8,8))
for xx in (7,28):
    rect(cross,(xx,14,xx+1,19),"Y2")
    rect(cross,(xx,17,xx+1,17),"S0")
for yy in range(14):
    for xx in (0,1,2,33,34,35):
        cross.putpixel((xx,yy+11),beam.getpixel((0,yy)))
for xx in range(14):
    for yy in (0,1,2,33,34,35):
        cross.putpixel((xx+11,yy),beam_ns.getpixel((xx,0)))
kit.add("overhead_ibeam_cross_junction_36x36",cross,kind="junction",zone="all",
        layer="overhead",source="junction_source.png",factor=40,
        note="Two 14px I-beam arms meet at 90 degrees; generated gusset on exact native E-W/N-S crossing. Join straight modules at all four edges.")

marker=canvas(6,14)
rect(marker,(0,0,5,13),"S2")
for yy in range(2,12):
    for xx in range(1,5):
        if ((xx+yy)//3)%2==0:
            rect(marker,(xx,yy,xx,yy),"Y2")
kit.add("overhead_ibeam_exposed_end_marker_6x14",marker,kind="marker",zone="all",
        layer="overhead",note="Yellow-black safety mark for an exposed beam end; flip horizontally as needed. Keep it off seams between straight modules.")

trolley=reduce_source(ROOT/"sources"/"hoist_trolley_source.png",45)
kit.add("overhead_hoist_trolley",trolley,kind="hoist_trolley",zone="armory_warehouse",
        layer="overhead",source="hoist_trolley_source.png",factor=45,
        note="Moving motor trolley only; no beam, cable or hook baked in. Set rail position and hang separate hook by stretched engine cable.")
kit.assets[-1]["cable_socket_px"]=[trolley.width//2,trolley.height-1]
hook=reduce_source(ROOT/"sources"/"hoist_hook_source.png",50)
kit.add("overhead_hoist_hook",hook,kind="hoist_hook",zone="armory_warehouse",
        layer="overhead",source="hoist_hook_source.png",factor=50,
        note="Separate lower hook block; engine draws/stretchs cable from trolley socket to top-center hook eye.")
kit.assets[-1]["cable_socket_px"]=[hook.width//2,0]

tray=tiling_strip("cable_tray_source.png",18,14)
kit.add("overhead_cable_tray_orange_60x14",tray,kind="tray",zone="hall_warehouse",
        layer="overhead",source="cable_tray_source.png",factor=18,
        note="Dark-steel tray with restrained orange cable bundle; seam-matched 60px straight segment.")
track=tiling_strip("curtain_track_source.png",18,12)
kit.add("overhead_medical_curtain_track_60x12",track,kind="track",zone="medical",
        layer="overhead",source="curtain_track_source.png",factor=18,
        note="Ceiling-mounted white/blue curtain-loop track; seam-matched 60px straight segment. Curtain fabric remains separate H3 art.")

kit.preview("H4b_overhead_lappland_1x",LIGHT/"wall_straight_60x46_light_v2.png",
            LIGHT/"rhodes_floor_equipment_v1.png",[],
            B1/"lappland_frame0_64.png",(109,142),(360,220),overhead_placements=[
                ("overhead_ibeam_wall_bracket_right_28x28",12,53),
                ("overhead_ibeam_wall_bracket_left_28x28",320,53),
                ("overhead_ibeam_straight_ew_60x14",40,59),
                ("overhead_ibeam_straight_ew_60x14",100,59),
                ("overhead_ibeam_cross_junction_36x36",158,48),
                ("overhead_ibeam_straight_ew_60x14",193,59),
                ("overhead_ibeam_straight_ew_60x14",253,59),
                ("overhead_cable_tray_orange_60x14",12,100),
                ("overhead_medical_curtain_track_60x12",275,103),
                ("overhead_hoist_trolley",210,52),
                ("overhead_hoist_hook",220,110),
                ])
review=load(ROOT/"H4b_overhead_lappland_1x.png")
draw=ImageDraw.Draw(review)
socket_top=(210+trolley.width//2,52+trolley.height-1)
socket_bottom=(220+hook.width//2,110)
draw.line((socket_top,socket_bottom),fill=rgba("S3"),width=2)
draw.line(((socket_top[0]-1,socket_top[1]),(socket_bottom[0]-1,socket_bottom[1])),fill=rgba("G1"),width=1)
review.save(ROOT/"H4b_overhead_lappland_1x.png")
review.resize((review.width*4,review.height*4),Image.Resampling.NEAREST).save(ROOT/"H4b_overhead_lappland_1x_4x.png")
kit.dep(H3/"armory_equipment_workbench.png","accepted armory main object used as height reference")
kit.finish("H4b_overhead_lappland_1x",{
    "layer":"overhead, above objects and characters",
    "placement_height_px":"ceiling beam roughly 40–60px above the floor below; offset image upward by world height",
    "collision":False,
    "occlusion":"engine fades whole ceiling layer to roughly 40% alpha when character walks beneath it",
    "beam_tiling":"straight E-W 60x14; rotate/use N-S 14x60; join with 36x36 cross and separate brackets",
    "hoist_cable":"engine stretches a 1–2px steel cable between cable_socket_px on trolley and hook; cable shown in composite only",
    "avoidance":"route above clear aisles or near north wall; avoid main furniture and interaction markers"},[
    "Generated original PNGs and prompts are in sources/. No placeholder assembly beam reused.",
    "Overhead artwork is rendered after people in the review composite; asset kit contains no fixed room layout.",
    "All assets use zero-yaw orthographic 3/4 appearance and the Rhodes 31-color palette."])
print("overhead",len(kit.assets),"assets")
