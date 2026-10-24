class_name ItemTooltip
extends RefCounted

## 情报部 2 阶 (龙门币平衡与科研部策划案): show where a piece sits in its rarity's band.
static var show_band := false

## Tooltip text for an item, top to bottom (装备与背包界面调研 §4.3): name in its
## rarity colour, kind and size, what wearing it changes stat by stat, base
## stats, random affixes with tiers (Alt adds their ranges), the trigger affix
## set apart, the item's own text, its protection state and its value. No 战力
## and no death forecast or key hints (用户 2026-10-05/06).

const UP := "6fdc8c"
const DOWN := "ff6b5b"
const FLAT := "8b97a3"
const LABELS := {"hp": "生命上限", "atk": "攻击力", "arts": "法术攻击力", "def": "防御", "res": "法抗",
	"aspd": "攻速", "crit": "暴击率", "crit_dmg": "暴击伤害", "move": "移速"}
const PERCENT := ["crit", "crit_dmg"]

static func text(game: GameManager, item: Item, detailed: bool, show_worn: bool) -> String:
	var lines: Array[String] = []
	var icon := ItemIcons.path_for(item)
	if not icon.is_empty() and ResourceLoader.exists(icon): lines.append("[img]%s[/img]" % icon)
	# Prefixes in their grade colours, the rest in the item's (装备前缀策划案 §2.1).
	lines.append("[font_size=19]%s[/font_size]" % item.name_bbcode())
	var kind := "%s · %d×%d" % [Item.CATEGORY_NAMES[item.category], item.width, item.height]
	if not item.material_id.is_empty():
		kind = "%s · ★%d · %d×%d" % [MaterialCatalog.group(item.material_id), MaterialCatalog.star(item.material_id), item.width, item.height]
		kind += " · 堆叠 %d/%d" % [item.quantity, item.max_stack] if item.is_stackable() else " · 不可堆叠"
	if FieldCatalog.REGIONS.has(item.origin_region): kind += " · 产地 " + FieldCatalog.REGIONS[item.origin_region].name.split(" · ")[0]
	if not item.exclusive_region.is_empty(): kind += " · [color=#ee8a24]地区专属[/color]"
	match item.named_kind():
		"special": kind += " · [color=#ff7a45]特殊装备[/color]"
		"exclusive": kind += " · [color=#ee8a24]◆ 敌人专属[/color]"
		"set": kind += " · [color=#4fd18b]套装[/color]"
		"boss": kind += " · [color=#b49ae8]◆ 首领专属[/color]"
	lines.append("[color=#99aab8]%s[/color]" % kind)
	# Grade and requirement (精英化与加点策划案 §7.4): white when met, red when not.
	var req := Progression.requirement(item)
	if not req.is_empty():
		var p: OperatorProgress = game.progress()
		var parts: Array[String] = []
		if int(req.elite) > 0: parts.append("[color=#%s]%s[/color]" % ["e9e9e9" if p.elite >= int(req.elite) else DOWN, Progression.ELITE_NAMES[int(req.elite)]])
		if int(req.value) > 0: parts.append("[color=#%s]%s %d[/color]" % ["e9e9e9" if p.attribute(str(req.attribute)) >= int(req.value) else DOWN, Progression.ATTRIBUTE_NAMES[req.attribute], int(req.value)])
		lines.append("%s%s%s" % [Progression.grade_label(int(req.grade)), ("  ·  抵 " + Progression.grade_label(int(req.grade) + 1)) if Scaling.crosses_tier(item) else "", ("  ·  需求 " + " · ".join(parts)) if not parts.is_empty() else ""])
	var worn: Item = game.player.equipped.get(item.category) if item.is_equippable() else null
	if item.is_equippable():
		if worn == item:
			lines.append("[color=#d8c27a]已装备[/color]")
		else:
			var preview := game.player.preview_equip(item)
			lines.append("[color=#99aab8]装备后（对比%s）：[/color]" % ("当前 " + worn.item_name if worn != null else "空槽"))
			for key in ["atk", "arts", "hp", "def", "res", "aspd", "crit", "crit_dmg", "move"]:
				if not is_equal_approx(float(preview.before[key]), float(preview.after[key])):
					lines.append("  " + _diff_line(key, preview.before[key], preview.after[key], false))
		lines.append("[color=#c9d3db]── 基础 ──[/color]")
		var base := CombatStats.item_stats(item)
		var names := {"atk": "攻击力", "hp": "生命", "def": "防御", "arts": "法术攻击力", "stamina_regen": "体力回复"}
		var r := item.power_range()
		var low := CombatStats.power_stats(item.category, float(r[0]), item.atk_share, item.grade) if not r.is_empty() else {}
		var high := CombatStats.power_stats(item.category, float(r[1]), item.atk_share, item.grade) if not r.is_empty() else {}
		for key in base:
			var span := "（范围 %d ~ %d）" % [roundi(low[key]), roundi(high[key])] if detailed and low.has(key) else ""
			lines.append("  %s +%d%s" % [names[key], roundi(base[key]), span])
		if show_band and not r.is_empty(): lines.append("  范围 %d%%" % roundi(Scaling.band_position(item) * 100.0))
		var intrinsic := item.modifiers.filter(func(m): return m.trigger == ItemModifier.Trigger.NONE and m.tier == GearCatalog.IMPLICIT_TIER)
		for mod in intrinsic: lines.append("  [color=#b8c4cf]固有 · %s%s[/color]" % [mod.describe(), mod.range_text() if detailed else ""])
		for entry in item.prefixes:
			var colour := PrefixCatalog.color_of(entry).to_html(false)
			for line in PrefixCatalog.lines_of(entry, item):
				lines.append("  [color=#%s]前缀[/color] · %s%s" % [colour, line[0], line[1] if detailed else ""])
		# Effect families: 阶等 is how many worn pieces carry it (前缀放大与特效阶等案 §4).
		for entry in item.prefixes:
			var fam := PrefixFamilies.family_of(str(entry.id))
			if fam.is_empty(): continue
			var families: PrefixFamilies = game.player.families if is_instance_valid(game) and is_instance_valid(game.player) else null
			var pieces := int(families.worn.get(fam, 0)) if families != null else 0
			var working := families != null and families.tiers.has(fam)
			var tier := maxi(pieces, 1)
			lines.append("[color=#%s]── %s%s ──[/color]" % ["b48cff" if working or pieces == 0 else "6d6d6d", PrefixFamilies.label(fam, tier), "" if working or pieces == 0 else " · 未生效"])
			for line in PrefixFamilies.lines(fam, tier): lines.append("  [color=#%s]%s[/color]" % ["e9e9e9" if line[1] else "6d6d6d", line[0]])
		var affixes := item.modifiers.filter(func(m): return m.trigger == ItemModifier.Trigger.NONE and m.tier != GearCatalog.IMPLICIT_TIER)
		if not affixes.is_empty():
			lines.append("[color=#c9d3db]── 词缀 ──[/color]")
			for mod in affixes: lines.append("  " + _affix_mark(item, mod) + mod.describe_detailed(detailed))
		var named: Dictionary = SpecialGear.GEAR.get(item.special, {}) if not item.special.is_empty() else {}
		if named.has("fx_text"):
			lines.append("[color=#ee8a24]── 专属效果 ──[/color]")
			lines.append("  [color=#f2c48a]◆ %s[/color]" % named.fx_text)
		if item.named_kind() == "set":
			var worn_count := 0
			for worn_item in game.player.equipped.values():
				if worn_item != null and not worn_item.special.is_empty() and str(SpecialGear.GEAR.get(worn_item.special, {}).get("set_id", "")) == str(named.set_id): worn_count += 1
			var set_lines := SpecialGear.set_lines(item, worn_count)
			lines.append("[color=#4fd18b]── %s %d/3 ──[/color]" % [set_lines[0][0], worn_count])
			for entry in set_lines.slice(1): lines.append("  [color=#%s]%s[/color]" % ["e9e9e9" if entry[1] else "6d6d6d", entry[0]])
		var triggers := item.modifiers.filter(func(m): return m.trigger != ItemModifier.Trigger.NONE)
		if not triggers.is_empty():
			lines.append("[color=#ff7a45]── 特殊效果 ──[/color]" if not item.special.is_empty() else "[color=#b48cff]── 触发 ──[/color]")
			for mod in triggers: lines.append("  [color=#cdb4ff]✦ %s%s[/color]" % [mod.describe(), mod.range_text() if detailed else ""])
	if not item.description.is_empty(): lines.append("[color=#e0d6b8]%s[/color]" % item.description)
	var state: Array[String] = []
	if item.insured: state.append("[color=#4fd1c5]已投保[/color]")
	if item.carried_in: state.append("带入")
	if not state.is_empty(): lines.append(" · ".join(state))
	# What delivering it actually pays (用户 2026-10-23: 界面显示到手的数字).
	if not GearCatalog.bound(item): lines.append("[color=#d8c27a]交付价 %s 龙门币[/color]" % Economy.format(Economy.direct_price(item)))
	if show_worn and worn != null and worn != item:
		lines.append("\n[color=#99aab8]── 当前装备（Shift）──[/color]")
		lines.append(text(game, worn, detailed, false))
	return "\n".join(lines)

