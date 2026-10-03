"""把静态拼装导出为引擎素材（res://art/rhodes_runtime/）。

镜头为无偏航的正交 3/4 俯视，1 纹素 = 1 屏幕像素，所以拼装图本身就是引擎画面。每个房间导出三部分：
  ground  地面层（地板、地贴、光池、墙顶条），引擎里铺成一块平面，纵向按 15·sin(俯角) 像素/单位换算；
  facade  北墙立面（墙段与挂件），引擎里是一张面向镜头的立牌，脚底在北墙墙根；
  sprites 每件物件一张立牌，按脚底坐标摆放，和人物互相遮挡；顶层物件（排序值 ≥ 9999）始终画在最上面。
另外按 WORLD 配置写出连续地图中的房间原点、墙体碰撞、交互点和出生点。

只在设置环境变量 RHODES_EXPORT=1 时由拼装脚本调用。"""
import hashlib
import json
import os
from PIL import Image, ImageChops

HERE = os.path.dirname(os.path.abspath(__file__))
RUNTIME = os.path.normpath(os.path.join(HERE, '..', 'rhodes_runtime'))
TEX = os.path.join(RUNTIME, 'tex')
PX_X, PX_Y = 15.0, 12.7
ENABLED = os.environ.get('RHODES_EXPORT') == '1'

SEAM = 16 / 15.0       # 相邻两房间的侧墙墙顶条各 8 像素，并排成 16 像素厚的隔墙，房间原点相应错开

# 连续地图：房间原点（西边缘 x，北墙 z；z 轴向北为正）、尺寸、门洞（本地单位）、交互点与出生点（本地单位）。
WORLD = {
    'hall': dict(origin=(0.0, 0.0), size=(128, 56), north_doors=[(24 + 66 + 22) / 15.0, 124.93], west_doors=[26.0], east_doors=[26.0],
                 south_open=False,
                 interact=[('dispatch', 'contracts', '调度台：接单', 64.0, 12.2),
                           ('lift', 'contracts', '外勤出发升降梯', 64.0, 1.2),
                           ('logistics', 'insurance', '后勤柜台：投保', 101.33, 14.0)],
                 spawns={'arrival': (64.0, 53.0)}),
    'warehouse': dict(origin=(-64.0 - SEAM, -8.0), size=(64, 36), east_doors=[18.0], west_doors=[], north_doors=[],
                      interact=[('stash', 'stash', '仓管台：仓库', 50.0, 12.0),
                                # 出库区：东北角两个出库托盘的南侧，公告板就在它们正上方的北墙
                                ('outbound', 'outbound', '出库区：订单与交付', 55.5, 8.2)], spawns={}),
    'medical': dict(origin=(128.0 + SEAM, 4.0), size=(45, 41), west_doors=[30.0], east_doors=[], north_doors=[],
                    interact=[('reception', 'report', '医疗前台：回收报告与治疗', 7.0, 9.0),
                              # 药房窗口在北墙（x 10–15.2），站在洗手台南侧
                              ('pharmacy', 'pharmacy', '药房窗口：配药', 12.6, 5.0),
                              # 检测门在 x 14 的玻璃隔断上，站点放在大厅一侧
                              ('decon', 'decon', '污染检测门：检测与处理', 12.0, 20.5)],
                    spawns={'death': (32.5, 25.0)}),
    'store': dict(origin=(0.0, 10.0), size=(18, 10), west_doors=[], east_doors=[], north_doors=[], south_open=True,
                  interact=[('store', 'store', '可露希尔的商店', 9.0, 4.2)], spawns={}),
    'armory': dict(origin=(100.0, 13.0), size=(28, 13), west_doors=[], east_doors=[], north_doors=[], south_open=True,
                   interact=[('workbench', 'loadout', '整备台：装备', 13.0, 5.4)], spawns={}),
}
DOOR_W = 3.0           # 门洞宽度（单位）
# 拼装脚本用 img.info['rt'] 给物件打标：'skip' 只用于拼装示意（拉普兰德、交互浮标、手持物品框），不导出；
# 'ground' 合进地面层（俯视的扁平件）；'nocollide' 导出但不生成碰撞（例如检测门本身就是通道）。
# 另有 img.info['grp']：写进 sprites 的 group 字段，引擎按组做动画（仓储区货架为 'shelf:<类别>'）。


