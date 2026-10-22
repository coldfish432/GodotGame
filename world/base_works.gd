class_name BaseWorks
extends Node

## The base's construction (基建设施修订案_v1_1.md §二–§三, 用户 2026-10-22):
## every facility part stands where it will be built, shown either as itself
## or, until its level (or link, or project) is reached, as a construction
## site of the shared kit — hazard tape round its footprint, barriers on three
## sides, tarp-covered crates, a work lamp. Each facility has a site terminal
## (build_post) where its upgrades are bought on the spot; the 基建总控台's own
## spot is the hub. Redrawn whenever what it shows changes.

## Site terminals: facility -> [room, layout x, z]. The hub's is in front of its console.
const POSTS := {
	"hub": ["hall", 104.0, -22.6],
	"warehouse": ["warehouse", -21.6, -18.4],
	"outfit": ["hall", 89.5, -11.6],
	"store": ["store", 5.0, 3.6],
	"workshop": ["workshop", -6.2, 3.4],
	"lab": ["lab", 131.6, -48.2],
	"exchange": ["hall", 40.6, -16.8],
	"farm": ["farm", 486.0, -18.6],
	"canteen": ["mess", 352.0, -19.0],
}

## Parts: [room, model, layout x, z, yaw°, when, footprint [w, d] (shown size,
## for the site and its collider; [] for one that needs no site), extra].
## `when` is "<facility>:<level>", "link:<facility>" or "project:<name>".
## extra: "decor" hides the room's own decor piece there instead of placing
## one; "wall" lifts it (y) onto a wall; "low" means no barriers (floor parts).
const PARTS := [
	# 基建总控台 and the trunks to each facility, lit as it is connected.
	["hall", "build_console", 104.0, -19.0, 0.0, "hub:1", [10.0, 5.0], {"tall": true}],
	["hall", "cable_trunk", 99.0, -16.0, 0.0, "link:warehouse", [], {}],
	["hall", "cable_trunk", 101.0, -16.0, 0.0, "link:outfit", [], {}],
	["hall", "cable_trunk", 103.0, -16.0, 0.0, "link:store", [], {}],
	["hall", "cable_trunk", 105.0, -16.0, 0.0, "link:workshop", [], {}],
	["hall", "cable_trunk", 107.0, -16.0, 0.0, "link:lab", [], {}],
	["hall", "cable_trunk", 109.0, -16.0, 0.0, "link:exchange", [], {}],
	["hall", "cable_trunk", 111.0, -16.0, 0.0, "link:farm", [], {}],
	["hall", "cable_trunk", 113.0, -16.0, 0.0, "link:canteen", [], {}],
	# 仓储部.
	["warehouse", "relay_cabinet", -19.6, -16.4, 0.0, "link:warehouse", [2.0, 1.2], {}],
	["warehouse", "drone_pad", -6.0, -41.4, 0.0, "warehouse:2", [4.6, 4.6], {"low": true}],
	["warehouse", "order_screen", -14.2, -8.4, 0.0, "warehouse:4", [3.0, 0.8], {"wall": 0.0}],
	# 整备部, by the 整备台.
	["hall", "relay_cabinet", 89.5, -9.0, 0.0, "link:outfit", [2.0, 1.2], {}],
	["hall", "pack_rig", 72.4, -4.4, 0.0, "outfit:2", [2.6, 1.6], {}],
	["hall", "secure_safe", 85.6, -8.6, 0.0, "outfit:3", [2.4, 1.8], {}],
	# 可露希尔商店: along the side walls, north of the hall wall (which hides
	# the store's southern strip from the camera), the door (x 6–9) and the
	# way to the counter left open.
	["store", "relay_cabinet", 16.8, 8.4, -90.0, "link:store", [1.2, 2.0], {}],
	["store", "closure_fridge", 16.6, 5.0, -90.0, "store:2", [1.4, 2.4], {}],
	["store", "goods_shelf", 1.2, 7.0, 90.0, "store:3", [0.8, 4.4], {}],
	["store", "display_case", 3.4, 4.2, 90.0, "store:4", [1.4, 4.4], {}],
	["store", "display_case_lock", 14.4, 4.2, 90.0, "store:5", [1.4, 4.4], {}],
	# 加工部: the second fabricator comes with Lv2.
	["workshop", "relay_cabinet", -3.4, 4.8, 0.0, "link:workshop", [2.0, 1.2], {}],
	["workshop", "fabricator", -23.0, 4.0, 0.0, "workshop:2", [7.0, 3.4], {"decor": true, "tall": true}],
	# 科研部: the research tree is the lab itself; the originium chamber the second slot.
	["lab", "relay_cabinet", 130.8, -44.0, 90.0, "link:lab", [1.2, 2.0], {}],
	["lab", "research_holo", 141.0, -46.6, 0.0, "lab:1", [6.0, 6.0], {"decor": true, "tall": true}],
	["lab", "originium_chamber", 152.6, -46.9, 0.0, "lab:2", [4.8, 4.8], {"decor": true, "tall": true}],
	# 交易所: the market wall and the post with Lv1, a trading desk a level.
	["hall", "relay_cabinet", 40.6, -14.2, 0.0, "link:exchange", [2.0, 1.2], {}],
	["hall", "trading_post", 25.5, -19.6, 0.0, "exchange:1", [8.0, 6.0], {"decor": true, "tall": true}],
	["hall", "trader_desk", 25.5, -9.8, 0.0, "exchange:1", [4.6, 1.6], {"decor": true}],
	["hall", "trader_desk", 16.0, -9.8, 0.0, "exchange:2", [4.6, 1.6], {"decor": true}],
	["hall", "trader_desk", 35.0, -9.8, 0.0, "exchange:3", [4.6, 1.6], {"decor": true}],
	["hall", "trader_desk", 16.0, -13.8, 0.0, "exchange:4", [4.6, 1.6], {"decor": true}],
	["hall", "trader_desk", 35.0, -13.8, 0.0, "exchange:5", [4.6, 1.6], {"decor": true}],
	# 农业部 (势力特供策划案 §四): three sun-lamp rooms; each level builds two
	# groups of six basins, a sun lamp with the first of its swirl
	# (BaseMap._farm_swirl draws the basins).
	["farm", "relay_cabinet", 492.6, -18.6, -90.0, "link:farm", [1.2, 2.0], {}],
	["farm", "sun_lamp", 461.0, -6.5, 0.0, "farm:1", [2.6, 2.6], {"tall": true}],
	["farm", "hydro_basin", 459.5, -2.0, 0.0, "farm:1", [10.5, 7.5], {"decor": true, "low": true, "group": 0}],
	["farm", "hydro_basin", 465.5, -5.0, 0.0, "farm:1", [7.5, 10.5], {"decor": true, "low": true, "group": 1}],
	["farm", "hydro_basin", 462.5, -11.0, 0.0, "farm:2", [10.5, 7.5], {"decor": true, "low": true, "group": 2}],
	["farm", "hydro_basin", 456.5, -8.0, 0.0, "farm:2", [7.5, 10.5], {"decor": true, "low": true, "group": 3}],
	["farm", "sun_lamp", 482.0, -6.5, 0.0, "farm:3", [2.6, 2.6], {"tall": true}],
	["farm", "hydro_basin", 480.5, -2.0, 0.0, "farm:3", [10.5, 7.5], {"decor": true, "low": true, "group": 4}],
	["farm", "hydro_basin", 486.5, -5.0, 0.0, "farm:3", [7.5, 10.5], {"decor": true, "low": true, "group": 5}],
	["farm", "hydro_basin", 483.5, -11.0, 0.0, "farm:4", [10.5, 7.5], {"decor": true, "low": true, "group": 6}],
	["farm", "hydro_basin", 477.5, -8.0, 0.0, "farm:4", [7.5, 10.5], {"decor": true, "low": true, "group": 7}],
	["farm", "sun_lamp", 476.0, -31.0, 0.0, "farm:5", [2.6, 2.6], {"tall": true}],
	["farm", "hydro_basin", 474.5, -26.5, 0.0, "farm:5", [10.5, 7.5], {"decor": true, "low": true, "group": 8}],
	["farm", "hydro_basin", 480.5, -29.5, 0.0, "farm:5", [7.5, 10.5], {"decor": true, "low": true, "group": 9}],
	["farm", "hydro_basin", 477.5, -35.5, 0.0, "farm:6", [10.5, 7.5], {"decor": true, "low": true, "group": 10}],
	["farm", "hydro_basin", 471.5, -32.5, 0.0, "farm:6", [7.5, 10.5], {"decor": true, "low": true, "group": 11}],
	# 食堂 (§五): the counter with Lv1; the kitchen's ranges (for show) with Lv1 and Lv3.
	["mess", "relay_cabinet", 366.0, -19.4, 0.0, "link:canteen", [2.0, 1.2], {}],
	["mess", "serving_counter", 349.0, -2.6, 0.0, "canteen:1", [10.0, 1.2], {}],
	["galley", "kitchen_range", 324.5, 9.0, 0.0, "canteen:1", [6.0, 1.4], {}],
	["galley", "kitchen_range", 333.5, 9.0, 0.0, "canteen:3", [6.0, 1.4], {}],
]
## Nodes the map builds beside a decor part, hidden with it (by name, nearest).
const DECOR_NODES := {"trading_post": ["QuoteRing", "MarketHologram", "MarketTicker"]}

