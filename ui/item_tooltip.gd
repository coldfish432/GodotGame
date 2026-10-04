class_name ItemTooltip
extends RefCounted

## Tooltip text for an item, top to bottom (装备与背包界面调研 §4.3): name in its
## rarity colour, kind and size, 战力 and what wearing it changes, base stats,
## random affixes with tiers (Alt adds their ranges), the trigger affix set
## apart, the item's own text, its protection state and what happens to it on
## death, value, then the controls.

const UP := "6fdc8c"
const DOWN := "ff6b5b"
const FLAT := "8b97a3"
const LABELS := {"rating": "战力", "hp": "生命上限", "atk": "攻击力", "arts": "法术攻击力", "def": "防御", "res": "法抗",
	"aspd": "攻速", "crit": "暴击率", "crit_dmg": "暴击伤害", "move": "移速"}
const PERCENT := ["crit", "crit_dmg"]

static func text(game: GameManager, item: Item, detailed: bool, show_worn: bool) -> String:
	var lines: Array[String] = []
	lines.append("[font_size=19][color=#%s]%s[/color][/font_size]" % [item.rarity_color().to_html(false), item.display_name()])
	var kind := "%s · %d×%d" % [Item.CATEGORY_NAMES[item.category], item.width, item.height]
	if FieldCatalog.REGIONS.has(item.origin_region): kind += " · 产地 " + FieldCatalog.REGIONS[item.origin_region].name.split(" · ")[0]
	if not item.exclusive_region.is_empty(): kind += " · [color=#ee8a24]地区专属[/color]"
	if not item.special.is_empty(): kind += " · [color=#ff7a45]特殊装备[/color]"
	lines.append("[color=#99aab8]%s[/color]" % kind)
	var worn: Item = game.player.equipped.get(item.category) if item.is_equippable() else null
	if item.is_equippable():
		if worn == item:
			lines.append("[color=#d8c27a]已装备[/color]  战力 %d" % game.player.power_rating())
		else:
			var preview := game.player.preview_equip(item)
			lines.append(_diff_line("rating", preview.before.rating, preview.after.rating, true))
			lines.append("[color=#99aab8]装备后（对比%s）：[/color]" % ("当前 " + worn.item_name if worn != null else "空槽"))
			for key in ["atk", "arts", "hp", "def", "res", "aspd", "crit", "crit_dmg", "move"]:
				if not is_equal_approx(float(preview.before[key]), float(preview.after[key])):
					lines.append("  " + _diff_line(key, preview.before[key], preview.after[key], false))
		lines.append("[color=#c9d3db]── 基础 ──[/color]")
		var base := CombatStats.power_stats(item.category, item.power)
		var names := {"atk": "攻击力", "hp": "生命", "def": "防御", "arts": "法术攻击力", "stamina_regen": "体力回复"}
		for key in base: lines.append("  %s +%d" % [names[key], roundi(base[key])])
		var affixes := item.modifiers.filter(func(m): return m.trigger == ItemModifier.Trigger.NONE)
		if not affixes.is_empty():
			lines.append("[color=#c9d3db]── 词缀 ──[/color]")
			for mod in affixes: lines.append("  " + mod.describe_detailed(detailed))
		var triggers := item.modifiers.filter(func(m): return m.trigger != ItemModifier.Trigger.NONE)
		if not triggers.is_empty():
			lines.append("[color=#ff7a45]── 特殊效果 ──[/color]" if not item.special.is_empty() else "[color=#b48cff]── 触发 ──[/color]")
			for mod in triggers: lines.append("  [color=#cdb4ff]✦ %s[/color]" % mod.describe())
	if not item.description.is_empty(): lines.append("[color=#e0d6b8]%s[/color]" % item.description)
	var state: Array[String] = []
	if item.gilded: state.append("[color=#ffd45a]已点金[/color]")
	if item.insured: state.append("[color=#4fd1c5]已投保[/color]")
	if item.carried_in: state.append("带入")
	if not state.is_empty(): lines.append(" · ".join(state))
	var outcome := game.death_outcome(item)
	if not outcome.is_empty():
		var colour := "6fdc8c" if outcome.begins_with("保留") else ("4fd1c5" if outcome.ends_with("（保险）") else "ff6b5b")
		lines.append("死亡时：[color=#%s]%s[/color]" % [colour, outcome])
	lines.append("[color=#d8c27a]交付价 %d[/color]" % item.value)
	if show_worn and worn != null and worn != item:
		lines.append("\n[color=#99aab8]── 当前装备（Shift）──[/color]")
		lines.append(text(game, worn, detailed, false))
	elif worn != null and worn != item:
		lines.append("[color=#6f8396]按住 Shift 查看当前装备 · Alt 词缀范围[/color]")
	return "\n".join(lines)

static func _value(key: String, value: float) -> String:
	if key in PERCENT: return "%d%%" % roundi(value * 100)
	if key == "move": return "%.1f" % value
	return str(roundi(value))

static func _diff_line(key: String, before: float, after: float, big: bool) -> String:
	var delta := after - before
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
	for key in ["rating", "hp", "atk", "arts", "def", "res", "aspd", "crit", "crit_dmg", "move"]:
		var line := "%s %s" % [LABELS[key], _value(key, now[key])]
		var delta := float(after[key]) - float(now[key])
		if not is_zero_approx(delta):
			line += "  [color=#%s](%s%s)[/color]" % [UP if delta > 0 else DOWN, "+" if delta > 0 else "−", _value(key, absf(delta))]
		lines.append(line)
	lines.append("吸血 %d%%  闪避 %d%%  回复 %d/秒" % [roundi(p.lifesteal() * 100), roundi(p.evasion() * 100), roundi(p.regen_rate())])
	lines.append("生命 %d / %d%s" % [roundi(maxf(p.hp, 0)), roundi(p.max_hp), ("  护盾 %d" % roundi(p.shield)) if p.shield > 0 else ""])
	return "\n".join(lines)
