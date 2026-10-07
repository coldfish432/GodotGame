class_name GearCatalog
extends RefCounted

## Equipment bases (装备策划案_v1_0.md §2, §4): every ordinary piece of gear
## is one of these. A base fixes the name, a power factor and an intrinsic
## ("固有") stat that does not use an affix slot. Random affixes still come
## from rarity, as before (LootTables.roll_equipment).
##
## Tiers 0/1/2 (浅/中/深) unlock at segments 1/3/5 (§2.2); elites, guards and
## vaults see them two segments early. The ranged bases (弩/铳) are designed
## but stay out of the pool until there is a ranged operator (§2.4).

## Forms that shoot rather than swing: they cannot attack the air.
const RANGED_FORMS := ["crossbow", "gun"]

const S := ItemModifier.Stat
const W := Item.Category.WEAPON
const A := Item.Category.ARMOR
const T := Item.Category.TRINKET

## Shallow / mid / deep bases open at these floors (the ten-floor camp rhythm).
const TIER_DEPTH := [1, 4, 7]
const EARLY_SOURCES := ["elite", "guard", "vault"]
const EARLY_BY := 2
## Marks an intrinsic modifier (ItemModifier.tier); −1 is a special item's cost.
const IMPLICIT_TIER := -2

## id: name, region, category, tier, power factor, intrinsic stats, form,
## enemies who carry it, icon, flavour text. `value` multiplies the delivery
## price (龙门币钱夹 only).
const BASES := {
	# --- 切尔诺伯格 · 坍塌矿区 (§4.1)
	"mine_cleaver": {"name": "改装砍刀", "region": "mine", "category": W, "tier": 0, "factor": 1.00, "implicit": [[S.CRIT_DMG, 0.10]],
		"form": "blade", "enemies": ["thug"], "icon": "modified_machete", "text": "刀背上还留着焊缝。"},
	"mine_shortblade": {"name": "制式短刀", "region": "mine", "category": W, "tier": 0, "factor": 0.95, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]],
		"form": "blade", "enemies": ["crossbow", "crossbow_leader"], "icon": "standard_dagger", "text": "缴获来的，编号被锉掉了。"},
	"mine_issue": {"name": "矿区制式刀", "region": "mine", "category": W, "tier": 0, "factor": 1.00, "implicit": [],
		"form": "blade", "icon": "mine_issue_blade", "text": "矿场配发的开路刀，砍支架也砍人。"},
	"mine_saber": {"name": "纠察队佩刀", "region": "mine", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.CRIT_RATE, 0.03]],
		"form": "blade", "icon": "patrol_saber", "text": "刀鞘不见了，刀还记得它是追人用的。"},
	"mine_pickaxe": {"name": "断镐战斧", "region": "mine", "category": W, "tier": 2, "factor": 1.15, "implicit": [[S.ATK_PCT, 0.04], [S.MOVE_SPEED_PCT, -0.04]],
		"form": "heavy", "icon": "pickhaft_blade", "text": "镐头断了一半，剩下那半磨成了斧。"},
	"mine_vest": {"name": "矿工护甲", "region": "mine", "category": A, "tier": 0, "factor": 1.00, "implicit": [[S.MAX_HP_PCT, 0.04]],
		"icon": "miner_vest", "text": "胸口缝着矿场的编号。"},
	"mine_reunion_coat": {"name": "整合运动制式外套", "region": "mine", "category": A, "tier": 0, "factor": 0.95, "implicit": [[S.MOVE_SPEED_PCT, 0.04]],
		"icon": "reunion_coat", "text": "穿上它的人不需要名字。"},
	"mine_greatcoat": {"name": "纠察队防寒大衣", "region": "mine", "category": A, "tier": 1, "factor": 1.05, "implicit": [[S.RES_FLAT, 4.0]],
		"icon": "patrol_winter_coat", "text": "厚得能挡住冻原的风，挡不住矿石病。"},
	"mine_hazard_suit": {"name": "矿场重型防护服", "region": "mine", "category": A, "tier": 2, "factor": 1.15, "implicit": [[S.DEF_FLAT, 20.0], [S.MOVE_SPEED_PCT, -0.04]],
		"icon": "heavy_mine_suit", "text": "给最深的矿道准备的，没来得及发下去。"},
	"mine_dust_mask": {"name": "防尘面罩", "region": "mine", "category": T, "tier": 0, "factor": 1.00, "implicit": [[S.RES_FLAT, 4.0]],
		"icon": "dust_mask", "text": "滤芯是黑的，说明它一直在工作。"},
	"mine_flask": {"name": "烈酒扁壶", "region": "mine", "category": T, "tier": 0, "factor": 0.95, "implicit": [[S.CRIT_DMG, 0.10]],
		"icon": "liquor_flask", "text": "摇一摇，还剩一口。"},
	"mine_reunion_mask": {"name": "整合运动面具", "region": "mine", "category": T, "tier": 1, "factor": 1.00, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]],
		"icon": "reunion_mask", "text": "面具都一样，所以没人记得谁倒下了。"},
	"mine_meter": {"name": "源石感应计", "region": "mine", "category": T, "tier": 2, "factor": 1.10, "implicit": [[S.ARTS_PCT, 0.05]],
		"icon": "originium_meter", "text": "罗德岛测绘队的仪器，指针一直贴在头上。"},
	# --- 龙门 (§4.2)
	"city_finger_blade": {"name": "指刃", "region": "city", "category": W, "tier": 0, "factor": 0.95, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]],
		"form": "fist", "enemies": ["brawler"], "icon": "finger_blade", "text": "出拳够快的人，刀只需要很短。"},
	"city_gang_chopper": {"name": "帮派砍刀", "region": "city", "category": W, "tier": 0, "factor": 1.00, "implicit": [[S.CRIT_DMG, 0.10]],
		"form": "blade", "enemies": ["thug"], "icon": "gang_machete", "text": "刀柄缠的红绳，是哪一家的颜色？"},
	"city_lgd_knife": {"name": "近卫局警用刀", "region": "city", "category": W, "tier": 0, "factor": 1.00, "implicit": [],
		"form": "blade", "icon": "lgd_knife", "text": "刀柄上有编号，登记在册。"},
	"city_escort_blade": {"name": "押运短刃", "region": "city", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.MOVE_SPEED_PCT, 0.04]],
		"form": "blade", "icon": "courier_dagger", "text": "货要准时到，人要活着到。"},
	"city_ring_saber": {"name": "炎式环首刀", "region": "city", "category": W, "tier": 2, "factor": 1.12, "implicit": [[S.CRIT_RATE, 0.03]],
		"form": "blade", "icon": "yan_ring_saber", "text": "刀法比刀老，刀也比城老。"},
	"city_lgd_vest": {"name": "近卫局制式护甲", "region": "city", "category": A, "tier": 0, "factor": 1.00, "implicit": [[S.DEF_FLAT, 20.0]],
		"icon": "lgd_vest", "text": "肩上的局徽被刮过，但没刮干净。"},
	"city_fire_suit": {"name": "消防署隔热服", "region": "city", "category": A, "tier": 0, "factor": 0.95, "implicit": [[S.RES_FLAT, 4.0]],
		"icon": "fire_suit", "text": "那天烧得最厉害的地方，他们最先进去。"},
	"city_carrier": {"name": "押运防弹背心", "region": "city", "category": A, "tier": 1, "factor": 1.05, "implicit": [[S.MAX_HP_PCT, 0.04]],
		"icon": "courier_vest", "text": "插板缺了一块，正好是挨过的那一块。"},
	"city_inspector": {"name": "特别督察组战术护甲", "region": "city", "category": A, "tier": 2, "factor": 1.15, "implicit": [[S.DEF_FLAT, 20.0], [S.MAX_HP_PCT, 0.04]],
		"icon": "inspector_armor", "text": "这身护甲的上一任主人，任期没满两年。"},
	"city_charm": {"name": "战术挂饰", "region": "city", "category": T, "tier": 0, "factor": 1.00, "implicit": [[S.CRIT_DMG, 0.10]],
		"icon": "tactical_charm", "text": "挂在背心上的小东西，谁都有一个。"},
	"city_radio": {"name": "近卫局对讲机", "region": "city", "category": T, "tier": 0, "factor": 0.95, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]],
		"icon": "lgd_radio", "text": "频道里只剩杂音，偶尔有人报位置。"},
	"city_wallet": {"name": "龙门币钱夹", "region": "city", "category": T, "tier": 1, "factor": 1.00, "implicit": [[S.MAX_HP_PCT, 0.04]], "value": 1.5,
		"icon": "lungmen_wallet", "text": "里面的钱早花完了，钱夹本身倒值钱。"},
	"city_talisman": {"name": "炎式平安符", "region": "city", "category": T, "tier": 2, "factor": 1.10, "implicit": [[S.ARTS_PCT, 0.05], [S.RES_FLAT, 4.0]],
		"icon": "yan_talisman", "text": "求平安的人，未必平安，但符留下来了。"},
	# --- 萨米 · 冻土林线 (§4.3)
	"snow_icebreaker": {"name": "破冰刀", "region": "snow", "category": W, "tier": 0, "factor": 1.00, "implicit": [[S.CRIT_DMG, 0.10]],
		"form": "blade", "enemies": ["ice_warrior"], "icon": "icebreaker_knife", "text": "先敲开冰，再敲开别的。"},
	"snow_skinner": {"name": "猎刀", "region": "snow", "category": W, "tier": 0, "factor": 0.95, "implicit": [[S.CRIT_RATE, 0.03]],
		"form": "blade", "enemies": ["ice_hunter"], "icon": "skinning_knife", "text": "皮要剥得完整，这是猎人对猎物的礼数。"},
	"snow_antler_knife": {"name": "角柄猎刀", "region": "snow", "category": W, "tier": 0, "factor": 1.00, "implicit": [[S.MOVE_SPEED_PCT, 0.04]],
		"form": "blade", "icon": "antler_hunter_knife", "text": "角是向林子借的，用完要还。"},
	"snow_machete": {"name": "科考队开路刀", "region": "snow", "category": W, "tier": 1, "factor": 1.05, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]],
		"form": "blade", "icon": "expedition_machete", "text": "南边城市造的刀，走到这里已经不像南边的了。"},
	"snow_rite_blade": {"name": "雪祀礼刃", "region": "snow", "category": W, "tier": 2, "factor": 1.15, "implicit": [[S.ATK_PCT, 0.04], [S.CRIT_RATE, 0.03]],
		"form": "blade", "icon": "snowpriest_blade", "text": "埋在冻土下面，刃口依然是冷的。"},
	"snow_fur_coat": {"name": "冰原毛皮外套", "region": "snow", "category": A, "tier": 0, "factor": 1.00, "implicit": [[S.MAX_HP_PCT, 0.04]],
		"icon": "tundra_fur_coat", "text": "毛朝里穿，雪就进不来。"},
	"snow_cloak": {"name": "雪橇巡逻队斗篷", "region": "snow", "category": A, "tier": 0, "factor": 0.95, "implicit": [[S.MOVE_SPEED_PCT, 0.04]],
		"icon": "sled_patrol_cloak", "text": "披上它，雪地里远远就能认出你是自己人。"},
	"snow_parka": {"name": "科考队防寒服", "region": "snow", "category": A, "tier": 1, "factor": 1.05, "implicit": [[S.RES_FLAT, 4.0]],
		"icon": "expedition_parka", "text": "标签上写的温度，这里早就低过了。"},
	"snow_lamellar": {"name": "骨片札甲", "region": "snow", "category": A, "tier": 2, "factor": 1.15, "implicit": [[S.DEF_FLAT, 20.0], [S.MAX_HP_PCT, 0.04]],
		"icon": "bone_lamellar", "text": "每一片骨头，都来自一只认得这片林子的兽。"},
	"snow_amulet": {"name": "骨制护符", "region": "snow", "category": T, "tier": 0, "factor": 1.00, "implicit": [[S.ARTS_PCT, 0.05]],
		"icon": "bone_amulet", "text": "刻痕被很多只手摸平了。"},
	"snow_flute": {"name": "角兽骨笛", "region": "snow", "category": T, "tier": 0, "factor": 0.95, "implicit": [[S.ATTACK_SPEED_PCT, 0.05]],
		"icon": "antler_flute", "text": "吹响时，林子会安静一下。"},
	"snow_drumstick": {"name": "兽骨鼓槌", "region": "snow", "category": T, "tier": 1, "factor": 1.00, "implicit": [[S.CRIT_DMG, 0.10]],
		"icon": "bone_drumstick", "text": "敲鼓的人不在了，鼓槌还记得节拍。"},
	"snow_cipher": {"name": "密文板残片", "region": "snow", "category": T, "tier": 2, "factor": 1.10, "implicit": [[S.ARTS_PCT, 0.05], [S.CRIT_DMG, 0.10]],
		"icon": "cipher_fragment", "text": "读不懂上面的字，但它好像读得懂你。"},
}

