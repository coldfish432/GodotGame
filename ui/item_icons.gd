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
	# 装备扩充: Sol's art, the weapons from E7–E9, armour and trinkets from E10–E12.
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
	# Trade packs (交易包修订案 §8): the supplies set until Sol's pack crates.
	"建材包": "toolkit", "电子包": "circuit_board", "医疗包": "medical_supplies", "作物包": "sugar_substitute", "燃料包": "fuel_can",
	"寒地物资包": "canvas_sheet", "源石包": "toolkit", "养成材料包": "toolkit", "违禁品包": "toolkit",
	"武器包": "toolkit", "防具包": "toolkit", "饰品包": "toolkit",
	"林地草药": "sugar_substitute", "鞣制兽皮": "canvas_sheet",
	# Borrowed until it has its own art.
	"玄纹墨": "loxic_kohl",
	# 势力特供, crops and 补给 (势力特供策划案_v0_2): borrowed until Sol's batch.
	"高能燃料": "battery", "下城区耳目": "relay", "高纯源岩助熔剂": "compound_cutting_fluid", "萨米冰原苔": "fuscous_fiber",
	"骑士工坊专利授权": "module_data_block", "企鹅专递单": "duct_tape", "残党向导": "damaged_device",
	"闪耀作物种子": "crystalline_component", "闪耀作物·变种种子": "crystalline_component",
	# 势力声望解锁策划案 §三 (Sol, 势力声望物品图标美术需求_v1).
	"近卫局通行证": "rank_lgd_pass", "下城区黑市名录": "rank_rat_directory", "莱茵实验抑制剂": "rank_rhine_suppressant",
	"雪山向导绳": "rank_karlan_rope", "矿场勘探图": "rank_ursus_survey", "残党暗号": "rank_reunion_password",
	"冰原熏肉": "rank_sami_meat", "商业联合会担保函": "rank_kaz_guarantee", "加急专递单": "rank_penguin_express",
	"商会荣誉理事章": "badge_lungmen", "老鼠王的信物": "badge_rat", "莱茵合作研究员证": "badge_rhine",
	"喀兰贸易金卡": "badge_karlan", "矿场主事铭牌": "badge_ursus", "残党联络人": "badge_reunion",
	"萨米部族护符": "badge_sami", "骑士竞技场赞助证": "badge_kazimierz", "企鹅物流 VIP 卡": "badge_penguin",
	"舰载麦": "sugar_substitute", "块茎薯": "orirock", "温室豆": "ester", "闪耀作物": "crystalline_component", "闪耀作物·变种": "originium_shard",
	"舰内口粮": "sugar", "食堂便当": "grindstone", "闪耀定食": "coagulating_gel", "变种盛宴": "polyester",
	# Growth (精英化与加点策划案 §3.2), placeholders until the M batch.
	"芯片": "guard_chip", "芯片组": "guard_chip_pack", "芯片助剂": "chip_catalyst", "双芯片": "guard_dualchip",
	"技巧概要·卷1": "skill_summary_1", "技巧概要·卷2": "skill_summary_2", "技巧概要·卷3": "skill_summary_3", "模组数据块": "module_data_block",
	"基础作战记录": "record_basic", "初级作战记录": "record_drill", "中级作战记录": "record_frontline", "高级作战记录": "record_tactical",
}
## Potions by potion type (M3).
const POTIONS := {"A": "potion_a", "B": "potion_b", "C": "potion_c", "D": "potion_d", "E": "potion_e", "F": "potion_f", "G": "potion_g",
	"H": "potion_h", "I": "potion_i", "J": "potion_j", "K": "potion_k", "L": "potion_l",
	"rat": "potion_rat", "reunion": "potion_reunion", "ursus": "potion_ursus", "sami": "potion_sami",
	"rhine": "rank_rhine_suppressant"}

static var _cache := {}

## 收藏品 (整理箱与收藏品策划案 v0.2; 美术需求 收藏品与整理箱图标_v1): Sol's file per piece.
const COLLECTIBLES := {
	"矿区通行证": "col_mine_pass",
	"矿工护身符": "col_miner_charm",
	"铁皮套娃": "col_tin_doll",
	"旧矿灯": "col_old_lamp",
	"旧式怀表": "col_pocket_watch",
	"源石灯罩": "col_lamp_shade",
	"学校纪念徽章": "col_school_badge",
	"帝国勋章": "col_imperial_medal",
	"茶楼筹码": "col_teahouse_chip",
	"旧版龙门币样钞": "col_lmd_specimen",
	"麻将牌匣": "col_mahjong",
	"老式收音机": "col_radio",
	"醒狮摆件": "col_lion_dance",
	"炎国瓷茶壶": "col_yan_teapot",
	"近卫局纪念章": "col_lgd_medal",
	"古玉坠": "col_jade_pendant",
	"驯鹿铃铛": "col_reindeer_bell",
	"兽皮护符": "col_hide_charm",
	"驯鹿角饰": "col_antler",
	"桦树皮篓": "col_birch_basket",
	"萨米木雕": "col_sami_carving",
	"雪境古地图": "col_snow_map",
	"萨满骨笛": "col_bone_flute",
	"极光琥珀": "col_aurora_amber",
	"街角咖啡杯": "col_coffee_cup",
	"歌剧院旧海报": "col_opera_poster",
	"银质餐刀匣": "col_silver_cutlery",
	"黄铜打火机": "col_brass_lighter",
	"陈年酒瓶": "col_vintage_bottle",
	"陶瓷狼像": "col_porcelain_wolf",
	"家族账本": "col_family_ledger",
	"家族印章": "col_family_seal",
	"芬手办": "fig_fang",
	"克洛丝手办": "fig_kroos",
	"杜宾手办": "fig_dobermann",
	"古米手办": "fig_gummy",
	"红豆手办": "fig_vigna",
	"角峰手办": "fig_matterhorn",
	"阿米娅手办": "fig_amiya",
	"德克萨斯手办": "fig_texas",
	"拉普兰德手办": "fig_lappland",
	"白面鸮手办": "fig_ptilopsis",
	"蓝毒手办": "fig_blue_poison",
	"临光手办": "fig_nearl",
	"能天使手办": "fig_exusiai",
	"银灰手办": "fig_silverash",
	"陈手办": "fig_chen",
	"艾雅法拉手办": "fig_eyjafjalla",
	"斯卡蒂手办": "fig_skadi",
	"凯尔希手办": "fig_kaltsit",
}