static func _value(key: String, value: float) -> String:
	if key in PERCENT: return "%d%%" % roundi(value * 100)
	if key == "move": return "%.1f" % value
	return str(roundi(value))

static func _diff_line(key: String, before: float, after: float, big: bool) -> String:
	var delta := after - before
	# A change that rounds to nothing at display precision shows as flat.
	if _value(key, absf(delta)) in ["0", "0%", "0.0"]: delta = 0.0
	var colour := FLAT if is_zero_approx(delta) else (UP if delta > 0 else DOWN)
	var arrow := "" if is_zero_approx(delta) else ("▲" if delta > 0 else "▼")
	var shown := _value(key, absf(delta)) if not is_zero_approx(delta) else "0"
	var line := "%s %s → %s  [color=#%s]%s%s[/color]" % [LABELS[key], _value(key, before), _value(key, after), colour, arrow, shown]
	return "[font_size=17]%s[/font_size]" % line if big else line

## The stat panel; with `preview` it shows what equipping it would change, in
## brackets, so the tooltip and the sheet agree (§5 layout notes).
static func stats_text(game: GameManager, preview: Item) -> String:
	var p := game.player
	var now := p.snapshot()
	var after := now
	if preview != null: after = p.preview_equip(preview).after
	var lines: Array[String] = []
	for key in ["hp", "atk", "arts", "def", "res", "aspd", "crit", "crit_dmg", "move"]:
		var line := "%s %s" % [LABELS[key], _value(key, now[key])]
		var delta := float(after[key]) - float(now[key])
		if not is_zero_approx(delta) and not _value(key, absf(delta)) in ["0", "0%", "0.0"]:
			line += "  [color=#%s](%s%s)[/color]" % [UP if delta > 0 else DOWN, "+" if delta > 0 else "−", _value(key, absf(delta))]
		lines.append(line)
	lines.append("吸血 %d%%  闪避 %d%%  回复 %d/秒" % [roundi(p.lifesteal() * 100), roundi(p.evasion() * 100), roundi(p.regen_rate())])
	lines.append("生命 %d / %d%s" % [roundi(maxf(p.hp, 0)), roundi(p.max_hp), ("  护盾 %d" % roundi(p.shield)) if p.shield > 0 else ""])
	return "\n".join(lines)

