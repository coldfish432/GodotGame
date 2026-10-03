"""四个舱室的静态拼装 v2（1:1 原生像素）。尺寸按常识区分大小：仓储区最大，商店最小。
小于一屏的房间放在 640×360 画布中央；大于一屏的输出全图，并按游戏镜头截一屏。"""
import os
from PIL import Image, ImageDraw, ImageOps
from assemble_lib import Scene, load, PX_X, PX_Y

OUT = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'evidence', 'rhodes-assembly')
os.makedirs(OUT, exist_ok=True)
LAP_SRC = os.path.join(os.path.dirname(__file__), '..', '..', 'godot_assets', 'lappland_combat_64.png')
LAPPLAND = Image.open(LAP_SRC).convert('RGBA').crop((0, 0, 64, 64))
LAPPLAND.info['rt'] = 'skip'

DARK = dict(wall='accepted_wall_straight_60x46_v5', cl='accepted_corner_left_L_v5', cr='accepted_corner_right_L_v5',
            strip='accepted_wall_top_6_plus2_v5', gap='accepted_door_side_gap38_v5')
LIGHT = dict(wall='batch3_equipment_v3/wall_straight_60x46_light_v2.png', cl='batch3_equipment_v3/corner_left_L_light_v2.png',
             cr='batch3_equipment_v3/corner_right_L_light_v2.png', strip='batch3_equipment_v3/wall_top_6_plus2_light_v2.png',
             gap='batch3_equipment_v3/door_side_gap38_light_v2.png')


