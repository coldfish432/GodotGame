"""仓储区与医疗部的功能拼装 v3（策划案 v2.0 第 2.5 节、基地玩法补充案 v0.1）。
仓储区：每个分区 3×3 货架位，前后遮挡；输出“开局（每区 1 个货架）”和“满配（每区 3×3）”两张。
医疗部：多房间布局——前台大厅、中央回收病房、北侧与南侧各一排单人病房、东端污染检测室。"""
import os
from PIL import Image, ImageDraw, ImageFont
from assemble_lib import load
from assemble_rooms import Room, DARK, LIGHT, OUT

FONT = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 11)
CELLS = [(12, 10), (27, 10), (42, 10), (57, 10), (12, 27), (27, 27), (42, 27), (57, 27), (12, 44), (27, 44), (42, 44), (57, 44)]
LAP_HEAD = 29   # 精灵帧上方 17 像素透明，可见头顶在脚底以上约 29 像素

import json as _json
_GLYPHS = _json.load(open(os.path.join(os.path.dirname(__file__), 'batch_H1b_wayfinding_v1', 'glyph_lookup.json'),
                          encoding='utf-8'))['fonts']['5x7']['glyphs']


def plate(text, fg=(195, 202, 204, 255), bg=(31, 36, 39, 255)):
    """拼装用编号牌：用已通过的 5×7 字形拼字（正式版应由美术出图替换）。"""
    w = sum(_GLYPHS[c]['advance_px'] if c in _GLYPHS else 4 for c in text) + 5
    img = Image.new('RGBA', (w, 11), bg)
    ImageDraw.Draw(img).rectangle((0, 0, w - 1, 10), outline=(11, 12, 13, 255))
    x = 3
    for c in text:
        if c in _GLYPHS:
            for yy, row in enumerate(_GLYPHS[c]['rows']):
                for xx, bit in enumerate(row):
                    if bit == '1':
                        img.putpixel((x + xx, 2 + yy), fg)
        x += _GLYPHS[c]['advance_px'] if c in _GLYPHS else 4
    return img



def lane(room, x0, x1, y):
    for yy in (y, y + 40):
        for xx in range(int(x0), int(x1), 12):
            for k in range(6):
                for t in range(2):
                    room.s.base.putpixel((xx + k, int(yy) + t), (184, 154, 42, 255))