## The mark in front of an affix line (属性伤害与地区装备策划案 v1.1 §13): ◆ for
## an orange signature, the region's character for its own lines, the
## element's character for a resistance. The line itself stays plain.
const REGION_MARKS := {"mine": "矿", "city": "龙", "snow": "萨", "siracusa": "叙"}
const RESIST_MARKS := {ItemModifier.Stat.RES_BURN: "burn", ItemModifier.Stat.RES_COLD: "cold", ItemModifier.Stat.RES_CORR: "corr",
	ItemModifier.Stat.RES_NERVE: "nerve", ItemModifier.Stat.RES_BLEED: "bleed"}

static func _affix_mark(item: Item, mod: ItemModifier) -> String:
	var region := item.origin_region
	if ItemModifier.is_signature(mod.stat) and REGION_MARKS.has(region):
		return "[color=#%s]◆ %s[/color] " % [Item.RARITY_COLORS[Item.ORANGE].to_html(false), REGION_MARKS[region]]
	if RESIST_MARKS.has(mod.stat):
		var kind: String = RESIST_MARKS[mod.stat]
		return "[color=#%s]%s[/color] " % [Elements.COLORS[kind].to_html(false), Elements.BADGES[kind]]
	if REGION_MARKS.has(region) and FieldCatalog.region_of_affix(mod.stat, item.category, region) == region:
		var colour: Color = (FieldCatalog.REGIONS[region].color as Color).lightened(0.45)
		return "[color=#%s]%s[/color] " % [colour.to_html(false), REGION_MARKS[region]]
	return ""
