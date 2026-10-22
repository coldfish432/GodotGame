class_name OperatorScreen
extends RefCounted

## C · 干员 (界面美术与布局策划案 v2 §4.2, S1/S7): a window docked on the
## left, 640 × 720, with three pages — 概览 (portrait, rank, the whole stat
## sheet, promotion), 属性 (attribute points, 作战记录, the base's crafts) and
## 技能 (the skill tree, talent and module). The same window at the base and in
## the field; in the field only points can be spent (精英化与加点策划案 §10).
## No class, no stars (用户 2026-10-21). Data, state and buttons only.

const W := 640.0
const H := 720.0
const HEADER := 52.0
const TOP := 66.0
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
	match tab:
		0: _overview(menu, stage, in_field, refresh)
		1: _attributes(menu, stage, in_field, refresh)
		2: _skills(menu, stage, in_field, refresh)

# --- 概览: who, rank, the stat sheet, promotion -----------------------------------------

static func _overview(menu: FieldMenu, stage: Control, in_field: bool, refresh: Callable) -> void:
	var game := menu.game
	var p: OperatorProgress = game.progress()
	var id := game.player.operator_id
	stage.add_child(AK.rect(Color(AK.SP, 0.06), Vector2(16, TOP), Vector2(280, 500)))
	var art := standing(id)
	if art != null:
		var image := TextureRect.new()
		image.texture = art
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		AK.put(stage, image, Vector2(36, TOP + 12), Vector2(240, 480))
	else:
		var bust := TextureRect.new()
		bust.texture = Operators.portrait(id)
		bust.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bust.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		AK.put(stage, bust, Vector2(60, TOP + 120), Vector2(192, 192))
	AK.put(stage, AK.label(Operators.display_name(id), 28, AK.FG), Vector2(24, TOP + 506))
	AK.put(stage, AK.label(id.to_upper(), 10, AK.MUTE, AK.en()), Vector2(26, TOP + 544))
	var rank := HBoxContainer.new()
	rank.add_theme_constant_override("separation", 10)
	rank.add_child(AK.tag(Progression.ELITE_NAMES[p.elite], AK.SP))
	rank.add_child(AK.label("Lv %d / %d" % [p.level, p.level_cap()], 16, AK.FG, AK.en()))
	AK.put(stage, rank, Vector2(24, TOP + 566))
	var bar := ExpBar.new()
	bar.ratio = 1.0 if p.at_cap() else float(p.exp) / maxf(1.0, p.exp_needed())
	AK.put(stage, bar, Vector2(24, TOP + 598), Vector2(264, 6))
	AK.put(stage, AK.label("满级" if p.at_cap() else "%d / %d" % [p.exp, p.exp_needed()], 11, AK.MUTE, AK.en()), Vector2(24, TOP + 608))
	# The whole sheet on the right (the I window keeps a summary).
	var sheet := VBoxContainer.new()
	sheet.add_theme_constant_override("separation", 2)
	AK.put(stage, sheet, Vector2(316, TOP + 4), Vector2(304, 0))
	var pl := game.player
	var now: Dictionary = pl.snapshot()
	var groups := [["基础", "BASE", [["生命", "hp"], ["攻击", "atk"], ["法术攻击", "arts"], ["防御", "def"], ["法术抗性", "res"]]],
		["战斗", "COMBAT", [["攻击速度", "aspd"], ["暴击率", "crit"], ["暴击伤害", "crit_dmg"]]],
		["其他", "OTHER", [["移动速度", "move"]]]]
	for group in groups:
		sheet.add_child(AK.section(group[0], group[1]))
		for entry in group[2]:
			var k: String = entry[1]
			sheet.add_child(_stat_row(entry[0], ItemTooltip._value(k, now[k]) if k != "hp" else "%d / %d" % [roundi(maxf(pl.hp, 0)), roundi(pl.max_hp)]))
	sheet.add_child(_stat_row("生命回复", "%d / 秒" % roundi(pl.regen_rate())))
	if p.elite < 2:
		var y := TOP + 400
		AK.put(stage, AK.section("晋升 · %s" % Progression.ELITE_NAMES[p.elite + 1], "PROMOTION"), Vector2(316, y))
		y += 28
		var cost: Dictionary = p.promotion_cost()
		AK.put(stage, AK.label("龙门币 %s" % Economy.format(game.promotion_lmd()), 12, AK.FG if game.gold >= game.promotion_lmd() else AK.RED), Vector2(316, y))
		y += 20
		for mat in cost.materials:
			var held := game.material_count(mat)
			AK.put(stage, AK.label("%s  %d / %d" % [mat, held, int(cost.materials[mat])], 12, AK.FG if held >= int(cost.materials[mat]) else AK.RED), Vector2(316, y))
			y += 20
		if not in_field:
			var promote := AK.go_button("晋升", "PROMOTE", "yellow", 18)
			promote.disabled = not game.promotion_refusal().is_empty()
			promote.pressed.connect(func(): game.promote_operator(); refresh.call())
			AK.put(stage, promote, Vector2(316, 640), Vector2(304, 56))

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
	var p: OperatorProgress = game.progress()
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
	var p: OperatorProgress = game.progress()
	AK.put(stage, AK.label("技能点 %d" % p.skill_points, 16, AK.SP), Vector2(20, TOP + 4))
	if not in_field:
		var refund := p.refundable_points()
		var respec := AK.button("洗点 · %s" % Economy.format(game.respec_price(refund, p.elite)), "plain", 11)
		respec.disabled = refund <= 0 or game.gold < game.respec_price(refund, p.elite)
		respec.pressed.connect(func(): game.respec_skills(); refresh.call())
		AK.put(stage, respec, Vector2(170, TOP + 2))
	var tree := SkillTrees.tree(game.player.operator_id)
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
			b.tooltip_text = SkillTrees.describe(game.player.operator_id, id, rank)
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
			var talent: Dictionary = SkillTrees.TALENTS.get(game.player.operator_id, {})
			stage.add_child(AK.rect(AK.PLATE_SOLID, Vector2(tx + 6, ny), Vector2(184, 46)))
			AK.put(stage, AK.label(str(talent.get("name", "")), 13, AK.FG if p.elite >= tier else AK.DIM), Vector2(tx + 14, ny + 4))
			AK.put(stage, AK.tag("天赋", AK.SP), Vector2(tx + 14, ny + 24))
			var hint := Control.new()
			hint.tooltip_text = SkillTrees.talent_text(game.player.operator_id, tier, p.module_level if tier == 2 else 0)
			AK.put(stage, hint, Vector2(tx + 6, ny), Vector2(184, 46))
			ny += 52
		if tier == 2:
			var module: Dictionary = SkillTrees.MODULES.get(game.player.operator_id, {})
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
