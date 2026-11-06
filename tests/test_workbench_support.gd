extends SceneTree

## 整备台 · 投保 / 增益 (用户 2026-11-02): insurance, 补给, 课题, flasks and
## 随队物资 all bought or set from the workbench, through the departments' own
## calls; the departments keep their own pages.

var game: GameManager
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = null) -> void:
	checks += 1
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label + ("" if detail == null or passed else "  %s" % str(detail)))

func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 4343
	root.add_child(game)
	await step(8)
	game.gold = 5000000
	await _locked()
	game.base.max_facilities()
	for i in range(6): game.base.shelf.append(MaterialCatalog.create(Economy.GOLD_ID, 10))
	game.base.shelf.append(MaterialCatalog.create("食堂便当", 2))
	await _insurance()
	await _support()
	print("WORKBENCH SUPPORT RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)

## What is not open yet is not on the page at all (用户 2026-11-02).
func _locked() -> void:
	for id in ["canteen", "lab", "store"]: game.base.set_facility(id, 0)
	await _open(4)
	check("all four columns stand", _has_label("补给") and _has_label("课题") and _has_label("药剂") and _has_label("随队物资"))
	check("no canteen: its column is empty", _row_button("食堂便当", "用餐") == null and _row_button("食堂便当", "已用餐") == null)
	check("no lab: no projects in it", _row_button(str(ResearchCatalog.PROJECTS["scan"][0]), "签订") == null)
	check("the two locked columns are greyed", _veils() == 2, _veils())
	check("a store short of its level: no 特供 flask", _row_button(BaseCatalog.create_potion("C", 1).display_name(), "购买") == null)
	# The store starts at Lv1: the plain kits are on sale from the start, the refined ones at Lv3.
	check("the store at its start: plain kits only", _row_button(str(FeatureCatalog.KITS["dust_mask"].name) + " ×", "购买") != null
		and _row_button(str(FeatureCatalog.KITS["dust_mask_plus"].name) + " ×", "购买") == null)
	game.close_modal()
	# Built, but its operator still lost (失散干员).
	game.base.max_facilities()
	game.base.start_locked()
	await _open(4)
	game.base.shelf.append(MaterialCatalog.create("食堂便当", 1))
	await _open(4)
	check("科研部 waiting for Pith: no projects", _has_label("课题") and _row_button(str(ResearchCatalog.PROJECTS["scan"][0]), "签订") == null)
	check("食堂 waiting for Touch: no meals", _has_label("补给") and _row_button("食堂便当", "用餐") == null)
	check("waiting departments stay greyed", _veils() == 2, _veils())
	check("the store's own shelf is there", _row_button(BaseCatalog.create_potion("C", 1).display_name(), "购买") != null)
	game.base.take_material("食堂便当", 1)
	game.close_modal()
	game.base.dept_lock = false

func _veils() -> int:
	var out: Array = []
	_walk(game.menu, func(n): if n.has_meta("locked_veil"): out.append(n))
	return out.size()

func _has_label(text: String) -> bool:
	return _find(game.menu, func(n): return n is Label and n.text == text) != null

func _open(tab: int) -> void:
	game.menu.workbench_tab = tab
	game.open_station("loadout")
	await step(2)

func _insurance() -> void:
	check("the workbench has 投保 and 增益 tabs", LoadoutScreens.WORKBENCH_TABS.slice(3) == ["投保", "增益"])
	var gear := Item.create("刀", Item.Category.WEAPON, 1, 2, 1.0)
	gear.value = 400
	game.inventory.try_add(gear)
	await _open(3)
	var b: Button = _find(game.menu, func(n): return n is Button and n.text.begins_with("投保 "))
	check("its 投保 tab lists the carried piece", b != null)
	if b != null:
		var lmd := game.gold
		var price := game.insurance_price(gear)
		b.pressed.emit()
		await step(1)
		check("and insures it there", gear.insured and game.gold == lmd - price, [gear.insured, lmd - game.gold, price])
	game.close_modal()
	# 后勤柜台 still sells it.
	game.open_station("insurance")
	await step(2)
	check("后勤柜台 keeps its own page", _find(game.menu, func(n): return n is Button and n.has_meta("uninsure")) != null)
	game.close_modal()

func _support() -> void:
	await _open(4)
	check("all open: no column greyed", _veils() == 0, _veils())
	# 补给
	var eat := _row_button("食堂便当", "用餐")
	check("增益 lists the canteen's stock", eat != null)
	if eat != null:
		eat.pressed.emit()
		await step(1)
		check("用餐 eats it for the next contract", game.provisions.meal() == "食堂便当" and game.material_count("食堂便当") == 1)
	# 课题
	var project: String = ResearchCatalog.PROJECTS.keys()[0]
	var sign := _row_button(str(ResearchCatalog.PROJECTS[project][0]), "签订")
	check("增益 lists the projects", sign != null)
	if sign != null:
		if sign.disabled: check("a project can be signed there", false, sign.tooltip_text)
		else:
			sign.pressed.emit()
			await step(1)
			check("签订 signs it", game.research.projects().has(project))
			var cancel := _row_button(str(ResearchCatalog.PROJECTS[project][0]), "取消")
			if cancel != null: cancel.pressed.emit()
			await step(1)
			check("and 取消 takes it off", not game.research.projects().has(project))
	# 药剂
	var a_before := game.potion_count("A")
	var buy_a := _row_button(BaseCatalog.create_potion("A", 1).display_name(), "购买")
	check("增益 lists the pharmacy's flasks", buy_a != null and not buy_a.disabled)
	if buy_a != null:
		buy_a.pressed.emit()
		await step(1)
		check("and buys one into the pack", game.potion_count("A") == a_before + 1)
	var special: String = game.closure_goods()[0]
	var s_before := game.potion_count(special)
	var buy_s := _row_button(BaseCatalog.create_potion(special, 1).display_name(), "购买")
	check("增益 lists 可露希尔's 特供", buy_s != null and not buy_s.disabled, buy_s.tooltip_text if buy_s != null else null)
	if buy_s != null:
		buy_s.pressed.emit()
		await step(1)
		check("and buys them for 赤金", game.potion_count(special) > s_before)
	# 随队物资
	var buy_k := _row_button(str(FeatureCatalog.KITS["dust_mask"].name) + " ×", "购买")
	check("增益 lists the field kits", buy_k != null and not buy_k.disabled)
	if buy_k != null:
		buy_k.pressed.emit()
		await step(1)
		check("and buys one", game.base.kit_stock("dust_mask") == 1)
		check("ticked to go along", game.kit_on("dust_mask", "mine"))
		var toggle: Button = _find(game.menu, func(n): return n is Button and n.get_meta("kit", "") == "dust_mask")
		var found := toggle != null
		if found: toggle.pressed.emit()
		await step(1)
		check("its tick turns it off", found and not game.kit_on("dust_mask", "mine"))
	game.close_modal()

## The button `action` in the 增益 row whose title starts with `title`.
func _row_button(title: String, action: String) -> Button:
	# Lambdas capture locals by value: collect into an array.
	var out: Array = []
	_walk(game.menu, func(n):
		if not (n is Label and n.text.begins_with(title)): return
		for c in n.get_parent().get_children():
			if c is Button and c.text == action: out.append(c))
	return out[0] if not out.is_empty() else null

func _find(root_node: Node, pred: Callable) -> Node:
	if pred.call(root_node): return root_node
	for c in root_node.get_children():
		var f := _find(c, pred)
		if f != null: return f
	return null

func _walk(n: Node, fn: Callable) -> void:
	fn.call(n)
	for c in n.get_children(): _walk(c, fn)