## E4: special gear uses its SpecialGear id as the icon id; regional
## exclusives are keyed by their effect.
const EXCLUSIVE_ICONS := {"raw_ore": "raw_originium", "sealed_ore": "raw_originium", "riot_shield": "riot_shield", "frozen_relic": "frozen_relic", "saluzzo_crest": "saluzzo_crest"}

static func icon_id(item: Item) -> String:
	if item == null: return ""
	if not item.material_id.is_empty(): return MATERIALS.get(item.material_id, "")
	if item.is_potion(): return POTIONS.get(item.potion_type, "")
	# 收藏品 and 整理箱 (整理箱与收藏品策划案 v0.2): Sol's file ("col_family_seal",
	# "case_material_2"); a piece without its file shows the name.
	if item.category == Item.Category.COLLECTIBLE: return COLLECTIBLES.get(item.base_id, "")
	if item.category == Item.Category.CASE: return "%s_%d" % [item.base_id, item.case_tier]
	if item.effect == GameManager.GIFT_PACK: return "gift_pack"
	if not item.special.is_empty(): return item.special if SpecialGear.GEAR.has(item.special) else ""
	if EXCLUSIVE_ICONS.has(item.effect): return EXCLUSIVE_ICONS[item.effect]
	if not item.base_id.is_empty(): return str(GearCatalog.base(item.base_id).get("icon", ""))
	return BY_NAME.get(item.item_name, "")

## E15 (装备部位拆分与数值案 §7): a head, hands, legs, feet or ring base whose art
## has not landed yet shows its slot's placeholder; Sol's file under the
## base's id replaces it with no code change.
const SLOT_PLACEHOLDERS := {Item.Category.HEAD: "placeholder_head", Item.Category.HANDS: "placeholder_hands",
	Item.Category.LEGS: "placeholder_legs", Item.Category.FEET: "placeholder_feet", Item.Category.RING: "placeholder_ring"}

static func path_for(item: Item) -> String:
	var id := icon_id(item)
	if not id.is_empty() and not ResourceLoader.exists(DIR + id + ".png") and item != null and SLOT_PLACEHOLDERS.has(item.category):
		id = SLOT_PLACEHOLDERS[item.category]
	return "" if id.is_empty() else DIR + id + ".png"

static func texture_for(item: Item) -> Texture2D:
	var path := path_for(item)
	if path.is_empty(): return null
	if not _cache.has(path):
		var art: Texture2D = load(path) if ResourceLoader.exists(path) else null
		if art != null and is_hires(art): art = _icon_sized(art, item)
		_cache[path] = art
	return _cache[path]

## Hand-painted, not pixel art (用户 2026-10-26: 手办可以是高清图，需要有手办的3d感):
## art this big is drawn smoothly — shrunk once to the icon size of its
## footprint for the grids (40 n − 8 px a side), shown large on the hover card.
const HIRES_TEXELS := 160

static func is_hires(art: Texture2D) -> bool:
	return art != null and maxi(art.get_width(), art.get_height()) > HIRES_TEXELS

static func is_hires_path(path: String) -> bool:
	return not path.is_empty() and ResourceLoader.exists(path) and is_hires(load(path))

static func _icon_sized(art: Texture2D, item: Item) -> Texture2D:
	var cells := Vector2i(item.height, item.width) if item.rotated else Vector2i(item.width, item.height)
	var box := Vector2(cells * 40 - Vector2i(8, 8))
	var k := minf(box.x / art.get_width(), box.y / art.get_height())
	var image := art.get_image().duplicate()
	if image.is_compressed(): image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(maxi(1, roundi(art.get_width() * k)), maxi(1, roundi(art.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	var icon := ImageTexture.create_from_image(image)
	# Loot.ground_texture keys its cache by path.
	icon.resource_name = art.resource_path
	return icon

## Draws the icon centred in `area` of `control` at 1:1; false when there is no icon.
static func draw(control: CanvasItem, item: Item, area: Rect2) -> bool:
	var texture := texture_for(item)
	if texture == null: return false
	if item.rotated:
		# Turned a quarter about the cell's centre (Item.rotate).
		var centre := area.get_center().floor()
		control.draw_set_transform(centre, PI * 0.5)
		control.draw_texture(texture, (-texture.get_size() * 0.5).floor())
		control.draw_set_transform(Vector2.ZERO)
		return true
	var at := (area.position + ((area.size - texture.get_size()) * 0.5).floor())
	control.draw_texture(texture, at)
	return true
