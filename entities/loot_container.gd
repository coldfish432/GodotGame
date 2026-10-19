class_name LootContainer
extends Node3D

## A point of interest (掉落物策划案 §4): a weapon box, a construction pile, an
## ore vein … E nearby opens it at once and shows the pack beside the box's own
## grid (用户 2026-10-13: 打开兴趣点时同时打开背包和兴趣点容器界面，容器内物品
## 需搜索读条，打开容器不需要读条). While that window is open its contents are
## searched one item at a time, each with its own bar (塔科夫's search), and
## each item found lands in the box's grid, to be dragged or Ctrl+clicked into
## the pack. Closing the window pauses the search; E again picks it up at the
## item it was on. Vault chests stay sealed until the guardians fall. No text
## over the box (用户 2026-10-12); a yellow rim while she is near one she can
## still use (用户 2026-10-13).

const REACH := 2.4
## The box's own grid, in pack cells.
const GRID := Vector2i(6, 5)
## How near she must be for the rim to show.
const RIM_REACH := 4.0
const RIM_SHADER := preload("res://world/interact_outline.gdshader")

var game: GameManager
var kind := "construction"
var guarded := false
var sealed := false
var opened := false
var vault := false
## 巨壳藤蔓 hides in it: opening wakes the vine instead (装备扩充策划案 §2.1).
var mimic := false
## What has been found and not yet taken.
var storage := ItemContainer.new(GRID.x, GRID.y)
## Contents still to be found, laid out in the box's grid when the lid comes
## up (each keeps its cell in grid_x/grid_y, -1 when it did not fit) and found
## from the top left to the bottom right, in place (塔科夫's search); and the
## search on the first of them: seconds done, -1 while paused or not started.
var _pending: Array[Item] = []
var _found := 0
var _search := -1.0
var _search_done := 0.0
var _mesh: MeshInstance3D
## A context variant of `kind` (兴趣点策划案_v1.md §3): same loot, dressed
## for where the map put it. "" = the kind's own model.
var variant := ""
var _model: MeshInstance3D
var _model_materials: Array[ShaderMaterial] = []
var _rim: ShaderMaterial
var _rim_on := false

## Models from tools/blender/kit/build_poi.py, by kind, variant or vault.
const MODELS := {
	"weapon_box": "res://art/kit/poi_weapon_box.glb", "armor_box": "res://art/kit/poi_armor_box.glb",
	"tool_box": "res://art/kit/poi_tool_box.glb", "safe": "res://art/kit/poi_safe.glb",
	"electronics": "res://art/kit/poi_electronics.glb", "medical": "res://art/kit/poi_medical.glb",
	"construction": "res://art/kit/poi_construction.glb", "ore_vein": "res://art/kit/poi_ore_vein.glb",
	"vault": "res://art/kit/poi_vault_chest.glb", "camp": "res://art/kit/poi_camp.glb",
	"ore_cart": "res://art/kit/poi_ore_cart.glb", "miner_locker": "res://art/kit/poi_miner_locker.glb",
	"winch_box": "res://art/kit/poi_winch_box.glb", "miner_pack": "res://art/kit/poi_miner_pack.glb",
	"depot": "res://art/kit/poi_depot.glb",
}
const MODEL_SCALE := 1.35
const VARIANT_NAMES := {"ore_cart": "翻倒的源石矿车", "miner_locker": "矿工储物柜", "winch_box": "绞车控制箱", "miner_pack": "遗留的矿工背包"}