var game: GameManager
var map: BaseMap
## Part index -> the pieces drawn for it now.
var _drawn := {}
## Part index -> the room's own decor piece it shows or hides.
var _decor := {}
var _decor_nodes := {}
var _shown := ""

func setup(p_game: GameManager, p_map: BaseMap) -> void:
	game = p_game
	map = p_map
	for i in range(PARTS.size()):
		var part: Array = PARTS[i]
		var extra: Dictionary = part[7]
		if extra.get("decor", false):
			_decor[i] = _find_decor(part[0], part[1], part[2], part[3])
			for name in DECOR_NODES.get(part[1], []): _decor_nodes[i] = _decor_nodes.get(i, []) + [_find_node(part[0], name)]
			if part[1] == "research_holo": _decor_nodes[i] = map.research_lights.values()
			if extra.has("group"): _decor_nodes[i] = map.farm_basins[int(extra.group)]
		elif not (part[6] as Array).is_empty() and not extra.get("low", false) and not extra.has("wall"):
			var foot: Array = part[6]
			map.add_runtime_collider(part[2] - foot[0] * 0.5, part[3] - foot[1] * 0.5, part[2] + foot[0] * 0.5, part[3] + foot[1] * 0.5)
	for id in POSTS:
		var spot: Array = POSTS[id]
		if not map.rooms.has(spot[0]): continue
		map.add_model(spot[0], "build_post", spot[1], spot[2] + 0.9)
		map.add_runtime_collider(spot[1] - 0.3, spot[2] + 0.6, spot[1] + 0.3, spot[2] + 1.2)
		map.interactables.append({"id": "site_" + id, "kind": "hub" if id == "hub" else "build_site", "facility": id,
			"label": BaseCatalog.facility_name(id), "room": spot[0], "position": map.to_world(spot[1], spot[2], BaseMap.PLAYER_Y)})
	refresh()

