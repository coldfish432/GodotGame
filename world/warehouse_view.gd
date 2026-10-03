class_name WarehouseView
extends Node

## The warehouse drawn from GameManager.base (基地玩法策划案_v1_0.md §3.3–3.6):
##   - one crate per item at receiving, sealed or open, sized by the item
##     (bays R01-R06 first, then stacked along the south wall);
##   - staging pallets that fill up in four steps;
##   - the cells on each rack's face, filled as items are shelved;
##   - a zone's floor frame lights up while she carries something that belongs there;
##   - the carried item's icon over Lappland's head;
##   - the order board's state: open, completed, or empty (§3.8).
## It also answers what she is standing at (target_at), for the E key.
##
## Everything is redrawn when the base changes, detected by a cheap signature
## each frame, so any code path that moves an item shows up without extra hooks.

const ROOM := "warehouse"
const CATEGORY_KEYS := ["weapon", "armor", "trinket", "material"]
const CRATE_REACH := 1.8        # units from a crate's feet
const RECEIVING_MARGIN := 1.5   # around the bays, for setting a carried item back down
const HAND_LIFT_PX := 33.0      # icon frame's bottom edge above her feet (her head is ~29 px up)
const PALLET_LIFT_PX := 7.0     # a crate's bottom on a pallet's deck

var game: GameManager
var map: BaseMap
var anchors := {}
var tex := {}                   # runtime textures exported with the room, by name
var cells := []                 # rack-face cell positions, px in an 80x64 rack image
var _crates: Array[Sprite3D] = []
var _pallet_loads: Array[Sprite3D] = []
var _zone_lights := {}          # category -> [MeshInstance3D]
var _cell_layers := {}          # category -> [Sprite3D], built order (west to east)
var _cell_textures: Array[Texture2D] = []  # by filled count 0..12
var _hand_icon: Sprite3D
var drone: SortDrone
var _racks_seen := {}           # category -> racks already given colliders
var _board: Sprite3D
var _board_lift := 0.0
var _hand_textures := {}
var _signature := ""

func setup(p_game: GameManager, p_map: BaseMap) -> void:
	game = p_game
	map = p_map
	var room: Dictionary = map.rooms[ROOM]
	anchors = room.get("anchors", {})
	cells = room.get("cells", [])
	for name in room.get("textures", {}):
		tex[name] = map.texture_at(room.textures[name])
	if anchors.is_empty() or tex.is_empty(): return
	for p in anchors.pallets:
		map.add_prop(ROOM, tex.pallet, p[0], p[1])
		_pallet_loads.append(map.add_prop(ROOM, tex.crate_medium_open, p[0], p[1] - 0.01, PALLET_LIFT_PX))  # just south: sorts over the pallet
	for c in range(CATEGORY_KEYS.size()):
		var key: String = CATEGORY_KEYS[c]
		_zone_lights[c] = []
		for p in anchors.zone_decals[key]:
			var decal := map.add_floor_decal(ROOM, tex["zone_%s_highlight" % key], p[0], p[1])
			decal.position.y += 0.001  # over the frame baked into the floor
			_zone_lights[c].append(decal)
		var layers: Array = []
		for group in map.room_visuals[ROOM].groups:
			if str(group).begins_with("shelf:%s:" % key):
				layers.append_array(map.room_visuals[ROOM].groups[group].filter(func(s): return s.get_meta("role", "") == "cells"))
		layers.sort_custom(func(a, b): return a.position.x * BaseMap.EAST < b.position.x * BaseMap.EAST)
		_cell_layers[c] = layers
	for filled in range(BaseCatalog.RACK_CELLS + 1): _cell_textures.append(_cells_texture(filled))
	# The board hangs on the north wall: drawn over the facade's copy, a hair south of the wall line.
	_board_lift = float(room.get("board_lift", 0))
	if anchors.has("order_board"):
		_board = map.add_prop(ROOM, tex.board_open, anchors.order_board[0], anchors.order_board[1] - 0.02, _board_lift)
	if tex.has("cargo_drone"):
		drone = SortDrone.new()
		add_child(drone)
		drone.setup(map, tex.cargo_drone)
	if map.warehouse_reveal:
		map.warehouse_reveal.built_check = func(category: String, slot: int) -> bool:
			return slot < int(game.base.racks[CATEGORY_KEYS.find(category)])
		map.warehouse_reveal.refresh_built()  # until now the reveal treated every slot as built
	_hand_icon = map.add_prop(ROOM, tex.carried_frame, 0, 0, HAND_LIFT_PX)
	_hand_icon.visible = false
	_hand_icon.no_depth_test = true  # always over her and whatever she walks behind
	_hand_icon.render_priority = 10
	refresh()