func _ready() -> void:
	add_to_group("loot_containers")
	add_to_group("search_points")
	var model_key := "vault" if vault else (variant if not variant.is_empty() else kind)
	if MODELS.has(model_key):
		_model = MeshInstance3D.new()
		_model.name = "Model"
		_model.mesh = TerraceDressing.kit_mesh(load(MODELS[model_key]))
		add_child(_model)
		_model.rotation.y = randf_range(-0.35, 0.35)
		# Read from the follow camera at a glance, a bit larger than life.
		_model.scale = Vector3.ONE * MODEL_SCALE
		# Its own copies of the materials, so opening this one dims only it.
		for surface in range(_model.mesh.get_surface_count()):
			var material := (_model.mesh.surface_get_material(surface) as ShaderMaterial).duplicate() as ShaderMaterial
			_model.set_surface_override_material(surface, material)
			_model_materials.append(material)
		_settle_model.call_deferred()
		var bounds := _model.mesh.get_aabb()
		_rim = ShaderMaterial.new()
		_rim.shader = RIM_SHADER
		_rim.set_shader_parameter("centre", bounds.get_center())
		_rim.set_shader_parameter("grow", 0.045 / MODEL_SCALE)
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.25, 0.8, 0.85) if not kind in ["ore_vein", "camp"] else Vector3(1.3, 0.9, 1.3)
	_mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color()
	_mesh.material_override = material
	_mesh.position.y = 0.1
	add_child(_mesh)
	# The placeholder box only stands in for kinds without a model (city depots, snow camps).
	_mesh.visible = _model == null
	if _model == null:
		_rim = ShaderMaterial.new()
		_rim.shader = RIM_SHADER
		_rim.set_shader_parameter("centre", Vector3.ZERO)
		_rim.set_shader_parameter("grow", 0.05)
	_refresh()

## Stand the model on the ground under the point (the point floats 0.5 above it).
func _settle_model() -> void:
	# Deferred: the field may have been cleared and this box taken out meanwhile.
	if not is_inside_tree() or not is_instance_valid(_model) or not is_instance_valid(game): return
	_model.global_position.y = game.ground_y(global_position)

func title() -> String:
	if VARIANT_NAMES.has(variant): return str(VARIANT_NAMES[variant])
	if vault: return {"vault_weapon": "密室武器箱", "vault_gear": "密室装备箱", "vault_base": "密室物资箱"}.get(kind, "密室宝箱")
	return str(LootTables.POI.get(kind, {}).get("name", "补给点"))

func color() -> Color:
	if vault: return Color("c9a43a")
	return LootTables.POI.get(kind, {}).get("color", Color("827357"))

## Name and state, as the HUD draws it over the box.
func status_text() -> String:
	var text := title()
	if sealed: text += " · 封印中"
	elif looted(): text += "（已搜空）"
	else: text += " [E]"
	return text

## Opening takes no time any more (用户 2026-10-13); kept for the HUD: -1.
func progress() -> float:
	return -1.0

## The search, for tests and sims: {"current": 0..1 on the item being searched
## (-1 when paused), "found": items already out, "total": all of them}, or {}
## before the lid is open or once everything is out.
func search_state() -> Dictionary:
	if not opened or _pending.is_empty(): return {}
	return {"current": _search / _search_done if _search >= 0.0 else -1.0, "found": _found, "total": _found + _pending.size()}

## Every item found (or never searched — opened directly).
func fully_searched() -> bool:
	return opened and _pending.is_empty()

## Searched to the end and everything taken out: nothing left to come for.
func looted() -> bool:
	return fully_searched() and storage.items.is_empty()

## Still worth E: not sealed, and something left to find or take.
func can_use() -> bool:
	return not sealed and not looted()

func is_searching() -> bool:
	return _search >= 0.0

func _refresh() -> void:
	(_mesh.material_override as StandardMaterial3D).albedo_color = color().darkened(0.55) if looted() else color()
	# Emptied: dimmed, the way a looted container reads in 塔科夫 by its open lid.
	for material in _model_materials:
		material.set_shader_parameter("gain", 0.45 if looted() else (1.6 if material.shader == TerraceDressing.GLOW_SHADER else 1.0))
	if looted(): _set_rim(false)

func _set_rim(on: bool) -> void:
	if on == _rim_on or _rim == null: return
	_rim_on = on
	for material in _model_materials: material.next_pass = _rim if on else null
	(_mesh.material_override as StandardMaterial3D).next_pass = _rim if on and _model == null else null

