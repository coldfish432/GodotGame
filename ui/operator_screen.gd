class_name OperatorScreen
extends RefCounted

## C · 干员 (界面美术与布局策划案 v2 §4.2, S1/S7): a window docked on the
## left, W × H, with three pages — 概览 (her set on the doll, rank, the whole
## stat sheet, promotion), 属性 (attribute points, 作战记录, the base's crafts) and
## 技能 (the skill tree, talent and module). The same window at the base and in
## the field; in the field only points can be spent (精英化与加点策划案 §10).
## No class, no stars (用户 2026-10-21). Data, state and buttons only.

const W := 640.0
const H := 720.0
const HEADER := 52.0
const TOP := 66.0
## The workbench's paper doll (392 × 418) in the left column (用户 2026-11-04: 娃娃有点小).
const DOLL_SCALE := 0.86
## Where the stat sheet starts, right of the doll.
const SHEET_X := 366.0
const TABS := ["概览", "属性", "技能"]

## The UA standing portrait (art/ui/portraits/op_<id>.png, 120×240), or null.
static func standing(id: String) -> Texture2D:
	var path := "res://art/ui/portraits/op_%s.png" % id
	return load(path) if ResourceLoader.exists(path) else null

static func show(menu: FieldMenu, in_field: bool) -> void:
	var game := menu.game
	var stage := menu.stage_begin(0.55 if in_field else 0.9)
	var refresh := func(): show(menu, in_field)
	var plate := Panel.new()
	plate.add_theme_stylebox_override("panel", Terminal.panel_style("plate"))
	AK.put(stage, plate, Vector2.ZERO, Vector2(W, H))
	Terminal.frame(plate, AK.HOLO, HEADER)
	stage.add_child(AK.rect(Color(0, 0, 0, 0.35), Vector2.ZERO, Vector2(W, HEADER)))
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -2)
	titles.add_child(AK.label("OPERATOR", 10, AK.MUTE, AK.en()))
	var title := AK.label("干员", 20, AK.FG)
	titles.add_child(title)
	if menu.reveal_pending: Terminal.type_in(title)
	AK.put(stage, titles, Vector2(20, 6))
	var tab: int = clampi(menu.operator_tab, 0, TABS.size() - 1)
	AK.put(stage, AK.toggle(TABS, tab, func(i): menu.operator_tab = i; refresh.call(), 13), Vector2(110, 7))
	var key := AK.label("C", 11, AK.FG, AK.en())
	key.add_theme_stylebox_override("normal", AK.box(AK.PLATE_3, Color.TRANSPARENT, 0, 4))
	AK.put(stage, key, Vector2(548, 16))
	var close := AK.button("✕", "ghost", 16)
	AK.put(stage, close, Vector2(W - 60, 0), Vector2(52, 52))
	close.pressed.connect(game.go_back)
	_roster(menu, stage, refresh)
	match tab:
		0: _overview(menu, stage, in_field, refresh)
		1: _attributes(menu, stage, in_field, refresh)
		2: _skills(menu, stage, in_field, refresh)

## 干员独立装备修订案 §三 (用户 2026-11-04: 已解锁的可在干员界面切换查看): every
## operator on the roster, a column beside the window; a click shows her, in
## her own set. Only to look: who deploys is chosen at the workbench.
const CHIP := Vector2(44, 48)
static func _roster(menu: FieldMenu, stage: Control, refresh: Callable) -> void:
	var game := menu.game
	var y := TOP
	for id in game.base.roster:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("operator", id)
		b.tooltip_text = Operators.display_name(id)
		var on: bool = id == game.viewed_id()
		for s in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(s, AK.box(AK.PLATE_3 if s == "hover" else AK.PLATE_2, AK.SP if on else AK.LINE, 2 if on else 1))
		AK.put(stage, b, Vector2(W + 8, y), CHIP)
		var art := standing(id)
		if art != null:
			var head := AtlasTexture.new()
			head.atlas = art
			head.region = Rect2((art.get_width() - 72) * 0.5, 2, 72, 72 * CHIP.y / CHIP.x)
			var image := TextureRect.new()
			image.texture = head
			image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.mouse_filter = Control.MOUSE_FILTER_IGNORE
			AK.put(b, image, Vector2(2, 2), CHIP - Vector2(4, 4))
		if id == game.player.operator_id:
			var deployed := AK.rect(AK.SP, Vector2(0, CHIP.y - 4), Vector2(CHIP.x, 4))
			deployed.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(deployed)
		var pick: String = id
		b.pressed.connect(func():
			game.view_operator = "" if pick == game.player.operator_id else pick
			refresh.call())
		y += CHIP.y + 6

