class_name ItemIcons
extends RefCounted

## Inventory icons for equipment (装备策划案 §6). Native 36 px per cell, drawn
## 1:1 and centred in the item tile. Icons come from the item's base
## (GearCatalog), its SpecialGear id, or its exclusive effect, else by name;
## items without art keep their text label.
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
}

static var _cache := {}

## E4: special gear uses its SpecialGear id as the icon id; regional
## exclusives are keyed by their effect.
const EXCLUSIVE_ICONS := {"raw_ore": "raw_originium", "riot_shield": "riot_shield", "frozen_relic": "frozen_relic"}

static func icon_id(item: Item) -> String:
	if item == null or not item.material_id.is_empty(): return ""
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