## Names that changed (they follow the art, §2.3), and the generic names of
## gear saved before bases existed, mapped by region to the shallow baseline.
const RENAMED := {"镐柄战刃": "断镐战斧", "冰原猎刀": "角柄猎刀"}
const LEGACY_BASELINE := {
	"外勤战刃": {"mine": "mine_issue", "city": "city_lgd_knife", "snow": "snow_antler_knife"},
	"防护甲胄": {"mine": "mine_vest", "city": "city_lgd_vest", "snow": "snow_fur_coat"},
}

static var _by_name := {}

static func id_for_name(item_name: String) -> String:
	if _by_name.is_empty():
		for id in BASES: _by_name[BASES[id].name] = id
	return _by_name.get(RENAMED.get(item_name, item_name), "")

## Bases registered at run time (tests; later the ranged bases), looked up
## after BASES.
static var extra_bases := {}

static func base(id: String) -> Dictionary:
	return BASES.get(id, extra_bases.get(id, {}))

## Bases of a slot in a region that a source may drop at a depth (§2.2–2.3).
static func eligible(category: int, region: String, depth: int, source: String) -> Array:
	var early := EARLY_BY if source in EARLY_SOURCES else 0
	var out: Array = []
	for id in BASES:
		var b: Dictionary = BASES[id]
		if int(b.category) != category or b.region != region: continue
		if source == "vault" and int(b.tier) < 1: continue
		if depth + early >= TIER_DEPTH[int(b.tier)]: out.append(id)
	if out.is_empty():  # a vault at depth 1 still opens with something
		for id in BASES:
			if int(BASES[id].category) == category and BASES[id].region == region and int(BASES[id].tier) == 1: out.append(id)
	return out

