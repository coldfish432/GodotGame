"""Deterministic native-resolution equipment sprites for the v1.0 art brief.

Run with: python art/items/generate_equipment_icons.py
Requires Pillow. All item pixels are selected from §6.3 of 装备策划案_v1_0.md.
"""
from __future__ import annotations

import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent
C = {
    "ink": "#141518", "iron0": "#2a2d33", "iron1": "#3a3f45", "iron2": "#6b737b",
    "iron3": "#a9b2b8", "iron4": "#e3e8ea", "leather0": "#3b2a20",
    "leather1": "#6a4a33", "leather2": "#9a7050", "cloth0": "#2b2f36",
    "cloth1": "#4a505a", "cloth2": "#7a808a",
}
M = {"rust0":"#5a3424","rust1":"#8e5232","rust2":"#c07a45","canvas0":"#6b5d48",
     "canvas1":"#9a8a68","ore0":"#ee8a24","ore1":"#ffb35a","yellow":"#d8a520",
     "white":"#d9d6cc","red":"#9c2b25"}
L = {"navy0":"#1f2e44","navy1":"#34506e","navy2":"#5f84a8","concrete":"#7a7c80",
     "red0":"#8e1f1f","red1":"#c23a2a","brass0":"#8a6a2a","brass1":"#c9a24a",
     "reflect":"#c8d860","green":"#68d848"}
S = {"wood0":"#5b3e28","wood1":"#8a6440","bone0":"#b9ae95","bone1":"#e6dfcc",
     "fur0":"#a68c6c","fur1":"#d8cbb5","ice0":"#5d8fb0","ice1":"#9cc8e0",
     "ice2":"#e4f4fb","red":"#b03a2e","yellow":"#d9a43a","blue":"#3f6fa8",
     "orange":"#d0662a"}
PALETTES = {"mine": {**C, **M}, "city": {**C, **L}, "snow": {**C, **S}}