# --- 概览: who, rank, the stat sheet, promotion -----------------------------------------

static func _overview(menu: FieldMenu, stage: Control, in_field: bool, refresh: Callable) -> void:
	var game := menu.game
	var p: OperatorProgress = game.viewed_progress()
	var id := game.viewed_id()
	# Her set on the doll (用户 2026-11-04: 干员界面加上可以看对应干员的装备，用娃娃
	# 布局): the workbench's layout, to look at — hover shows each piece's card.
	stage.add_child(AK.rect(Color(AK.SP, 0.06), Vector2(16, TOP), Vector2(340, 372)))
	LoadoutScreens.doll(game, stage, Vector2(16, TOP + 6), DOLL_SCALE, null, Callable(), game.operator_view(id))
	AK.put(stage, AK.label(Operators.display_name(id), 28, AK.FG), Vector2(24, TOP + 384))
	AK.put(stage, AK.label(id.to_upper(), 10, AK.MUTE, AK.en()), Vector2(26, TOP + 422))
	var rank := HBoxContainer.new()
	rank.add_theme_constant_override("separation", 10)
	rank.add_child(AK.tag(Progression.ELITE_NAMES[p.elite], AK.SP))
	rank.add_child(AK.label("Lv %d / %d" % [p.level, p.level_cap()], 16, AK.FG, AK.en()))
	AK.put(stage, rank, Vector2(24, TOP + 444))
	var bar := ExpBar.new()
	bar.ratio = 1.0 if p.at_cap() else float(p.exp) / maxf(1.0, p.exp_needed())
	AK.put(stage, bar, Vector2(24, TOP + 476), Vector2(324, 6))
	AK.put(stage, AK.label("满级" if p.at_cap() else "%d / %d" % [p.exp, p.exp_needed()], 11, AK.MUTE, AK.en()), Vector2(24, TOP + 486))
	# The whole sheet on the right, final values; it scrolls above the promotion block.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	AK.put(stage, scroll, Vector2(SHEET_X, TOP + 4), Vector2(W - SHEET_X - 12, (392.0 if p.elite < 2 else H - TOP - 20.0)))
	var sheet := VBoxContainer.new()
	sheet.add_theme_constant_override("separation", 0)
	sheet.custom_minimum_size.x = W - SHEET_X - 28
	scroll.add_child(sheet)
	for group in detail_groups(game.operator_view(game.viewed_id())):
		sheet.add_child(AK.section(group[0], group[1]))
		for entry in group[2]:
			if entry.size() == 1:
				var line := AK.label(entry[0], 12, AK.FG)
				line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				line.custom_minimum_size.x = W - SHEET_X - 34
				sheet.add_child(line)
			else: sheet.add_child(_stat_row(entry[0], entry[1]))
	if p.elite < 2:
		var y := TOP + 400
		AK.put(stage, AK.section("晋升 · %s" % Progression.ELITE_NAMES[p.elite + 1], "PROMOTION"), Vector2(SHEET_X, y))
		y += 28
		var cost: Dictionary = p.promotion_cost()
		AK.put(stage, AK.label("龙门币 %s" % Economy.format(game.promotion_lmd()), 12, AK.FG if game.gold >= game.promotion_lmd() else AK.RED), Vector2(SHEET_X, y))
		y += 20
		for mat in cost.materials:
			var held := game.material_count(mat)
			AK.put(stage, AK.label("%s  %d / %d" % [mat, held, int(cost.materials[mat])], 12, AK.FG if held >= int(cost.materials[mat]) else AK.RED), Vector2(SHEET_X, y))
			y += 20
		if not in_field:
			var promote := AK.go_button("晋升", "PROMOTE", "yellow", 18)
			promote.disabled = not game.promotion_refusal().is_empty()
			promote.pressed.connect(func(): game.promote_operator(); refresh.call())
			AK.put(stage, promote, Vector2(SHEET_X, 640), Vector2(W - SHEET_X - 20, 56))