func ready() -> bool: return not anchors.is_empty() and not tex.is_empty()

func _process(_delta: float) -> void:
	if not ready() or not is_instance_valid(game): return
	var signature := _signature_of(game.base) + board_state()
	if signature != _signature: refresh()
	var hand: Item = game.base.hand
	_hand_icon.visible = hand != null and game.in_base
	if _hand_icon.visible:
		var p := _layout(game.player.global_position)
		map.place_billboard(_hand_icon, p.x, p.y, HAND_LIFT_PX)
		_hand_icon.modulate = Color.WHITE

func refresh() -> void:
	if not ready(): return
	var base: BaseState = game.base
	_signature = _signature_of(base) + board_state()
	if _board: _board.texture = tex["board_" + board_state()]
	# Receiving crates.
	for sprite in _crates: map.remove_prop(ROOM, sprite)
	_crates.clear()
	var spots: Array = anchors.bays + anchors.overflow
	for i in range(mini(base.crates.size(), spots.size())):
		var crate: Dictionary = base.crates[i]
		var look := "crate_%s_%s" % [BaseCatalog.CRATE_SIZES[BaseCatalog.crate_size(crate.item)], "open" if crate.opened else "sealed"]
		var sprite := map.add_prop(ROOM, tex[look], spots[i][0], spots[i][1])
		sprite.set_meta("item", crate.item)
		_crates.append(sprite)
	# Staging: four pallets, one more loaded per quarter of capacity in use.
	var quarter := BaseCatalog.STAGING_CAPACITY / 4.0
	for k in range(_pallet_loads.size()):
		_pallet_loads[k].visible = base.staging.size() > k * quarter
	# Newly built racks: shown by the reveal, given a footprint the first time they appear.
	_sync_racks(base)
	# Rack faces: cells fill west rack first, left to right, front to back.
	for c in _cell_layers:
		var count := base.shelf_count(c)
		for r in range(_cell_layers[c].size()):
			var filled := clampi(count - r * BaseCatalog.RACK_CELLS, 0, BaseCatalog.RACK_CELLS)
			_cell_layers[c][r].texture = _cell_textures[filled]
	# Zone frames light up for the category she is carrying.
	for c in _zone_lights:
		for decal in _zone_lights[c]: decal.visible = base.hand != null and base.hand.category == c
	if base.hand: _hand_icon.texture = _hand_texture(base.hand.category)

func _sync_racks(base: BaseState) -> void:
	var changed := false
	for c in range(CATEGORY_KEYS.size()):
		var built := int(base.racks[c])
		var seen := int(_racks_seen.get(c, 1))   # slot 0 is exported with its collider
		for slot in range(seen, built):
			for sprite: Sprite3D in map.room_visuals[ROOM].groups.get("shelf:%s:%d" % [CATEGORY_KEYS[c], slot], []):
				if sprite.get_meta("role", "") != "rack": continue
				var x := sprite.position.x * BaseMap.EAST
				var w := sprite.texture.get_width() / 15.0 * 0.8
				map.add_runtime_collider(x - w * 0.5, sprite.position.z - 0.65, x + w * 0.5, sprite.position.z + 0.65)
		if built != seen: changed = true
		_racks_seen[c] = built
	if changed and map.warehouse_reveal: map.warehouse_reveal.refresh_built()

## The drone's route after a sort: receiving, then the zones that got something.
func fly_drone(categories: Array) -> void:
	if drone == null or categories.is_empty(): return
	var start := Vector2(anchors.bays[1][0], anchors.bays[1][1] + 2.0)
	var stops: Array[Vector2] = []
	for c in categories:
		var zone: Array = anchors.zones[CATEGORY_KEYS[c]]
		stops.append(Vector2((zone[0] + zone[2]) * 0.5, zone[3]))
	drone.fly(start, stops)

## "open" while an order can be filled from what she has, "completed" while a
## finished order waits for the next refresh, "open" for orders she cannot fill
## yet, "empty" when the board has nothing.
func board_state() -> String:
	var orders: OrderBoard = game.base.orders
	if orders_fillable(): return "open"
	if orders.slots.any(func(o): return o != null and o.state == "done"): return "completed"
	return "open" if not orders.open_orders().is_empty() else "empty"

## Whether some open order can be filled from the shelves or the pack right now.
func orders_fillable() -> bool:
	var orders: OrderBoard = game.base.orders
	var deliverable := game.deliverable_items()
	for i in range(orders.slots.size()):
		var order = orders.slots[i]
		if order != null and order.state == "open" and deliverable.any(func(x): return orders.matches(i, x)): return true
	return false

