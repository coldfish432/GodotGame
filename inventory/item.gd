extends Resource
class_name Item

## Equipment/material identity, footprint, affixes and contract protection.

## 装备部位拆分与数值案 v1.0 (用户 2026-10-21): eight slots. ARMOR and TRINKET
## stay for saves and for the three warehouse/order groups (group_of); new
## gear is always one of the eight slots. Appended so saved ids keep meaning.
enum Category { WEAPON, ARMOR, TRINKET, MATERIAL, HEAD, CHEST, HANDS, LEGS, FEET, AMULET, RING }
## The paper doll's slots, in Grim Dawn's reading order.
const SLOTS := [Category.WEAPON, Category.HEAD, Category.CHEST, Category.HANDS, Category.LEGS, Category.FEET, Category.AMULET, Category.RING]
const ARMOR_SLOTS := [Category.HEAD, Category.CHEST, Category.HANDS, Category.LEGS, Category.FEET]
const JEWEL_SLOTS := [Category.AMULET, Category.RING]
## One palette for rarity everywhere (grid borders, names, ground drops), the
## same as relics: grey-white, blue, gold — 明日方舟's 3★ / 4★-5★ feel
## (装备与背包界面调研 §5.2).
const RARITY_COLORS := [Color("c9d3db"), Color("5aa9ff"), Color("f3b04a")]
const RARITY_NAMES := ["普通", "精良", "稀有"]
const CATEGORY_NAMES := ["武器", "防具", "饰品", "材料", "头部", "胸甲", "手部", "腿部", "脚部", "项链", "戒指"]

static func slot_name(category: int) -> String:
	return CATEGORY_NAMES[clampi(category, 0, CATEGORY_NAMES.size() - 1)]

## The three gear groups plus materials (warehouse racks, orders, factions):
## the five armour slots are ARMOR, the amulet and the ring TRINKET.
static func group_of(category: int) -> int:
	if category in ARMOR_SLOTS: return Category.ARMOR
	if category in JEWEL_SLOTS: return Category.TRINKET
	return category

## Old saves' ARMOR and TRINKET pieces are a chest and an amulet now.
static func slot_of(category: int) -> int:
	match category:
		Category.ARMOR: return Category.CHEST
		Category.TRINKET: return Category.AMULET
	return category

static func is_armor_slot(category: int) -> bool:
	return category in ARMOR_SLOTS or category == Category.ARMOR

static func is_jewel_slot(category: int) -> bool:
	return category in JEWEL_SLOTS or category == Category.TRINKET

@export var item_name: String = ""
@export var category: Category = Category.MATERIAL
@export var width: int = 1
@export var height: int = 1
@export var power: float = 0.0
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
## SpecialGear template id for special equipment, "" otherwise.
@export var special: String = ""
## GearCatalog base id for ordinary equipment (装备策划案 §2), "" otherwise.
@export var base_id: String = ""
## Stacking (掉落物策划案 §2.1): a PRTS material stack. `value` is always
## unit_value × quantity for stacks.
@export var material_id: String = ""
@export var quantity: int = 1
@export var max_stack: int = 1
@export var unit_value: int = 0
## A flask ("A" / "B" / "C", BaseCatalog.POTIONS) — flasks are pack items; one kind
## stacks in a cell up to BaseCatalog.POTION_STACK (用户 2026-10-17); "" for everything else.
@export var potion_type: String = ""
## 档位 Ⅰ–Ⅹ (复利数值改造清单 B): the ten-floor tier it dropped in, which fixes
## its value range and its requirement. Flasks carry it too (E). 0 for
## materials and gear saved before grades (filled in on load).
@export var grade: int = 0
## A trinket's split of its panel between ATK and arts (清单 F): 1 all ATK,
## 0 all arts. Trinkets saved before it gave arts only, so 0 is the default.
@export var atk_share: float = 0.0
## Named prefixes (装备前缀策划案): [{id, rolls: {key: 0.8–1.2}}], one or two,
## highest grade first. Empty for materials and set pieces.
@export var prefixes: Array = []
## The 基础效能 at the middle of its rarity's band (清单 B; power_range).
## 0 for gear whose power does not roll (named gear, old saves).
@export var power_mid: float = 0.0
## The value before prefixes and roll quality (PrefixCatalog.refresh_value).
@export var value_base: int = 0
## How many times 精调 has been used on it (each one costs more).
@export var tune_count: int = 0

