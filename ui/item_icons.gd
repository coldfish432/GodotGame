class_name ItemIcons
extends RefCounted

## Inventory icons for equipment (装备策划案 §6). Native 36 px per cell, drawn
## 1:1 and centred in the item tile. Icons come from the item's base
## (GearCatalog), its SpecialGear id, or its exclusive effect, else by name;
## items without art keep their text label. Materials and potions are
## looked up by material id and potion type.
## Finished art is copied from art/items/batch_*_v* into art/items/runtime/.

const DIR := "res://art/items/runtime/"
## Item name → icon id: E1 (切尔诺伯格), E2 (龙门), E3 (萨米).
const BY_NAME := {
	"改装砍刀": "modified_machete", "制式短刀": "standard_dagger", "矿区制式刀": "mine_issue_blade",
	"纠察队佩刀": "patrol_saber", "断镐战斧": "pickhaft_blade",
	"矿工护甲": "miner_vest", "整合运动制式外套": "reunion_coat", "纠察队防寒大衣": "patrol_winter_coat",
	"矿场重型防护服": "heavy_mine_suit",
	"防尘面罩": "dust_mask", "烈酒扁壶": "liquor_flask", "整合运动面具": "reunion_mask", "源石感应计": "originium_meter",
	# E2 龙门
	"指刃": "finger_blade", "帮派砍刀": "gang_machete", "近卫局警用刀": "lgd_knife", "押运短刃": "courier_dagger",
	"炎式环首刀": "yan_ring_saber",
	"近卫局制式护甲": "lgd_vest", "消防署隔热服": "fire_suit", "押运防弹背心": "courier_vest", "特别督察组战术护甲": "inspector_armor",
	"战术挂饰": "tactical_charm", "近卫局对讲机": "lgd_radio", "龙门币钱夹": "lungmen_wallet", "炎式平安符": "yan_talisman",
	# E3 萨米
	"破冰刀": "icebreaker_knife", "猎刀": "skinning_knife", "角柄猎刀": "antler_hunter_knife",
	"科考队开路刀": "expedition_machete", "雪祀礼刃": "snowpriest_blade",
	"冰原毛皮外套": "tundra_fur_coat", "雪橇巡逻队斗篷": "sled_patrol_cloak", "科考队防寒服": "expedition_parka", "骨片札甲": "bone_lamellar",
	"骨制护符": "bone_amulet", "角兽骨笛": "antler_flute", "兽骨鼓槌": "bone_drumstick", "密文板残片": "cipher_fragment",
	# 装备扩充: the weapons (E7–E9, 37 icons) are Sol's art; armour and trinkets
	# stay placeholder recolours until E10–E12.
	"工兵锹": "mine_x01", "大号管钳": "mine_x02", "缠链指虎": "mine_x03", "纠察队钩刀": "mine_x04",
	"游击队旧式刺刀": "mine_x05", "施术短刃": "mine_x06", "攻坚破门锤": "mine_x07", "帝国突击矛": "mine_x08",
	"拼装轻甲": "mine_x09", "改装喷射背架": "mine_x10", "整合运动术师兜袍": "mine_x11", "伪装吉利服": "mine_x12",
	"游击队旧式军大衣": "mine_x13", "复合护具": "mine_x14", "头戴矿灯": "mine_x15", "军用止血带": "mine_x16",
	"劳役编号牌": "mine_x17", "切尔文铜币": "mine_x18", "纠察队手铐": "mine_x19", "游击队臂章": "mine_x20",
	"高能虫囊": "mine_x21", "拆下的施术单元": "mine_x22", "拆迁大锤": "city_x01", "铜指虎": "city_x02",
	"消防斧": "city_x03", "蝴蝶双刀": "city_x04", "护卫铁尺": "city_x05", "警用链锤": "city_x06",
	"炎式苗刀": "city_x07", "炎式朴刀": "city_x08", "执勤反光雨衣": "city_x09", "拳馆练功服": "city_x10",
	"染血白工装": "city_x11", "拾荒者伪装衫": "city_x12", "香主绸衫": "city_x13", "防爆重甲": "city_x14",
	"执勤警哨": "city_x15", "防风打火机": "city_x16", "老千骰子": "city_x17", "跌打药酒瓶": "city_x18",
	"无人机遥控器": "city_x19", "当铺铜牌": "city_x20", "琉璃护身珠": "city_x21", "染污短刀": "snow_x01",
	"伐木斧": "snow_x02", "兽颚指虎": "snow_x03", "凿冰长刀": "snow_x04", "科考冰镐": "snow_x05",
	"岩角战锤": "snow_x06", "裂骨拳刃": "snow_x07", "林线猎矛": "snow_x08", "角兽长毛披肩": "snow_x09",
	"桦皮护胸": "snow_x10", "林业护具": "snow_x11", "搜救队绳索背心": "snow_x12", "科考站加热背心": "snow_x13",
	"冬牙角盔": "snow_x14", "雪祀羽氅": "snow_x15", "族树木片": "snow_x16", "鼷兽毛团": "snow_x17",
	"幸运晶石": "snow_x18", "骨缝雪镜": "snow_x19", "手持定位仪": "snow_x20", "角兽银铃": "snow_x21",
	"黑雪结晶": "snow_x22", "猎首獠牙串": "snow_x23",
	# E13 v1 (叙拉古, 2026-10-18): Sol's art; eight touched up by Claude
	# (outline, joins, lifted darks: art/items/batch_E13_fix/).
	"黄铜拳套": "brass_knuckles", "肉铺剁骨刀": "butcher_cleaver", "弹簧折刀": "switchblade",
	"家族细匕首": "family_stiletto", "旧城撬棍": "old_town_crowbar", "理发店剃刀": "barber_razor",
	"手杖剑": "cane_sword", "葡萄园修枝镰": "vineyard_billhook", "灭迹弯刃": "eraser_curved_blade",
	"角头的灌铅手杖": "lead_cane", "狼首指虎": "wolfhead_knuckles",
	# E6 v1 (罗德岛制式, 2026-10-18).
	"罗德岛制式双刀": "rhodes_dual_blades", "罗德岛制式剑": "rhodes_sword", "罗德岛外勤制服": "rhodes_field_uniform",
	"罗德岛制式防护背心": "rhodes_protective_vest", "罗德岛制式信标": "rhodes_beacon", "罗德岛制式急救包": "rhodes_medkit",
	"罗德岛干员证章": "rhodes_badge",
	# E14 v1 (远程与法杖, 2026-10-18).
	"整合运动手弩": "reunion_hand_crossbow", "改装射钉枪": "modified_nail_gun", "帝国制式重弩": "imperial_heavy_crossbow", "拼装施术杖": "scrap_casting_staff",
	"整合运动术师长杖": "reunion_caster_staff", "近卫局警用手弩": "lgd_hand_crossbow", "组长连弩": "leader_repeating_crossbow", "拉特兰走私手铳": "laterano_smuggled_pistol",
	"铜铃术杖": "bronze_bell_staff", "炎式符杖": "yan_talisman_staff", "萨米猎弓": "sami_hunting_bow", "冰原猎铳": "tundra_hunting_gun",
	"复合角弓": "composite_horn_bow", "桦木巫杖": "birch_shaman_staff", "雪祀仪杖": "snowpriest_staff", "家族枪弩": "family_gun_crossbow",
	"折叠袖弩": "folding_sleeve_crossbow", "猎场双管铳": "double_barrel_gun", "律师的施术手杖": "lawyer_casting_cane", "审判庭仪杖": "tribunal_staff",
	"罗德岛制式弩": "rhodes_crossbow", "罗德岛制式法杖": "rhodes_staff",
}