## What Lappland is standing at, for the E key: {kind, label, ...} or {}.
##   crate    a crate within reach: open it, or look at what is in it
##   zone     a category's shelving area, while carrying something
##   staging  the staging area: put the carried item down, or take one out
##   putback  receiving, while carrying: put it back in a crate
func target_at(global: Vector3) -> Dictionary:
	if not ready(): return {}
	var base: BaseState = game.base
	var p := _layout(global)
	if base.hand != null:
		for c in range(CATEGORY_KEYS.size()):
			if _inside(p, anchors.zones[CATEGORY_KEYS[c]]):
				var refusal := base.shelve_hand_refusal(c)
				var zone: String = BaseCatalog.CATEGORY_NAMES[c]
				return {"kind": "zone", "category": c,
					"label": ("上架到%s区（%d/%d）" % [zone, base.shelf_count(c), base.capacity(c)]) if refusal.is_empty() else ("%s区：%s" % [zone, "放不下" if c == base.hand.category else "类别不对"])}
		if _inside(p, anchors.staging):
			return {"kind": "staging", "label": "放进暂存区（%d/%d）" % [base.staging.size(), BaseCatalog.STAGING_CAPACITY]}
		if _near_receiving(p):
			return {"kind": "putback", "label": "把 %s 放回货箱" % base.hand.item_name}
		return {}
	var best: Sprite3D = null
	var best_distance := CRATE_REACH
	for sprite in _crates:
		var d := Vector2(sprite.position.x * BaseMap.EAST, sprite.position.z).distance_to(p)
		if d < best_distance:
			best_distance = d
			best = sprite
	if best:
		var item: Item = best.get_meta("item")
		var sealed := base.location_of(item) == "crate_sealed"
		return {"kind": "crate", "item": item,
			"label": ("开箱（%s箱）" % BaseCatalog.CRATE_SIZE_NAMES[BaseCatalog.crate_size(item)]) if sealed else ("查看 %s" % item.item_name)}
	if _inside(p, anchors.staging):
		return {"kind": "staging", "label": "暂存区（%d/%d）" % [base.staging.size(), BaseCatalog.STAGING_CAPACITY]}
	return {}

## Layout position (x east, z north) of a global position.
func _layout(global: Vector3) -> Vector2:
	return Vector2((global.x - BaseMap.ORIGIN.x) / BaseMap.EAST, global.z - BaseMap.ORIGIN.z)

## rect = [x0, z_south, x1, z_north] in layout units.
static func _inside(p: Vector2, rect: Array) -> bool:
	return p.x >= rect[0] and p.x <= rect[2] and p.y >= rect[1] and p.y <= rect[3]

func _near_receiving(p: Vector2) -> bool:
	var xs: Array = anchors.bays.map(func(b): return b[0])
	var zs: Array = anchors.bays.map(func(b): return b[1])
	return p.x >= xs.min() - RECEIVING_MARGIN - 1.5 and p.x <= xs.max() + RECEIVING_MARGIN + 1.5 \
		and p.y >= zs.min() - RECEIVING_MARGIN and p.y <= zs.max() + RECEIVING_MARGIN + 2.5

static func _signature_of(base: BaseState) -> String:
	var parts: Array[String] = []
	for crate in base.crates: parts.append("%s%s" % [crate.item.uid, "o" if crate.opened else "s"])
	parts.append("|%d|%s|" % [base.staging.size(), base.hand.uid if base.hand else ""])
	for c in base.racks: parts.append("%d:%d/%d" % [c, base.shelf_count(c), base.racks[c]])
	return ",".join(parts)

func _cells_texture(filled: int) -> Texture2D:
	var image := Image.create(80, 64, false, Image.FORMAT_RGBA8)
	var empty := _rgba(tex.slot_empty)
	var full := _rgba(tex.slot_filled)
	for k in range(cells.size()):
		var src: Image = full if k < filled else empty
		image.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(cells[k][0], cells[k][1]))
	return ImageTexture.create_from_image(image)

func _hand_texture(category: int) -> Texture2D:
	if _hand_textures.has(category): return _hand_textures[category]
	var image := _rgba(tex.carried_frame)
	var icon := _rgba(tex["icon_" + CATEGORY_KEYS[category]])
	image.blend_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), Vector2i(4, 4))
	_hand_textures[category] = ImageTexture.create_from_image(image)
	return _hand_textures[category]

## blend_rect needs both images in the same format.
static func _rgba(texture: Texture2D) -> Image:
	var image := texture.get_image().duplicate()
	image.convert(Image.FORMAT_RGBA8)
	return image
