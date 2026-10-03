"""Build H4 medical gameplay assets from generated originals and native state layers."""
from __future__ import annotations

import sys
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
ART = ROOT.parent
sys.path.insert(0, str(ART))
from h3_source_pipeline import reduce_source
from h4_kit import H4Kit
from pixel_kit import COLORS, canvas, draw_text, line, load, rect, rgba

B1 = ART / "batch1_v5"
H3 = ART / "batch_H3_medical_v4"
H3_ORIGINAL = ART / "batch_H3_medical_v1"
kit = H4Kit(ROOT,"medical",(45,41),version=2,
            method="Furniture/equipment uses generated originals, uniform integer reduction and 31-color quantization. Top-down glass partitions, 38px gate clearance, scan-beam and text plates are exact native-grid geometric modules; the E-W strip is a pixel-perfect 90-degree turn of the accepted N-S strip.")


def source(name: str, factor: int) -> Image.Image:
    return reduce_source(ROOT/"sources"/(name+"_source.png"),factor)


# One generated desk frame for both screen states, so the shell and anchor never shift.
reception = source("reception",19)
for state in ("idle","alert"):
    im = reception.copy()
    cx = im.width//2
    if state == "alert":
        rect(im,(cx+7,4,cx+10,7),"Y2")
        rect(im,(cx+12,8,cx+14,9),"Y1")
        # Alert is a recovery report, not the default monitor chart.
        rect(im,(cx-3,8,cx+3,9),"Y2")
    kit.add("medical_reception_"+state,im,kind="prop",zone="reception",
            group="reception",state=state,source="reception_source.png",factor=19,
            emit_colors=("Y2",) if state=="alert" else ("T2","T3"),
            note="Generated curved front counter, shallow top plane, integrated recovery-report terminal. Alert adds yellow status pixels.")

kit.generated("pharmacy_window_source.png","medical_pharmacy_window",23,
              kind="wall",zone="pharmacy",wall=True,emit_colors=("Y2",),
              note="Wall-mounted service window, 36px tall, on the 40px wall face.")
shelf = kit.generated("pharmacy_shelf_source.png","medical_pharmacy_shelf_base",28,
                      kind="wall",zone="pharmacy",wall=True,
                      note="Three-bay shelf; potion sprites are independent full/empty slot contents.")

fulls: dict[str,Image.Image] = {}
empties: dict[str,Image.Image] = {}
for letter,factor in (("a",90),("b",85),("c",90)):
    full = source("potion_"+letter,factor)
    # Fixed-size empty state retains the generated bottle outline and cap, but
    # drains saturated liquid from the lower portion of the vessel.
    empty = full.copy()
    px = empty.load()
    cut = full.height * (5 if letter=="a" else 4) // 12
    saturated = {rgba(n)[:3] for n in ("T0","T1","T2","T3","B0","B1","B2","Y0","Y1","Y2","O0","O1","O2","R0")}
    for y in range(cut,full.height-1):
        for x in range(1,full.width-1):
            if px[x,y][3] and px[x,y][:3] in saturated:
                px[x,y] = rgba("G1" if (x+y)%3 else "W1")
    fulls[letter],empties[letter]=full,empty
    for state,im in (("full",full),("empty",empty)):
        kit.add(f"medical_potion_{letter}_{state}",im,kind="prop",zone="pharmacy",
                group="potion_"+letter,state=state,
                source="potion_"+letter+"_source.png",factor=factor,
                note="Independent pharmacy slot. A/B/C are visual bottle types; gameplay effects remain unspecified.")

