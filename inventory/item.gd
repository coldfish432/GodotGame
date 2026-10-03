extends Resource
class_name Item

## Equipment/material identity, footprint, affixes and contract protection.

enum Category { WEAPON, ARMOR, TRINKET, MATERIAL }

@export var item_name: String = ""
@export var category: Category = Category.MATERIAL
@export var width: int = 1
@export var height: int = 1
@export var power: float = 0.0
@export var gilded: bool = false
@export var modifiers: Array[ItemModifier] = []
@export var uid: String = ""
@export var rarity: int = 0
@export var value: int = 10
@export var exclusive_region: String = ""
## The region it was found in (FieldCatalog.REGIONS key); "" for items made at
## the base or saved before this existed. Orders can ask for a region's loot.
@export var origin_region: String = ""
@export var effect: String = ""
@export var description: String = ""
@export var insured: bool = false
@export var carried_in: bool = false

var grid_x: int = -1
var grid_y: int = -1

func is_equippable() -> bool:
	return category != Category.MATERIAL

static func create(p_name: String, p_category: Category, p_width: int, p_height: int, p_power: float = 0.0) -> Item:
	var item := Item.new()
	item.uid = "%s-%s-%s" % [Time.get_unix_time_from_system(), Time.get_ticks_usec(), randi()]
	item.item_name = p_name
	item.category = p_category
	item.width = p_width
	item.height = p_height
	item.power = p_power
	return item

func display_name() -> String:
	return ["普通", "精良", "稀有"][clampi(rarity, 0, 2)] + " · " + item_name

func details() -> String:
	var parts: Array[String] = [description]
	if is_equippable():
		var base := CombatStats.power_stats(category, power)
		var names := {"atk": "攻击力", "hp": "生命", "def": "防御", "arts": "法术攻击力", "stamina_regen": "体力回复"}
		for key in base: parts.append("%s +%d" % [names[key], roundi(base[key])])
	for modifier in modifiers:
		parts.append(modifier.describe())
	return " / ".join(parts)

func to_data() -> Dictionary:
	var mods: Array = []
	for mod in modifiers:
		mods.append({"stat": mod.stat, "amount": mod.amount, "trigger": mod.trigger})
	return {"uid": uid, "name": item_name, "category": category, "width": width, "height": height,
		"power": power, "rarity": rarity, "value": value, "region": exclusive_region, "origin": origin_region, "effect": effect,
		"description": description, "mods": mods, "gilded": gilded, "insured": insured, "carried_in": carried_in}

static func from_data(data: Dictionary) -> Item:
	var item := create(str(data.get("name", "物品")), int(data.get("category", 3)) as Category,
		clampi(int(data.get("width", 1)), 1, 10), clampi(int(data.get("height", 1)), 1, 6), float(data.get("power", 0)))
	item.uid = str(data.get("uid", item.uid))
	item.rarity = int(data.get("rarity", 0))
	item.value = int(data.get("value", 10))
	item.exclusive_region = str(data.get("region", ""))
	item.origin_region = str(data.get("origin", ""))
	item.effect = str(data.get("effect", ""))
	item.description = str(data.get("description", ""))
	item.gilded = bool(data.get("gilded", false))
	item.insured = bool(data.get("insured", false))
	item.carried_in = bool(data.get("carried_in", false))
	for data_mod in data.get("mods", []):
		var mod := ItemModifier.new()
		mod.stat = int(data_mod.get("stat", 0)) as ItemModifier.Stat
		mod.amount = float(data_mod.get("amount", 0))
		mod.trigger = int(data_mod.get("trigger", 0)) as ItemModifier.Trigger
		# Loot used to roll "melee cooldown -8%"; that affix is now attack speed.
		# Convert to the same attack interval so saved gear keeps its effect.
		if mod.trigger == ItemModifier.Trigger.NONE and mod.stat == ItemModifier.Stat.BLADE_COOLDOWN_PCT and mod.amount > -1.0:
			mod.stat = ItemModifier.Stat.ATTACK_SPEED_PCT
			mod.amount = 1.0 / (1.0 + mod.amount) - 1.0
		item.modifiers.append(mod)
	return item