def _save_tex(img):
    os.makedirs(TEX, exist_ok=True)
    digest = hashlib.sha1(img.tobytes() + bytes(str(img.size), 'ascii')).hexdigest()[:16]
    name = f'{digest}.png'
    path = os.path.join(TEX, name)
    if not os.path.exists(path):
        img.save(path)
    return 'res://art/rhodes_runtime/tex/' + name


def _render_ground(scene):
    """与 Scene.render(lit=True) 相同，但不画物件：地板、地贴、光池。"""
    out = scene.base.copy()
    for img, x, y in scene.decals:
        out.alpha_composite(img, (int(x), int(y)))
    for img, x, y, s in scene.lights:
        l = img.convert('RGB').point(lambda v: int(v * s))
        layer = Image.new('RGB', out.size, (0, 0, 0))
        layer.paste(l, (int(x), int(y)))
        rgb = ImageChops.add(out.convert('RGB'), layer)
        out = Image.merge('RGBA', (*rgb.split(), out.getchannel('A')))
    return out


def _wall_segments(cfg):
    """房间四周墙体碰撞（世界坐标矩形 [x0, z0, x1, z1]），门洞处断开。"""
    ox, oz = cfg['origin']
    w, d = cfg['size']
    t = 0.6
    segs = []

    def along_x(z, doors):
        cuts = sorted(doors)
        x = 0.0
        for c in cuts + [None]:
            end = w if c is None else c - DOOR_W / 2
            if end > x:
                segs.append([ox + x, z - t / 2, ox + end, z + t / 2])
            if c is not None:
                x = c + DOOR_W / 2

    def along_z(x, doors):
        cuts = sorted(doors)
        u = 0.0
        for c in cuts + [None]:
            end = d if c is None else c - DOOR_W / 2
            if end > u:
                segs.append([x - t / 2, oz - end, x + t / 2, oz - u])
            if c is not None:
                u = c + DOOR_W / 2

    # 碰撞体放在墙顶条上（地面以外），内侧贴齐地面边缘
    along_x(oz + t / 2, cfg.get('north_doors', []))
    if not cfg.get('south_open', False):
        along_x(oz - d - t / 2, [])
    along_z(ox - t / 2, cfg.get('west_doors', []))
    along_z(ox + w + t / 2, cfg.get('east_doors', []))
    return segs


