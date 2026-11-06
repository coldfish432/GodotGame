extends SceneTree

## C · 概览's full sheet (用户 2026-11-02: 局内角色面板显示所有词条和属性的最终数值):
## the core groups are there in the field, conversion and dodge read the
## Player's final values, conditional affixes show as their tooltip line,
## and the window builds with them.

var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(label: String, passed: bool, seen: Variant = null) -> void:
	checks += 1
	if not passed:
		failures += 1
		if seen != null: print("   seen: ", seen)
	print(("PASS " if passed else "FAIL ") + label)

func step(count: int = 3) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func rows_of(groups: Array) -> Dictionary:
	var out := {}
	for group in groups:
		for entry in group[2]: out[entry[0]] = entry[1] if entry.size() > 1 else group[0]
	return out

func titles(groups: Array) -> Array:
	return groups.map(func(g): return g[0])

func labels_in(node: Node, out: Array) -> void:
	if node is Label: out.append(node.text)
	for child in node.get_children(): labels_in(child, out)

func run() -> void:
	var game := GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(4)
	await game.start_contract("city")
	var p := game.player
	game.set_process(false)
	p.set_physics_process(false)
	await step(2)

	var groups := OperatorScreen.detail_groups(p)
	var rows := rows_of(groups)
	check("core groups show", titles(groups).slice(0, 4) == ["基础", "攻击", "防御", "体力"], titles(groups))
	for name in ["攻击力", "攻击间隔", "伤害转换", "物理闪避", "法术闪避", "对近战闪避", "整体减伤", "闪避冷却", "赤金获取", "灼燃抗性"]:
		check("row: " + name, rows.has(name))
	check("attack power is the final one", rows["攻击力"] == str(roundi(p.attack_power())), rows["攻击力"])
	check("no conditional group without such affixes", not titles(groups).has("条件词条"))

	# Gear-level stats, straight on the sheet the way equipment adds them.
	p.stats.conv_burn = 0.30
	p.stats.conv_cold = 0.50   # 80% asked, capped at 60% and split 3:5
	p.stats.evasion = 0.10
	p.stats.evasion_melee = 0.05
	p.stats.crowd_dmg = 0.04
	p.stats.sig_escort = 1.0
	rows = rows_of(OperatorScreen.detail_groups(p))
	check("conversion total is capped", rows["伤害转换"] == "60%", rows["伤害转换"])
	check("conversion splits by share", rows.get("转为灼燃") == "22.5%" and rows.get("转为寒冷") == "37.5%", [rows.get("转为灼燃"), rows.get("转为寒冷")])
	check("dodge is the final chance", rows["物理闪避"] == OperatorScreen._pct(p.evasion()) and rows["对近战闪避"] == OperatorScreen._pct(minf(0.6, p.evasion() + 0.05)), [rows["物理闪避"], rows["对近战闪避"]])
	check("regional affix reads as its tooltip line", rows.has("周围每有 1 个敌人，伤害 +4%（最多 5 个）"), rows.keys().slice(-3))
	check("signature reads as its line", rows.has("押运守则：闪避成功后，下一次攻击必定暴击"))

	game.menu.show_training(true)
	await step(2)
	var texts := []
	labels_in(game.menu, texts)
	check("the window shows the sheet", texts.has("伤害转换") and texts.has("60%") and texts.has("条件词条"), texts.size())

	print("DETAIL SHEET RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