const POWER_LOW := 0.9
const POWER_HIGH := 1.1

## The 基础效能 range this piece rolls in (复利数值改造清单 B): its rarity's band
## around power_mid, the band's middle. [] when its power does not roll.
func power_range() -> Array:
	if power_mid <= 0.0: return []
	var mid := Scaling.band_mid(rarity)
	var b := Scaling.band(rarity)
	return [power_mid * float(b[0]) / mid, power_mid * float(b[1]) / mid]

## Where its power sits in that range, 0 to 1 (0.5 when it does not roll).
func power_position() -> float:
	var r := power_range()
	if r.is_empty() or is_equal_approx(float(r[0]), float(r[1])): return 0.5
	return clampf((power - float(r[0])) / (float(r[1]) - float(r[0])), 0.0, 1.0)

var grid_x: int = -1
var grid_y: int = -1

func is_equippable() -> bool:
	return category != Category.MATERIAL

func is_potion() -> bool:
	return not potion_type.is_empty()

## A new trinket's split (清单 F): all ATK, all arts, or a mix, a third each.
static func roll_atk_share(rng: RandomNumberGenerator) -> float:
	var roll := rng.randf()
	if roll < 0.35: return 1.0
	if roll < 0.70: return 0.0
	return snappedf(rng.randf_range(0.2, 0.8), 0.05)

static func create(p_name: String, p_category: Category, p_width: int, p_height: int, p_power: float = 0.0) -> Item:
	var item := Item.new()
	item.uid = "%s-%s-%s" % [Time.get_unix_time_from_system(), Time.get_ticks_usec(), randi()]
	item.item_name = p_name
	item.category = p_category
	item.width = p_width
	item.height = p_height
	item.power = p_power
	return item

const SPECIAL_COLOR := Color("ff7a45")
## Enemy exclusives (Grim Dawn's MI) and set pieces (装备扩充策划案 §1).
const EXCLUSIVE_COLOR := Color("ee8a24")
const SET_COLOR := Color("4fd18b")
## A region boss's own pieces wear the boss bar's lavender (Boss与守卫者策划案 §10).
const BOSS_COLOR := Color("b49ae8")

## "special" / "exclusive" / "set" for named gear, "" for everything else.
func named_kind() -> String:
	if special.is_empty(): return ""
	return str(SpecialGear.GEAR.get(special, {}).get("kind", "special"))

func is_stackable() -> bool:
	return max_stack > 1 and (not material_id.is_empty() or is_potion())

func can_stack_with(other: Item) -> bool:
	return other != null and other != self and is_stackable() and other.material_id == material_id 		and other.potion_type == potion_type and other.effect == effect and (not is_potion() or other.grade == grade)

func set_quantity(count: int) -> void:
	quantity = maxi(count, 0)
	if is_stackable() or unit_value > 0: value = unit_value * quantity

func room() -> int:
	return maxi(0, max_stack - quantity)

## Moves as much of `other` into this stack as fits; returns how many moved.
func absorb(other: Item) -> int:
	if not can_stack_with(other): return 0
	var moved := mini(room(), other.quantity)
	set_quantity(quantity + moved)
	other.set_quantity(other.quantity - moved)
	return moved

## Takes `count` off this stack as a new stack (count < quantity).
func split(count: int) -> Item:
	var part := Item.from_data(to_data())
	part.uid = "%s-%s-%s" % [Time.get_unix_time_from_system(), Time.get_ticks_usec(), randi()]
	part.set_quantity(count)
	set_quantity(quantity - count)
	return part

func stack_suffix() -> String:
	return " ×%d" % quantity if is_stackable() else ""