# batch, id, name, region, kind, descriptive art note, emit palette keys
ITEMS = [
 ("E1","modified_machete","改装砍刀","mine","weapon","wide straight steel-plate machete, weld, taped grip",[]),
 ("E1","standard_dagger","制式短刀","mine","weapon","narrow short blade, standard guard, filed nameplate",[]),
 ("E1","mine_issue_blade","矿区制式刀","mine","weapon","plain straight blade, wood handle, iron ferrule",[]),
 ("E1","patrol_saber","纠察队佩刀","mine","weapon","slightly curved saber, brass half-bow guard, red root",[]),
 ("E1","pickhaft_blade","镐柄战刃","mine","weapon","long haft, short heavy edge, hooked half-pick",[]),
 ("E1","miner_vest","矿工护甲","mine","armor","canvas vest, leather shoulders, blank white cloth patch, unlit lamp",[]),
 ("E1","reunion_coat","整合运动制式外套","mine","armor","dark hooded coat, red left armband, torn hem",[]),
 ("E1","patrol_winter_coat","纠察队防寒大衣","mine","armor","double-breasted gray-green coat, fur collar, torn epaulette",[]),
 ("E1","heavy_mine_suit","矿场重型防护服","mine","armor","bulky sealed suit, round filter, yellow hazard shoulder",[]),
 ("E1","dust_mask","防尘面罩","mine","trinket","front half-mask, two round filters, broken head strap",[]),
 ("E1","liquor_flask","烈酒扁壶","mine","trinket","curved metal flask, neck cord, dent",[]),
 ("E1","reunion_mask","整合运动面具","mine","trinket","white full-face mask, two horizontal eye slits, crack",[]),
 ("E1","originium_meter","源石感应计","mine","trinket","small gauge box, needle at maximum, orange lamp",["ore1"]),
 ("E2","finger_blade","指刃","city","weapon","knuckle grip with four visible holes, short blade",[]),
 ("E2","gang_machete","帮派砍刀","city","weapon","broad tip, narrow root, red cord on butt",[]),
 ("E2","lgd_knife","近卫局警用刀","city","weapon","straight service knife, black grip, three non-text dots",[]),
 ("E2","courier_dagger","押运短刃","city","weapon","single edge short knife, nylon strap and sheath clasp",[]),
 ("E2","yan_ring_saber","炎式环首刀","city","weapon","slender straight blade, ring pommel, red tassel, fuller",[]),
 ("E2","lgd_vest","近卫局制式护甲","city","armor","navy vest, two reflective bars, abstract shoulder patch",[]),
 ("E2","fire_suit","消防署隔热服","city","armor","pale foil coat, yellow sleeve and hem bands, scorched corner",[]),
 ("E2","courier_vest","押运防弹背心","city","armor","black plate carrier, three pouches, one empty slot",[]),
 ("E2","inspector_armor","特别督察组战术护甲","city","armor","full tactical chest, shoulders, neck, red ID bar",[]),
 ("E2","tactical_charm","战术挂饰","city","trinket","short webbing, D ring, tiny flashlight",["reflect"]),
 ("E2","lgd_radio","近卫局对讲机","city","trinket","upright radio, short antenna, green status lamp",["green"]),
 ("E2","lungmen_wallet","龙门币钱夹","city","trinket","leather wallet, brass clasp, blank golden slip",[]),
 ("E2","yan_talisman","炎式平安符","city","trinket","red cloth charm, gold round motif, tassel, no glyph",[]),
 ("E3","icebreaker_knife","破冰刀","snow","weapon","thick short chisel tip, white frost flecks",[]),
 ("E3","skinning_knife","猎刀","snow","weapon","thin skinning blade with upswept tip, hide cord",[]),
 ("E3","antler_hunter_knife","角柄猎刀","snow","weapon","straight edge, curved antler grip, tiny woven tape",[]),
 ("E3","expedition_machete","科考队开路刀","snow","weapon","modern sawback machete, orange plastic guard",[]),
 ("E3","snowpriest_blade","雪祀礼刃","snow","weapon","long curved blade, ivory grip, three-color tape, ice marks",["ice2"]),
 ("E3","tundra_fur_coat","冰原毛皮外套","snow","armor","thick leather coat with jagged fur collar",[]),
 ("E3","sled_patrol_cloak","雪橇巡逻队斗篷","snow","armor","white hooded cape with red and yellow hem",[]),
 ("E3","expedition_parka","科考队防寒服","snow","armor","orange puffer coat with reflective bars and high zip",[]),
 ("E3","bone_lamellar","骨片札甲","snow","armor","rows of bone armor tied with leather, scapula shoulders",[]),
 ("E3","bone_amulet","骨制护符","snow","trinket","small perforated bone on cord, three scratches",[]),
 ("E3","antler_flute","角兽骨笛","snow","trinket","short bone flute, three holes, colorful end tape",[]),
 ("E3","bone_drumstick","兽骨鼓槌","snow","trinket","wooden shaft, bone mallet head, hide strip and feather",[]),
 ("E3","cipher_fragment","密文板残片","snow","trinket","jagged stone tablet with abstract blue-white grooves",["ice2"]),
 ("E4","raw_originium","未封装源石原矿","mine","ore","vertical dark ore rock, orange crystal prisms and chips",["ore0","ore1"]),
 ("E4","riot_shield","近卫局暴动盾","city","shield","front rectangular riot shield, blue viewport, reflection, scratches",[]),
 ("E4","frozen_relic","冻土下的旧物","snow","relic","carved bone piece half frozen in ice block",[]),
 ("E4","lord_blade","领主宽刃","city","weapon","extremely wide almost square blade, transverse scuffs",[]),
 ("E4","twin_fang","双生狼牙","snow","weapon","two crossed curved blades, white glints",["ice2"]),
 ("E4","ember_fang","余烬之牙","snow","weapon","single blade with dark red-orange ember ridge",["red","orange"]),
 ("E4","moon_edge","月下刃","snow","weapon","fine curved blade with continuous cold-white highlight",["ice2"]),
 ("E4","crystal_edge","源石结晶刃","mine","weapon","blade broken by two orange crystal clusters",["ore0","ore1"]),
 ("E4","vein_core","共振矿芯","mine","trinket","metal frame, orange crystal core, three vibration marks",["ore0","ore1"]),
 ("E4","shadow_bracer","残影护腕","city","trinket","front wrist guard with displaced dark afterimage",[]),
 ("E4","spike_plate","尖刺重铠","mine","armor","heavy iron plate with shoulder and chest spikes",[]),
 ("E4","bash_shield","反击塔盾","city","shield","tall tower shield, protruding steel boss, red rim",[]),
]

def size_for(kind):
    return {"weapon":(36,16),"armor":(36,36),"shield":(36,36),"trinket":(16,16),
            "ore":(16,36),"relic":(36,16)}[kind]

