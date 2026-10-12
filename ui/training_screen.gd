class_name TrainingScreen
extends RefCounted

## 干员养成 (精英化与加点策划案_v0_2.md §10): level and 作战记录, promotion,
## the four attributes, the skill tree with its modifiers and transmuters, the
## talent and module, respec and the chip / skill-summary crafts. At the base
## everything works; in the field (backpack → 加点) only points can be spent.
## Data, state and buttons only (用户 2026-10-05: no rule text).

const TOP := 72.0

static func show(menu: FieldMenu, in_field: bool) -> void:
	var game := menu.game
	var p: OperatorProgress = game.progress()
	var stage := BaseScreens.shell(menu, "干员养成", "OPERATOR", [], 0, Callable(), "ELITE",
		[["lmd", Economy.format(game.gold)]])
	var refresh := func(): show(menu, in_field)
	# --- Left: who, level, records, promotion ------------------------------------
	var x := 16.0
	stage.add_child(AK.rect(AK.PLATE_2, Vector2(x, TOP + 6), Vector2(300, 636)))
	if not in_field:
		var tabs := HBoxContainer.new()
		tabs.add_theme_constant_override("separation", 4)
		for id in Operators.ORDER:
			var tab := AK.button(Operators.display_name(id), "blue" if id == game.player.operator_id else "plain", 12)
			var chosen: String = id
			tab.pressed.connect(func(): game.choose_operator(chosen); refresh.call())
			tabs.add_child(tab)
		AK.put(stage, tabs, Vector2(x + 10, TOP + 14))
	var portrait := TextureRect.new()
	portrait.texture = Operators.portrait(game.player.operator_id)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	AK.put(stage, portrait, Vector2(x + 10, TOP + 50), Vector2(96, 96))
	AK.put(stage, AK.label(Operators.display_name(game.player.operator_id), 20, AK.FG), Vector2(x + 116, TOP + 54))
	AK.put(stage, AK.tag(Progression.ELITE_NAMES[p.elite], AK.SP), Vector2(x + 116, TOP + 86))
	AK.put(stage, AK.label("Lv %d / %d" % [p.level, p.level_cap()], 18, AK.FG, AK.en()), Vector2(x + 116, TOP + 110))
	var bar := ExpBar.new()
	bar.ratio = 1.0 if p.at_cap() else float(p.exp) / maxf(1.0, p.exp_needed())
	AK.put(stage, bar, Vector2(x + 10, TOP + 154), Vector2(280, 8))
	AK.put(stage, AK.label("满级" if p.at_cap() else "%d / %d" % [p.exp, p.exp_needed()], 11, AK.MUTE, AK.en()), Vector2(x + 10, TOP + 164))
	var y := TOP + 190
	AK.put(stage, AK.section("作战记录", "BATTLE RECORD"), Vector2(x + 10, y))
	y += 26
	for record in Progression.RECORDS:
		var have := int(game.base.records.get(record, 0))
		AK.put(stage, AK.label("%s ×%d" % [record, have], 13, MaterialCatalog.STAR_COLORS[Progression.RECORD_STAR[record]]), Vector2(x + 10, y + 4))
		if not in_field:
			var one := AK.button("使用", "plain", 11)
			one.disabled = have <= 0 or p.at_cap()
			var name: String = record
			one.pressed.connect(func(): game.feed_record(name, 1); refresh.call())
			AK.put(stage, one, Vector2(x + 168, y))
			var all := AK.button("全部", "plain", 11)
			all.disabled = have <= 0 or p.at_cap()
			all.pressed.connect(func(): game.feed_record(name, have); refresh.call())
			AK.put(stage, all, Vector2(x + 230, y))
		y += 32
	y += 6
	if p.elite < 2:
		AK.put(stage, AK.section("晋升 · %s" % Progression.ELITE_NAMES[p.elite + 1], "PROMOTION"), Vector2(x + 10, y))
		y += 26
		var cost: Dictionary = p.promotion_cost()
		AK.put(stage, AK.label("龙门币 %s" % Economy.format(int(cost.lmd)), 12, AK.FG if game.gold >= int(cost.lmd) else AK.RED), Vector2(x + 10, y))
		y += 20
		for id in cost.materials:
			var held := game.material_count(id)
			AK.put(stage, AK.label("%s  %d / %d" % [id, held, int(cost.materials[id])], 12, AK.FG if held >= int(cost.materials[id]) else AK.RED), Vector2(x + 10, y))
			y += 20
		if not in_field:
			var promote := AK.button("晋升", "yellow", 14)
			promote.disabled = not game.promotion_refusal().is_empty()
			promote.pressed.connect(func(): game.promote_operator(); refresh.call())
			AK.put(stage, promote, Vector2(x + 10, y + 4), Vector2(280, 36))
	# --- Middle: the skill tree ---------------------------------------------------
	var mx := 332.0
	AK.put(stage, AK.label("技能点 %d" % p.skill_points, 16, AK.SP), Vector2(mx, TOP + 8))
	if not in_field:
		var refund := p.refundable_points()
		var respec := AK.button("洗点 · %s" % Economy.format(Progression.respec_cost(refund, p.elite)), "plain", 11)
		respec.disabled = refund <= 0 or game.gold < Progression.respec_cost(refund, p.elite)
		respec.pressed.connect(func(): game.respec_skills(); refresh.call())
		AK.put(stage, respec, Vector2(mx + 150, TOP + 6))
	var tree := SkillTrees.tree(game.player.operator_id)
	for tier in range(3):
		var tx := mx + tier * 196.0
		stage.add_child(AK.rect(AK.PLATE_2 if p.elite >= tier else Color(0.12, 0.12, 0.12), Vector2(tx, TOP + 40), Vector2(190, 602)))
		AK.put(stage, AK.label(Progression.ELITE_NAMES[tier], 13, AK.FG if p.elite >= tier else AK.DIM), Vector2(tx + 8, TOP + 46))
		var ny := TOP + 72
		for id in tree:
			var data: Dictionary = tree[id]
			if int(data.tier) != tier: continue
			var rank := p.rank(id)
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			for s in ["normal", "hover", "pressed", "disabled"]:
				b.add_theme_stylebox_override(s, AK.box(AK.PLATE_3 if s == "hover" else Color("1d1d1d")))
			b.tooltip_text = SkillTrees.describe(game.player.operator_id, id, rank)
			AK.put(stage, b, Vector2(tx + 6, ny), Vector2(178, 58))
			var kind_names := {"signature": "招牌", "skill": "技能", "modifier": "修饰", "passive": "被动", "transmuter": "变换"}
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
				AK.put(b, toggle, Vector2(118, 28))
			elif block.is_empty() and not mat_short:
				var plus := AK.button("+%d" % SkillTrees.rank_cost(data, rank), "yellow", 11)
				var node_id: String = id
				plus.pressed.connect(func(): game.add_skill_rank(node_id); refresh.call())
				AK.put(b, plus, Vector2(130, 28))
			elif rank < int(data.max):
				AK.put(b, AK.label(block if not block.is_empty() else "材料不足", 10, AK.DIM), Vector2(110, 36))
			for child in b.get_children():
				if not child is Button: child.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ny += 64
		# Talent (精英 1 / 2) and module (精英 2) sit at the foot of their tier.
		if tier >= 1:
			var talent: Dictionary = SkillTrees.TALENTS.get(game.player.operator_id, {})
			stage.add_child(AK.rect(Color("1d1d1d"), Vector2(tx + 6, ny), Vector2(178, 46)))
			AK.put(stage, AK.label(str(talent.get("name", "")), 13, AK.FG if p.elite >= tier else AK.DIM), Vector2(tx + 14, ny + 4))
			AK.put(stage, AK.tag("天赋", AK.SP), Vector2(tx + 14, ny + 24))
			var hint := Control.new()
			hint.tooltip_text = SkillTrees.talent_text(game.player.operator_id, tier, p.module_level if tier == 2 else 0)
			AK.put(stage, hint, Vector2(tx + 6, ny), Vector2(178, 46))
			ny += 52
		if tier == 2:
			var module: Dictionary = SkillTrees.MODULES.get(game.player.operator_id, {})
			stage.add_child(AK.rect(Color("1d1d1d"), Vector2(tx + 6, ny), Vector2(178, 74)))
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
	# --- Right: attributes, crafts ---------------------------------------------
	var rx := 932.0
	AK.put(stage, AK.label("属性点 %d" % p.attribute_points, 16, AK.SP), Vector2(rx, TOP + 8))
	var ry := TOP + 44
	for key in Progression.ATTRIBUTES:
		stage.add_child(AK.rect(AK.PLATE_2, Vector2(rx, ry), Vector2(332, 62)))
		AK.put(stage, AK.label(Progression.ATTRIBUTE_NAMES[key], 15, AK.FG), Vector2(rx + 12, ry + 6))
		AK.put(stage, AK.label(str(p.attribute(key)), 20, AK.FG, AK.en()), Vector2(rx + 110, ry + 4))
		AK.put(stage, AK.label(_per_point(key), 11, AK.MUTE), Vector2(rx + 12, ry + 36))
		var add := AK.button("+", "yellow", 16)
		add.disabled = p.attribute_points <= 0
		var attr: String = key
		add.pressed.connect(func(): game.add_attribute_point(attr); refresh.call())
		AK.put(stage, add, Vector2(rx + 276, ry + 10), Vector2(44, 40))
		ry += 68
	if not in_field:
		ry += 8
		AK.put(stage, AK.section("合成", "CRAFT"), Vector2(rx, ry))
		ry += 28
		for recipe in GameManager.CRAFTS:
			var r: Dictionary = GameManager.CRAFTS[recipe]
			var parts: Array[String] = []
			for id in r.materials: parts.append("%s %d/%d" % [id, game.material_count(id), int(r.materials[id])])
			AK.put(stage, AK.label(recipe, 13, AK.FG), Vector2(rx, ry + 2))
			AK.put(stage, AK.label("  ".join(parts), 10, AK.MUTE), Vector2(rx, ry + 22))
			var craft := AK.button("合成", "plain", 11)
			craft.disabled = not game.materials_refusal(r.materials).is_empty()
			var which: String = recipe
			craft.pressed.connect(func(): game.craft(which); refresh.call())
			AK.put(stage, craft, Vector2(rx + 270, ry + 4))
			ry += 46

static func _per_point(key: String) -> String:
	var names := {"hp": "生命", "def": "防御", "regen": "回复", "atk": "攻击", "crit": "暴击率", "crit_dmg": "暴伤",
		"aspd": "攻速", "stamina_regen": "体力回复", "move_pct": "移速", "arts": "法术攻击", "arts_dmg_pct": "法术伤害", "res": "法抗"}
	var parts: Array[String] = []
	for stat in Progression.PER_POINT[key]:
		var v := float(Progression.PER_POINT[key][stat])
		var shown := ("+%s%%" % _trim(v * 100.0)) if stat in ["crit", "crit_dmg", "move_pct", "arts_dmg_pct"] else ("+%s" % _trim(v))
		parts.append("%s %s" % [names[stat], shown])
	return " · ".join(parts)

static func _trim(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else ("%.1f" % v)

class ExpBar extends Control:
	var ratio := 0.0
	func _draw() -> void:
		AK.draw_bar(self, Rect2(Vector2.ZERO, size), ratio, AK.SP)