func display_name() -> String:
	if not material_id.is_empty(): return "★%d · %s" % [MaterialCatalog.star(material_id), item_name]
	var quality: String = {"special": "特殊", "exclusive": "专属", "set": "套装", "boss": "首领"}.get(named_kind(), RARITY_NAMES[clampi(rarity, 0, 2)])
	var mark: String = (str(Progression.GRADE_MARKS[clampi(grade, 0, Progression.GRADE_MAX)]) + " · ") if grade > 0 else ""
	return mark + quality + " · " + PrefixCatalog.name_part(self) + item_name

## The name as coloured runs: [text, colour] — the quality and base name in
## the item's colour, each prefix in its grade's colour, "·" dim (§2.1).
func name_runs() -> Array:
	var full := display_name()
	if prefixes.is_empty() or not material_id.is_empty(): return [[full, rarity_color()]]
	var head := full.left(full.length() - item_name.length() - PrefixCatalog.name_part(self).length())
	var runs: Array = [[head, rarity_color()]]
	for entry in prefixes:
		runs.append([str(PrefixCatalog.get_entry(str(entry.id)).get("name", "")), PrefixCatalog.color_of(entry)])
		runs.append(["·", PrefixCatalog.DOT_COLOR])
	runs.append([item_name, rarity_color()])
	return runs

## The name as BBCode, each run translated on its own.
func name_bbcode() -> String:
	var out := ""
	for run in name_runs(): out += "[color=#%s]%s[/color]" % [run[1].to_html(false), I18n.t(run[0])]
	return out

func rarity_color() -> Color:
	if not material_id.is_empty(): return MaterialCatalog.color(material_id)
	match named_kind():
		"special": return SPECIAL_COLOR
		"exclusive": return EXCLUSIVE_COLOR
		"set": return SET_COLOR
		"boss": return BOSS_COLOR
	return RARITY_COLORS[clampi(rarity, 0, 2)]

func details() -> String:
	var parts: Array[String] = [description]
	if is_equippable():
		var base := CombatStats.item_stats(self)
		var names := {"atk": "攻击力", "hp": "生命", "def": "防御", "arts": "法术攻击力", "stamina_regen": "体力回复"}
		for key in base: parts.append("%s +%d" % [names[key], roundi(base[key])])
	for modifier in modifiers:
		parts.append(modifier.describe())
	for entry in prefixes:
		for line in PrefixCatalog.lines_of(entry, self): parts.append(line[0])
	return " / ".join(parts)