def poly(d, xy, fill): d.polygon(xy, fill=fill)
def line(d, xy, fill, width=1): d.line(xy, fill=fill, width=width)

def blade(d, key, p):
    city = key in {"finger_blade","gang_machete","lgd_knife","courier_dagger","yan_ring_saber","lord_blade"}
    snow = key in {"icebreaker_knife","skinning_knife","antler_hunter_knife","expedition_machete","snowpriest_blade","twin_fang","ember_fang","moon_edge"}
    metal = p["iron2"] if not snow else p["bone0"]
    shine = p["iron3"] if not snow else p["ice1"]
    dark = p["iron1"]
    leather = p["leather1"] if not snow else p["wood1"]
    def handle(y=7, x0=2, x1=12):
        poly(d,[(x0,y-2),(x1,y-2),(x1,y+2),(x0,y+2)], leather)
        line(d,[(x0+2,y-2),(x0+2,y+1)],p["leather2"])
        line(d,[(x0+5,y-2),(x0+5,y+1)],p["leather0"])
        line(d,[(x0+8,y-2),(x0+8,y+1)],p["leather2"])
    def guard(x=12,y=7,tall=3): line(d,[(x,y-tall),(x,y+tall)],p["iron3"],2)
    if key == "pickhaft_blade":
        handle(8,2,23); poly(d,[(23,5),(30,4),(34,6),(30,10),(24,11)],p["iron2"])
        poly(d,[(23,4),(25,2),(26,1),(28,2),(27,6)],p["rust1"])
        line(d,[(4,6),(20,6)],p["canvas1"])
    elif key == "finger_blade":
        poly(d,[(3,6),(16,5),(17,10),(3,11)],p["navy2"])
        for x in (5,8,11,14): d.point((x,8),fill=(0,0,0,0))
        poly(d,[(17,6),(23,5),(28,6),(34,7),(29,10),(17,10)],p["iron2"])
        line(d,[(20,6),(27,6)],p["iron3"])
    elif key == "yan_ring_saber":
        d.ellipse((1,4,7,10),outline=p["brass1"],width=2)
        poly(d,[(7,6),(13,5),(13,9),(7,9)],p["leather0"])
        guard(14,7,2)
        poly(d,[(15,5),(31,5),(34,7),(31,10),(15,10)],p["iron2"])
        line(d,[(16,6),(31,6)],p["iron4"])
        line(d,[(18,8),(29,8)],p["iron1"])
        line(d,[(3,10),(2,13)],p["red1"],2)
    elif key == "twin_fang":
        for y, tip in ((4,31),(10,34)):
            poly(d,[(2,y-1),(8,y-2),(9,y+1),(2,y+2)],p["wood1"])
            poly(d,[(9,y-2),(24,y-2),(tip,y-3),(tip-3,y+1),(21,y+2),(9,y+2)],p["ice0"])
            line(d,[(11,y-2),(23,y-2)],p["ice1"])
        d.point((26,3),fill=p["ice2"])
        d.point((28,9),fill=p["ice2"])
    else:
        handle()
        if key in {"antler_hunter_knife","snowpriest_blade"}:
            poly(d,[(2,6),(5,5),(12,6),(12,9),(5,10),(2,9)],p["bone0"])
            line(d,[(3,6),(9,6)],p["bone1"])
        if key == "gang_machete":
            line(d,[(3,5),(7,5)],p["red1"],2)
        if key == "courier_dagger":
            line(d,[(2,11),(13,11)],p["navy1"],2)
        if key == "expedition_machete": guard(13,7,3); line(d,[(12,3),(14,3)],p["orange"],2)
        elif key not in {"skinning_knife","icebreaker_knife"}: guard(13,7,3)
        shapes = {
          "modified_machete":[(14,4),(30,4),(34,6),(33,11),(29,12),(14,11)],
          "standard_dagger":[(14,6),(25,6),(30,8),(25,10),(14,10)],
          "mine_issue_blade":[(14,5),(30,5),(34,7),(30,11),(14,11)],
          "patrol_saber":[(14,5),(27,4),(34,5),(32,8),(27,10),(14,10)],
          "gang_machete":[(14,6),(23,5),(32,3),(34,4),(34,11),(28,12),(14,10)],
          "lgd_knife":[(14,6),(28,6),(33,8),(28,10),(14,10)],
          "courier_dagger":[(14,6),(27,5),(32,7),(28,10),(14,10)],
          "icebreaker_knife":[(13,5),(31,5),(33,6),(33,11),(13,11)],
          "skinning_knife":[(13,7),(27,6),(33,3),(31,8),(26,10),(13,10)],
          "antler_hunter_knife":[(13,5),(29,5),(34,7),(30,10),(13,10)],
          "expedition_machete":[(14,5),(18,5),(19,3),(21,5),(23,3),(25,5),(31,5),(34,8),(30,12),(14,11)],
          "snowpriest_blade":[(14,6),(24,5),(32,3),(34,4),(31,8),(25,10),(14,10)],
          "ember_fang":[(14,5),(30,4),(34,6),(30,10),(14,11)],
          "moon_edge":[(14,6),(24,5),(33,2),(34,4),(30,9),(24,11),(14,11)],
          "crystal_edge":[(14,5),(29,5),(34,7),(30,11),(14,11)],
          "lord_blade":[(14,3),(31,3),(34,4),(34,12),(30,13),(14,12)],
        }
        poly(d,shapes[key],metal)
        if key not in {"skinning_knife","moon_edge"}: line(d,[(15,5),(min(29,shapes[key][1][0]),5)],shine)
        if key == "modified_machete": line(d,[(22,5),(22,10)],p["rust2"])
        elif key == "standard_dagger": d.rectangle((12,6,14,7),fill=p["iron1"])
        elif key == "mine_issue_blade": d.rectangle((11,5,13,9),fill=p["iron2"])
        elif key == "patrol_saber":
            line(d,[(13,4),(18,3),(19,9)],p["rust2"])
            d.point((15,6),fill=p["red"])
        elif key == "gang_machete": line(d,[(27,10),(32,10)],p["iron3"])
        elif key == "lgd_knife":
            for x in (4,6,8): d.point((x,7),fill=p["iron3"])
        elif key == "courier_dagger": d.rectangle((7,10,10,12),fill=p["navy2"])
        elif key == "icebreaker_knife":
            for x in (21,26,30): d.point((x,7),fill=p["ice2"])
        elif key == "antler_hunter_knife": line(d,[(3,11),(5,13)],p["red"])
        elif key == "snowpriest_blade":
            for x,c in zip((12,13,14),("red","yellow","blue")): d.point((x,10),fill=p[c])
            line(d,[(22,7),(29,5)],p["ice1"])
            d.point((24,6),fill=p["ice2"])
            d.point((28,5),fill=p["ice2"])
        elif key == "ember_fang": line(d,[(17,7),(29,6)],p["red"],2); line(d,[(20,7),(28,6)],p["orange"])
        elif key == "moon_edge": line(d,[(17,8),(26,7),(31,5)],p["ice2"])
        elif key == "crystal_edge":
            poly(d,[(21,5),(23,1),(25,5),(24,9)],p["ore0"])
            poly(d,[(28,6),(30,2),(32,7),(30,10)],p["ore1"])
        elif key == "lord_blade":
            for y in (6,9): line(d,[(22,y),(29,y-1)],p["iron3"])
    if key == "patrol_saber": line(d,[(13,4),(16,3),(19,4)],p["rust2"])