## The vault guardians fell.
func unseal() -> void:
	sealed = false
	_refresh()

func can_open() -> bool:
	return not opened and not sealed

## E on an opened box with items left takes the search up again.
func can_resume() -> bool:
	return opened and not _pending.is_empty() and _search < 0.0

func is_channeling() -> bool:
	return _search >= 0.0

## E nearby: lifts the lid at once the first time (rolling its contents, or
## waking a 巨壳藤蔓), and starts or resumes the search. GameManager opens the
## window with it; false when there is nothing to open.
func begin_open() -> bool:
	if not is_instance_valid(game) or sealed or looted(): return false
	if not opened:
		opened = true
		var contents = game.container_contents(self)
		if contents == null:
			_refresh()
			return false
		_pending = lay_out(contents)
		_found = 0
	if can_resume(): _begin_item()
	_refresh()
	return true

## The window closed: the item being searched keeps no partial progress; what
## is found stays in the box.
func cancel(_reason: String) -> void:
	if _search < 0.0: return
	_search = -1.0
	_refresh()

func _process(delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.player): return
	# The rim while she walks by one still worth opening.
	_set_rim(can_use() and game.simulation_active() and not game.hands_busy() and game.player.global_position.distance_to(global_position) <= RIM_REACH)
	# Searched only while its window is open; the field runs on meanwhile.
	if _search < 0.0 or game.looting != self: return
	_search += delta
	if _search >= _search_done:
		var item: Item = _pending.pop_front()
		_found += 1
		game.drop_found(self, item, _found, _found + _pending.size())
		if _pending.is_empty():
			_search = -1.0
			_refresh()
		else:
			_begin_item()

func _begin_item() -> void:
	_search = 0.0
	_search_done = search_seconds(_pending[0])

## The cell the search is on (the next item's top left), for the grid's
## magnifier; (-1, -1) when nothing is being searched.
func search_cell() -> Vector2i:
	if _search < 0.0 or _pending.is_empty(): return Vector2i(-1, -1)
	var next: Item = _pending[0]
	if next.grid_x < 0: return Vector2i(-1, -1)
	return Vector2i(next.grid_x, next.grid_y)

## The cells each item still to be found will take (用户 2026-10-17: 搜索时先把
## 物体所占的格子的轮廓勾勒出来); items that spilled past the grid have none.
func pending_rects() -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	if not opened: return out
	for item in _pending:
		if item.grid_x >= 0: out.append(Rect2i(item.grid_x, item.grid_y, item.width, item.height))
	return out

## Gives every item a cell in the box's grid (big ones first, the way a
## packed box holds them), then orders the search by reading order: row by
## row from the top left. What does not fit is found last.
static func lay_out(items: Array[Item]) -> Array[Item]:
	var plan := ItemContainer.new(GRID.x, GRID.y)
	var by_size := items.duplicate()
	by_size.sort_custom(func(a: Item, b: Item) -> bool: return a.width * a.height > b.width * b.height)
	var spilled: Array[Item] = []
	for item: Item in by_size:
		if not plan.try_add(item):
			item.grid_x = -1
			item.grid_y = -1
			spilled.append(item)
	var placed: Array[Item] = plan.items.duplicate()
	placed.sort_custom(func(a: Item, b: Item) -> bool: return a.grid_y < b.grid_y or (a.grid_y == b.grid_y and a.grid_x < b.grid_x))
	placed.append_array(spilled)
	return placed

## How long one item takes to find: quick for 赤金 and materials, longer the
## rarer the equipment (塔科夫's search scales with what turns up).
static func search_seconds(item: Item) -> float:
	if item.material_id == Economy.GOLD_ID: return 0.5
	if item.category == Item.Category.MATERIAL: return 0.7
	return [1.0, 1.6, 2.4][clampi(item.rarity, 0, 2)]

## Rolls the contents and spills them all at once (tests, and anything that
## opens a box without searching it).
func open_now() -> void:
	if opened: return
	opened = true
	_refresh()
	if is_instance_valid(game): game.on_container_opened(self)
