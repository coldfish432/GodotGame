extends SceneTree

## 用户 2026-10-21: 整备台实现拖拽装备/拖入背包，所有物品转移都实现拖拽; the
## dispatch board picks the floors in the middle and goes on to 最终准备.

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
	game.fixed_map_seed = 4545
	root.add_child(game)
	await step(8)
	await _dispatch()
	await _workbench()
	await _depot()
	print("DRAG RESULT: %d checks, %d failures" % [checks, failures])
	game.queue_free()
	await step(2)
	quit(1 if failures else 0)

func _dispatch() -> void:
	game.base.camps["mine"] = 20
	game.open_station("contracts")
	await step(1)
	var tiles := _all(game.menu, func(n): return n is Button and str(n.get_meta("label", "")) in ["CH-01", game.camp_label(10), game.camp_label(20)])
	check("the floors are picked in the middle", tiles.size() == 3 and tiles.all(func(b): return b.global_position.x < 880), tiles.size())
	(tiles[2] as Button).pressed.emit()
	await step(1)
	check("a camp start shows its block's floors", _all(game.menu, func(n): return n is Label and n.text == "CH-21").size() == 1)
	var go: Button = _find(game.menu, func(n): return n is Button and str(n.get_meta("label", n.text)).begins_with("最终准备"))
	check("the button is 最终准备", go != null)
	go.pressed.emit()
	await step(1)
	check("and leads to the departure screen with that start", game._pending_start_camp == 20 and game.menu._screen != "station" or game._pending_start_camp == 20)
	game.close_modal()

func _workbench() -> void:
	var blade := Item.create("拖拽刀", Item.Category.WEAPON, 1, 2, 1.0)
	game.base.put_back(blade, "shelf")
	game.open_station("loadout")
	await step(1)
	var slot: LoadoutScreens.DollSlot = _find(game.menu, func(n): return n is LoadoutScreens.DollSlot and n.category == Item.Category.WEAPON)
	check("a weapon slot takes a dragged blade from the depot", slot != null and _drop(slot, blade))
	await step(1)
	check("dropping it wears it", game.player.equipped.values().has(blade) and not game.stash.has(blade))
	var pack: AK.BagGrid = _find(game.menu, func(n): return n is AK.BagGrid and n.container == game.inventory)
	check("the pack takes the worn blade", pack != null and _drop(pack, blade))
	await step(1)
	check("dropping it there takes it off into the pack", game.inventory.items.has(blade) and not game.player.equipped.values().has(blade))
	var safe: AK.BagGrid = _find(game.menu, func(n): return n is AK.BagGrid and n.container == game.safe_bag)
	if safe != null and safe.container.can_take(blade):
		_drop(safe, blade)
		await step(1)
		check("pack → safe bag by drag", game.safe_bag.items.has(blade))
	var depot: BaseScreens.FlowGrid = _find(game.menu, func(n): return n is BaseScreens.FlowGrid)
	check("the depot takes it back", depot != null and _drop(depot, blade))
	await step(1)
	check("dropping it there stores it", game.stash.has(blade) and not game.carried_items().has(blade))
	game.close_modal()

func _depot() -> void:
	var blade: Item = game.stash.filter(func(i): return i.item_name == "拖拽刀")[0]
	game.base.console = true
	game.menu.stash_tab = 0
	game.open_station("stash")
	await step(1)
	var zone: Control = _find(game.menu, func(n): return n.get_class() == "Control" and n.size == Vector2(932, 56))
	check("the carry-in row takes a shelf item", zone != null and _drop(zone, blade))
	await step(1)
	check("dropping it brings it", game.carried_items().has(blade))
	var grid: BaseScreens.FlowGrid = _find(game.menu, func(n): return n is BaseScreens.FlowGrid)
	check("the shelves take it back", grid != null and _drop(grid, blade))
	await step(1)
	check("dropping it stores it", game.stash.has(blade))
	game.close_modal()

## Drops `item` on `target` through its ItemDrag hooks; false if refused.
func _drop(target: Control, item: Item) -> bool:
	var data := ItemDrag.payload(item)
	var can: Callable = target.get_meta("drop_can", Callable())
	var take: Callable = target.get_meta("drop_take", Callable())
	if not can.is_valid() or not bool(can.call(Vector2.ZERO, data)): return false
	take.call(Vector2.ZERO, data)
	return true

func _find(n: Node, pred: Callable) -> Node:
	if pred.call(n): return n
	for c in n.get_children():
		var f := _find(c, pred)
		if f != null: return f
	return null

func _all(n: Node, pred: Callable) -> Array:
	var out: Array = []
	if pred.call(n): out.append(n)
	for c in n.get_children(): out += _all(c, pred)
	return out