def armor(d,key,p):
    snow = key in {"tundra_fur_coat","sled_patrol_cloak","expedition_parka","bone_lamellar"}
    city = key in {"lgd_vest","fire_suit","courier_vest","inspector_armor"}
    base = p["fur0"] if snow else p["navy0"] if city else p["canvas0"]
    if key in {"reunion_coat","courier_vest"}: base=p["cloth0"]
    if key == "fire_suit": base=p["concrete"]
    if key == "expedition_parka": base=p["orange"]
    if key == "sled_patrol_cloak": base=p["bone1"]
    if key == "spike_plate": base=p["iron1"]
    # Shape family changes the silhouette at collar, shoulders and hem.
    if key == "sled_patrol_cloak":
        poly(d,[(13,4),(23,4),(27,9),(31,31),(27,34),(9,34),(5,31),(9,9)],base)
        poly(d,[(13,3),(23,3),(26,8),(23,15),(13,15),(10,8)],p["fur1"])
        poly(d,[(15,6),(21,6),(22,10),(14,10)],p["bone0"])
    elif key == "heavy_mine_suit":
        poly(d,[(13,4),(23,4),(26,7),(33,8),(34,16),(29,20),(29,32),(24,34),(20,30),(16,30),(12,34),(7,32),(7,20),(2,16),(3,8),(10,7)],base)
    elif key == "spike_plate":
        poly(d,[(13,5),(23,5),(30,8),(34,5),(32,16),(29,18),(29,31),(23,34),(13,34),(7,31),(7,18),(4,16),(2,5),(8,8)],base)
        for x in (5,10,27,31): poly(d,[(x-2,9),(x,2),(x+2,10)],p["iron2"])
    elif key == "reunion_coat":
        poly(d,[(13,5),(23,5),(29,7),(33,15),(29,18),(29,31),(26,33),(22,31),(18,34),(14,31),(10,33),(7,31),(7,18),(3,15),(7,7)],base)
        poly(d,[(14,4),(22,4),(25,9),(22,13),(14,13),(11,9)],p["cloth1"])
    elif key in {"miner_vest","lgd_vest","courier_vest"}:
        poly(d,[(12,6),(24,6),(28,10),(31,17),(28,21),(27,31),(9,31),(8,21),(5,17),(8,10)],base)
    elif key == "expedition_parka":
        poly(d,[(13,3),(23,3),(27,8),(30,10),(33,18),(29,21),(28,32),(23,34),(13,34),(8,32),(7,21),(3,18),(6,10),(9,8)],base)
    else:
        poly(d,[(12,5),(24,5),(29,9),(33,17),(29,20),(28,32),(23,34),(13,34),(8,32),(7,20),(3,17),(7,9)],base)
    # Common chest-plane and symmetrical depth blocks.
    shade = p["fur1"] if snow else p["navy1"] if city else p["canvas1"]
    if key == "fire_suit": shade=p["iron3"]
    if key == "expedition_parka": shade=p["leather2"]
    if key == "spike_plate": shade=p["iron2"]
    poly(d,[(12,12),(18,15),(24,12),(27,16),(26,29),(22,31),(14,31),(10,29),(9,16)],shade)
    line(d,[(11,13),(11,27)],p["iron3"] if key=="fire_suit" else shade)
    if key == "miner_vest":
        poly(d,[(7,10),(12,7),(15,12),(11,17),(6,16)],p["leather1"])
        poly(d,[(29,10),(24,7),(21,12),(25,17),(30,16)],p["leather1"])
        d.rectangle((14,17,21,19),fill=p["white"])
        d.ellipse((23,27,27,31),fill=p["iron2"])
    elif key == "reunion_coat":
        line(d,[(17,13),(16,30)],p["cloth2"]); d.rectangle((6,15,9,17),fill=p["red"])
        poly(d,[(24,31),(27,31),(28,27),(25,29)],p["cloth0"])
    elif key == "patrol_winter_coat":
        poly(d,[(11,7),(16,4),(18,12),(13,15)],p["white"])
        poly(d,[(25,7),(20,4),(18,12),(23,15)],p["white"])
        for y in (18,23,28): d.point((15,y),fill=p["iron3"]);d.point((21,y),fill=p["iron3"])
        d.point((10,7),fill=p["rust1"])
    elif key == "heavy_mine_suit":
        d.ellipse((13,15,23,25),fill=p["iron1"],outline=p["iron3"])
        for x in (5,27):
            poly(d,[(x,9),(x+4,8),(x+5,13),(x+1,15)],p["yellow"])
            d.point((x+2,11),fill=p["iron1"])
    elif key == "lgd_vest":
        for y in (18,24): d.rectangle((12,y,24,y+1),fill=p["reflect"])
        d.rectangle((7,9,10,12),fill=p["navy2"])
    elif key == "fire_suit":
        for x in (4,29): d.rectangle((x,17,x+3,18),fill=p["reflect"])
        d.rectangle((9,29,27,30),fill=p["reflect"])
        poly(d,[(26,30),(29,28),(28,33),(24,33)],p["cloth0"])
    elif key == "courier_vest":
        for x in (12,17,22): d.rectangle((x,20,x+3,26),fill=p["cloth1"])
        d.rectangle((21,17,25,19),fill=p["cloth0"])
    elif key == "inspector_armor":
        poly(d,[(7,10),(12,8),(15,14),(10,18),(4,17)],p["navy2"])
        poly(d,[(29,10),(24,8),(21,14),(26,18),(32,17)],p["navy2"])
        poly(d,[(14,8),(22,8),(23,13),(13,13)],p["iron2"])
        d.rectangle((20,17,25,18),fill=p["red1"])
    elif key == "tundra_fur_coat":
        for x in (8,11,14,20,23,26): poly(d,[(x,8),(x+2,11),(x+1,15),(x-1,12)],p["fur1"])
        line(d,[(12,16),(12,28)],p["wood1"]);line(d,[(24,16),(24,28)],p["wood1"])
    elif key == "sled_patrol_cloak":
        for x in range(8,29,4): d.rectangle((x,30,x+1,31),fill=p["red"]);d.point((x+2,32),fill=p["yellow"])
    elif key == "expedition_parka":
        for y in (16,21,26): line(d,[(10,y),(26,y)],p["wood1"])
        line(d,[(18,9),(18,30)],p["iron3"])
        for x in (4,29): d.rectangle((x,16,x+3,17),fill=p["ice2"])
    elif key == "bone_lamellar":
        for y in (15,20,25):
            for x in (10,15,20,25): d.rectangle((x,y,x+3,y+3),fill=p["bone0"])
        poly(d,[(5,10),(12,5),(15,12),(10,18),(4,16)],p["bone1"])
        poly(d,[(31,10),(24,5),(21,12),(26,18),(32,16)],p["bone1"])
    elif key == "spike_plate":
        for x in (12,18,24): poly(d,[(x-2,17),(x,13),(x+2,17)],p["iron3"])
        line(d,[(10,27),(26,27)],p["rust2"])

