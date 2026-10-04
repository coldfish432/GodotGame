class_name SpecialGear
extends RefCounted

## Special equipment (特殊装备): named gear whose fixed special affix deals
## damage of its own — the attack effects that used to be relics (用户
## 2026-10-03: relics change numbers and rules; attack effects belong to
## equipment). Each also rolls one ordinary affix. Being equipment, it follows
## every equipment rule: it takes pack cells, can be gilded, insured, carried
## home and kept. One per slot, so the three slots are a real choice.
##
## How it is obtained is still open (用户：具体归宿待定). For now it drops from
## ordinary loot rolls at DROP_CHANCE, region-weighted, so it can be played.

const DROP_CHANCE := 0.05
const DROP_CHANCE_PER_REWARD := 0.03
const REGION_WEIGHT := 3.0

const T := ItemModifier.Trigger
const GEAR := {
	"lord_blade": {"name": "领主宽刃", "category": Item.Category.WEAPON, "size": Vector2i(2, 1), "power": 2.6, "region": "city",
		"triggers": [T.CLEAVE], "cost": [ItemModifier.Stat.ATTACK_SPEED_PCT, -0.10],
		"text": "一把为了同时面对很多人而打的刀。", "source": "宽刃（原锋刃构筑物）"},
	"twin_fang": {"name": "双生狼牙", "category": Item.Category.WEAPON, "size": Vector2i(2, 1), "power": 2.2, "region": "snow",
		"triggers": [T.SWORD_WAVE, T.TWIN_WAVE], "cost": [],
		"text": "两柄刃，一道光分成三道。", "source": "双生剑气（原狼魂构筑物）"},
	"ember_fang": {"name": "余烬之牙", "category": Item.Category.WEAPON, "size": Vector2i(2, 1), "power": 2.2, "region": "snow",
		"triggers": [T.SWORD_WAVE, T.EMBER], "cost": [],
		"text": "刃脊里封着一点不肯熄的火。", "source": "余烬剑气（原狼魂构筑物）"},
	"moon_edge": {"name": "月下刃", "category": Item.Category.WEAPON, "size": Vector2i(2, 1), "power": 2.4, "region": "snow",
		"triggers": [T.SWORD_WAVE, T.MOON_WAVE], "cost": [],
		"text": "刀光够亮的时候，会自己飞出去。", "source": "月下双刃（原桥梁构筑物）"},
	"crystal_edge": {"name": "源石结晶刃", "category": Item.Category.WEAPON, "size": Vector2i(2, 1), "power": 2.4, "region": "mine",
		"triggers": [T.ARTS_EDGE], "cost": [],
		"text": "刃上长出了不该长的东西。", "source": "源石结晶刃（原源石构筑物）"},
	"vein_core": {"name": "共振矿芯", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 2.0, "region": "mine",
		"triggers": [T.VEIN_BURST], "cost": [],
		"text": "握在手里会轻轻发颤，敌人倒下时颤得更厉害。", "source": "矿脉共振（原源石构筑物）"},
	"shadow_bracer": {"name": "残影护腕", "category": Item.Category.TRINKET, "size": Vector2i(1, 1), "power": 2.0, "region": "city",
		"triggers": [T.AFTERIMAGE], "cost": [],
		"text": "动得够快，影子也会伤人。", "source": "残影步（原迅捷构筑物）"},
	"spike_plate": {"name": "尖刺重铠", "category": Item.Category.ARMOR, "size": Vector2i(2, 2), "power": 2.6, "region": "mine",
		"triggers": [T.THORNS], "cost": [ItemModifier.Stat.MOVE_SPEED_PCT, -0.08],
		"text": "抱住它的人会后悔。", "source": "坚壁 4 共鸣的荆棘"},
	"bash_shield": {"name": "反击塔盾", "category": Item.Category.ARMOR, "size": Vector2i(2, 2), "power": 2.6, "region": "city",
		"triggers": [T.SHIELD_BASH], "cost": [],
		"text": "挡下来的，原样还回去。", "source": "盾反（原坚壁构筑物）"},
}

static func drop_chance(reward: float) -> float:
	return DROP_CHANCE + maxf(reward, 0.0) * DROP_CHANCE_PER_REWARD

static func create(id: String, depth: int, rng: RandomNumberGenerator) -> Item:
	var data: Dictionary = GEAR[id]
	var size: Vector2i = data.size
	var item := Item.create(data.name, data.category, size.x, size.y, float(data.power) + depth * 0.2)
	item.special = id
	item.rarity = 2
	item.value = 60 + depth * 10
	item.description = data.text
	for trigger in data.triggers: item.modifiers.append(ItemModifier.trigger_mod(trigger))
	if not data.cost.is_empty():
		var cost := ItemModifier.stat_mod(data.cost[0], data.cost[1])
		cost.tier = -1
		item.modifiers.append(cost)
	var pool: Array = FieldCatalog.AFFIX_POOLS[data.category]
	var stat: int = pool[rng.randi_range(0, pool.size() - 1)]
	var tier := FieldCatalog._roll_tier(2, rng)
	var mod := ItemModifier.stat_mod(stat as ItemModifier.Stat, float(FieldCatalog.AFFIX_AMOUNTS[stat]) * ItemModifier.TIER_SCALES[tier])
	mod.tier = tier
	item.modifiers.append(mod)
	return item

## A region's own special gear is REGION_WEIGHT times as likely.
static func roll(region: String, depth: int, rng: RandomNumberGenerator) -> Item:
	var total := 0.0
	for id in GEAR: total += REGION_WEIGHT if GEAR[id].region == region else 1.0
	var pick := rng.randf() * total
	for id in GEAR:
		pick -= REGION_WEIGHT if GEAR[id].region == region else 1.0
		if pick <= 0.0:
			var item := create(id, depth, rng)
			item.origin_region = region
			return item
	return create(GEAR.keys().back(), depth, rng)