func _process(_delta: float) -> void:
	if is_instance_valid(game) and _signature() != _shown: refresh()

## What decides the drawing: facility levels, links and the projects.
func _signature() -> String:
	var base: BaseState = game.base
	return "%s|%s|%s%s" % [str(base.facilities), str(base.connected), base.console, base.drone]

## Whether part `i` is built.
func built(i: int) -> bool:
	var when: String = PARTS[i][5]
	var base: BaseState = game.base
	var what := when.get_slice(":", 0)
	var arg := when.get_slice(":", 1)
	match what:
		"link": return base.is_connected_to_hub(arg)
		"project": return bool(base.get(arg))
	return base.facility_level(what) >= int(arg)

func refresh() -> void:
	_shown = _signature()
	for i in range(PARTS.size()):
		var part: Array = PARTS[i]
		if not map.rooms.has(part[0]): continue
		var state := built(i)
		if _drawn.has(i) and bool(_drawn[i].state) == state: continue
		for piece in _drawn.get(i, {}).get("pieces", []):
			if is_instance_valid(piece): map.remove_model(part[0], piece)
		var pieces: Array = []
		var extra: Dictionary = part[7]
		if extra.get("decor", false):
			if is_instance_valid(_decor.get(i)): (_decor[i] as Node3D).visible = state
			for node in _decor_nodes.get(i, []):
				if is_instance_valid(node): node.visible = state
		elif state:
			pieces.append(map.add_model(part[0], part[1], part[2], part[3], deg_to_rad(part[4]), float(extra.get("wall", 0.0))))
		if not state and not (part[6] as Array).is_empty(): pieces.append_array(_site(part))
		_drawn[i] = {"state": state, "pieces": pieces}