## Every stat she has, as it stands right now: [[title, EN, rows]], a row
## [name, value] or [whole line] (an affix that asks about the fight). The
## core groups always show; elemental extras and conditional affixes only when
## she has them.
static func detail_groups(pl: Player) -> Array:
	var s := pl.stats
	var v := func(key: String) -> float: return float(s.get(key, 0.0))
	var base := [["生命", "%d / %d" % [roundi(maxf(pl.hp, 0)), roundi(pl.max_hp)]]]
	if pl.condition_hp_penalty > 0.0: base.append(["生命上限（伤病污染后）", str(roundi(pl.life_cap()))])
	if pl.shield > 0.0: base.append(["护盾", str(roundi(pl.shield))])
	base.append_array([["攻击力", str(roundi(pl.attack_power()))], ["法术攻击力", str(roundi(pl.arts_power()))],
		["防御", str(roundi(pl.defense_value()))], ["法术抗性", str(roundi(pl.resistance()))], ["移动速度", "%.1f" % pl.move_speed]])
	var offense := [["攻击速度", str(roundi(pl.current_aspd()))], ["攻击间隔", "%.2f 秒" % pl.current_cooldown()],
		["攻击范围", "%.1f 米" % pl.weapon_range()],
		["暴击率", _pct(pl.crit_rate())], ["暴击伤害", _pct(pl.crit_damage())],
		["伤害加成", _pct(pl.damage_bonus - 1.0, true)], ["物理伤害", _pct(v.call("phys_dmg_pct"), true)],
		["法术伤害", _pct(v.call("arts_dmg_pct"), true)], ["无视防御", _pct(pl.physical_pierce())],
		["对精英伤害", _pct(v.call("elite_pct"), true)], ["技能伤害", _pct(pl.wave_multiplier() - 1.0, true)],
		["技能冷却", _pct(pl.skill_cd_factor() - 1.0, true)], ["吸血", _pct(pl.lifesteal())]]
	var reduce: float = v.call("dmg_reduce") + (0.25 if pl.equipped_effect("riot_shield") else 0.0)
	var defence := [["物理闪避", _pct(pl.evasion())], ["法术闪避", _pct(pl.arts_evasion())],
		["对近战闪避", _pct(clampf(pl.evasion() + v.call("evasion_melee"), 0.0, CombatStats.EVASION_CAP))],
		["对远程闪避", _pct(clampf(pl.evasion() + v.call("evasion_ranged"), 0.0, CombatStats.EVASION_CAP))],
		["整体减伤", _pct(minf(CombatStats.REDUCTION_CAP, reduce))], ["受到伤害", _pct(v.call("taken_pct") + pl.hex("taken"), true)],
		["生命回复", "%d / 秒" % roundi(pl.regen_rate())], ["受到治疗", _pct(v.call("heal_pct"), true)],
		["药剂回复", _pct(pl.potion_heal_multiplier)]]
	var stamina := [["体力回复", "%.1f / 秒" % pl.stamina_regen_rate()], ["闪避体力消耗", str(roundi(pl.dash_cost()))],
		["闪避冷却", "%.2f 秒" % pl.dash_cooldown_total()]]
	var elements := []
	if pl.elements != null:
		for kind in ["burn", "cold", "corr", "nerve", "bleed"]:
			elements.append([Elements.NAMES[kind] + "抗性", str(roundi(pl.elements.res(kind)))])
		if v.call("res_cap") > 0.0: elements.append(["元素抗性上限", str(roundi(minf(Elements.RES_CAP_MAX, Elements.RES_CAP + v.call("res_cap"))))])
		var conv := pl.elements.convert_share()
		elements.append(["伤害转换", _pct(conv)])
		var conv_total := 0.0
		for kind in Elements.KINDS: conv_total += v.call(Elements.CONV_KEY[kind])
		for kind in Elements.KINDS:
			var share: float = v.call(Elements.CONV_KEY[kind]) / conv_total * conv if conv_total > 0.0 else 0.0
			if share > 0.0: elements.append(["转为" + Elements.NAMES[kind], _pct(share)])
		for kind in Elements.KINDS:
			if v.call(Elements.ADD_KEY[kind]) > 0.0: elements.append(["附加" + Elements.NAMES[kind], _pct(v.call(Elements.ADD_KEY[kind]))])
		for kind in ["burn", "cold", "corr", "nerve", "bleed", "necro"]:
			if not is_zero_approx(v.call(Elements.DMG_KEY[kind])): elements.append([Elements.NAMES[kind] + "伤害", _pct(v.call(Elements.DMG_KEY[kind]), true)])
		var proc := float(Elements.FORM_PROC.get(pl.weapon_form(), 1.0))
		for dot in Elements.DOT_CHANCE_KEY:
			var chance: float = v.call(Elements.DOT_CHANCE_KEY[dot]) * proc
			if chance > 0.0: elements.append([Elements.DOT_NAMES[dot] + "几率", _pct(minf(1.0, chance))])
		for entry in [["持续伤害", "dot_pct"], ["持续时间", "dot_dur_pct"], ["损伤累积", "build_pct"]]:
			if not is_zero_approx(v.call(entry[1])): elements.append([entry[0], _pct(v.call(entry[1]), true)])
	var game := pl.game if is_instance_valid(pl.game) else null
	var gold := pl.gold_gain_multiplier * (pl.elements.gold_mult() if pl.elements != null else 1.0) * (game.research.gold_factor() if game != null and game.research != null else 1.0)
	var gains := [["赤金获取", _pct(gold - 1.0, true)], ["经验获取", _pct(pl.exp_gain_multiplier - 1.0, true)],
		["装备掉率", _pct(pl.drop_rate_bonus, true)], ["威胁累积", _pct(v.call("pressure_pct"), true)], ["污染累积", _pct(v.call("contam_pct"), true)]]
	# Regional affixes and orange signatures read as their own tooltip lines.
	var conditional := []
	for stat in ItemModifier.SHEET_KEYS:
		var key: String = ItemModifier.SHEET_KEYS[stat]
		if stat < ItemModifier.Stat.CROWD_DMG or stat == ItemModifier.Stat.BUILD_PCT or key in CONDITIONAL_SHOWN: continue
		if is_zero_approx(v.call(key)): continue
		var mod := ItemModifier.new()
		mod.stat = stat
		mod.amount = v.call(key)
		var line := mod.describe()
		if not line.is_empty(): conditional.append([line])
	var groups := [["基础", "BASE", base], ["攻击", "OFFENSE", offense], ["防御", "DEFENCE", defence], ["体力", "STAMINA", stamina]]
	if not elements.is_empty(): groups.append(["元素", "ELEMENTS", elements])
	groups.append(["收益", "GAINS", gains])
	if not conditional.is_empty(): groups.append(["条件词条", "CONDITIONAL", conditional])
	return groups

