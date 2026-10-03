"""Build H4 warehouse gameplay states from saved image sources and native decals."""
from __future__ import annotations

import sys
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
ART = ROOT.parent
sys.path.insert(0, str(ART))
from h3_source_pipeline import reduce_source
from h4_kit import H4Kit
from pixel_kit import canvas, draw_text, line, load, poly, rect, rgba

H2 = ART / "batch_H2_warehouse_v2"
B1 = ART / "batch1_v5"
kit = H4Kit(ROOT, "warehouse", (60, 32), version=2)


def align(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    assert image.width <= size[0] and image.height <= size[1]
    result = canvas(*size)
    result.alpha_composite(image, ((size[0] - image.width) // 2, size[1] - image.height))
    return result


def cargo_icon(category: str) -> Image.Image:
    im = canvas(14, 14)
    d = ImageDraw.Draw(im)
    if category == "weapon":
        poly(im, [(6,1),(9,1),(8,7),(7,9),(5,9),(5,7)], "G2")
        rect(im,(3,9,10,10),"Y2"); rect(im,(6,11,7,13),"S2")
    elif category == "armor":
        poly(im, [(2,2),(11,2),(11,8),(7,12),(2,8)], "G2")
        poly(im, [(4,4),(9,4),(9,8),(7,10),(4,8)], "B0")
    elif category == "trinket":
        d.ellipse((4,1,9,6),outline=rgba("G2"),width=2)
        poly(im, [(7,5),(11,9),(7,13),(3,9)], "Y2")
        rect(im,(6,8,8,10),"T2")
    else:
        poly(im,[(7,1),(12,5),(10,11),(5,13),(1,8),(3,3)],"D")
        poly(im,[(6,4),(9,5),(8,9),(5,9)],"O2")
    return im


for category in ("weapon", "armor", "trinket", "material"):
    kit.add("warehouse_category_"+category+"_14x14", cargo_icon(category), kind="icon",
            zone="storage", note="Upright category icon; weapon / armor / trinket / material.")

# Pair states use the same native outer canvas and bottom-center anchor. No axis is resampled.
for size, factor in (("small",60),("medium",45),("large",35)):
    variants = {state: reduce_source(ROOT/"sources"/f"crate_{size}_{state}_source.png",factor)
                for state in ("sealed","open")}
    bounds = (max(v.width for v in variants.values()), max(v.height for v in variants.values()))
    for state, image in variants.items():
        kit.add(f"warehouse_loot_crate_{size}_{state}",align(image,bounds),kind="prop",
                zone="receiving",state=state,group=f"crate_{size}",
                source=f"crate_{size}_{state}_source.png",factor=factor,
                note="Sealed hides contents; opened reveals the empty dark cavity. Bottom-center aligned.")

for name, factor, zone in (("cargo_drone",40,"storage"),
                           ("dispatch_pallet",36,"dispatch")):
    kit.generated(name+"_source.png","warehouse_"+name,factor,kind="prop",zone=zone,
                  emit_colors=("T2",) if name=="cargo_drone" else (),
                  note="Generated front-facing equipment; icon-free small hardware.")

trolley_path=H2/"warehouse_trolley_42x34.png"
kit.add("warehouse_trolley_empty",load(trolley_path),kind="prop",zone="carry-in",
        group="carry_trolley",state="empty",note="Accepted H2 empty trolley, unchanged.")
loaded=align(reduce_source(ROOT/"sources"/"trolley_loaded_source.png",35),(42,34))
kit.add("warehouse_trolley_loaded",loaded,kind="prop",zone="carry-in",
        group="carry_trolley",state="loaded",source="trolley_loaded_source.png",factor=35,
        note="Generated cargo; exact 42x34 accepted trolley state box, bottom-center anchor.")
kit.dep(trolley_path,"accepted 42x34 trolley empty state")

# H2 rack outer frame is locked. Retire the bottle contents and replace them with trinkets.
rack_path = H2/"warehouse_rack_consumables_80x64.png"
rack = load(rack_path)
ImageDraw.Draw(rack).rectangle((9,10,69,56),fill=(0,0,0,0))
for y in (21,38,55):
    rect(rack,(8,y,70,y+2),"S3")
trinkets = reduce_source(ROOT/"sources"/"trinkets_source.png",34)
for j in range(4):
    piece = trinkets.crop((j*trinkets.width//4,0,(j+1)*trinkets.width//4,trinkets.height))
    rack.alpha_composite(piece,(11+j*15,37-piece.height))
    rack.alpha_composite(piece,(11+j*15,54-piece.height))
rect(rack,(9,0,70,8),"S2")
draw_text(rack,"B1-03-C",19,1,5,"G2")
kit.add("warehouse_rack_trinket_80x64",rack,kind="prop",zone="storage",
        source="trinkets_source.png",factor=34,
        note="Dedicated trinket rack; accepted H2 80x64 frame, generated pendants, B1-03-C header in accepted 5x7 glyphs.")
kit.dep(rack_path,"accepted rack frame geometry, category contents retired")

# The 12x12 slot sprite goes inside each existing rack opening; positions are top-left.
slot_empty = canvas(12,12)
rect(slot_empty,(0,0,11,11),"S1"); rect(slot_empty,(1,1,10,10),"S0")
rect(slot_empty,(2,9,9,10),"S2")
slot_full = slot_empty.copy()
poly(slot_full,[(3,7),(5,3),(8,3),(10,7),(8,9),(3,9)],"G1")
rect(slot_full,(4,5,7,6),"Y2")
for state,im in (("empty",slot_empty),("filled",slot_full)):
    kit.add("warehouse_shelf_slot_"+state+"_12x12",im,kind="overlay",zone="storage",
            state=state,group="shelf_slot",note="Place on accepted rack cells; x=12,27,42,57; y=10,27,44. Cell replacement overlay.")

for idx in range(4):
    category=("weapon","armor","trinket","material")[idx]
    for row in (1,2):
        plate=canvas(21,10)
        rect(plate,(0,0,20,9),"S0");rect(plate,(1,1,19,8),"S2")
        draw_text(plate,f"{chr(65+idx)}{row}",4,2,3,"G2")
        kit.add(f"warehouse_rack_plate_{category}_{row}",plate,kind="sign",zone="storage",
                note="Rack-head numbering A1–D2; 3x5 accepted glyphs.")

# Floor category frames retain H2's 90x44 geometry. Highlight adds only native-grid pixels.
for category in ("weapon","armor","trinket","material"):
    for state in ("normal","highlight"):
        im=canvas(90,44)
        edge="T2" if state=="highlight" else "Y1"
        for x in range(2,88):
            if (x//7)%2==0:
                rect(im,(x,1,x,2),edge);rect(im,(x,41,x,42),edge)
        for y in range(3,41):
            if (y//5)%2==0:
                rect(im,(1,y,2,y),edge);rect(im,(87,y,88,y),edge)
        rect(im,(6,5,83,5),"S2");rect(im,(6,38,83,38),"S2")
        im.alpha_composite(cargo_icon(category),(8,14))
        draw_text(im,category.upper(),27,18,5,"T3" if state=="highlight" else "G2")
        kit.add(f"warehouse_zone_{category}_{state}_90x44",im,kind="decal",zone="storage",
                group="zone_"+category,state=state,
                emit_colors=("T2","T3") if state=="highlight" else (),
                note="Matching-category carry highlight; native 90x44 floor frame, transparent outside strokes.")

head=canvas(22,22)
rect(head,(1,1,20,20),"S2");rect(head,(2,2,19,19),"B0")
rect(head,(3,3,18,18),"S0")
for x in range(5,17):
    if x%2==0: rect(head,(x,0,x,0),"T2")
kit.add("warehouse_carried_item_frame_22x22",head,kind="overlay",zone="carry",
        note="Draw at character head top minus 24px; place 14x14 category icon at (4,4).")

board=reduce_source(ROOT/"sources"/"order_board_source.png",25)
for state in ("empty","open","completed"):
    im=board.copy()
    # Cards are state overlays on one generated board frame.
    if state!="empty":
        for k in range(3):
            x=6+k*20
            rect(im,(x,13,x+16,31),"G2")
            rect(im,(x+1,14,x+15,30),"W1")
            im.alpha_composite(cargo_icon(("material","weapon","armor")[k]).crop((0,0,9,9)),(x+4,16))
            if state=="completed":
                line(im,[(x+2,25),(x+6,28),(x+13,21)],"E1",2)
            else:
                rect(im,(x+3,27,x+12,28),"Y1")
    kit.add("warehouse_order_board_"+state,im,kind="wall",zone="dispatch",wall=True,
            group="order_board",state=state,source="order_board_source.png",factor=25,
            emit_colors=("E1",) if state=="completed" else ("Y2",) if state=="open" else (),
            note="Three board states share the same generated frame and wall anchor.")

for n in range(1,7):
    im=canvas(30,25)
    rect(im,(1,1,28,23),"Y1");rect(im,(3,3,26,21),"S1")
    draw_text(im,f"R{n:02d}",5,9,3,"Y2")
    for x in (2,27): rect(im,(x,5,x,19),"Y2")
    kit.add(f"warehouse_receiving_bay_R{n:02d}_30x25",im,kind="decal",zone="receiving",
            note="Numbered crate bay. Slot counts configurable; six examples R01–R06.")

kit.preview("H4_warehouse_lappland_1x",B1/"wall_straight_60x46_v5.png",
            ART/"batch2_v2"/"rhodes_floor_v1.png",[
                ("warehouse_rack_trinket_80x64",8,44),
                ("warehouse_order_board_open",108,48),
                ("warehouse_zone_trinket_highlight_90x44",8,133),
                ("warehouse_receiving_bay_R01_30x25",131,143),
                ("warehouse_loot_crate_small_sealed",133,112),
                ("warehouse_loot_crate_medium_open",188,98),
                ("warehouse_cargo_drone",222,45),
                ("warehouse_dispatch_pallet",244,146),
                ("warehouse_trolley_loaded",304,127),
                ("warehouse_carried_item_frame_22x22",77,104),
                ("warehouse_category_trinket_14x14",81,108),
            ],B1/"lappland_frame0_64.png",(56,130),(360,220))
for dependency,purpose in (("warehouse_rack_weapons_80x64.png","accepted WEAPON rack"),
                           ("warehouse_rack_armor_80x64.png","accepted ARMOR rack"),
                           ("warehouse_rack_materials_80x64.png","accepted MATERIAL rack"),
                           ("warehouse_storage_terminal_on_64x52.png","accepted dispatch/storage terminal"),
                           ("warehouse_freight_lift_idle_96x56.png","accepted receiving lift")):
    kit.dep(H2/dependency,purpose)
kit.finish("H4_warehouse_lappland_1x",{
    "room_px": [900,408], "receiving_bay_codes": [f"R{x:02d}" for x in range(1,7)],
    "rack_cell_top_left_px": [[x,y] for y in (10,27,44) for x in (12,27,42,57)],
    "carry_icon_offset_px": [4,4],
    "state_switch": "Swap paired sprites by state_group; no transform or anchor change.",
    "accepted_dependencies": "Use H2 weapon/armor/material racks, storage terminal, counter, forklift, wall bay and floor unchanged."},[
    "Only four categories exist: weapon, armor, trinket, material. H2 consumables rack and zone are retired.",
    "Crate size does not reveal contents until opened; source art includes no category logo.",
    "S-logo is absent from ordinary racks, trolley, pallets and crates; H2 main terminal/supergraphic remain representative logo placements.",
    "§3.5 A: volume from generated top/front surfaces; B: zone lines, rack codes and receiving numbers; C: lit state outlines; D: slot/board/crate interaction states."])
print("warehouse",len(kit.assets),"assets")