## Picks a base id. Ordinary enemies drop the weapon they carry; elites their
## region's deepest weapon; everything else draws from the region's table,
## the deepest unlocked tier at weight 2 and the rest at 1 (elites ×2 deep).
static func pick(category: int, region: String, depth: int, source: String, enemy_type: String, rng: RandomNumberGenerator) -> String:
	if category == W:
		if source == "elite":
			for id in BASES:
				if BASES[id].region == region and int(BASES[id].category) == W and int(BASES[id].tier) == 2: return id
		var carried := _carried(enemy_type, region)
		if not carried.is_empty(): return carried
	var ids := eligible(category, region, depth, source)
	var top := 0
	for id in ids: top = maxi(top, int(BASES[id].tier))
	var weights: Array = []
	for id in ids:
		var tier := int(BASES[id].tier)
		var w := 2.0 if tier == top else 1.0
		if source == "elite" and tier == 2: w *= 2.0
		weights.append(w)
	var total := 0.0
	for w in weights: total += w
	var roll := rng.randf() * total
	for i in range(ids.size()):
		roll -= float(weights[i])
		if roll <= 0.0: return ids[i]
	return ids.back()

## The weapon an enemy type carries, its own region's version first.
static func _carried(enemy_type: String, region: String) -> String:
	if enemy_type.is_empty(): return ""
	var fallback := ""
	for id in BASES:
		if enemy_type in BASES[id].get("enemies", []):
			if BASES[id].region == region: return id
			if fallback.is_empty(): fallback = id
	return fallback