def overhead_beam(room, y, x0=None, x1=None, z=20000):
    """顶层：横跨房间的工字钢横梁（拼装示意，正式版由美术出图）。y 为梁上沿的画面坐标。
    顶层画在所有物件与人物之上；进引擎后，人物走到下方时应把顶层淡出。"""
    x0 = room.x0 - 6 if x0 is None else x0
    x1 = room.x1 + 6 if x1 is None else x1
    w = x1 - x0
    beam = Image.new('RGBA', (w, 10))
    px = beam.load()
    rows = [(11, 12, 13), (115, 125, 130), (61, 68, 72), (61, 68, 72), (44, 50, 54), (61, 68, 72),
            (61, 68, 72), (31, 36, 39), (11, 12, 13)]
    for yy, c in enumerate(rows):
        for xx in range(w):
            px[xx, yy + 1] = c + (255,)
    for xx in range(0, w, 30):                      # 腹板加强筋
        for yy in range(3, 8):
            px[xx, yy] = (31, 36, 39, 255)
    for end in (range(0, 14), range(w - 14, w)):    # 两端黄黑警示
        for xx in end:
            for yy in range(2, 8):
                px[xx, yy] = (244, 215, 60, 255) if ((xx + yy) // 3) % 2 == 0 else (11, 12, 13, 255)
    room.s.items.append((z, 0, beam, x0, int(y) - 1))
    for bx in (x0, x1 - 8):                         # 墙上的支座
        bracket = Image.new('RGBA', (8, 14), (86, 96, 100, 255))
        ImageDraw.Draw(bracket).rectangle((0, 0, 7, 13), outline=(11, 12, 13, 255))
        room.s.items.append((z, 1, bracket, bx, int(y) - 3))


class Room:
    def __init__(self, name, w_units, d_units, shell, wall_tile=None, floor_tile='rhodes_floor_v1.png'):
        self.name = name
        self.w = int(w_units * PX_X)
        self.d = round(d_units * PX_Y)
        cw, ch = max(640, self.w + 80), max(360, self.d + 46 + 60)
        self.s = Scene(cw, ch)
        self.x0 = (cw - self.w) // 2
        self.wall_top = (ch - self.d - 46) // 2
        self.fy = self.wall_top + 46
        self.x1 = self.x0 + self.w
        self.bottom = self.fy + self.d
        self.shell = shell
        self.wall_tile = load(wall_tile or shell['wall'])[0]
        self.floor_tile = floor_tile
        self.s.tile(floor_tile, self.x0, self.fy, self.w, self.d)

    def u(self, units):
        return self.fy + units * PX_Y

    def fx(self, units):
        return self.x0 + units * PX_X

    def north(self, items):
        """北墙从左到右铺设；('wall', 宽) 为墙段，('item', id) 为挂件（下垫墙段），其余宽度在末尾补墙。"""
        widths = [ref if kind == 'wall' else load(ref)[0].width for kind, ref in items]
        filler = (self.x1 - 24) - (self.x0 + 24) - sum(widths)
        assert filler >= 0, (self.name, filler)
        x = self.x0 + 24
        for (kind, ref), w in zip(items + [('wall', filler)], widths + [filler]):
            xx, left = x, w
            while left > 0:
                self.s.paste_now(self.wall_tile.crop((0, 0, min(60, left), 46)), xx, self.wall_top)
                xx += 60
                left -= 60
            if kind == 'item':
                img = load(ref)[0]
                self.s.paste_now(img, x, self.wall_top + (46 - img.height) // 2)
            x += w

    def walls(self, west_door_u=None, east_door_u=None):
        self.s.paste_now(load(self.shell['cl'])[0], self.x0 - 8, self.wall_top)
        self.s.paste_now(load(self.shell['cr'])[0], self.x1 - 24, self.wall_top)
        strip, gap = load(self.shell['strip'])[0], load(self.shell['gap'])[0]
        for x, mirror, door_u in ((self.x0 - 8, False, west_door_u), (self.x1, True, east_door_u)):
            y = self.wall_top + 60
            while y < self.bottom:
                img = ImageOps.mirror(strip) if mirror else strip
                self.s.paste_now(img.crop((0, 0, 8, min(60, self.bottom - y))), x, y)
                y += 60
            if door_u is not None:
                # 缺口图块精确压在门的位置（38 像素缺口居中于第 30 行），先补地板作门槛
                door_y = int(round(self.u(door_u))) - 30
                self.s.floor_under(self.floor_tile, self.x0, self.fy, x, door_y, 8, 60)
                self.s.paste_now(ImageOps.mirror(gap) if mirror else gap, x, door_y)

    def rack(self, ref, x, feet_y):
        """靠底边站立的高件（货架等），manifest 中锚点记在上沿，这里按脚底摆放。"""
        img = load(ref)[0]
        self.s.items.append((feet_y, 0, img, x - img.width // 2, feet_y - img.height))
        return feet_y - img.height

    def hang(self, ref, cx, top_y):
        img = load(ref)[0]
        self.s.items.append((10000, 0, img, cx - img.width // 2, top_y))

    def export(self, key, partitions=()):
        import export_runtime
        export_runtime.export(key, self.s, self.x0, self.x1, self.wall_top, self.fy, self.bottom, partitions)

    def lappland(self, x, y):
        self.s.items.append((y, 0, LAPPLAND, x - 32, y - 46))

    def save(self, view=None):
        img = self.s.render(lit=True)
        img.save(os.path.join(OUT, f'room_{self.name}_v2_1x.png'))
        k = 3 if img.width <= 640 else 2
        img.resize((img.width * k, img.height * k), Image.NEAREST).save(os.path.join(OUT, f'room_{self.name}_v2_{k}x.png'))
        if view:
            vx = max(0, min(img.width - 640, int(view[0] - 320)))
            vy = max(0, min(img.height - 360, int(view[1] - 200)))
            v = img.crop((vx, vy, vx + 640, vy + 360))
            v.resize((1920, 1080), Image.NEAREST).save(os.path.join(OUT, f'room_{self.name}_v2_view_3x.png'))


# ======================= 仓储区 B1-03（大：56×32，暗钢） =======================
r = Room('warehouse', 56, 32, DARK)
r.north([('item', 'warehouse_wall_bay_120x46'), ('wall', 30), ('item', 'warehouse_notice_board_76x38'), ('wall', 40),
         ('item', 'warehouse_supergraphic_160x46'), ('wall', 40), ('item', 'warehouse_wall_clipboard_22x28'), ('wall', 30),
         ('item', 'warehouse_wall_bay_120x46')])
DOOR_U = 16.0
r.walls(east_door_u=DOOR_U)
s = r.s
# 四个类别区：每区一排货架，地面类别框在货架前方
blocks = [('weapons', 5.0, 8.0, 3), ('armor', 27.0, 8.0, 3), ('consumables', 5.0, 20.0, 3), ('materials', 27.0, 20.0, 2)]
for cat, ux, uy, n in blocks:
    feet = r.u(uy)
    for i in range(n):
        x = r.fx(ux) + i * 92 + 40
        s.light('light_pool_rectangle_cool_90x60', x, feet + 20, 0.22)
        s.decal(f'warehouse_zone_{cat}_90x44', x, feet + 24)
        top = r.rack(f'warehouse_rack_{cat}_80x64', x, feet)
        r.hang('warehouse_over_shelf_lamp_48x12', x, top - 14)
# 材料区：第三个位置放源石封存柜，旁边是封存箱
mx = r.fx(27.0) + 2 * 92 + 40
s.light('light_pool_circle_warm_60x40', mx, r.u(20.0), 0.40)
s.prop('warehouse_originium_containment_56x48', mx, r.u(20.0))
s.prop('warehouse_originium_sealed_crate_44x36', mx + 64, r.u(20.6))
s.prop('warehouse_originium_sealed_crate_44x36', mx + 64, r.u(23.0))
# 东侧：门口的仓储终端（主物件）与货运升降台（交付点）
s.prop('warehouse_storage_terminal_on_64x52', r.fx(50.0), r.u(DOOR_U - 4.0))
s.decal('warehouse_operator_spot_12x6', r.fx(50.0), r.u(DOOR_U - 2.6))
s.light('light_pool_rectangle_warm_90x60', r.fx(49.0), r.u(26.4), 0.28)
s.prop('warehouse_freight_lift_ready_96x56', r.fx(49.0), r.u(27.6))
# 叉车通道与搬运工具
s.prop('warehouse_forklift_70x48', r.fx(24.0), r.u(14.6))
s.prop('warehouse_trolley_42x34', r.fx(44.0), r.u(9.0))
s.prop('warehouse_trolley_42x34', r.fx(20.0), r.u(27.0))
for ux, uy in ((52.0, 3.0), (2.4, 3.2), (2.4, 15.4), (40.0, 29.6), (45.0, 29.8)):
    s.prop('warehouse_pallet_48x24', r.fx(ux), r.u(uy))
    s.prop('warehouse_supply_crate_42x32', r.fx(ux), r.u(uy) - 1)
# 扩建区：西南角
s.decal('expansion_pending_zone_90x60', r.fx(6.0), r.u(28.0))
s.decal('expansion_pending_zone_90x60', r.fx(12.4), r.u(28.0))
s.prop('expansion_temporary_partition_90x46', r.fx(6.0), r.u(31.6))
s.prop('expansion_temporary_partition_90x46', r.fx(12.4), r.u(31.6))
s.items.append((0, 0, load('small_number_plate_B1_03')[0], r.x1 - 34, int(r.u(DOOR_U)) - 34))
r.lappland(r.fx(52.0), r.u(DOOR_U + 0.6))
r.save(view=(r.fx(44.0), r.u(18.0)))

# ======================= 可露希尔商店 B1-01（小：18×10，暖色） =======================
r = Room('store', 18, 10, LIGHT, wall_tile='batch_H3_store_v1/store_wall_warm_60x46.png',
         floor_tile='batch_H3_store_v4/store_floor_warm_120x120.png')
r.north([('item', 'store_back_product_shelf'), ('wall', 8), ('item', 'store_warm_sign'), ('wall', 8),
         ('item', 'store_product_poster')])
r.walls()
s = r.s
cx = r.fx(9.0)
counter_y = r.u(4.2)
s.light('light_pool_rectangle_warm_90x60', cx, counter_y + 14, 0.22)
s.decal('store_counter_zone_80x36', cx, counter_y + 20)
s.prop('store_front_counter', cx, counter_y)
s.decal('store_stand_spot_closure_behind_counter_12x6', cx - 30, counter_y - 12)
s.decal('store_stand_spot_customer_at_terminal_12x6', cx, counter_y + 22)
r.hang('store_warm_pendant_lamp', cx + 26, counter_y - 52)
for x, ref, tag in ((r.fx(2.8), 'store_weapon_glass_case', 'store_price_tag_weapon_24x14'),
                    (r.fx(15.2), 'store_equipment_glass_case', 'store_price_tag_equipment_24x14')):
    y = r.u(7.4)
    s.light('light_pool_circle_cool_60x40', x, y, 0.20)
    s.prop(ref, x, y)
    ref_w = load(ref)[0].width
    s.items.append((y + 1, 0, load(tag)[0], x + ref_w // 2 - 20, y - 6))
s.prop('store_stacked_merchandise_boxes', r.fx(4.6), r.u(2.6))
s.prop('store_stacked_merchandise_boxes', r.fx(13.8), r.u(2.4))
s.prop('store_potted_plant', r.fx(16.8), r.u(2.2))
s.decal('store_safety_strip_30x10', cx, r.bottom - 6)
r.lappland(cx + 30, r.u(9.0))
r.export('store')
r.save()

# ======================= 整备室 B1-02（中，紧凑：28×13，浅色） =======================
r = Room('armory', 28, 13, LIGHT, floor_tile='batch3_equipment_v3/rhodes_floor_equipment_v1.png')
r.north([('item', 'armory_weapon_wall'), ('wall', 4), ('item', 'armory_tool_board'), ('wall', 4),
         ('item', 'armory_department_sign_120x36'), ('wall', 4), ('item', 'armory_weapon_wall')])
r.walls()
s = r.s
cx = r.fx(13.0)
by = r.u(5.4)
s.light('light_pool_rectangle_cool_90x60', cx, by + 10, 0.30)
s.decal('armory_bench_zone_100x44', cx, by + 16)
s.prop('armory_equipment_workbench', cx, by)
s.decal('armory_stand_spot_bench_operator_12x6', cx, by + 18)
# 吊钩和待吊运的装备箱紧挨工作台东侧
hx = r.fx(23.0)
BEAM_Y = r.fy + 12                              # 顶层横梁贴北墙前方走，避开工作台与机械臂（上沿的画面 y）
beam = load('overhead_ibeam_straight_ew_60x14')[0]
bl, br = load('overhead_ibeam_wall_bracket_left_28x28')[0], load('overhead_ibeam_wall_bracket_right_28x28')[0]
row = Image.new('RGBA', (r.w + 16, 28))
for x in range(14, r.w + 2, 60):
    row.alpha_composite(beam.crop((0, 0, min(60, r.w + 2 - x), 14)), (x, 7))
row.alpha_composite(bl, (0, 0))
row.alpha_composite(br, (row.width - 28, 0))
s.items.append((20000, 0, row, r.x0 - 8, BEAM_Y - 7))
trolley, hook = load('overhead_hoist_trolley')[0], load('overhead_hoist_hook')[0]
case_top = int(r.u(7.6)) - 20
tx, ty = hx - 16, BEAM_Y - 3                     # 吊车骑在梁上
hook_y = case_top - 3 - hook.height              # 吊钩停在装备箱正上方
s.items.append((20001, 0, trolley, tx, ty))
cable = Image.new('RGBA', (2, max(1, hook_y - (ty + 17))))
for yy in range(cable.height):
    cable.putpixel((0, yy), (152, 162, 166, 255))
    cable.putpixel((1, yy), (61, 68, 72, 255))
s.items.append((20001, 1, cable, tx + 15, ty + 17))  # 钢缆：吊车接口 (16,17) → 吊钩接口 (7,0)
s.items.append((20001, 2, hook, tx + 16 - 7, hook_y))
s.prop('armory_equipment_case', hx, r.u(7.6))
s.prop('armory_equipment_case', hx - 20, r.u(9.8))
s.prop('armory_equipment_case', hx + 20, r.u(9.8))
lamp = load('armory_task_lamp')[0]              # 作业灯也挂在同一根横梁上
s.items.append((20001, 3, lamp, int(cx) - lamp.width // 2, BEAM_Y + 9))
s.prop('armory_robotic_arm', cx + 72, by + 2)
s.decal('armory_stand_spot_weapon_wall_inspector_12x6', r.fx(3.6), r.u(2.2))
# 工作台西侧：两摞装备箱靠墙
for k in range(2):
    s.prop('armory_equipment_case', r.fx(3.2), r.u(6.0 + k * 1.8))
    s.prop('armory_equipment_case', r.fx(5.8), r.u(6.0 + k * 1.8))
s.decal('armory_safety_strip_30x10', cx, r.bottom - 6)
r.lappland(cx - 40, r.u(11.0))
r.export('armory')
r.save()

# ======================= 医疗部 B1-04（中：32×20，最白） =======================
r = Room('medical', 32, 20, LIGHT, wall_tile='batch_H3_medical_v1/medical_wall_white_60x46.png',
         floor_tile='batch_H3_medical_v1/medical_floor_cool_120x120.png')
r.north([('item', 'medical_medicine_cabinet'), ('wall', 14), ('item', 'medical_sanitizer'), ('wall', 40),
         ('item', 'medical_department_sign_120x36'), ('wall', 40), ('item', 'medical_medicine_cabinet'), ('wall', 14),
         ('item', 'medical_sanitizer')])
DOOR_U = 10.0
r.walls(west_door_u=DOOR_U)
s = r.s
# 回收病床：阵亡后在此醒来，靠近通往大厅的西门
bx, byy = r.fx(6.0), r.u(13.0)
s.light('light_pool_rectangle_cool_90x60', bx, byy, 0.28)
s.decal('medical_recovery_zone_100x44', bx, byy + 8)
s.prop('medical_recovery_bed', bx, byy)
s.prop('medical_iv_stand', bx - 40, byy - 6)
r.hang('medical_suspended_monitor', bx + 12, byy - 60)
s.decal('medical_stand_spot_recovery_attendant_12x6', bx + 46, byy + 4)
# 病房：一排 4 张病床，床间隔帘
for i in range(4):
    x = r.fx(13.0) + i * 76
    s.prop('medical_ward_bed', x, r.u(5.2))
    s.prop('medical_iv_stand', x - 30, r.u(4.6))
    if i < 3:
        s.prop('medical_privacy_curtain', x + 38, r.u(5.6))
s.prop('medical_wash_sink', r.fx(28.6), r.u(14.4))
s.prop('medical_wash_sink', r.fx(24.6), r.u(14.4))
s.decal('medical_stand_spot_medicine_cabinet_staff_12x6', r.fx(3.0), r.u(1.6))
s.items.append((0, 0, load('small_number_plate_B1_04')[0], r.x0 + 2, int(r.u(DOOR_U)) - 34))
r.lappland(bx + 46, r.u(16.0))
r.save()
print('rooms done')