## The construction kit round a part's footprint: tape, barriers on the north,
## west and east sides (open to the camera), crates under tarps, a lamp, and
## scaffolding round a tall one. Floor parts get tape and a crate only.
func _site(part: Array) -> Array:
	var room: String = part[0]
	var x: float = part[2]
	var z: float = part[3]
	var foot: Array = part[6]
	var w: float = foot[0]
	var d: float = foot[1]
	var extra: Dictionary = part[7]
	var out: Array = []
	# Tape: a 1 m strip stretched along each edge.
	for edge in [[x, z + d * 0.5, w, 0.0], [x, z - d * 0.5, w, 0.0], [x - w * 0.5, z, d, PI / 2.0], [x + w * 0.5, z, d, PI / 2.0]]:
		var strip := map.add_model(room, "build_tape", edge[0], edge[1], edge[3])
		strip.scale = Vector3(edge[2], 1.0, 1.0)
		out.append(strip)
	out.append(map.add_model(room, "build_crate_tarp", x - w * 0.18, z, deg_to_rad(8.0)))
	if w >= 3.0: out.append(map.add_model(room, "build_crate_tarp", x + w * 0.22, z + d * 0.1, deg_to_rad(-14.0)))
	if extra.get("low", false) or extra.has("wall"): return out
	# Barriers: 2 m sections along the north edge, then down the sides.
	var n := maxi(1, roundi(w / 2.0))
	for k in range(n):
		out.append(map.add_model(room, "build_barrier", x - w * 0.5 + (k + 0.5) * w / n, z + d * 0.5 + 0.2))
	var m := maxi(1, roundi(d / 2.0))
	for k in range(m):
		var bz := z + d * 0.5 - (k + 0.5) * d / m
		out.append(map.add_model(room, "build_barrier", x - w * 0.5 - 0.2, bz, PI / 2.0))
		out.append(map.add_model(room, "build_barrier", x + w * 0.5 + 0.2, bz, PI / 2.0))
	out.append(map.add_model(room, "build_cone", x - w * 0.5 + 0.3, z - d * 0.5 - 0.4))
	out.append(map.add_model(room, "build_cone", x + w * 0.5 - 0.3, z - d * 0.5 - 0.4))
	out.append(map.add_model(room, "build_lamp", x + w * 0.5 - 0.5, z + d * 0.5 - 0.5, deg_to_rad(-135.0)))
	if extra.get("tall", false): out.append(map.add_model(room, "build_scaffold", x, z + d * 0.25))
	return out

## The room's own decor piece `model` at layout (x, z).
func _find_decor(room: String, model: String, x: float, z: float) -> Node3D:
	var root := map.get_node_or_null(NodePath(room))
	if root == null: return null
	var at := Vector2(BaseMap.EAST * x, z)
	for child in root.get_children():
		if child is MeshInstance3D and child.get_meta("model", "") == model and Vector2(child.position.x, child.position.z).distance_to(at) < 0.5:
			return child
	return null

func _find_node(room: String, name: String) -> Node:
	var root := map.get_node_or_null(NodePath(room))
	return root.find_child(name, false, false) if root else null
