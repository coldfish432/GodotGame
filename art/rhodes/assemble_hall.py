"""舰桥大厅静态拼装 v5：128×56 单位（约横 3 屏 × 纵 2 屏）。输出全图与若干 640×360 镜头截图。"""
import os
from PIL import Image, ImageOps
from assemble_lib import Scene, load, PX_X, PX_Y

OUT = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'evidence', 'rhodes-assembly')
os.makedirs(OUT, exist_ok=True)

W_UNITS, D_UNITS = 128, 56
X0 = 40
X1 = X0 + int(W_UNITS * PX_X)
WALL_TOP = 30
FLOOR_Y = WALL_TOP + 46
FLOOR_BOTTOM = FLOOR_Y + round(D_UNITS * PX_Y)
CX = (X0 + X1) // 2


def u(units):
    """距北墙 units 单位处的地面 y。"""
    return FLOOR_Y + units * PX_Y


s = Scene(X1 + X0, FLOOR_BOTTOM + 30)
s.tile('rhodes_floor_v1.png', X0, FLOOR_Y, X1 - X0, FLOOR_BOTTOM - FLOOR_Y)

# ---------------- 北墙 ----------------
wall, _ = load('accepted_wall_straight_60x46_v5')
door, _ = load('batch1_v5/door_open_45x46_v5.png')
slot, _ = load('room_slot_door_sealed')
marks = {}
WIDTH = {'door': 45, 'slot': 45, 'window': 98, 'lightbox': 36, 'xl': 146, 'detail': 40, 'cable': 27}


def wall_run(x, w):
    while w > 0:
        s.paste_now(wall.crop((0, 0, min(60, w), 46)), x, WALL_TOP)
        x += 60
        w -= 60


def put(item, x):
    kind = item[0]
    if kind == 'wall':
        wall_run(x, item[1])
        return item[1]
    if kind == 'door':
        s.paste_now(door, x, WALL_TOP)
        marks[item[1]] = x + 22
    elif kind == 'slot':
        s.paste_now(slot, x, WALL_TOP)
    elif kind == 'window':
        s.wall(item[1], x, WALL_TOP)
    elif kind == 'lightbox':
        s.wall('north_wall_lightbox_slot_36x46', x, WALL_TOP)
        s.wall('rhodes_logo_lightbox_v1', x + 2, WALL_TOP + 1)
    elif kind == 'xl':
        s.wall('north_wall_XL_backplate_slot_146x46', x, WALL_TOP)
        s.wall('rhodes_logo_XL_lockup_v1', x + 3, WALL_TOP + 1)
    elif kind == 'detail':
        wall_run(x, 40)
        s.wall('wall_mounted_extinguisher_14x28', x + 6, WALL_TOP + 10)
        s.wall('emergency_stop_plate_16x20', x + 22, WALL_TOP + 12)
    elif kind == 'cable':
        wall_run(x, 27)
        s.wall('orange_cable_drop_28x36', x, WALL_TOP + 4)
    return WIDTH[kind]


def run(items, x, x_end, filler_at):
    used = sum(i[1] if i[0] == 'wall' else WIDTH[i[0]] for i in items)
    items = items[:filler_at] + [('wall', x_end - x - used)] + items[filler_at:]
    for it in items:
        x += put(it, x)
    assert x == x_end, (x, x_end)


WL = ('window', 'north_wall_window_left_98x46')
WR = ('window', 'north_wall_window_right_98x46')
# 商店门前移 66 像素，正对商店前台：门后两侧是展柜，门开在两柜之间（引擎碰撞验证过）
run([('wall', 66), ('door', 'store'), ('wall', 40), ('lightbox',), ('detail',), ('slot',), ('wall', 60), WL, ('cable',), WR,
     ('wall', 60), WL, ('cable',), WR, ('wall', 24)], X0 + 24, CX - 48, filler_at=6)
run([('wall', 24), ('xl',), ('wall', 24), WL, ('cable',), WR, ('wall', 60), ('slot',), ('detail',), ('lightbox',),
     ('wall', 40), ('door', 'armory')], CX + 48, X1 - 24, filler_at=10)

# 墙角与侧墙（右侧镜像，让接触阴影朝向室内）
s.paste_now(load('accepted_corner_left_L_v5')[0], X0 - 8, WALL_TOP)
s.paste_now(load('accepted_corner_right_L_v5')[0], X1 - 24, WALL_TOP)
strip, _ = load('accepted_wall_top_6_plus2_v5')
gap, _ = load('accepted_door_side_gap38_v5')
DOOR_U = 26.0