## Makes `item` this base: name, power factor, intrinsic stats, flavour text.
static func apply(item: Item, id: String) -> void:
	var b: Dictionary = BASES[id]
	item.base_id = id
	item.item_name = b.name
	item.power *= float(b.factor)
	item.description = b.text
	item.value = roundi(item.value * float(b.get("value", 1.0)))
	var implicit: Array[ItemModifier] = []
	for pair in b.implicit:
		var mod := ItemModifier.stat_mod(pair[0], float(pair[1]))
		mod.tier = IMPLICIT_TIER
		implicit.append(mod)
	implicit.append_array(item.modifiers)
	item.modifiers = implicit

## For loading: fills `base_id` on gear saved before it existed (name only;
## old items keep their stats).
static func backfill(item: Item) -> void:
	if not item.base_id.is_empty() or not item.is_equippable() or not item.special.is_empty() or not item.exclusive_region.is_empty(): return
	if RENAMED.has(item.item_name): item.item_name = RENAMED[item.item_name]
	var id := id_for_name(item.item_name)
	if id.is_empty() and LEGACY_BASELINE.has(item.item_name):
		id = LEGACY_BASELINE[item.item_name].get(item.origin_region, "")
		if not id.is_empty(): item.item_name = BASES[id].name
	if not id.is_empty() and int(BASES[id].category) == item.category: item.base_id = id