def export(key, scene, x0, x1, wall_top, fy, bottom, partitions=()):
    """partitions：房间内部隔断，本地单位 (ux0, uz0, ux1, uz1) 的列表，用于碰撞。"""
    if not ENABLED:
        return
    cfg = WORLD[key]
    ox, oz = cfg['origin']
    ground_full = _render_ground(scene)
    for sort, order, img, x, y in sorted(scene.items, key=lambda t: (t[0], t[1])):
        if img.info.get('rt') == 'ground':
            ground_full.alpha_composite(img, (int(x), int(y)))
    left = x0 - 8
    ground = ground_full.crop((left, fy, x1 + 8, bottom))
    facade = scene.base.crop((left, wall_top, x1 + 8, fy))
    room = dict(id=key, origin=[ox, oz], size=list(cfg['size']),
                ground=dict(tex=_save_tex(ground), w_px=ground.width, h_px=ground.height, x=ox + (left - x0) / PX_X, z=oz),
                facade=dict(tex=_save_tex(facade), w_px=facade.width, h_px=facade.height, x=ox + (left - x0) / PX_X, z=oz),
                sprites=[], colliders=_wall_segments(cfg), interactables=[], spawns={})
    # export_extra：只给引擎、不进静态拼装图的物件（例如未建的货架位）
    for sort, _order, img, x, y in list(scene.items) + list(getattr(scene, 'export_extra', [])):
        tag = img.info.get('rt')
        if tag in ('skip', 'ground'):
            continue
        overhead = sort >= 9999
        bottom_y = y + img.height
        # 排序值就是脚底；排序值小于图像底边的（墙上的编号牌、侧墙牌）按图像底边站立
        feet = bottom_y if (overhead or sort < bottom_y) else sort
        cx = x + img.width / 2
        wx = ox + (cx - x0) / PX_X
        wz = oz - (feet - fy) / PX_Y
        lift_px = feet - bottom_y                  # 图像底边高于脚底的像素数（吊挂件 > 0）
        entry = dict(tex=_save_tex(img), x=round(wx, 4), z=round(wz, 4), lift_px=round(lift_px, 2),
                     w=img.width, h=img.height, overhead=overhead)
        if img.info.get('grp'):
            entry['group'] = img.info['grp']          # 引擎按组播放动画，例如仓储区货架 'shelf:<类别>'
        if img.info.get('role'):
            entry['role'] = img.info['role']          # 例如 'cells'：货架正面的格位层，引擎按存量重画
        # 碰撞：落地的物件（排除顶层、吊挂件、编号牌这类小件）。prop() 的锚点在图像最后一行，底边比脚底低 1 像素，所以按 ±2 像素判断
        if tag != 'nocollide' and not overhead and abs(sort - bottom_y) <= 2 and img.height >= 16 and img.width >= 18:
            entry['collide'] = [round(img.width / PX_X * 0.8, 3), 0.9 if img.height < 60 else 1.3]
        room['sprites'].append(entry)
    # 引擎摆放动态物件用的锚点：本地单位的点 [x, u] 换成世界坐标 [x, z]，矩形 [x0, u0, x1, u1] 换成 [x0, z_south, x1, z_north]
    def to_world(v):
        if isinstance(v, dict): return {k: to_world(x) for k, x in v.items()}
        if isinstance(v, list) and len(v) == 2 and all(isinstance(x, (int, float)) for x in v):
            return [round(ox + v[0], 4), round(oz - v[1], 4)]
        if isinstance(v, list) and len(v) == 4 and all(isinstance(x, (int, float)) for x in v):
            return [round(ox + v[0], 4), round(oz - v[3], 4), round(ox + v[2], 4), round(oz - v[1], 4)]
        if isinstance(v, list): return [to_world(x) for x in v]
        return v
    if getattr(scene, 'anchors', None): room['anchors'] = to_world(scene.anchors)
    # 引擎运行时拼用的贴图（货箱、格位、图标等），按名称索引
    textures = dict(getattr(scene, 'textures', None) or {})
    textures.update(getattr(scene, 'textures_extra', None) or {})
    if textures: room['textures'] = {k: _save_tex(img) for k, img in textures.items()}
    if getattr(scene, 'cells', None): room['cells'] = scene.cells
    if getattr(scene, 'board_lift', None) is not None: room['board_lift'] = scene.board_lift
    # 逐帧动画（例如仓储区货架的地面闸门）：只导出贴图，摆放由引擎按对应的物件决定
    for name, imgs in getattr(scene, 'anim', {}).items():
        room.setdefault('anim', {})[name] = [_save_tex(img) for img in imgs]
    for ux0, uz0, ux1, uz1 in partitions:
        room['colliders'].append([ox + min(ux0, ux1), oz - max(uz0, uz1), ox + max(ux0, ux1), oz - min(uz0, uz1)])
    for ident, kind, label, ux, uz in cfg['interact']:
        room['interactables'].append(dict(id=ident, kind=kind, label=label, x=ox + ux, z=oz - uz))
    for name, (ux, uz) in cfg['spawns'].items():
        room['spawns'][name] = [ox + ux, oz - uz]
    os.makedirs(RUNTIME, exist_ok=True)
    with open(os.path.join(RUNTIME, f'room_{key}.json'), 'w', encoding='utf-8') as f:
        json.dump(room, f, ensure_ascii=False, indent=1)
    print('exported', key, len(room['sprites']), 'sprites', len(room['colliders']), 'colliders')