## Sheet keys an affix shares with a line already in the groups above.
const CONDITIONAL_SHOWN := ["heal_pct", "contam_pct"]

## A share as a percentage, one decimal when it is not whole.
static func _pct(value: float, signed: bool = false) -> String:
	var shown := value * 100.0
	var text := str(roundi(shown)) if absf(shown - roundf(shown)) < 0.05 else "%.1f" % shown
	if signed and shown > 0.0 and text != "0": text = "+" + text
	return text + "%"

static func _stat_row(name: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 22
	row.add_child(AK.label(name, 12, AK.MUTE))
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(fill)
	row.add_child(AK.label(value, 14, AK.FG, AK.en()))
	return row

# --- 属性: points, battle records, crafts ----------------------------------------------

static func _attributes(menu: FieldMenu, stage: Control, in_field: bool, refresh: Callable) -> void:
	var game := menu.game
	var p: OperatorProgress = game.viewed_progress()
	AK.put(stage, AK.label("属性点 %d" % p.attribute_points, 16, AK.SP), Vector2(20, TOP + 4))
	var y := TOP + 36
	for key in Progression.ATTRIBUTES:
		stage.add_child(AK.rect(AK.PLATE_2, Vector2(16, y), Vector2(608, 60)))
		AK.put(stage, AK.label(Progression.ATTRIBUTE_NAMES[key], 15, AK.FG), Vector2(28, y + 6))
		AK.put(stage, AK.label(str(p.attribute(key)), 20, AK.FG, AK.en()), Vector2(130, y + 4))
		AK.put(stage, AK.label(_per_point(key), 11, AK.MUTE), Vector2(28, y + 36))
		var add := AK.button("+", "yellow", 16)
		add.disabled = p.attribute_points <= 0
		var attr: String = key
		add.pressed.connect(func(): game.add_attribute_point(attr); refresh.call())
		AK.put(stage, add, Vector2(568, y + 10), Vector2(44, 40))
		y += 66
	y += 10
	AK.put(stage, AK.section("作战记录", "BATTLE RECORD"), Vector2(20, y))
	var ry := y + 28
	for record in Progression.RECORDS:
		var have := int(game.base.records.get(record, 0))
		AK.put(stage, AK.label("%s ×%d" % [record, have], 13, MaterialCatalog.STAR_COLORS[Progression.RECORD_STAR[record]]), Vector2(20, ry + 4))
		if not in_field:
			var one := AK.button("使用", "plain", 11)
			one.disabled = have <= 0 or p.at_cap()
			var name: String = record
			one.pressed.connect(func(): game.feed_record(name, 1); refresh.call())
			AK.put(stage, one, Vector2(178, ry))
			var all := AK.button("全部", "plain", 11)
			all.disabled = have <= 0 or p.at_cap()
			all.pressed.connect(func(): game.feed_record(name, have); refresh.call())
			AK.put(stage, all, Vector2(240, ry))
		ry += 32
	if not in_field:
		AK.put(stage, AK.section("合成", "CRAFT"), Vector2(332, y))
		var cy := y + 28
		for recipe in GameManager.CRAFTS:
			var r: Dictionary = GameManager.CRAFTS[recipe]
			var parts: Array[String] = []
			for id in r.materials: parts.append("%s %d/%d" % [id, game.material_count(id), int(r.materials[id])])
			AK.put(stage, AK.label(recipe, 13, AK.FG), Vector2(332, cy + 2))
			AK.put(stage, AK.label("  ".join(parts), 10, AK.MUTE), Vector2(332, cy + 22))
			var craft := AK.button("合成", "plain", 11)
			craft.disabled = not game.materials_refusal(r.materials).is_empty()
			var which: String = recipe
			craft.pressed.connect(func(): game.craft(which); refresh.call())
			AK.put(stage, craft, Vector2(572, cy + 4))
			cy += 46

static func _per_point(key: String) -> String:
	var names := {"hp": "生命", "def": "防御", "regen": "回复", "atk": "攻击", "crit": "暴击率", "crit_dmg": "暴伤",
		"aspd": "攻速", "stamina_regen": "体力回复", "move_pct": "移速", "arts": "法术攻击", "arts_dmg_pct": "法术伤害", "res": "法抗",
		"hp_pct": "生命", "atk_pct": "攻击", "arts_pct": "法术攻击", "def_pct": "防御"}
	var parts: Array[String] = []
	for stat in Progression.PER_POINT[key]:
		var v := float(Progression.PER_POINT[key][stat])
		var percent: bool = stat in ["crit", "crit_dmg"] or str(stat).ends_with("_pct")
		var shown := ("+%s%%" % _trim(v * 100.0)) if percent else ("+%s" % _trim(v))
		parts.append("%s %s" % [names.get(stat, stat), shown])
	return " · ".join(parts)

static func _trim(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else ("%.1f" % v)

# --- 技能: the tree, talent, module -----------------------------------------------------

static func _skills(menu: FieldMenu, stage: Control, in_field: bool, refresh: Callable) -> void:
	var game := menu.game
	var p: OperatorProgress = game.viewed_progress()
	AK.put(stage, AK.label("技能点 %d" % p.skill_points, 16, AK.SP), Vector2(20, TOP + 4))
	if not in_field:
		var refund := p.refundable_points()
		var respec := AK.button("洗点 · %s" % Economy.format(game.respec_price(refund, p.elite)), "plain", 11)
		respec.disabled = refund <= 0 or game.gold < game.respec_price(refund, p.elite)
		respec.pressed.connect(func(): game.respec_skills(); refresh.call())
		AK.put(stage, respec, Vector2(170, TOP + 2))
	var tree := SkillTrees.tree(game.viewed_id())
	var kind_names := {"signature": "招牌", "skill": "技能", "modifier": "修饰", "passive": "被动", "transmuter": "变换"}
	for tier in range(3):
		var tx := 16.0 + tier * 204.0
		stage.add_child(AK.rect(AK.PLATE_2 if p.elite >= tier else Color(AK.PLATE_SOLID, 0.6), Vector2(tx, TOP + 34), Vector2(196, 612)))
		AK.put(stage, AK.label(Progression.ELITE_NAMES[tier], 13, AK.FG if p.elite >= tier else AK.DIM), Vector2(tx + 8, TOP + 40))
		var ny := TOP + 64
		for id in tree:
			var data: Dictionary = tree[id]
			if int(data.tier) != tier: continue
			var rank := p.rank(id)
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			for s in ["normal", "hover", "pressed", "disabled"]:
				b.add_theme_stylebox_override(s, AK.box(AK.PLATE_3 if s == "hover" else AK.PLATE_SOLID))
			b.tooltip_text = SkillTrees.describe(game.viewed_id(), id, rank)
			AK.put(stage, b, Vector2(tx + 6, ny), Vector2(184, 58))
			AK.put(b, AK.label(str(data.name), 13, AK.FG if rank > 0 else AK.MUTE), Vector2(8, 6))
			AK.put(b, AK.tag(kind_names.get(str(data.type), ""), AK.PAPER), Vector2(8, 32))
			AK.put(b, AK.label(SkillTrees.rank_label(data, rank), 12, AK.SP if rank > 0 else AK.DIM, AK.en()), Vector2(60, 34))
			var block := p.rank_block(id)
			var materials := SkillTrees.rank_materials(data, rank)
			var mat_short := not materials.is_empty() and not game.materials_refusal(materials).is_empty()
			if str(data.type) == "transmuter" and rank > 0:
				var on: bool = p.transmuter(str(data.group)) == id
				var toggle := AK.button("启用中" if on else "启用", "blue" if on else "plain", 11)
				var node_id: String = id
				var group: String = data.group
				toggle.pressed.connect(func(): game.set_transmuter(group, "" if on else node_id); refresh.call())
				AK.put(b, toggle, Vector2(124, 28))
			elif block.is_empty() and not mat_short:
				var plus := AK.button("+%d" % SkillTrees.rank_cost(data, rank), "yellow", 11)
				var node_id: String = id
				plus.pressed.connect(func(): game.add_skill_rank(node_id); refresh.call())
				AK.put(b, plus, Vector2(136, 28))
			elif rank < SkillTrees.max_rank(data):
				AK.put(b, AK.label(block if not block.is_empty() else "材料不足", 10, AK.DIM), Vector2(116, 36))
			for child in b.get_children():
				if not child is Button: child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ny += 64
		if tier >= 1:
			var talent: Dictionary = SkillTrees.TALENTS.get(game.viewed_id(), {})
			stage.add_child(AK.rect(AK.PLATE_SOLID, Vector2(tx + 6, ny), Vector2(184, 46)))
			AK.put(stage, AK.label(str(talent.get("name", "")), 13, AK.FG if p.elite >= tier else AK.DIM), Vector2(tx + 14, ny + 4))
			AK.put(stage, AK.tag("天赋", AK.SP), Vector2(tx + 14, ny + 24))
			var hint := Control.new()
			hint.tooltip_text = SkillTrees.talent_text(game.viewed_id(), tier, p.module_level if tier == 2 else 0)
			AK.put(stage, hint, Vector2(tx + 6, ny), Vector2(184, 46))
			ny += 52
		if tier == 2:
			var module: Dictionary = SkillTrees.MODULES.get(game.viewed_id(), {})
			stage.add_child(AK.rect(AK.PLATE_SOLID, Vector2(tx + 6, ny), Vector2(184, 74)))
			AK.put(stage, AK.label(str(module.get("name", "")), 13, AK.FG if p.module_level > 0 else AK.MUTE), Vector2(tx + 14, ny + 4))
			AK.put(stage, AK.tag("模组 %s" % str(module.get("type", "")), AK.CYAN), Vector2(tx + 14, ny + 24))
			AK.put(stage, AK.label("%d/3" % p.module_level, 12, AK.SP, AK.en()), Vector2(tx + 100, ny + 26))
			if not in_field and p.module_level < 3:
				var cost: Dictionary = SkillTrees.MODULE_COST[p.module_level]
				var upgrade := AK.button("%s · %s" % ["解锁" if p.module_level == 0 else "升级", Economy.format(int(cost.lmd))], "plain", 11)
				upgrade.disabled = not game.module_refusal().is_empty()
				upgrade.tooltip_text = "模组数据块 %d / %d" % [game.material_count("模组数据块"), int(cost.materials["模组数据块"])]
				upgrade.pressed.connect(func(): game.upgrade_module(); refresh.call())
				AK.put(stage, upgrade, Vector2(tx + 14, ny + 44))


class ExpBar extends Control:
	var ratio := 0.0
	func _draw() -> void:
		AK.draw_bar(self, Rect2(Vector2.ZERO, size), ratio, AK.SP)
