class_name WarehouseView
extends Node

## The warehouse drawn from GameManager.base (基地玩法策划案_v1_0.md §3.3–3.6),
## in models since B-M2 (基地建模改造案_v1):
##   - the cells on each rack's face, filled by the items of its kind;
##   - the order board's state: open, completed, or empty (§3.8).
## 仓库修订 (用户 2026-10-23) took the crates, staging, the floor frames and
## carrying away: the room is for show, and nothing in it takes the E key.
##
## Everything is redrawn when the base changes, detected by a cheap signature
## each frame, so any code path that moves an item shows up without extra hooks.

const ROOM := "warehouse"
const CATEGORY_KEYS := ["weapon", "armor", "trinket", "material"]
const CRATE_REACH := 1.8        # units from a crate's feet
const RECEIVING_MARGIN := 1.5   # around the bays, for setting a carried item back down
const HAND_LIFT_PX := 33.0      # icon frame's bottom edge above her feet (her head is ~29 px up)
const PALLET_DECK := 0.2        # a crate's bottom on a pallet's deck (m)
## The order board's screen, by state (board_state): colour and brightness.
const BOARD_LOOK := {"open": Color(0.35, 0.85, 1.0), "completed": Color(0.45, 1.0, 0.55), "empty": Color(0.12, 0.2, 0.24)}
## A zone frame's depth and one rack column's width (anchors.zones / zone_decals).
const ZONE_DEPTH := 3.46
const ZONE_COLUMN := 5.73

var game: GameManager
var map: BaseMap
var anchors := {}
var tex := {}                   # runtime textures exported with the room, by name
var cells := []                 # rack-face cell positions, px in an 80x64 rack image
var _crates: Array[MeshInstance3D] = []
var _pallet_loads: Array[MeshInstance3D] = []
var _zone_lights := {}          # category -> [MeshInstance3D]
var _zone_frames := {}          # category -> [MeshInstance3D], one per rack column
var _cell_layers := {}          # category -> [[MeshInstance3D] x 12], built order (west to east)
var _hand_icon: Sprite3D
var drone: SortDrone
var _racks_seen := {}           # category -> racks already given colliders
var _board: MeshInstance3D      # the board's frame on the north wall
var _board_screen: MeshInstance3D
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
		map.add_model(ROOM, "pallet", p[0], p[1])
		_pallet_loads.append(map.add_model(ROOM, "crate_medium_open", p[0], p[1], 0.0, PALLET_DECK))
	# The receiving bays and the staging area, framed on the deck.
	for bay in anchors.bays: map.add_model(ROOM, "floor_frame", bay[0], bay[1])
	var staging: Array = anchors.staging
	var frame := map.add_model(ROOM, "floor_frame", (staging[0] + staging[2]) * 0.5, (staging[1] + staging[3]) * 0.5)
	frame.scale = Vector3(absf(staging[2] - staging[0]) / 2.4, 1.0, absf(staging[3] - staging[1]) / 2.4)
	for c in range(CATEGORY_KEYS.size()):
		var key: String = CATEGORY_KEYS[c]
		_zone_lights[c] = []
		_zone_frames[c] = []
		# The zone frame is laid one column at a time: it reaches as far as the
		# racks do (用户 2026-10-07), and the lit one sits a hair above it.
		for p in anchors.zone_decals[key]:
			var centre_z: float = p[1] + ZONE_DEPTH * 0.5
			var plain := map.add_model(ROOM, "zone_frame", p[0], centre_z)
			plain.scale = Vector3(ZONE_COLUMN / 5.6, 1.0, ZONE_DEPTH / 3.2)
			_zone_frames[c].append(plain)
			var lit := map.add_model(ROOM, "zone_frame_glow", p[0], centre_z, 0.0, 0.004)
			lit.scale = plain.scale
			_zone_lights[c].append(lit)
		# The front row's racks carry the cells, west to east.
		var layers: Array = []
		var racks: Dictionary = map.room_visuals[ROOM].racks
		var groups: Array = racks.keys().filter(func(g): return str(g).begins_with("shelf:%s:" % key) and not racks[g].cells.is_empty())
		groups.sort_custom(func(a, b): return racks[a].node.position.x * BaseMap.EAST < racks[b].node.position.x * BaseMap.EAST)
		for g in groups: layers.append(racks[g].cells)
		_cell_layers[c] = layers
	# The board hangs on the north wall, its screen drawn in the board's state.
	if anchors.has("order_board"):
		_board = map.add_model(ROOM, "order_board", anchors.order_board[0], anchors.order_board[1] - 0.12)
		_board_screen = MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(3.7, 1.8)
		_board_screen.mesh = quad
		# Faces south, the quad's front, just proud of the frame.
		_board_screen.position = Vector3(0, 2.5, -0.1)
		_board_screen.rotation.y = PI
		var screen := StandardMaterial3D.new()
		screen.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_board_screen.material_override = screen
		_board.add_child(_board_screen)
	drone = SortDrone.new()
	add_child(drone)
	drone.setup(map)
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
	_hand_icon.visible = false