def side(x, mirror):
    y = WALL_TOP + 60
    while y < FLOOR_BOTTOM:
        img = ImageOps.mirror(strip) if mirror else strip
        s.paste_now(img.crop((0, 0, 8, min(60, FLOOR_BOTTOM - y))), x, y)
        y += 60
    # 侧门：缺口图块（38 像素缺口居中于第 30 行）精确压在门的位置上，不再对齐 60 像素墙段网格，
    # 这样相邻房间的两个缺口、引擎里的门洞碰撞（z −26）三者一致。缺口里先补地板作门槛。
    door_y = int(round(u(DOOR_U))) - 30
    s.floor_under('rhodes_floor_v1.png', X0, FLOOR_Y, x, door_y, 8, 60)
    s.paste_now(ImageOps.mirror(gap) if mirror else gap, x, door_y)


side(X0 - 8, False)
side(X1, True)

# ---------------- 警戒线围区（借用第二批地贴，按 6 像素周期拼接） ----------------
HZ = {k: load(f'batch2_v1/rhodes_hazard_{k}_v1.png')[0]
      for k in ('horizontal', 'vertical', 'corner_NW', 'corner_NE', 'corner_SW', 'corner_SE')}


def frame(x, y, w, h):
    x -= x % 6
    y -= y % 6
    w -= w % 6
    h -= h % 6
    for xx in range(x + 24, x + w - 24, 60):
        seg = HZ['horizontal'].crop((0, 0, min(60, x + w - 24 - xx), 6))
        s.decals.append((seg, xx, y))
        s.decals.append((seg, xx, y + h - 6))
    for yy in range(y + 24, y + h - 24, 60):
        seg = HZ['vertical'].crop((0, 0, 6, min(60, y + h - 24 - yy)))
        s.decals.append((seg, x, yy))
        s.decals.append((seg, x + w - 6, yy))
    s.decals += [(HZ['corner_NW'], x, y), (HZ['corner_NE'], x + w - 24, y),
                 (HZ['corner_SW'], x, y + h - 24), (HZ['corner_SE'], x + w - 24, y + h - 24)]


# ---------------- 出发升降梯 ----------------
s.light('light_pool_rectangle_warm_90x60', CX, u(2.6), 0.28)
s.decal('lift_boarding_zone_decal_96x48', CX, u(2.0))
s.prop('exit_lift_standby_module', CX, FLOOR_Y)

# ---------------- 调度区（中轴） ----------------
s.light('light_pool_rectangle_cool_90x60', CX, u(12.0), 0.45)
s.prop('accepted_dispatch_console_on_95x43', CX, u(12.2))
py = u(13.3)
s.prop('dispatch_platform_railing_164x44', CX, py)
for dx, n in ((-98, 'corner_left_32x44'), (98, 'corner_right_32x44'), (-124, 'end_left_20x44'), (124, 'end_right_20x44')):
    s.prop('dispatch_platform_' + n, CX + dx, py)

# ---------------- 西侧：值班监控区 ----------------
wx = CX - 560
frame(wx - 120, int(u(5.0)), 300, int(9 * PX_Y))
for i, xx in enumerate((wx - 70, wx, wx + 70, wx + 140)):
    s.light('light_pool_circle_cool_60x40', xx, u(9.0), 0.35)
    s.prop('duty_station_empty_on' if i < 3 else 'duty_station_empty_off', xx, u(9.0))
s.prop('hanging_monitor_cluster_4', wx + 35, u(9.0) - 54, layer_bias=60)
s.prop('store_potted_plant', wx - 100, u(13.0))
s.prop('store_potted_plant', wx + 170, u(13.0))

# ---------------- 东侧：后勤区 ----------------
ex = CX + 560
frame(ex - 130, int(u(9.0)), 260, int(10 * PX_Y))
s.light('light_pool_circle_warm_60x40', ex, u(14.0), 0.40)
s.prop('accepted_logistics_counter_on_71x40', ex, u(14.0))
s.prop('hanging_monitor_cluster_2', ex, u(14.0) - 42, layer_bias=60)
s.prop('duty_station_empty_off', ex - 80, u(17.6))
s.prop('duty_station_empty_off', ex + 80, u(17.6))
s.prop('store_potted_plant', ex + 150, u(10.0))

# ---------------- 门口小物（借用仓储、商店、整备、医疗批次的部件） ----------------
s.prop('warehouse_supply_crate_42x32', marks['store'] + 70, u(2.6))
s.prop('store_stacked_merchandise_boxes', marks['store'] + 116, u(2.8))
s.prop('armory_equipment_case', marks['armory'] - 80, u(2.6))
s.prop('warehouse_pallet_48x24', X0 + 50, u(DOOR_U - 4.5))
s.prop('warehouse_supply_crate_42x32', X0 + 52, u(DOOR_U - 4.6))
s.prop('medical_sanitizer', X1 - 40, u(DOOR_U - 4.0))