def shield(d,key,p):
    if key == "riot_shield":
        poly(d,[(6,3),(30,3),(31,28),(27,33),(9,33),(5,28)],p["navy0"])
        poly(d,[(8,5),(28,5),(28,26),(25,31),(11,31),(8,26)],p["navy1"])
        d.rectangle((11,9,25,14),fill=p["navy2"])
        line(d,[(12,10),(23,10)],p["iron3"])
        d.rectangle((9,20,27,21),fill=p["reflect"])
        line(d,[(13,26),(20,23)],p["iron2"])
        line(d,[(23,28),(26,25)],p["iron2"])
    else:
        poly(d,[(7,2),(29,2),(31,7),(30,27),(25,34),(11,34),(6,27),(5,7)],p["red0"])
        poly(d,[(9,4),(27,4),(28,27),(24,32),(12,32),(8,27)],p["navy0"])
        poly(d,[(13,8),(23,8),(25,24),(18,29),(11,24)],p["iron2"])
        d.ellipse((13,13,23,23),fill=p["iron3"])
        d.ellipse((16,15,20,19),fill=p["iron4"])

def trinket(d,key,p):
    if key == "dust_mask":
        poly(d,[(3,6),(6,4),(10,4),(13,6),(12,11),(9,13),(7,13),(4,11)],p["canvas0"])
        for x in (2,11): d.ellipse((x,8,x+3,11),fill=p["iron2"])
        line(d,[(3,6),(2,3),(5,2)],p["leather1"])
    elif key == "liquor_flask":
        poly(d,[(4,5),(12,5),(13,8),(12,13),(4,13),(3,8)],p["iron2"])
        d.rectangle((6,2,10,5),fill=p["leather1"])
        line(d,[(5,6),(4,10)],p["iron3"])
        d.point((9,10),fill=p["iron1"])
    elif key == "reunion_mask":
        poly(d,[(5,2),(11,2),(13,5),(12,12),(8,14),(4,12),(3,5)],p["white"])
        line(d,[(5,7),(7,7)],p["cloth0"])
        line(d,[(9,7),(11,7)],p["cloth0"])
        line(d,[(8,3),(7,5),(9,6)],p["iron2"])
    elif key == "originium_meter":
        d.rectangle((2,3,13,13),fill=p["iron1"])
        d.ellipse((4,5,11,12),fill=p["iron3"])
        line(d,[(7,9),(10,6)],p["iron0"])
        d.point((12,4),fill=p["ore1"])
    elif key == "tactical_charm":
        line(d,[(6,2),(6,6)],p["navy1"],2)
        d.arc((5,5,12,12),0,310,fill=p["brass1"],width=2)
        d.rectangle((3,10,6,13),fill=p["iron2"])
        d.point((4,11),fill=p["reflect"])
    elif key == "lgd_radio":
        d.rectangle((4,4,12,14),fill=p["navy0"])
        line(d,[(6,4),(6,1)],p["iron2"])
        d.rectangle((6,6,10,8),fill=p["navy2"])
        d.point((11,6),fill=p["green"])
        for y in (10,12): line(d,[(6,y),(10,y)],p["iron2"])
    elif key == "lungmen_wallet":
        poly(d,[(2,5),(12,5),(14,7),(14,13),(3,13),(2,10)],p["leather1"])
        d.rectangle((5,3,11,6),fill=p["brass1"])
        d.rectangle((9,8,13,10),fill=p["brass0"])
    elif key == "yan_talisman":
        poly(d,[(4,3),(12,3),(13,11),(8,13),(3,11)],p["red1"])
        d.ellipse((6,6,10,10),outline=p["brass1"])
        line(d,[(8,12),(8,15)],p["red0"],2)
    elif key == "bone_amulet":
        line(d,[(5,2),(8,5),(11,2)],p["wood1"])
        poly(d,[(7,5),(11,5),(12,11),(9,14),(5,12)],p["bone0"])
        d.point((8,6),fill=p["wood0"])
        for y in (8,10,12): d.point((9,y),fill=p["wood1"])
    elif key == "antler_flute":
        poly(d,[(3,5),(13,5),(13,10),(3,10)],p["bone0"])
        for x in (6,8,10): d.point((x,7),fill=p["wood0"])
        for y,c in zip((5,7,9),("red","yellow","blue")): d.point((13,y),fill=p[c])
    elif key == "bone_drumstick":
        line(d,[(4,12),(11,5)],p["wood1"],3)
        d.ellipse((9,2,14,7),fill=p["bone1"])
        line(d,[(5,10),(7,12)],p["fur0"])
        line(d,[(4,9),(2,5)],p["ice1"])
    elif key == "cipher_fragment":
        poly(d,[(3,4),(7,2),(12,4),(14,8),(11,13),(5,14),(2,10)],p["iron2"])
        line(d,[(5,6),(8,8),(10,5)],p["ice2"])
        line(d,[(6,11),(9,10)],p["ice1"])
    elif key == "vein_core":
        d.rectangle((3,3,12,12),fill=p["iron2"])
        poly(d,[(8,4),(11,7),(9,11),(5,9)],p["ore0"])
        d.point((8,6),fill=p["ore1"])
        for x in (1,13,15): d.point((x,7),fill=p["rust2"])
    elif key == "shadow_bracer":
        poly(d,[(6,3),(14,5),(13,13),(6,14)],p["navy0"])
        poly(d,[(3,2),(11,3),(12,12),(4,14)],p["navy1"])
        line(d,[(5,5),(10,5)],p["navy2"])
        line(d,[(5,10),(10,10)],p["iron2"])