for state,contents in (("full",fulls),("empty",empties)):
    im=shelf.copy()
    for i,letter in enumerate("abc"):
        bottle=contents[letter]
        x=(i*shelf.width//3)+((shelf.width//3-bottle.width)//2)
        im.alpha_composite(bottle,(x,max(1,shelf.height-4-bottle.height)))
    kit.add("medical_pharmacy_shelf_"+state,im,kind="wall",zone="pharmacy",wall=True,
            group="pharmacy_shelf_state",state=state,source="pharmacy_shelf_source.png",factor=28,
            note="Three independently addressable bottle slots; this full/empty board is a convenience composite.")

kit.generated("exam_bed_source.png","medical_contamination_exam_bed",25,
              kind="prop",zone="contamination",
              note="Clean examination bed with visible orthographic top/front planes.")
kit.generated("scanner_source.png","medical_contamination_scanner",28,
              kind="prop",zone="contamination",emit_colors=("T2","T3","R0"),
              note="Scanner gantry; place behind/around the examination bed with clear center aperture.")
kit.generated("waiting_chairs_source.png","medical_waiting_chairs_3",26,
              kind="prop",zone="waiting",note="Three front-facing waiting chairs; future operator stand spots.")
kit.generated("nurse_station_source.png","medical_nurse_station",23,
              kind="prop",zone="ward",emit_colors=("B2",),
              note="Nurse station terminal has patient-list content, not warehouse chart UI.")

for label,width in (("CONTAMINATION",90),("WARD",34)):
    sign=canvas(width,13)
    rect(sign,(0,0,width-1,12),"B0")
    rect(sign,(1,1,width-2,11),"W1")
    rect(sign,(2,2,width-3,3),"B1")
    draw_text(sign,label,6 if width>40 else 5,5,5,"B0")
    kit.add("medical_sign_"+label.lower(),sign,kind="wall",zone="contamination" if width>40 else "ward",
            wall=True,note="Accepted 5x7 glyph sheet over native sign plate; no generated lettering.")

for state,color in (("green","E1"),("red","R0")):
    lamp=canvas(10,10)
    rect(lamp,(0,1,9,9),"S2")
    rect(lamp,(2,2,7,7),"D")
    rect(lamp,(3,3,6,6),color)
    kit.add("medical_contamination_door_lamp_"+state,lamp,
            kind="wall",zone="contamination",wall=True,group="contamination_lamp",
            state=state,emit_colors=(color,),
            note="Green normal / red high-contamination door signal; fixed 10x10 frame.")

# North-south top-down glass partition: 6px colored glass cap + 2px floor contact shadow.
for state in ("continuous","door_gap"):
    strip=canvas(8,90)
    for y in range(90):
        if state=="door_gap" and 27<=y<65:
            continue
        rect(strip,(0,y,0,y),"W2")
        rect(strip,(1,y,4,y),"B2")
        rect(strip,(5,y,5,y),"B0")
        rect(strip,(6,y,7,y),"S2")
    if state=="door_gap":
        rect(strip,(0,26,5,26),"G2")
        rect(strip,(0,65,5,65),"G2")
    kit.add("medical_glass_partition_ns_"+state+"_8x90",strip,
            kind="strip",zone="partition",group="glass_partition",state=state,
            note="Top-down N-S glass line, 6px strip + 2px contact shadow; 38px doorway in gap variant.")
    horizontal=strip.transpose(Image.Transpose.ROTATE_270)
    kit.add("medical_glass_partition_ew_"+state+"_90x8",horizontal,
            kind="strip",zone="partition",group="glass_partition_ew",state=state,
            note="Exact native 90-degree turn of accepted N-S glass strip; 6px glass top and 2px lower contact shadow, 38px clear door gap.")

# Side-facing gate is a north-south partition insert. The structural body keeps
# rows 26..63 fully transparent; the pass-through scan beam is a separate emit.
for state,color in (("green","E1"),("red","R0")):
    gate=canvas(20,90)
    for y in list(range(0,26))+list(range(64,90)):
        rect(gate,(6,y,6,y),"W2")
        rect(gate,(7,y,11,y),"B2")
        rect(gate,(12,y,12,y),"B0")
        rect(gate,(13,y,14,y),"S2")
    # Two detector heads aim into the 38px E-W passage.
    rect(gate,(3,19,17,25),"S2")
    rect(gate,(4,20,16,24),"W1")
    rect(gate,(6,23,13,25),"T1")
    rect(gate,(3,64,17,70),"S2")
    rect(gate,(4,65,16,69),"W1")
    rect(gate,(6,64,13,66),"T1")
    rect(gate,(14,12,18,18),"D")
    rect(gate,(15,13,17,16),color)
    kit.add("medical_contamination_gate_ns_"+state+"_20x90",gate,
            kind="strip",zone="contamination_gate",group="contamination_gate_ns",state=state,
            emit_colors=(color,),
            note="Side-facing E-W passage through N-S glass wall. Body has fully transparent 38px clear gap at y=26..63; detector heads and signal lamp are outside it. Align partition strip at gate local x=6.")
beam=canvas(20,90)
for y in range(26,64):
    if y%4 in (0,1):
        rect(beam,(9,y,10,y),"T2")
        rect(beam,(11,y,11,y),"T1")
kit.add("medical_contamination_scan_beam_ns_20x90",beam,
        kind="overlay",zone="contamination_gate",emit_colors=("T2",),
        note="Non-colliding scan beam in 38px clearance; draw above the gate body while active, or hide when idle.")

# Match H1b 32x12 number-plate framing and accepted 5x7 lettering.
plate_ref=ART/"batch_H1b_wayfinding_v1"/"small_number_plate_B1_01.png"
for number in range(1,12):
    plate=load(plate_ref)
    rect(plate,(3,3,28,10),"S1")
    draw_text(plate,f"W-{number:02d}",4,3,5,"G2")
    kit.add(f"medical_room_plate_W_{number:02d}_32x12",plate,
            kind="wall",zone="single_rooms",wall=True,
            note=f"W-{number:02d} on accepted H1b B1 32x12 plate frame; native accepted 5x7 glyphs.")
recovery=canvas(58,12)
rect(recovery,(0,0,57,11),"S2")
rect(recovery,(1,1,56,10),"S1")
rect(recovery,(1,1,56,2),"Y2")
draw_text(recovery,"RECOVERY",5,3,5,"G2")
kit.add("medical_recovery_plate_58x12",recovery,kind="wall",zone="recovery_ward",wall=True,
        note="RECOVERY plate in accepted B1 number-plate framing and 5x7 glyphs.")
kit.dep(plate_ref,"accepted H1b 32x12 number-plate frame")

# The accepted H3 ward bed is the common state frame. Only the bedding/patient
# region comes from a uniformly reduced edit of its original source.
bed_path = H3/"medical_ward_bed.png"
bed_empty=load(bed_path)
kit.add("medical_ward_bed_empty",bed_empty,kind="prop",zone="ward",
        group="ward_bed",state="empty",note="Byte-compatible accepted H3 v4 empty ward bed.")
occupied_src=source("occupied_bed",28)
occupied_crop=occupied_src.crop(((occupied_src.width-bed_empty.width)//2,
                                (occupied_src.height-bed_empty.height)//2,
                                (occupied_src.width+bed_empty.width)//2,
                                (occupied_src.height+bed_empty.height)//2))
bed_occ=bed_empty.copy()
overlay=occupied_crop.copy()
mask=Image.new("L",bed_empty.size,0)
ImageDraw.Draw(mask).rectangle((6,4,bed_empty.width-7,20),fill=255)
overlay.putalpha(Image.composite(overlay.getchannel("A"),Image.new("L",bed_empty.size,0),mask))
bed_occ.alpha_composite(overlay)
kit.add("medical_ward_bed_occupied",bed_occ,kind="prop",zone="ward",
        group="ward_bed",state="occupied",source="occupied_bed_source.png",factor=28,
        note="Accepted bed frame preserved; generated patient/blanket bedding inserted at same 53x34 anchor.")
kit.dep(bed_path,"accepted H3 v4 ward-bed geometry")
kit.dep(H3/"medical_recovery_bed.png","accepted H3 recovery bed for death wake-up point")

# Small staff stand spots use native, unobtrusive floor marks.
for number in (1,2):
    spot=canvas(12,6)
    rect(spot,(1,3,10,4),"B1")
    rect(spot,(4,1,7,2),"T2")
    kit.add(f"medical_staff_stand_spot_{number}",spot,kind="decal",zone="ward" if number==2 else "reception",
            note="Stand spot for future unnamed medical operator; currently empty.")

kit.preview("H4_medical_lappland_1x",H3_ORIGINAL/"medical_wall_white_60x46.png",
            H3_ORIGINAL/"medical_floor_cool_120x120.png",[
                ("medical_pharmacy_window",3,6),
                ("medical_pharmacy_shelf_full",89,11),
                ("medical_sign_contamination",244,5),
                ("medical_waiting_chairs_3",5,106),
                ("medical_reception_alert",87,116),
                ("medical_contamination_gate_ns_green_20x90",220,75),
                ("medical_contamination_scan_beam_ns_20x90",220,75),
                ("medical_glass_partition_ew_door_gap_90x8",239,151),
                ("medical_recovery_plate_58x12",167,53),
                ("medical_room_plate_W_01_32x12",293,153),
                ("medical_nurse_station",8,172),
                ("medical_ward_bed_occupied",273,171),
            ],B1/"lappland_frame0_64.png",(166,140),(360,240))
kit.finish("H4_medical_lappland_1x",{
    "room_px": [675,523], "room_units": [45,41],
    "lobby": "west x=0..14 units; reception, three waiting-chair rows and pharmacy window",
    "contamination_gate": "only entrance from lobby into ward region; side-facing gate in N-S glass partition, local clear aperture [0,26,20,38], render scan beam separately",
    "recovery_ward": "central 16x19-unit square at x=21.5..37.5 units, four doors, accepted recovery bed and nurse station",
    "ring_corridor": "4 units wide around the central recovery ward",
    "single_rooms": "plates W-01 through W-11 provided; room placement and final assembly by user",
    "front_reception": "place near room entry with stand spot",
    "pharmacy": "place window and shelf separately on 40px wall face; each bottle has independent full/empty state",
    "contamination": "side-facing gate controls only entrance to ward area; red/green signal by threshold",
    "ward": "reuse H3 recovery bed for Lappland wake-up; ward bed states are 53x34 fixed",
    "glass_partition": "N-S and E-W native glass strips plus 38px door gaps; only outer north wall uses elevation",
    "state_switch": "Swap equal-size sprites within state_group without changing transforms."},[
    "A/B/C potion names are temporary visual identifiers; no medical effect or balance value is implied.",
    "No new Lappland death or injury animation; occupied ward bed is a generic future patient.",
    "§3.5 A: generated shaded top/front planes; B: department signs/blue graphic bands; C: pharmacy, scanner and warning emits; D: stand spots, charts, patient and status switches."])
print("medical",len(kit.assets),"assets")