func to_data() -> Dictionary:
	var mods: Array = []
	for mod in modifiers:
		mods.append({"stat": mod.stat, "amount": mod.amount, "trigger": mod.trigger, "tier": mod.tier, "mid": mod.mid, "scale": mod.scale, "band": mod.band})
	return {"uid": uid, "name": item_name, "category": category, "width": width, "height": height,
		"power": power, "rarity": rarity, "value": value, "region": exclusive_region, "origin": origin_region, "effect": effect,
		"description": description, "mods": mods, "insured": insured, "carried_in": carried_in, "special": special, "base": base_id,
		"material": material_id, "quantity": quantity, "max_stack": max_stack, "unit_value": unit_value, "potion": potion_type, "grade": grade,
		"prefixes": prefixes.duplicate(true), "power_mid": power_mid, "value_base": value_base, "tunes": tune_count, "atk_share": atk_share,
		"tiers": 2, "slots": 3}

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
	item.insured = bool(data.get("insured", false))
	item.carried_in = bool(data.get("carried_in", false))
	item.special = str(data.get("special", ""))
	item.base_id = str(data.get("base", ""))
	item.material_id = str(data.get("material", ""))
	item.max_stack = maxi(1, int(data.get("max_stack", 1)))
	item.unit_value = int(data.get("unit_value", 0))
	item.potion_type = str(data.get("potion", ""))
	# Flasks saved one per cell stack now (用户 2026-10-17).
	if item.is_potion() and item.max_stack < BaseCatalog.POTION_STACK:
		item.max_stack = BaseCatalog.POTION_STACK
		if item.unit_value <= 0: item.unit_value = item.value
	item.quantity = clampi(int(data.get("quantity", 1)), 1, item.max_stack)
	item.grade = clampi(int(data.get("grade", 0)), 0, Progression.GRADE_MAX)
	# Gear saved before ten-floor tiers kept T1–T6 of layer + block; its tier
	# comes from its power instead (复利数值改造清单 B). Flasks were all tier Ⅰ.
	if int(data.get("tiers", 1)) < 2:
		item.grade = 1 if item.is_potion() else 0
		if item.is_potion(): item.item_name = BaseCatalog.potion_name(item.potion_type, 1)
	item.atk_share = clampf(float(data.get("atk_share", 0.0)), 0.0, 1.0)
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
		mod.tier = int(data_mod["tier"]) if data_mod.has("tier") else ItemModifier.infer_tier(mod.stat, mod.amount)
		mod.mid = float(data_mod.get("mid", 0.0))
		mod.scale = float(data_mod.get("scale", 1.0))
		mod.band = int(data_mod.get("band", -1))
		item.modifiers.append(mod)
	item.power_mid = float(data.get("power_mid", 0.0))
	item.value_base = int(data.get("value_base", 0))
	item.tune_count = int(data.get("tunes", 0))
	for entry in data.get("prefixes", []):
		if entry is Dictionary and PrefixCatalog.all().has(str(entry.get("id", ""))):
			var rolls := {}
			for key in entry.get("rolls", {}): rolls[str(key)] = float(entry.rolls[key])
			item.prefixes.append({"id": str(entry.id), "rolls": rolls})
	# Before eight slots (装备部位拆分与数值案 §9, 用户 2026-10-21: 改成修改后对应的
	# 数值): armour is a chest, a trinket an amulet, at that slot's share — the
	# panel by its per-slot figures (CombatStats), the affixes scaled here.
	if int(data.get("slots", 1)) < 2 and (item.category == Category.ARMOR or item.category == Category.TRINKET):
		item.category = slot_of(item.category) as Category
		for mod in item.modifiers:
			if mod.trigger != ItemModifier.Trigger.NONE or mod.tier == -1: continue
			mod.amount *= GearSlots.affix(item.category)
			mod.mid *= GearSlots.affix(item.category)
			mod.scale *= GearSlots.affix(item.category)
	# Gear saved before bases existed, or under a renamed base (装备策划案 §2.3).
	GearCatalog.backfill(item)
	if int(data.get("slots", 1)) < 3: _migrate_slot_tables(item)
	Progression.backfill_grade(item)
	# Gear saved before prefixes rolls them once (装备前缀策划案 §0.2-6).
	if not data.has("prefixes"): PrefixCatalog.backfill(item)
	return item

## Gear saved under the slot multiplier (部位词条数值表 v1.0, 用户 2026-10-21):
## a non-weapon piece's affixes move to its slot's own sizes at the same
## place in their band, and its base's intrinsics are rebuilt from the new
## table where its panel sits.
static func _migrate_slot_tables(item: Item) -> void:
	if item.category == Category.WEAPON or not item.category in SLOTS or not item.special.is_empty(): return
	for mod in item.modifiers:
		if not mod.is_random_affix(): continue
		var f := FieldCatalog.slot_ratio(mod.stat, item.category) / GearSlots.affix(item.category)
		mod.amount *= f
		mod.scale *= f
	if item.base_id.is_empty() or not GearCatalog.BASES.has(item.base_id) or int(GearCatalog.BASES[item.base_id].category) != item.category: return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(item.uid)
	var rest: Array[ItemModifier] = []
	for mod in item.modifiers:
		if mod.tier != GearCatalog.IMPLICIT_TIER: rest.append(mod)
	var implicit := GearCatalog.implicits_for(item, item.base_id, rng, item.power_position())
	implicit.append_array(rest)
	item.modifiers = implicit