def ore(d,p):
    poly(d,[(5,3),(10,2),(12,8),(14,15),(12,22),(14,29),(10,34),(4,32),(2,27),(4,21),(2,13)],p["iron1"])
    poly(d,[(5,7),(8,3),(10,12),(8,24),(4,23)],p["ore0"])
    poly(d,[(8,11),(12,7),(13,17),(10,28),(7,24)],p["ore1"])
    d.point((3,32),fill=p["iron2"]);d.point((13,32),fill=p["iron2"])

def relic(d,p):
    poly(d,[(3,4),(29,3),(33,7),(31,13),(5,14),(2,10)],p["ice0"])
    poly(d,[(4,5),(18,4),(17,13),(6,12)],p["ice1"])
    poly(d,[(15,6),(28,5),(30,8),(27,11),(15,11)],p["bone0"])
    for x in (20,24,27): d.point((x,8),fill=p["wood0"])
    line(d,[(5,5),(11,5)],p["ice2"])

def outline(img, dark):
    """One native pixel on the complete exterior (including detached details)."""
    alpha = img.getchannel("A")
    eroded = alpha.filter(ImageFilter.MinFilter(3))
    px = img.load(); a = alpha.load(); inside = eroded.load()
    for y in range(img.height):
        for x in range(img.width):
            if a[x,y] and not inside[x,y]: px[x,y] = tuple(bytes.fromhex(dark[1:])) + (255,)