## Materials by material id (美术补全案 M1 PRTS materials, M2 common supplies);
## stacks keep their count badge. Ids without art yet fall back to text.
const MATERIALS := {
	"源岩": "orirock", "固源岩": "orirock_cube", "固源岩组": "orirock_cluster", "提纯源岩": "orirock_concentration",
	"代糖": "sugar_substitute", "糖": "sugar", "酯原料": "ester", "聚酸酯": "polyester",
	"异铁碎片": "oriron_shard", "异铁": "oriron", "异铁组": "oriron_cluster", "双酮": "diketon",
	"酮凝集": "polyketon", "破损装置": "damaged_device", "装置": "device", "全新装置": "integrated_device",
	"改量装置": "optimized_device", "研磨石": "grindstone", "化合切削液": "compound_cutting_fluid", "扭转醇": "loxic_kohl",
	"轻锰矿": "manganese_ore", "晶体元件": "crystalline_component", "褐素纤维": "fuscous_fiber", "凝胶": "coagulating_gel",
	"D32钢": "d32_steel", "碳": "carbon_stick", "碳素": "carbon_brick", "碳素组": "carbon_pack",
	"基础加固建材": "building_material_basic", "进阶加固建材": "building_material_adv", "家具零件": "furniture_part", "赤金": "pure_gold",
	"源石碎片": "originium_shard", "螺栓": "bolts", "螺母": "nuts", "钉子": "nails",
	"木板": "plank", "金属板": "metal_plate", "软管": "hose", "密封泡沫": "sealing_foam",
	"胶带": "duct_tape", "帆布": "canvas_sheet", "电线": "wire_coil", "电源线": "power_cord",
	"灯泡": "light_bulb", "继电器": "relay", "电路板": "circuit_board", "微型电机": "micro_motor",
	"蓄电池": "battery", "车用蓄电池": "car_battery", "固体燃料": "solid_fuel", "燃料罐": "fuel_can",
	"扳手": "wrench", "工具套装": "toolkit", "医用耗材包": "medical_supplies",
	# Trade goods and 萨米 goods: stand-in icons from the supplies set until drawn.
	"工业补给箱": "toolkit", "电子元件箱": "circuit_board", "野外生活包": "canvas_sheet", "医疗补给箱": "medical_supplies",
	"林地草药": "sugar_substitute", "鞣制兽皮": "canvas_sheet",
	# Growth (精英化与加点策划案 §3.2), placeholders until the M batch.
	"近卫芯片": "guard_chip", "近卫芯片组": "guard_chip_pack", "芯片助剂": "chip_catalyst", "近卫双芯片": "guard_dualchip",
	"技巧概要·卷1": "skill_summary_1", "技巧概要·卷2": "skill_summary_2", "技巧概要·卷3": "skill_summary_3", "模组数据块": "module_data_block",
}
## Potions by potion type (M3).
const POTIONS := {"A": "potion_a", "B": "potion_b", "C": "potion_c"}