# ---------------- 地面：标志、箭头 ----------------
# 地板拼色标志：16×16 块钢板，左上角对齐大厅地板网格的第 24 列、第 6 行（CX 处于第 32 列，标志水平居中）
import floor_logo_mosaic
mosaic_path, _ = floor_logo_mosaic.build(16, col0=24, row0=6)
s.paste_now(Image.open(mosaic_path).convert('RGBA'), X0 + 24 * 30, FLOOR_Y + 6 * 30)
s.decal('floor_arrow_icon_01', marks['store'], u(2.0))
s.decal('floor_arrow_icon_02', marks['armory'], u(2.0))
s.decal('floor_arrow_warehouse_left_40x28', X0 + 32, u(DOOR_U))
s.decal('floor_arrow_medical_right_40x28', X1 - 32, u(DOOR_U))
s.prop('side_wall_top_sign_03', X0 + 22, u(DOOR_U - 2.6), layer_bias=-400)
s.prop('side_wall_top_sign_04', X1 - 22, u(DOOR_U - 2.6), layer_bias=-400)
for xx, yy, n in ((CX - 300, 38, 'floor_arrow_warehouse_left_40x28'), (CX - 640, 30, 'floor_arrow_warehouse_left_40x28'),
                  (CX + 300, 38, 'floor_arrow_medical_right_40x28'), (CX + 640, 30, 'floor_arrow_medical_right_40x28'),
                  (marks['store'], 20, 'floor_arrow_icon_01'), (marks['armory'], 20, 'floor_arrow_icon_02')):
    s.decal(n, xx, u(yy))

# ---------------- 总导视牌（落地立牌，支腿为拼装补画） ----------------
board, _ = load('hall_directory_board_192x50')
stand = Image.new('RGBA', (board.width, board.height + 14))
stand.alpha_composite(board)
for lx in (30, board.width - 34):
    for yy in range(board.height, board.height + 14):
        for xx in range(lx, lx + 4):
            stand.putpixel((xx, yy), (61, 68, 72, 255) if xx < lx + 3 else (21, 24, 26, 255))
for bx, by in ((CX - 420, u(46.0)), (CX + 230, u(22.0))):
    s.items.append((by, 9999, stand, bx - board.width // 2, by - stand.height))

# ---------------- 两翼施工围挡（南侧两角） ----------------
s.prop('wing_construction_barrier_uncleared_128x56', X0 + 52, FLOOR_BOTTOM - 2)
s.prop('wing_construction_barrier_uncleared_128x56', X1 - 52, FLOOR_BOTTOM - 2)

# ---------------- 交互浮标、拉普兰德 ----------------
for mx, my in ((CX, u(12.2) - 54), (ex, u(14.0) - 58), (CX, FLOOR_Y - 84)):
    marker = load('interaction_marker_cyan')[0]
    marker.info['rt'] = 'skip'
    s.items.append((9999, 0, marker, mx - 6, my))
lap_path = os.path.join(os.path.dirname(__file__), '..', '..', 'godot_assets', 'lappland_combat_64.png')
lap = Image.open(lap_path).convert('RGBA').crop((0, 0, 64, 64))
lap.info['rt'] = 'skip'
LAP = (CX, u(53.0))
s.items.append((LAP[1], 0, lap, LAP[0] - 32, LAP[1] - 46))

# 引擎的交互浮标（world/base_markers.gd）：常规青色，有事可做时黄色
s.textures = {'marker_cyan': load('interaction_marker_cyan')[0], 'marker_yellow': load('interaction_marker_yellow')[0]}
import export_runtime
export_runtime.export('hall', s, X0, X1, WALL_TOP, FLOOR_Y, FLOOR_BOTTOM)


def save(img, name, k):
    img.save(os.path.join(OUT, name + '_1x.png'))
    if k > 1:
        img.resize((img.width * k, img.height * k), Image.NEAREST).save(os.path.join(OUT, name + f'_{k}x.png'))


full = s.render(lit=True)
save(full, 'hall_v5_full_lit', 1)


def view(cx, cy, name):
    x = max(0, min(full.width - 640, int(cx - 320)))
    y = max(0, min(full.height - 360, int(cy - 200)))
    save(full.crop((x, y, x + 640, y + 360)), name, 3)


view(*LAP, 'hall_v5_view_arrival')
view(CX, u(24), 'hall_v5_view_center')
view(CX, u(8), 'hall_v5_view_lift')
view(wx, u(12), 'hall_v5_view_west')
view(ex, u(16), 'hall_v5_view_east')
print('canvas', full.size, 'floor', X1 - X0, 'x', FLOOR_BOTTOM - FLOOR_Y,
      'screens', round((X1 - X0) / 640, 2), 'x', round((FLOOR_BOTTOM - WALL_TOP) / 360, 2))