def render(entry):
    batch,key,name,region,kind,note,emit_keys=entry
    p=PALETTES[region]; img=Image.new("RGBA",size_for(kind)); d=ImageDraw.Draw(img)
    if kind=="weapon": blade(d,key,p)
    elif kind=="armor": armor(d,key,p)
    elif kind=="shield": shield(d,key,p)
    elif kind=="trinket": trinket(d,key,p)
    elif kind=="ore": ore(d,p)
    else: relic(d,p)
    dark = p["wood0"] if key in {"bone_amulet","antler_flute","bone_drumstick"} else p["navy0"] if region=="city" else p["iron0"]
    outline(img,dark)
    # Emission is a strict same-pixel subset of the finished opaque sprite.
    emit = Image.new("RGBA",img.size)
    if emit_keys:
        src,dst=img.load(),emit.load(); colors={tuple(bytes.fromhex(p[k][1:]))+(255,) for k in emit_keys}
        for y in range(img.height):
            for x in range(img.width):
                if src[x,y] in colors: dst[x,y]=src[x,y]
    return img,emit

def preview(img): return img.resize((img.width*8,img.height*8),Image.Resampling.NEAREST)

def contact(items,folder,batch):
    rows=[]; font=ImageFont.load_default()
    for entry in items:
        _,key,name,region,kind,_,_=entry
        im=Image.open(folder/f"{key}.png").convert("RGBA")
        row=Image.new("RGB",(398,106),"#20242b")
        rd=ImageDraw.Draw(row)
        rd.text((8,6),key,fill="#e3e8ea",font=font)
        # Three rarity frames, each shown at native in-game 2x scale.
        for n,border in enumerate(("#6b737b","#5f84a8","#c9a24a")):
            x=12+n*129; y=29
            rd.rectangle((x,y,x+118,y+67),outline=border,width=2,fill="#272b31")
            disp=im.resize((im.width*2,im.height*2),Image.Resampling.NEAREST)
            row.paste(disp,(x+(119-disp.width)//2,y+(68-disp.height)//2),disp)
        rows.append(row)
    sheet=Image.new("RGB",(398,106*len(rows)+28),"#20242b")
    ImageDraw.Draw(sheet).text((8,7),f"{batch}  |  native sprites at 2x  |  common / fine / rare",fill="#e3e8ea",font=font)
    for i,row in enumerate(rows): sheet.paste(row,(0,28+i*106))
    sheet.save(folder/"contact_sheet.png")

def main():
    master=[]
    for batch in ("E1","E2","E3","E4"):
        folder=ROOT/f"batch_{batch}_v1"; folder.mkdir(parents=True,exist_ok=True)
        entries=[]; current=[e for e in ITEMS if e[0]==batch]
        for entry in current:
            _,key,name,region,kind,note,emit_keys=entry
            img,emit=render(entry)
            img.save(folder/f"{key}.png")
            preview(img).save(folder/f"{key}_8x.png")
            has_emit=bool(emit_keys)
            if has_emit: emit.save(folder/f"{key}_emit.png")
            data={"id":key,"name":name,"region":region,"kind":kind,"file":f"{key}.png",
                  "preview":f"{key}_8x.png","native_size":list(img.size),"has_emit":has_emit,
                  "emit_file":f"{key}_emit.png" if has_emit else None,"description":note}
            entries.append(data); master.append({"batch":batch,"directory":folder.name,**data})
        contact(current,folder,batch)
        (folder/"manifest.json").write_text(json.dumps({"batch":batch,"source":"装备策划案_v1_0.md §§3-6",
            "scale":2,"preview_scale":8,"palette":"§6.3","items":entries},ensure_ascii=False,indent=2),encoding="utf-8")
    (ROOT/"manifest.json").write_text(json.dumps({"source":"装备策划案_v1_0.md §§3-6",
        "batches":["E1","E2","E3","E4"],"contact_sheet":"contact_sheet.png",
        "items":master},ensure_ascii=False,indent=2),encoding="utf-8")
    sheets=[Image.open(ROOT/f"batch_{batch}_v1"/"contact_sheet.png").convert("RGB") for batch in ("E1","E2","E3","E4")]
    all_sheet=Image.new("RGB",(398*4,max(s.height for s in sheets)),"#20242b")
    for i,sheet in enumerate(sheets): all_sheet.paste(sheet,(398*i,0))
    all_sheet.save(ROOT/"contact_sheet.png")

if __name__=="__main__": main()