func refresh() -> void:
	if not ready(): return
	var base: BaseState = game.base
	_signature = _signature_of(base) + board_state()
	if _board:
		_board.set_meta("state", board_state())
		(_board_screen.material_override as StandardMaterial3D).albedo_color = BOARD_LOOK[board_state()]
	for k in range(_pallet_loads.size()): _pallet_loads[k].visible = false
	# Newly built racks: shown by the reveal, given a footprint the first time they appear.
	_sync_racks(base)
	# Rack faces: cells fill west rack first, left to right, front to back.
	for c in _cell_layers:
		var count := _kind_count(base, c)
		for r in range(_cell_layers[c].size()):
			var filled := clampi(count - r * base.rack_cells(), 0, base.rack_cells())
			var cells: Array = _cell_layers[c][r]
			for k in range(cells.size()): cells[k].visible = k < filled
	for c in _zone_lights:
		for k in range(_zone_frames[c].size()): _zone_frames[c][k].visible = false
		for k in range(_zone_lights[c].size()): _zone_lights[c][k].visible = false

## Items of a rack zone's kind (Item.group_of), for its racks' faces.
static func _kind_count(base: BaseState, category: int) -> int:
	return base.shelf.filter(func(x): return Item.group_of(x.category) == category).size()

func _sync_racks(base: BaseState) -> void:
	var changed := false
	for c in range(CATEGORY_KEYS.size()):
		var built := int(base.racks[c])
		var seen := int(_racks_seen.get(c, 1))   # slot 0 is exported with its collider
		for slot in range(seen, built):
			var rack: Dictionary = map.room_visuals[ROOM].racks.get("shelf:%s:%d" % [CATEGORY_KEYS[c], slot], {})
			if rack.is_empty(): continue
			var at: Vector3 = rack.at
			var x := at.x * BaseMap.EAST
			map.add_runtime_collider(x - BaseMap.RACK_WIDTH * 0.5, at.z - 0.65, x + BaseMap.RACK_WIDTH * 0.5, at.z + 0.65)
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

## Nothing in the warehouse room takes the E key any more (仓库修订).
func target_at(_global: Vector3) -> Dictionary:
	return {}

## Rack columns built in a zone: the front row fills first, left to right
## (assemble_function_rooms.py slot order), so it is the rack count up to three.
func zone_columns(category: int) -> int:
	return clampi(int(game.base.racks[category]), 1, 3)

## The zone's floor frame, [x0, z_south, x1, z_north], cut to its built columns.
func zone_rect(category: int) -> Array:
	var full: Array = anchors.zones[CATEGORY_KEYS[category]]
	var decals: Array = anchors.zone_decals[CATEGORY_KEYS[category]]
	var last: Array = decals[zone_columns(category) - 1]
	var half := float(full[2]) - float(decals[2][0])   # the third frame's east edge past its centre
	return [full[0], full[1], minf(float(full[2]), float(last[0]) + half), full[3]]

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
	for c in base.racks: parts.append("%d:%d/%d" % [c, _kind_count(base, c), base.racks[c]])
	return ",".join(parts)

func _hand_texture(category: int) -> Texture2D:
	# A slot's piece (a ring, a helmet) carries its group's icon (8 slots).
	category = Item.group_of(category)
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