static var _cache := {}

## E4: special gear uses its SpecialGear id as the icon id; regional
## exclusives are keyed by their effect.
const EXCLUSIVE_ICONS := {"raw_ore": "raw_originium", "riot_shield": "riot_shield", "frozen_relic": "frozen_relic", "saluzzo_crest": "saluzzo_crest"}

static func icon_id(item: Item) -> String:
	if item == null: return ""
	if not item.material_id.is_empty(): return MATERIALS.get(item.material_id, "")
	if item.is_potion(): return POTIONS.get(item.potion_type, "")
	if not item.special.is_empty(): return item.special if SpecialGear.GEAR.has(item.special) else ""
	if EXCLUSIVE_ICONS.has(item.effect): return EXCLUSIVE_ICONS[item.effect]
	if not item.base_id.is_empty(): return str(GearCatalog.base(item.base_id).get("icon", ""))
	return BY_NAME.get(item.item_name, "")

static func path_for(item: Item) -> String:
	var id := icon_id(item)
	return "" if id.is_empty() else DIR + id + ".png"

static func texture_for(item: Item) -> Texture2D:
	var path := path_for(item)
	if path.is_empty(): return null
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]

## Draws the icon centred in `area` of `control` at 1:1; false when there is no icon.
static func draw(control: CanvasItem, item: Item, area: Rect2) -> bool:
	var texture := texture_for(item)
	if texture == null: return false
	var at := (area.position + ((area.size - texture.get_size()) * 0.5).floor())
	control.draw_texture(texture, at)
	return true