def save_with_zones(room, tag_name, zones):
    img = room.s.render(lit=True)
    overlay = Image.new('RGBA', img.size, (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    for name, (ux0, uy0, ux1, uy1), color in zones:
        box = (room.fx(ux0), room.u(uy0), room.fx(ux1), room.u(uy1))
        od.rectangle(box, fill=color + (45,), outline=color + (230,), width=2)
        od.text((box[0] + 4, box[1] + 3), name, font=FONT, fill=(255, 255, 255, 255), stroke_width=2, stroke_fill=(11, 12, 13, 255))
    zoned = Image.alpha_composite(img, overlay)
    for tag, im in (('build', img), ('zones', zoned)):
        im.save(os.path.join(OUT, f'func3_{tag_name}_{tag}_1x.png'))
        im.resize((im.width * 2, im.height * 2), Image.NEAREST).save(os.path.join(OUT, f'func3_{tag_name}_{tag}_2x.png'))


# =========================== 仓储区 B1-03（64×36） ===========================
ZONE_W = 3 * 86          # 一行 3 个货架
ROW_STEP = 3.4           # 前后排间距（单位），小于货架高度，后排被前排遮住下半截
CATS = [('weapon', 'warehouse_rack_weapons_80x64', 1.6, 3.0, 22),
        ('armor', 'warehouse_rack_armor_80x64', 21.8, 3.0, 40),
        ('trinket', 'warehouse_rack_trinket_80x64', 1.6, 20.0, 7),
        ('material', 'warehouse_rack_materials_80x64', 21.8, 20.0, 30)]


def warehouse(full):
    r = Room('warehouse', 64, 36, DARK)
    # 订单公告板挂在出库区（东北角托盘）正上方：交付和看订单在同一个地方（基地玩法策划案 §3.8）
    BOARD_WALL = 235
    r.north([('item', 'warehouse_wall_bay_120x46'), ('wall', 30), ('item', 'warehouse_wall_clipboard_22x28'), ('wall', 30),
             ('item', 'warehouse_supergraphic_160x46'), ('wall', 60), ('item', 'warehouse_wall_bay_120x46'), ('wall', BOARD_WALL),
             ('item', 'warehouse_order_board_open')])
    board_img = load('warehouse_order_board_open')[0]
    board_left_u = (24 + 120 + 30 + 22 + 30 + 160 + 60 + 120 + BOARD_WALL) / 15
    DOOR_U = 18.0
    r.walls(east_door_u=DOOR_U)
    s = r.s
    empty_cell, full_cell = load('warehouse_shelf_slot_empty_12x12')[0], load('warehouse_shelf_slot_filled_12x12')[0]
    # 只导出、不进静态拼装图的物件（未建的货架位）：export_runtime 会一并导出
    s.export_extra = []
    for cat, rack_ref, ux, uy, stock in CATS:
        # 货架位：3 行 × 3 列。开局只有前排最左一个；满配全部放满。
        # 建造顺序（基地玩法策划案 §3.6）：先前排从左到右，再中排，最后后排 → 位号 slot 0–8
        for row in range(3):
            feet = r.u(uy + row * ROW_STEP + ROW_STEP)    # row 0 = 最北的一排
            for col in range(3):
                x = r.fx(ux) + col * 86 + 42
                slot = (2 - row) * 3 + col
                group = f'shelf:{cat}:{slot}'        # 引擎按位号显示已建的货架，进入仓储区时从地面升起（world/room_reveal.gd）
                built = full or slot == 0
                if not built:
                    s.decal('pending_build_floor_compact_28x18', x, feet - 6)
                    if full:
                        continue
                    # 运行时扩建用：先不画、不碰撞，建好后由引擎显示并补碰撞
                    rack = load(rack_ref)[0]
                    rack.info.update(grp=group, rt='nocollide', role='rack')
                    s.export_extra.append((feet, 0, rack, x - rack.width // 2, feet - rack.height))
                else:
                    r.rack(rack_ref, x, feet)
                    s.items[-1][2].info.update(grp=group, role='rack')
                # 只有最前排（row 2）能看到格位；按存量从左到右、从前往后填
                if row == 2:
                    order = col
                    filled = max(0, min(12, stock - order * 12)) if full else min(12, stock)
                    cells = Image.new('RGBA', (80, 64))
                    for k, (cx, cy) in enumerate(CELLS):
                        cells.alpha_composite(full_cell if k < filled else empty_cell, (cx, cy))
                    cells.info['grp'] = group
                    cells.info['role'] = 'cells'      # 引擎按个人仓库存量重画（world/warehouse_view.gd）
                    entry = (feet + 0.5, 0, cells, x - 40, feet - 64)
                    if built: s.items.append(entry)
                    else: s.export_extra.append(entry)
            if row == 0 and full:
                for col in range(3):
                    r.hang('warehouse_over_shelf_lamp_48x12', r.fx(ux) + col * 86 + 42, int(r.u(uy + ROW_STEP)) - 78)
        front = r.u(uy + 3 * ROW_STEP)
        head_plate = load(f'warehouse_rack_plate_{cat}_1')[0]
        head_plate.info['grp'] = f'shelf:{cat}:0'
        s.items.append((front + 1, 0, head_plate, int(r.fx(ux)) - 6, int(front) - 40))
        # 高亮态只在满配示意图里演示；引擎在手持对应类别物品时叠加高亮（world/warehouse_view.gd）
        zone = 'highlight' if (cat == 'trinket' and full) else 'normal'
        for col in range(3):
            s.decal(f'warehouse_zone_{cat}_{zone}_90x44', r.fx(ux) + col * 86 + 42, front + 44)
    # 源石封存柜：材料区东侧
    cage_x = r.fx(21.8) + ZONE_W + 34
    s.light('light_pool_circle_warm_60x40', cage_x, r.u(30.0), 0.40)
    s.prop('warehouse_originium_containment_56x48', cage_x, r.u(30.0))
    # 叉车主通道
    lane(r, r.fx(0.6), r.fx(63.4), r.u(16.6))
    s.prop('warehouse_forklift_70x48', r.fx(42.0), r.u(19.2))
    if full:
        s.items.append((10000, 0, load('warehouse_cargo_drone')[0], int(r.fx(30.0)), int(r.u(15.6))))
    else:
        r.s.textures_extra = {'cargo_drone': load('warehouse_cargo_drone')[0]}
    # 仓管台、出库区、推车、收货区、扩建区
    s.light('light_pool_circle_cool_60x40', r.fx(50.0), r.u(12.0), 0.40)
    s.prop('warehouse_storage_terminal_on_64x52', r.fx(50.0), r.u(12.0))
    s.decal('warehouse_operator_spot_12x6', r.fx(50.0), r.u(13.4))
    for i in range(2):
        s.prop('warehouse_dispatch_pallet', r.fx(53.5) + i * 58, r.u(5.0))
    s.prop('warehouse_trolley_loaded', r.fx(60.0), r.u(DOOR_U + 2.6))
    s.light('light_pool_rectangle_warm_90x60', r.fx(58.0), r.u(32.6), 0.28)
    s.prop('warehouse_freight_lift_ready_96x56', r.fx(58.0), r.u(33.8))
    crates = ['warehouse_loot_crate_large_sealed', 'warehouse_loot_crate_medium_sealed', 'warehouse_loot_crate_small_sealed',
              'warehouse_loot_crate_medium_open', 'warehouse_loot_crate_small_sealed', None]
    for k in range(6):
        row, col = divmod(k, 3)
        x, y = r.fx(44.5) + col * 40, r.u(25.0 + row * 3.0)
        s.decal(f'warehouse_receiving_bay_R0{k + 1}_30x25', x, y + 4)
        if crates[k]:
            s.prop(crates[k], x, y)
            s.items[-1][2].info['rt'] = 'skip'   # 示意；引擎按收货区的真实货箱摆放
    s.items.append((0, 0, load('small_number_plate_B1_03')[0], r.x1 - 34, int(r.u(DOOR_U)) - 34))
    lx, ly = r.fx(9.0), r.u(34.0)
    r.lappland(lx, ly)
    frame = load('warehouse_carried_item_frame_22x22')[0].copy()
    frame.info['rt'] = 'skip'
    frame.alpha_composite(load('warehouse_category_trinket_14x14')[0], (4, 4))
    s.items.append((10001, 0, frame, int(lx) - 11, int(ly) - LAP_HEAD - 24))
    name = 'warehouse_full' if full else 'warehouse_start'
    # 暂存区：收货区东侧、货运升降台北侧的空地。正式地贴待 H5（STAGING 框线），先用色板虚线框加 5×7 字形
    sx0, su0, sx1, su1 = 52.4, 22.0, 58.6, 29.6
    staging = Image.new('RGBA', (int((sx1 - sx0) * 15), int((su1 - su0) * 12.7)), (0, 0, 0, 0))
    dash = (195, 202, 204, 255)
    for xx in range(0, staging.width, 8):
        for yy in (0, 1, staging.height - 2, staging.height - 1):
            for k in range(4):
                if xx + k < staging.width: staging.putpixel((xx + k, yy), dash)
    for yy in range(0, staging.height, 8):
        for xx in (0, 1, staging.width - 2, staging.width - 1):
            for k in range(4):
                if yy + k < staging.height: staging.putpixel((xx, yy + k), dash)
    staging.alpha_composite(plate('STAGING'), (4, staging.height - 15))   # 底边：托盘上的货箱会挡住上沿
    s.decals.append((staging, int(r.fx(sx0)), int(r.u(su0))))
    pallets = [(54.0, 24.8), (57.0, 24.8), (54.0, 28.0), (57.0, 28.0)]
    if not full:
        # 引擎用到的锚点（本地单位：x 向东，u 向南）。点为 [x, u]，矩形为 [x0, u0, x1, u1]
        zones, zone_decals = {}, {}
        for cat, _ref, ux, uy, _stock in CATS:
            front = uy + 3 * ROW_STEP
            zones[cat] = [ux - 0.2, front, ux + (2 * 86 + 87) / 15, front + 44 / 12.7]
            zone_decals[cat] = [[ux + (col * 86 + 42) / 15, front + 44 / 12.7] for col in range(3)]
        r.s.anchors = {
            'bays': [[44.5 + (k % 3) * 40 / 15, 25.0 + (k // 3) * 3.0] for k in range(6)],
            'overflow': [[44.2, 33.8], [46.9, 33.8], [49.6, 33.8], [52.3, 33.8], [44.2, 31.0], [46.9, 31.0]],
            'zones': zones, 'zone_decals': zone_decals,
            'staging': [sx0, su0, sx1, su1], 'pallets': [list(p) for p in pallets],
            # 公告板：北墙墙根上的中心点；引擎把三态图叠在立面上，底边比墙根高 board_lift 像素
            'order_board': [board_left_u + board_img.width / 30, 0.0],
        }
        r.s.textures = {'pallet': load('warehouse_dispatch_pallet')[0],
                        'slot_empty': empty_cell, 'slot_filled': full_cell,
                        'carried_frame': load('warehouse_carried_item_frame_22x22')[0]}
        for size in ('small', 'medium', 'large'):
            for state in ('sealed', 'open'):
                r.s.textures[f'crate_{size}_{state}'] = load(f'warehouse_loot_crate_{size}_{state}')[0]
        for cat, *_ in CATS:
            r.s.textures[f'icon_{cat}'] = load(f'warehouse_category_{cat}_14x14')[0]
            r.s.textures[f'zone_{cat}_highlight'] = load(f'warehouse_zone_{cat}_highlight_90x44')[0]
        r.s.cells = [list(c) for c in CELLS]
        r.s.board_lift = (46 - board_img.height) // 2
        for state in ('empty', 'open', 'completed'):
            r.s.textures[f'board_{state}'] = load(f'warehouse_order_board_{state}')[0]
    else:
        for x, u in pallets:
            s.prop('warehouse_dispatch_pallet', r.fx(x), r.u(u))
    if not full:
        # 货架地面闸门的开启帧，引擎在进入仓储区时播放（shelf_hatch.py）
        from shelf_hatch import hatch_frames
        r.s.anim = {'shelf_hatch': hatch_frames(load)}
        r.export('warehouse')       # 引擎首版用开局状态：每区一个货架
    save_with_zones(r, name, [
        ('武器 A（3×3 货架位）', (0.6, 0.4, 19.6, 15.0), (224, 120, 42)),
        ('防具 B', (20.8, 0.4, 39.8, 15.0), (88, 136, 168)),
        ('饰品 C（手持饰品时高亮）', (0.6, 18.4, 19.6, 33.0), (95, 208, 216)),
        ('材料 D + 源石封存柜', (20.8, 18.4, 43.0, 33.0), (232, 92, 40)),
        ('叉车主通道', (0.6, 15.2, 63.4, 18.2), (244, 215, 60)),
        ('仓管台', (45.0, 7.0, 55.0, 14.4), (95, 191, 106)),
        ('出库区：订单交付', (51.0, 0.6, 63.4, 9.0), (200, 160, 90)),
        ('收货区：开箱入库', (43.4, 22.0, 63.4, 35.6), (241, 217, 166)),
    ])


warehouse(full=False)
warehouse(full=True)

# =========================== 医疗部 B1-04（45×41：前台大厅 + 环形病房区） ===========================
# 西侧（x 0–14）前台大厅保留；病房区（x 14–45）：中央正方形回收病房，四周一圈走廊，走廊外侧一圈单人病房。
# 房间内部的墙一律只画墙顶（玻璃隔断条，横竖通用），门为隔断上的缺口；只有房间最外侧的北墙有立面。
r = Room('medical', 45, 41, LIGHT, wall_tile='batch_H3_medical_v1/medical_wall_white_60x46.png',
         floor_tile='batch_H3_medical_v1/medical_floor_cool_120x120.png')
r.north([('item', 'medical_department_sign_120x36'), ('wall', 6), ('item', 'medical_pharmacy_window')])
DOOR_U = 30.0                                   # 通往大厅的西门放在大厅南部
r.walls(west_door_u=DOOR_U)
s = r.s
s.paste_now(load('medical_pharmacy_shelf_full')[0], r.x0 + 24 + 126 + 6, r.wall_top + 8)
GLASS_V = load('medical_glass_partition_ns_continuous_8x90')[0]
GLASS_H = load('medical_glass_partition_ew_continuous_90x8')[0]   # H4 v2 正式横向隔断
POST = (195, 202, 204, 255)
GAP = 38


PARTS = []                                      # 隔断碰撞（本地单位），导出给引擎


def _segments(a, b, gaps, emit):
    for g0, g1 in sorted(gaps):
        if g0 > a:
            emit(a, g0)
        a = max(a, g1)
    if b > a:
        emit(a, b)


def glass_h(ux0, ux1, uy, doors=()):
    x0, x1, y = int(r.fx(ux0)), int(r.fx(ux1)), int(r.u(uy)) - 4
    layer = Image.new('RGBA', (x1 - x0, 8))
    x = 0
    while x < x1 - x0:
        layer.alpha_composite(GLASS_H.crop((0, 0, min(90, x1 - x0 - x), 8)), (x, 0))
        x += 90
    for d in doors:
        c = int(r.fx(d)) - x0
        for xx in range(c - GAP // 2, c + GAP // 2):
            for yy in range(8):
                layer.putpixel((xx, yy), (0, 0, 0, 0))
        for px in (c - GAP // 2 - 6, c + GAP // 2):          # 门柱顶面
            for xx in range(px, px + 6):
                for yy in range(1, 7):
                    layer.putpixel((xx, yy), POST)
    s.paste_now(layer, x0, y)
    _segments(ux0, ux1, [(d - GAP / 2 / 15, d + GAP / 2 / 15) for d in doors], lambda a, b: PARTS.append((a, uy - 0.15, b, uy + 0.15)))


def glass_v(ux, uy0, uy1, doors=()):
    x, y0, y1 = int(r.fx(ux)) - 4, int(r.u(uy0)), int(r.u(uy1))
    layer = Image.new('RGBA', (8, y1 - y0))
    y = 0
    while y < y1 - y0:
        layer.alpha_composite(GLASS_V.crop((0, 0, 8, min(90, y1 - y0 - y))), (0, y))
        y += 90
    for d in doors:
        c = int(r.u(d)) - y0
        g = int(GAP * 0.85)                                   # 纵向缺口按地面压缩
        for yy in range(c - g // 2, c + g // 2):
            for xx in range(8):
                layer.putpixel((xx, yy), (0, 0, 0, 0))
        for py in (c - g // 2 - 6, c + g // 2):
            for yy in range(py, py + 6):
                for xx in range(1, 7):
                    layer.putpixel((xx, yy), POST)
    s.paste_now(layer, x, y0)
    g = int(GAP * 0.85) / 2 / 12.7
    _segments(uy0, uy1, [(d - g, d + g) for d in doors], lambda a, b: PARTS.append((ux - 0.15, a, ux + 0.15, b)))


def room(ux, uy, n, state, door_u=None):
    """单人病房：一张床、一个输液架、门口编号牌。"""
    s.prop(f'medical_ward_bed_{state}', r.fx(ux + 3.8), r.u(uy + 4.6))
    s.prop('medical_iv_stand', r.fx(ux + 1.2), r.u(uy + 4.0))
    if door_u is not None:
        s.items.append((0, 0, load(f'medical_room_plate_W_{n:02d}_32x12')[0], int(r.fx(door_u[0])) - 12, int(r.u(door_u[1])) - 14))


# ---- 西侧：前台大厅 ----
s.light('light_pool_circle_warm_60x40', r.fx(7.0), r.u(9.0), 0.30)
s.prop('medical_reception_alert', r.fx(7.0), r.u(9.0))
s.items[-1][2].info['role'] = 'reception'   # 引擎按有无未读报告、未治疗重伤切换两态（world/medical_view.gd）
s.decal('medical_staff_stand_spot_1', r.fx(7.0), r.u(7.0))
marker = load('interaction_marker_yellow')[0]
marker.info['rt'] = 'skip'
s.items.append((9999, 0, marker, int(r.fx(7.0)) - 6, int(r.u(9.0)) - 48))
for k in range(3):
    s.prop('medical_waiting_chairs_3', r.fx(6.0), r.u(16.0 + k * 3.6))
s.prop('store_potted_plant', r.fx(2.0), r.u(36.0))
s.prop('store_potted_plant', r.fx(12.4), r.u(36.0))
s.prop('medical_wash_sink', r.fx(11.6), r.u(3.0))

# ---- 大厅与病房区之间：玻璃隔断，唯一入口是污染检测门 ----
GATE_U = 20.5
glass_v(14.0, 0.0, 41.0, doors=[GATE_U])
gate = load('medical_contamination_gate_ns_red_20x90')[0]          # 侧向检测门：通行缺口在 y=26..63
gate_top = int(r.u(GATE_U)) - 44
gate.info['rt'] = 'ground'           # 俯视的检测门条贴在地面层，人物从上面走过
s.items.append((int(r.u(GATE_U)) + 46, 0, gate, int(r.fx(14.0)) - 10, gate_top))
s.items.append((20000, 0, load('medical_contamination_scan_beam_ns_20x90')[0], int(r.fx(14.0)) - 10, gate_top))
s.items.append((0, 0, load('medical_sign_contamination')[0], int(r.fx(14.0)) - 45, int(r.u(GATE_U)) - 70))
s.decal('floor_arrow_medical_right_40x28', r.fx(10.6), r.u(GATE_U + 2.2))

# ---- 北排单人病房（y 0–7，4 间），门开向北走廊 ----
xs = [14.0, 21.75, 29.5, 37.25, 45.0]
for k in range(4):
    if k > 0:
        glass_v(xs[k], 0.0, 7.0)
    room(xs[k], 0.0, k + 1, 'occupied' if k == 2 else 'empty', door_u=(xs[k] + 5.8, 7.0))
glass_h(14.0, 45.0, 7.0, doors=[x + 5.8 for x in xs[:4]])
# 西北角那间改作污染处置室：检测床
# ---- 东侧（x 38–45）：留空（用户 2026-10-01：原三间病房与物资摆放都取消） ----
# ---- 南排单人病房（y 34–41，4 间），门开向南走廊 ----
glass_h(14.0, 45.0, 34.0, doors=[x + 5.8 for x in xs[:4]])
for k in range(4):
    if k > 0:
        glass_v(xs[k], 34.0, 41.0)
    room(xs[k], 34.0, 5 + k, 'occupied' if k == 0 else 'empty', door_u=(xs[k] + 5.8, 34.0))

# ---- 中央：正方形回收病房（x 18–34，y 11–30；画面上约 240×241 像素），四面开门 ----
CX0, CX1, CY0, CY1 = 21.5, 37.5, 11.0, 30.0   # 病房区（x 14–45）水平居中
mid_x, mid_y = (CX0 + CX1) / 2, (CY0 + CY1) / 2
glass_h(CX0, CX1, CY0, doors=[mid_x])
glass_h(CX0, CX1, CY1, doors=[mid_x])
glass_v(CX0, CY0, CY1, doors=[mid_y])
glass_v(CX1, CY0, CY1, doors=[mid_y])
s.items.append((0, 0, load('medical_recovery_plate_58x12')[0], int(r.fx(mid_x)) - 29, int(r.u(CY0)) - 22))
bx, by = r.fx(mid_x), r.u(mid_y + 1.0)
s.light('light_pool_rectangle_cool_90x60', bx, by, 0.32)
s.decal('medical_recovery_zone_100x44', bx, by + 8)
s.prop('medical_recovery_bed', bx, by)
s.prop('medical_iv_stand', bx - 40, by - 6)
r.hang('medical_suspended_monitor', bx + 12, by - 60)
s.decal('medical_stand_spot_recovery_attendant_12x6', bx + 46, by + 4)
s.prop('medical_nurse_station', r.fx(mid_x), r.u(CY1 - 2.6))
s.decal('medical_staff_stand_spot_2', r.fx(mid_x), r.u(CY1 - 4.6))
s.prop('medical_wash_sink', r.fx(CX0 + 2.6), r.u(CY0 + 3.6))
s.prop('medical_iv_stand', r.fx(CX1 - 1.6), r.u(CY0 + 3.2))
r.lappland(bx + 46, r.u(mid_y + 4.4))
# 引擎用：检测门的红/绿两态叠在地面层的门上（底边中点），前台两态
s.anchors = {'gate': [14.0, GATE_U + 46 / 12.7]}
s.textures = {'gate_red': load('medical_contamination_gate_ns_red_20x90')[0], 'gate_green': load('medical_contamination_gate_ns_green_20x90')[0],
              'reception_idle': load('medical_reception_idle')[0], 'reception_alert': load('medical_reception_alert')[0]}
r.export('medical', PARTS)

save_with_zones(r, 'medical', [
    ('前台大厅：重伤治疗·回收报告·候诊', (0.6, 0.4, 13.4, 40.6), (244, 215, 60)),
    ('污染检测门（病房区唯一入口）', (11.6, 17.0, 16.6, 24.0), (200, 60, 60)),
    ('单人病房 W-01–04', (14.4, 0.2, 44.6, 6.8), (120, 184, 232)),
    ('单人病房 W-05–08', (14.4, 34.2, 44.6, 40.8), (120, 184, 232)),
    ('环形走廊', (14.4, 7.2, 38.0, 10.8), (152, 162, 166)),
    ('中央回收病房：阵亡醒来', (21.7, 11.2, 37.3, 29.8), (232, 92, 40)),
])
print('function rooms v3 done')
