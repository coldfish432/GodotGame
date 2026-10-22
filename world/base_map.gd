class_name BaseMap
extends Node3D

## Rhodes Island home base: one continuous, walkable map, every room built
## from Blender kit pieces (基地建模改造案_v1; tools/blender/base). The layout,
## collision, stations and spawns still come from the rooms' exported data
## (art/rhodes_runtime/room_*.json, once the pixel assemblies'): each old
## pixel prop stands as its model (PROP_MODELS), walls are laid round each
## room's rectangle with doorways where its colliders leave gaps, and kit
## pieces cut a checkerboard hole round Lappland while they cover her.
## Markers and the carried icon stay billboards (base_markers, warehouse_view).
## The layout is authored with x growing east (screen right). With the game's
## camera, screen right is world -X, so every layout x is mirrored.
## The base sits far from the field origin so it never overlaps a field map.

const DATA_DIR := "res://art/rhodes_runtime/"
## The rooms round the hall (用户 2026-10-18: 加工部放在房间里，重新设计各房间
## 的位置布局): the west wing industrial (the warehouse, and 加工部 north of it,
## its door in the hall's west wall), the east the medical bay, the north
## corners the store and 人事部 (the old armory).
const ROOMS := ["hall", "warehouse", "workshop", "medical", "store", "armory", "lab",
	"deck2", "deck2_x", "farm", "farm2", "mess", "galley", "sealed_w", "sealed_nw", "sealed_ne", "sealed_n", "sealed_sw", "sealed_se"]
## The second deck (势力特供策划案_v0_2 §三; 用户 2026-10-22: 整体轮廓相同，
## 房间分隔不用一样，第二层不需要舰桥这个大片区域): the first deck's outline
## 320 m east, divided its own way (tools/blender/base/make_deck2_rooms.py) —
## the lift on the north wall and a road south from it to a corridor, 食堂
## and its kitchen, 农业部 in the east wing, the rest sealed for now. Reached
## only by the lift; the camera keeps to the deck she is on.
const DECK2_ROOMS := ["deck2", "deck2_x", "farm", "farm2", "mess", "galley", "sealed_w", "sealed_nw", "sealed_ne", "sealed_n", "sealed_sw", "sealed_se"]
## Doorways shut for now, by room: [side, where along it (x for north, z
## for west and east)]. Each is a blast door, and a collider closes it.
## A doorway wider than OPENING is an opening: no door, no wall.
const SEALED_DOORS := {"deck2_x": [["west", -26.0], ["north", 416.0]], "sealed_w": [["east", -26.0]],
	"sealed_sw": [["north", 352.0]], "sealed_se": [["north", 416.0]]}
const OPENING := 6.0
const ORIGIN := Vector3(0, 0, -400)
const EAST := -1.0
const PX := 1.0 / 15.0
const GROUND_PX_PER_UNIT := 12.7
## Lappland's billboard pivots 0.96 above her feet, so it depth-sorts as if
## she stood ~1.5 units further south. Props pivot at the same height and
## shift their image down to match; sorting then compares feet with feet.
const SORT_PIVOT_Y := 0.96
const PIVOT_SCREEN_PX := SORT_PIVOT_Y * 0.5300 * 15.0  # 0.53 = cos(58°), the screen rise per unit height
## The same at the camera's tilt now (GameManager._keep_sprites_upright), for
## billboards placed every frame; ones placed once are kept by the camera's
## "upright_sprites" group instead.
static var pivot_screen_px := PIVOT_SCREEN_PX
const INTERACT_RANGE := 3.0
## The game camera never yaws or pitches, so a quad turned to this basis once
## is a billboard (same orientation Sprite3D's billboard mode produces).
static var CAMERA_BASIS := Basis.looking_at(Vector3(0, -16, 10).normalized(), Vector3.UP)
const PLAYER_Y := 0.7

## Every room is modelled (基地建模改造案_v1; 用户 2026-10-18: 先做大厅看效果,
## then 完成其他房间).
const KIT := "res://art/kit/base_%s.glb"
const KIT_SEE_THROUGH := preload("res://world/base_kit_see_through.gdshader")
const DECK_SHADER := preload("res://world/base_deck.gdshader")
## Stand-in deck plate until Sol's R1 (tools/blender/base/make_deck_tile.py).
const DECK_TILE := preload("res://art/kit/textures/base_deck_tile.png")
## Sol's L logo: the rook tower in the triangle (art/rhodes/batch2_v1).
const LOGO := preload("res://art/kit/textures/base_rhodes_logo.png")
const WALL_BAY := 4.0
## The bridge wall round the lift (用户 2026-10-18: 主控台变大，突出宏伟).
const BRIDGE_HALF := 20.2
## Half the width each fixed wall piece takes from its run.
const PIECE_HALF := {"wall_door": 2.0, "sealed_door": 2.0, "bridge_wall": 20.2}
## Ribs along a modelled room's side walls.
const COLUMN_PITCH := 12.0
## How far a wall collider may sit off its room's edge and still count as that wall.
const EDGE_SLACK := 0.15
const SOUTH_WALL_SCALE := 0.3
## Walls, doors and the side ribs stand this much taller than modelled, like
## the props (PROP_SCALE), so a doorway clears an operator's sprite (用户
## 2026-10-18: 墙和门也加高，和人物比例一致). The bridge wall and the lift
## gate are already built to the bridge's scale and keep theirs.
const WALL_HEIGHT := 1.4
## The old pixel props, by the first 8 characters of their image, and what
## each is now: [model, height above the floor (m), yaw (degrees), shift
## north (m), shift east (m)]. "-" is gone: the lift well's rail gave way to the command
## bridge, and lettered plates and signs are not kept (场景里不挂文字).
## "rack" and "cells" are the warehouse's racks (_add_rack).
const PROP_MODELS := {
	"0f0054e9": ["lift_gate"], "6826174e": ["command_dais"],
	"24cc82cc": ["-"], "af0b7327": ["-"], "292af138": ["-"], "639f0de0": ["-"], "3226a545": ["-"],
	"808235e1": ["desk"], "6c5f3874": ["desk_off"],
	"19f30694": ["hanging_screens", 3.0], "e6ff5c8b": ["hanging_screens_pair", 3.0],
	"d2fe88fb": ["plant"], "ff8fbd2d": ["logistics_counter"],
	"92704f0e": ["crate"], "8a8b819e": ["crate_stack"], "344acf8f": ["case"], "0606c235": ["bench"], "e46c1fb1": ["dispenser"],
	"a72f47a0": ["-"], "1b19fe2e": ["-"],
	"2b08222c": ["-"], "21819f02": ["south_barrier"],
	# 商店
	"866ea73d": ["store_counter"], "8fc5de31": ["pendant_lamp", 2.3], "056e93de": ["display_case"],
	"5335b957": ["display_case_weapon"], "0e6e6ed5": ["-"], "58f38861": ["-"],
	# 武器库
	"cb98b1bc": ["armory_bench"], "102d151b": ["armory_rail", 3.4], "4f935ac6": ["rail_hoist", 0.0, 0.0, -0.5],
	"65f49680": ["-"], "c8e7c0f2": ["-"], "b2ed94b5": ["bench_lamp", 2.4], "de831267": ["robot_arm", 0.0, 0.0, 0.0, 1.8],
	# 医疗部
	"d32a15e8": ["med_reception"], "56f808a8": ["bench"], "483a4552": ["med_sink"], "3fab980b": ["-"], "57b49d70": ["-"],
	"f11ac06b": ["med_bed", 0.0, 0.0, 0.7], "06ea2c60": ["med_bed_used", 0.0, 0.0, 0.7], "6b2044f6": ["iv_stand", 0.0, 0.0, 0.7],
	"d8432da7": ["-"], "3df02ecd": ["-"], "0eac6a17": ["-"], "281a1432": ["-"], "bcf07023": ["-"], "fe4cebe4": ["-"],
	"ca166644": ["-"], "73ccd468": ["-"], "ab656fc0": ["-"],
	"4010224f": ["med_icu", 0.0, 0.0, 0.5], "071f756a": ["med_monitor_arm", 2.0], "0dd902fb": ["-"],
	# 仓储区
	"edc6c7e4": ["rack", "weapon"], "d8a080d4": ["rack", "armor"], "1612c6b0": ["rack", "trinket"], "bd53a4bb": ["rack", "material"],
	"ec36b11f": ["cells"], "570be9b2": ["cells"],
	"1501cb9c": ["-"], "505917f9": ["-"], "e296338a": ["-"], "bbb44585": ["-"], "a0f79d41": ["-"],
	"0da52080": ["recycler"], "b6bca1f9": ["forklift", 0.0, 90.0], "48da9315": ["stash_terminal"], "ae5c1004": ["pallet"],
	"1a4995c5": ["cargo_cart"], "fdfc8ab8": ["cargo_lift", 0.0, 0.0, -0.4],
}
## Per room: the deck plate, and whether the logo is laid into its floor.
## Sol's painted plates (基地材质美术需求_v1 R1/R3/R10, 6 m a tile) are used
## once they are in art/kit/textures/painted/; until then the stand-ins (2 m).
const PAINTED := "res://art/kit/textures/painted/"
const DECK_PAINTED := {"medical": "base_deck_med", "store": "base_deck_store", "lab": "base_deck_lab"}
const DECK_TILES := {
	"medical": preload("res://art/kit/textures/base_deck_med.png"),
	"store": preload("res://art/kit/textures/base_deck_store.png"),
	# 科研部 borrows the medical deck until Sol's RS2 plate arrives.
	"lab": preload("res://art/kit/textures/base_deck_med.png"),
}
## Rooms with the logo laid into the floor: [layout x, z, size] of the logo
## and its colour ([] for the hall's: the middle of the room, steel grey).
const DECK_INLAY := {"hall": [64.0, -25.6, 7.6, Color(0.5, 0.54, 0.57)], "medical": [136.0, -31.6, 8.4, Color(0.42, 0.78, 0.74)]}
## Props are modelled at real size, but the operators' sprites stand about
## twice a real person's height (29 px over 15 px a metre at a 58° camera):
## furniture is shown this much larger so the two read together (用户
## 2026-10-18: 物件都可以更大一些，和人物的比例不太对). The building itself
## (walls, floors, partitions) and what hangs on a wall or a rail keep their
## size; crowded rows (racks, crates, pallets) are scaled less, to their pitch.
const PROP_SCALE := 1.4
const UNSCALED := ["research_holo", "wall_", "bridge_wall", "lift_gate", "command_dais", "market_wall", "holo_screen_frame", "lounge_rug", "holo_table", "column", "floor_", "zone_frame",
	"med_zone", "med_floor_line", "med_partition", "armory_rail", "rail_hoist", "intel_wall", "container_stack", "gantry_crane",
	"conveyor", "south_barrier", "big_screen", "cargo_lift", "scan_gate", "directory_board", "goods_shelf", "weapon_wall_rack",
	"order_board", "sand_table", "cell_", "store_sign", "build_", "cable_trunk", "drone_pad", "order_screen",
	# 农业部's swirl keeps its 1.5 m grid (势力特供策划案 §四).
	"hydro_basin", "crop_"]
const PROP_SCALES := {"rack_hatch": Vector3(1.12, 1.0, 1.2), "rack_hatch_leaf": Vector3(1.12, 1.0, 1.2), "rack_": 1.25,
	"crate_": 1.25, "pallet": 1.2, "case": 1.05, "lab_bench": 1.15, "med_cabinet": 1.25}

## How much larger than modelled `model` is shown (per axis).
static func prop_scale(model: String) -> Vector3:
	for prefix in UNSCALED:
		if model.begins_with(prefix): return Vector3.ONE
	if PROP_SCALES.has(model):
		var exact: Variant = PROP_SCALES[model]
		return exact if exact is Vector3 else Vector3.ONE * float(exact)
	for prefix in PROP_SCALES:
		if model.begins_with(prefix):
			var by: Variant = PROP_SCALES[prefix]
			return by if by is Vector3 else Vector3.ONE * float(by)
	return Vector3.ONE * PROP_SCALE

## The warehouse racks (B-M2): a rack model per zone, and what fills a cell.
## Cells sit on the rack's three shelves, four across, the top row first and
## west to east, like the old 80x64 rack face (WarehouseView.cells).
const RACK_HEIGHT := 2.7 * 1.25
const RACK_WIDTH := 5.3
## Half the hatch's depth: each leaf's (as shown, PROP_SCALES rack_hatch_leaf).
const HATCH_LEAF := 0.85 * 1.2
const CELL_COLUMNS := [1.5, 0.5, -0.5, -1.5]
const CELL_ROWS := [1.82, 1.02, 0.22]
## The command dais round the dispatch spot (用户 2026-10-18: 中间这个太丑了，
## 重新设计; tools/blender/base: base_command_dais): its crescent desk's radius,
## and how far south of the spot the guide lines start.
const DAIS_DESK := 4.4
## Props whose collider is their model's own outline rather than the old
## pixel box, which the scaled models outgrew (beds, seats, crates, carts);
## the rest keep the box their station's walk-up spot was laid out with.
const MODEL_BOXES := ["med_bed", "med_bed_used", "med_icu", "bench", "crate", "crate_stack", "case", "forklift", "recycler",
	"cargo_cart", "pallet", "display_case", "display_case_weapon", "plant", "med_sink", "robot_arm"]
const RING_RADIUS := 7.5
## Decoration with no old pixel prop behind it (基地装饰调研_v1 §6, 用户
## 2026-10-18: 添加装饰品让大厅不那么空), per modelled room: [model, layout x,
## layout z, yaw, height, footprint [w, d] or [] for none (on the floor or
## overhead)].
const DECOR := {
	"hall": [
		# 战略区 (south centre): the sand table, in sight from the dais.
		["holo_table", 64.0, -42.6, 0.0, 0.0, [33.6, 21.8]],
		["first_aid", 116.0, -21.5, 0.0, 0.0, [3.8, 0.8]],
		# 整备台 by the lift: equip, then step onto the lift (用户: 整备后直接出发).
		["armory_bench", 78.5, -5.0, 0.0, 0.0, [6.0, 1.26]], ["weapon_rack_stand", 88.6, -4.6, 0.0, 0.0, [2.4, 0.9]],
		["case", 74.0, -8.6, 0.0, 0.0, [2.4, 0.7]],
		# 交易所 (north-west): the market wall, two rows of trading desks, the counter.
		# 全息行情巨幕 (用户 2026-10-18: 改为全息超大屏，显示 K 线和涨跌): the
		# emitter pylons and rail; the screen and the quote ring over the
		# counter are live holograms (_add_market_holo).
		["holo_screen_frame", 25.5, -6.0, 0.0, 0.0, [26.0, 1.0]],
		# The trading floor (用户 2026-10-18: 建模也换，参考真实交易所): two rows
		# of trader workstations facing the wall, each with its monitor array;
		# behind them a trading post after the NYSE floor's, the quote ring
		# turning over it, where the exchange terminal is.
		["trader_desk", 16.0, -9.8, 0.0, 0.0, [3.2, 1.1]], ["trader_desk", 25.5, -9.8, 0.0, 0.0, [3.2, 1.1]], ["trader_desk", 35.0, -9.8, 0.0, 0.0, [3.2, 1.1]],
		["trader_desk", 16.0, -13.8, 0.0, 0.0, [3.2, 1.1]], ["trader_desk", 35.0, -13.8, 0.0, 0.0, [3.2, 1.1]],
		["trading_post", 25.5, -19.6, 0.0, 0.0, []],
		["plant", 13.0, -20.5, 0.0, 0.0, [0.8, 0.8]], ["plant", 38.0, -20.5, 0.0, 0.0, [0.8, 0.8]], ["plant", 40.5, -4.0, 0.0, 0.0, [0.8, 0.8]],
		# 干员休息区 (south-west): a warm floor, the bar, drinks, two sofa corners, books.
		["lounge_rug", 21.0, -41.5, 0.0, 0.0, []],
		["bar_counter", 12.0, -32.6, 0.0, 0.0, [4.2, 1.4]],
		["vending_machine", 24.5, -30.6, 0.0, 0.0, [1.0, 0.8]], ["vending_machine", 26.1, -30.6, 0.0, 0.0, [1.0, 0.8]],
		["sofa", 18.0, -38.6, 0.0, 0.0, [2.4, 0.9]], ["coffee_table", 18.0, -41.6, 0.0, 0.0, [1.4, 0.8]],
		["sofa", 18.0, -44.6, 180.0, 0.0, [2.4, 0.9]], ["sofa", 12.6, -41.6, -90.0, 0.0, [0.9, 2.4]],
		["sofa", 32.0, -43.6, 0.0, 0.0, [2.4, 0.9]], ["coffee_table", 32.0, -46.6, 0.0, 0.0, [1.4, 0.8]],
		["sofa", 37.4, -46.6, 90.0, 0.0, [0.9, 2.4]],
		["bookshelf", 1.2, -38.0, 90.0, 0.0, [0.5, 2.4]], ["bookshelf", 1.2, -42.0, 90.0, 0.0, [0.5, 2.4]], ["bookshelf", 1.2, -46.0, 90.0, 0.0, [0.5, 2.4]],
		["hanging_screens_pair", 18.0, -36.0, 0.0, 3.0, []],
		["plant", 4.0, -31.5, 0.0, 0.0, [0.8, 0.8]], ["plant", 26.5, -50.5, 0.0, 0.0, [0.8, 0.8]], ["plant", 40.0, -36.0, 0.0, 0.0, [0.8, 0.8]],
		# Signs hung from the ceiling (用户: 指示牌改为吊在天花板上), and the
		# directory over the floor logo.
		["hanging_sign_warehouse", 4.2, -23.0, 0.0, 3.3, []], ["hanging_sign_medical", 123.8, -23.0, 0.0, 3.3, []],
		["hanging_sign_store", 7.5, -2.5, 0.0, 3.3, []], ["hanging_sign_personnel", 124.9, -2.5, 0.0, 3.3, []],
		["hanging_sign_exchange", 40.0, -22.0, 0.0, 3.3, []], ["hanging_sign_lounge", 21.0, -29.5, 0.0, 3.3, []],
		["hanging_sign_loadout", 78.5, -3.0, 0.0, 3.3, []], ["hanging_sign_logistics", 49.5, -3.0, 0.0, 3.3, []],
		["hanging_sign_workshop", 4.0, -8.0, 0.0, 3.3, []], ["hanging_sign_research", 123.8, -46.0, 0.0, 3.3, []],
		# The directory over the crossroads of the main street and the axis.
		["hanging_directory", 64.0, -29.6, 0.0, 3.4, []],
		# 货运区 (north-east): supplies come in on the conveyor and wait under
		# the crane; the containers stand against the east wall so they no
		# longer hide 人事部. (加工部 is a room of its own now.)
		["conveyor", 92.0, -3.75, 0.0, 0.0, [1.8, 7.4]],
		["pallet", 99.0, -4.0, 0.0, 0.0, [2.4, 1.3]], ["pallet", 103.5, -4.0, 0.0, 0.0, [2.4, 1.3]], ["crate_medium_sealed", 99.0, -4.0, 0.0, 0.25, []],
		["crate_large_sealed", 103.5, -4.0, 0.0, 0.25, []], ["forklift", 110.0, -11.0, 90.0, 0.0, [2.6, 1.6]],
		["crate_stack", 98.0, -13.0, 0.0, 0.0, [2.3, 1.0]], ["crate_stack", 101.5, -13.2, 0.0, 0.0, [2.3, 1.0]],
		["case", 116.5, -6.0, 0.0, 0.0, [2.4, 0.7]], ["cargo_cart", 116.0, -15.0, 0.0, 0.0, [1.9, 1.0]],
		["container_stack", 125.4, -11.5, -90.0, 0.0, [2.6, 12.2]],
		["gantry_crane", 108.0, -8.0, 0.0, 0.0, []],
		# 后勤柜台 west of the lift (投保 before leaving).
		["logistics_counter", 49.5, -5.0, 0.0, 0.0, [4.7, 1.2]], ["plant", 42.5, -3.0, 0.0, 0.0, [0.8, 0.8]],
		# Round the sand table: benches either side, plants at its corners.
		["bench", 43.0, -42.6, 90.0, 0.0, [0.8, 3.2]], ["bench", 85.0, -42.6, -90.0, 0.0, [0.8, 3.2]],
		["plant", 44.0, -33.0, 0.0, 0.0, [0.8, 0.8]], ["plant", 84.0, -33.0, 0.0, 0.0, [0.8, 0.8]],
		["plant", 44.0, -53.0, 0.0, 0.0, [0.8, 0.8]], ["plant", 84.0, -53.0, 0.0, 0.0, [0.8, 0.8]],
		# 简报区 (south-east): rows of benches facing a hanging screen.
		["big_screen", 106.0, -32.5, 0.0, 3.0, []],
		["bench", 99.5, -39.0, 180.0, 0.0, [3.2, 0.8]], ["bench", 106.0, -39.0, 180.0, 0.0, [3.2, 0.8]], ["bench", 112.5, -39.0, 180.0, 0.0, [3.2, 0.8]],
		["bench", 99.5, -44.0, 180.0, 0.0, [3.2, 0.8]], ["bench", 106.0, -44.0, 180.0, 0.0, [3.2, 0.8]], ["bench", 112.5, -44.0, 180.0, 0.0, [3.2, 0.8]],
		["desk", 106.0, -35.0, 180.0, 0.0, [3.0, 1.2]],
		["plant", 94.0, -33.0, 0.0, 0.0, [0.8, 0.8]], ["plant", 118.0, -33.0, 0.0, 0.0, [0.8, 0.8]], ["plant", 118.0, -52.0, 0.0, 0.0, [0.8, 0.8]],
		["plant", 52.0, -20.0, 0.0, 0.0, [0.8, 0.8]], ["plant", 76.0, -20.0, 0.0, 0.0, [0.8, 0.8]],
	],
	"store": [
		# Footprints kept to the wall side: the way round behind the counter
		# passes between them and the crate stacks.
		["goods_shelf", 3.6, 9.8, 0.0, 0.0, [4.4, 0.2]], ["goods_shelf", 14.4, 9.8, 0.0, 0.0, [4.4, 0.2]],
		["store_sign", 9.0, 9.92, 0.0, 1.9, []],
	],
	# 加工部 (用户 2026-10-18: 加工部放在房间里): two fabricators and the
	# material racks along the north wall, a robot arm and a cart in the
	# middle, the bench, stock and a cutter low on the camera side.
	"workshop": [
		["fabricator", -33.0, 4.0, 0.0, 0.0, [4.85, 2.3]], ["fabricator", -23.0, 4.0, 0.0, 0.0, [4.85, 2.3]],
		["rack_material", -14.0, 4.9, 0.0, 0.0, [4.2, 1.2]], ["rack_material", -8.0, 4.9, 0.0, 0.0, [4.2, 1.2]],
		["robot_arm", -28.0, -0.6, 0.0, 0.0, [2.25, 1.2]], ["cargo_cart", -17.0, -0.4, 0.0, 0.0, [1.9, 1.0]],
		["armory_bench", -34.0, -4.4, 0.0, 0.0, [6.0, 1.26]], ["crate_stack", -22.5, -5.2, 0.0, 0.0, [2.3, 1.0]],
		["case", -17.5, -5.6, 0.0, 0.0, [2.4, 0.7]],
		["pallet", -10.0, -5.4, 0.0, 0.0, [2.4, 1.3]], ["crate_small_sealed", -10.0, -5.4, 0.0, 0.25, []],
	],
	# 科研部 (龙门币平衡与科研部策划案_v1_1 §5.3): sample cabinets, the analyser,
	# the fume hood and the fridge on the north wall; the research tree's
	# hologram west of centre with the terminal in front, the originium
	# chamber east of it; benches east; only low things on the camera side.
	"lab": [
		["sample_cabinet", 132.6, -40.0, 0.0, 0.0, [2.4, 0.8]], ["sample_cabinet", 135.8, -40.0, 0.0, 0.0, [2.4, 0.8]],
		["originium_scanner", 147.0, -40.8, 0.0, 0.0, [2.9, 2.6]], ["fume_hood", 157.8, -40.1, 0.0, 0.0, [2.6, 1.1]],
		["sample_fridge", 162.5, -39.8, 0.0, 0.0, [0.9, 0.8]], ["med_sink", 165.5, -39.9, 0.0, 0.0, [1.4, 0.7]],
		["research_holo", 141.0, -46.6, 0.0, 0.0, [5.1, 5.1]],
		["originium_chamber", 152.6, -46.9, 0.0, 0.0, [3.3, 3.3]],
		["lab_bench", 160.4, -45.6, 0.0, 0.0, [4.1, 0.8]], ["lab_bench", 160.4, -49.6, 0.0, 0.0, [4.1, 0.8]],
		["lab_bench", 166.2, -45.6, 90.0, 0.0, [0.8, 4.1]],
		["desk", 133.6, -53.8, 180.0, 0.0, [3.0, 1.2]], ["med_cart", 147.5, -54.2, 0.0, 0.0, [1.1, 0.7]],
		["cargo_cart", 156.0, -54.0, 0.0, 0.0, [1.9, 1.0]], ["crate_stack", 164.0, -54.4, 0.0, 0.0, [2.3, 1.0]],
		["plant", 130.4, -55.0, 0.0, 0.0, [0.8, 0.8]], ["plant", 168.0, -40.2, 0.0, 0.0, [0.8, 0.8]],
	],
	# 农业部 (势力特供策划案 §四), the second deck's east wing opened into one
	# (用户 2026-10-22: 农业部放到右侧两个房间，墙壁打通 … 中间墙删掉，重新布局):
	# two sun-lamp rooms along the north, the third south-east of them past
	# the door (their basins: _farm_swirl); the terminal by the door, tanks
	# on the east wall, the potting and seed store along the south.
	"farm": [
		["water_tank", 491.6, -25.0, 0.0, 0.0, [2.6, 2.0]], ["water_tank", 491.6, -29.6, 0.0, 0.0, [2.6, 2.0]],
		["med_sink", 452.0, -33.0, 90.0, 0.0, [0.7, 1.4]],
		["plant", 451.0, -17.0, 0.0, 0.0, [0.8, 0.8]], ["plant", 492.4, -34.6, 0.0, 0.0, [0.8, 0.8]],
	],
	"farm2": [
		["water_tank", 452.4, -52.6, 0.0, 0.0, [2.6, 2.0]], ["water_tank", 456.6, -52.6, 0.0, 0.0, [2.6, 2.0]],
		["seed_cabinet", 463.0, -54.6, 0.0, 0.0, [2.4, 0.8]], ["seed_cabinet", 466.6, -54.6, 0.0, 0.0, [2.4, 0.8]],
		["rack_material", 473.4, -55.3, 0.0, 0.0, [4.2, 1.2]],
		["potting_bench", 466.0, -46.0, 0.0, 0.0, [3.6, 1.0]], ["potting_bench", 474.0, -46.0, 0.0, 0.0, [3.6, 1.0]],
		["compost_bin", 486.6, -53.4, 0.0, 0.0, [1.6, 1.2]], ["compost_bin", 486.6, -50.2, 0.0, 0.0, [1.6, 1.2]],
		["cargo_cart", 482.0, -46.0, 0.0, 0.0, [1.9, 1.0]], ["crate_stack", 455.0, -44.0, 0.0, 0.0, [2.3, 1.0]],
	],
	# 食堂 (§五), north of the corridor: the serving counter under the
	# kitchen's door (BaseWorks builds it), long tables either side of the
	# way in from the corridor (x 348), vending machines on the east wall.
	"mess": [
		["mess_table", 328.5, -10.0, 0.0, 0.0, [6.0, 2.6]], ["mess_table", 338.5, -10.0, 0.0, 0.0, [6.0, 2.6]],
		["mess_table", 358.5, -10.0, 0.0, 0.0, [6.0, 2.6]], ["mess_table", 368.5, -10.0, 0.0, 0.0, [6.0, 2.6]],
		["mess_table", 328.5, -16.6, 0.0, 0.0, [6.0, 2.6]], ["mess_table", 338.5, -16.6, 0.0, 0.0, [6.0, 2.6]],
		["mess_table", 358.5, -16.6, 0.0, 0.0, [6.0, 2.6]], ["mess_table", 368.5, -16.6, 0.0, 0.0, [6.0, 2.6]],
		["vending_machine", 375.6, -4.0, -90.0, 0.0, [1.0, 1.4]], ["vending_machine", 375.6, -6.6, -90.0, 0.0, [1.0, 1.4]],
		["dish_rack", 321.4, -5.0, 90.0, 0.0, [0.8, 2.6]], ["dispenser", 363.0, -1.3, 0.0, 0.0, [0.6, 0.6]],
		["plant", 321.6, -19.6, 0.0, 0.0, [0.8, 0.8]], ["plant", 375.4, -19.6, 0.0, 0.0, [0.8, 0.8]], ["plant", 357.0, -1.2, 0.0, 0.0, [0.8, 0.8]],
	],
	# The kitchen north of 食堂, for show (用户 2026-10-22: 添加厨房区域，仅作为装饰):
	# the ranges on its north wall (BaseWorks), a prep island, fridges, a sink.
	"galley": [
		["dish_rack", 321.3, 5.0, 90.0, 0.0, [0.8, 2.6]], ["lab_bench", 329.5, 5.2, 0.0, 0.0, [4.1, 0.8]],
		["sample_fridge", 337.2, 6.4, -90.0, 0.0, [0.8, 0.9]], ["sample_fridge", 337.2, 5.0, -90.0, 0.0, [0.8, 0.9]],
		["med_sink", 334.6, 1.3, 0.0, 0.0, [1.4, 0.7]],
	],
	# The road from the lift on the north wall down to the corridor (用户
	# 2026-10-22: 升降梯是在中间的上面，中间留出道路).
	"deck2": [
		["cargo_lift", 384.0, -1.9, 0.0, 0.0, []],
		["plant", 378.9, -19.4, 0.0, 0.0, [0.8, 0.8]], ["plant", 389.1, -19.4, 0.0, 0.0, [0.8, 0.8]],
	],
	"deck2_x": [
		["bench", 350.0, -29.9, 0.0, 0.0, [3.2, 0.8]], ["bench", 418.0, -29.9, 0.0, 0.0, [3.2, 0.8]],
		["plant", 322.0, -29.8, 0.0, 0.0, [0.8, 0.8]], ["plant", 446.0, -29.8, 0.0, 0.0, [0.8, 0.8]],
	],
	# Sealed for now (用户 2026-10-22: 实在没东西放的区域可以暂时封闭): stores under tarps.
	"sealed_w": [["build_crate_tarp", 262.0, -20.0, 10.0, 0.0, []], ["build_crate_tarp", 290.0, -32.0, -12.0, 0.0, []],
		["crate_stack", 275.0, -38.0, 0.0, 0.0, []], ["pallet", 305.0, -16.0, 0.0, 0.0, []]],
	"sealed_nw": [["build_crate_tarp", 290.0, 0.0, 6.0, 0.0, []], ["pallet", 305.0, -2.0, 0.0, 0.0, []]],
	"sealed_ne": [["build_crate_tarp", 400.0, -8.0, 8.0, 0.0, []], ["pallet", 412.0, -5.0, 0.0, 0.0, []], ["build_crate_tarp", 428.0, -14.0, -10.0, 0.0, []]],
	"sealed_n": [["build_crate_tarp", 434.0, 7.0, 0.0, 0.0, []]],
	"sealed_sw": [["build_crate_tarp", 338.0, -42.0, 12.0, 0.0, []], ["crate_stack", 352.0, -38.0, 0.0, 0.0, []], ["build_crate_tarp", 366.0, -49.0, -6.0, 0.0, []]],
	"sealed_se": [["build_crate_tarp", 400.0, -45.0, -8.0, 0.0, []], ["pallet", 420.0, -50.0, 0.0, 0.0, []], ["build_crate_tarp", 432.0, -40.0, 14.0, 0.0, []]],
	# 人事部, in the old armory (用户 2026-10-18: 这里变成人事部): the front desk,
	# the operators' roster hologram, file cabinets, an interview table.
	"armory": [
		["personnel_desk", 113.0, 7.5, 0.0, 0.0, [5.2, 1.15]],
		["roster_holo", 104.5, 6.5, 0.0, 0.0, [2.2, 2.2]],
		["file_cabinets", 106.0, 12.45, 0.0, 0.0, [4.0, 0.64]], ["file_cabinets", 119.5, 12.45, 0.0, 0.0, [4.0, 0.64]],
		["interview_table", 121.5, 6.0, 0.0, 0.0, [2.0, 2.0]],
		["plant", 101.5, 2.0, 0.0, 0.0, [0.8, 0.8]], ["plant", 126.6, 11.5, 0.0, 0.0, [0.8, 0.8]],
	],
	# 用户 2026-10-18: 医疗部表现力不足，太空了 — the lobby a working waiting
	# room, the ring corridor a ward's working corridor, the treatment room
	# Rhodes' own (Originium scanner, the lab bench); the beds are dressed in
	# _dress_bed.
	"medical": [
		# The scan gate stands in the corridor wall's gap (anchors.gate is its old floor plate).
		["scan_gate", 143.07, -16.5, 90.0, 0.0, []],
		# Lobby: the pharmacy's cabinets, a screen over the waiting benches,
		# check-in kiosks by the hall door, wheelchairs and a gurney parked south.
		["med_cabinet", 131.3, 3.55, 0.0, 0.0, [1.6, 0.7]], ["med_cabinet", 133.4, 3.55, 0.0, 0.0, [1.6, 0.7]],
		["med_cabinet", 135.5, 3.55, 0.0, 0.0, [1.6, 0.7]], ["med_cabinet", 137.6, 3.55, 0.0, 0.0, [1.6, 0.7]],
		["hanging_screens_pair", 135.1, -9.4, 0.0, 2.6, []],
		["dispenser", 141.9, -12.0, 0.0, 0.0, [0.6, 0.6]], ["plant", 141.9, -13.6, 0.0, 0.0, [0.8, 0.8]],
		["med_kiosk", 131.0, -22.0, 0.0, 0.0, [0.7, 0.5]], ["med_kiosk", 132.1, -22.0, 0.0, 0.0, [0.7, 0.5]],
		["bench", 135.1, -29.6, 0.0, 0.0, [3.2, 0.8]],
		["wheelchair", 131.3, -35.8, 0.0, 0.0, [0.7, 1.0]], ["wheelchair", 132.3, -35.8, 0.0, 0.0, [0.7, 1.0]],
		["gurney", 138.4, -36.0, 0.0, 0.0, [2.0, 0.8]],
		# The ring corridor: the nurse station facing the treatment room, carts,
		# gas, a crash cart, a gurney waiting.
		["nurse_station", 146.8, -11.5, 90.0, 0.0, [1.0, 3.8]],
		["med_cart", 149.3, -20.6, 0.0, 0.0, [1.1, 0.7]], ["oxygen_rack", 149.8, -24.2, -90.0, 0.0, [0.7, 1.6]],
		["crash_cart", 144.2, -24.6, 0.0, 0.0, [1.0, 0.7]],
		["med_cart", 161.5, -3.75, 0.0, 0.0, [1.1, 0.7]],
		["gurney", 170.4, -16.5, 90.0, 0.0, [0.8, 2.0]], ["wheelchair", 173.2, -12.6, -90.0, 0.0, [1.0, 0.7]],
		["med_cart", 168.0, -21.6, 0.0, 0.0, [1.1, 0.7]], ["oxygen_rack", 173.6, -26.6, -90.0, 0.0, [0.7, 1.6]],
		["med_cart", 155.0, -29.25, 0.0, 0.0, [1.1, 0.7]], ["wheelchair", 163.0, -29.2, 0.0, 0.0, [0.7, 1.0]],
		["med_cabinet", 172.9, -8.0, -90.0, 0.0, [0.7, 1.6]], ["med_cabinet", 172.9, -22.0, -90.0, 0.0, [0.7, 1.6]],
		# The treatment room: the Originium scanner, the research bench and its
		# sample fridge on the north wall, a crash cart by the ICU bed.
		["originium_scanner", 153.6, -17.6, 0.0, 0.0, [2.9, 2.6]],
		["lab_bench", 162.7, -7.8, 0.0, 0.0, [4.1, 0.8]], ["sample_fridge", 165.6, -7.85, 0.0, 0.0, [0.9, 0.8]],
		["crash_cart", 163.4, -16.0, 0.0, 0.0, [1.0, 0.7]], ["med_cart", 155.6, -24.6, 0.0, 0.0, [1.1, 0.7]],
		["med_cabinet", 151.3, -22.4, 90.0, 0.0, [0.7, 1.6]], ["med_cabinet", 151.3, -24.4, 90.0, 0.0, [0.7, 1.6]],
	],
}
## The medical bay's floor guide lines (wayfinding): [model, x0, z0, x1, z1],
## straight runs. Green from the hall door to the scan gate and on into the
## ward ring, blue to the pharmacy.
const GUIDE_LINES := {"medical": [
	["med_floor_line", 130.5, -25.6, 141.4, -25.6], ["med_floor_line", 141.4, -25.6, 141.4, -16.5],
	["med_floor_line", 143.6, -16.5, 148.6, -16.5],
	["med_floor_line_blue", 130.5, -26.4, 140.6, -26.4], ["med_floor_line_blue", 140.6, -26.4, 140.6, -6.6],
]}
## Floor zones laid over a room's deck, so its parts read from above: [model,
## x0, z0, x1, z1] (the medical bay's ward rows pale blue, its treatment room
## pale teal).
const FLOOR_ZONES := {"medical": [
	["med_zone_ward", 143.2, 3.9, 174.0, -2.85], ["med_zone_ward", 143.2, -30.15, 174.0, -36.9],
	["med_zone_treat", 150.75, -7.25, 166.35, -25.85],
], "lab": [["med_zone_treat", 148.6, -43.2, 156.6, -51.2]]}
## Each room's wall bay and ceiling light (the medical bay white and cool,
## 农业部 the warm white of grow lights, 食堂 warm).
const WALL_MODELS := {"medical": "wall_panel_med", "lab": "wall_panel_med", "farm": "wall_panel_med", "farm2": "wall_panel_med"}
const SEALED_LAMP := Color(0.07, 0.07, 0.08)
const LAMP_COLOURS := {"medical": Color(0.36, 0.38, 0.4), "lab": Color(0.3, 0.33, 0.37), "farm": Color(0.4, 0.38, 0.3), "mess": Color(0.4, 0.33, 0.24),
	"farm2": Color(0.4, 0.38, 0.3), "galley": Color(0.4, 0.35, 0.28), "sealed_w": SEALED_LAMP, "sealed_nw": SEALED_LAMP, "sealed_ne": SEALED_LAMP,
	"sealed_n": SEALED_LAMP, "sealed_sw": SEALED_LAMP, "sealed_se": SEALED_LAMP}

## 农业部's swirl (Provisions.basin_rect): the sun lamp at this layout spot,
## a tile this many metres. Basins are drawn by _farm_swirl, crops by set_farm.
const FARM_CENTRES := [Vector2(461.0, -6.5), Vector2(482.0, -6.5), Vector2(476.0, -31.0)]
const FARM_TILE := 1.5
## Crops stand on the basin's bed (build_base_kit.CROP_Y).
const CROP_Y := 0.72
const CROP_MODELS := {"舰载麦": "crop_wheat", "块茎薯": "crop_tuber", "温室豆": "crop_bean", "闪耀作物": "crop_shine", "闪耀作物·变种": "crop_shine_var"}
## Ripe shining crops light their basin (the RimWorld nod, 势力特供策划案 §4.2).
const CROP_GLOW := {"闪耀作物": Color(0.45, 0.95, 1.0), "闪耀作物·变种": Color(0.85, 0.6, 1.0)}
## Rooms whose south side is another room's north wall.
const SHARED_SOUTH := ["mess", "sealed_ne", "deck2", "deck2_x", "sealed_nw", "farm"]
## 科研部's own pieces stand in for these until they are built in Blender and
## exported (build_base_kit.LAB_BUILDERS).
const STAND_INS := {"sample_cabinet": "med_cabinet", "fume_hood": "lab_bench", "originium_chamber": "originium_scanner",
	# 基建设施修订案 v1.1 §六, until build_base_kit.WORKS_BUILDERS are exported.
	"build_post": "stash_terminal", "build_tape": "floor_stripe", "build_crate_tarp": "crate_large_sealed", "build_barrier": "south_barrier",
	"build_cone": "plant", "build_lamp": "pendant_lamp", "build_scaffold": "rail_hoist", "build_console": "dispatch_console",
	"cable_trunk": "floor_stripe", "relay_cabinet": "file_cabinets", "drone_pad": "floor_frame", "order_screen": "wall_sign",
	"pack_rig": "weapon_rack_stand", "secure_safe": "case", "closure_fridge": "vending_machine", "display_case_lock": "display_case",
	"research_holo": "roster_holo", "hanging_sign_research": "hanging_sign_workshop"}
## The base's layout (用户 2026-10-18: 重整主基地摆放逻辑): the old pixel props
## standing where a new area now is are left out, [x0, z0, x1, z1] per room:
## the hall's north-west is the exchange floor, its south-west the operators'
## lounge, and the armory is 人事部.
const PROP_CLEAR := {"hall": [[0.0, -23.6, 44.0, 0.0], [0.0, -55.0, 44.0, -28.5], [85.0, -23.6, 128.0, 0.0]],
	"armory": [[99.0, 0.0, 129.0, 14.0]]}
## Stations placed by the layout, not by the rooms' exported data: [room,
## layout x, z]. The 整备台 stands by the lift (整备后直接出发); the exchange
## terminal at its counter; the 人事部 terminal at the old armory's desk.
## (基地布局调研_v2: everything a departure needs within a few steps of the
## lift — 整备台 east of it, the 后勤柜台 west, the dais in front; the
## workshop gets the old cargo bay.)
const STATION_SPOTS := {
	"workbench": ["hall", 78.5, -5.0], "logistics": ["hall", 49.5, -5.0], "exchange": ["hall", 25.5, -21.2],
	# The lift up to the second deck, by the departure lift's gate.
	"deck_lift": ["hall", 71.5, -1.8],
	# The sand table's near edge, off the main street (沙盘航行策划案 §6).
	"sand_table": ["hall", 64.0, -30.6],
	"personnel": ["armory", 113.0, 7.5],
}
const STATION_LABELS := {"exchange": ["exchange", "交易所终端"], "sand_table": ["sand_table", "沙盘"], "personnel": ["personnel", "人事部终端"], "deck_lift": ["lift", "升降梯"],
	"logistics": ["insurance", "后勤柜台：投保"]}
## Spawns placed by the layout: she comes back up the lift, so she arrives at it.
const SPAWN_SPOTS := {"arrival": [64.0, -4.0], "deck_lift": [71.5, -4.4]}
## Lanes painted on a room's deck: [layout x from, x to, z].
const LANES := {"warehouse": [[-63.0, -24.0, -25.8], [-63.0, -24.0, -29.6]],
	# The hall's main street, west door to east door, broken at the axis.
	"hall": [[4.0, 57.0, -23.8], [71.0, 124.0, -23.8], [4.0, 57.0, -28.2], [71.0, 124.0, -28.2]],
	"deck2_x": [[322.0, 446.0, -24.2], [322.0, 446.0, -27.8]]}
## The crane's legs stand at either end of its span.
const CRANE_HALF_SPAN := 13.0
## Expansion joints across a modelled room's deck at these layout x.
const JOINTS := {"hall": [44.5, 91.0]}
## The sand table's hologram (基地建模改造案_v1 §八): Terra over the table's
## emitter plate, and the little blue Rhodes Island over where the ship is.
const HOLOGRAM_SHADER := preload("res://world/base_hologram.gdshader")
const HOLOGRAM_RING := preload("res://world/base_hologram_ring.gdshader")
const TERRA_MAP := preload("res://art/kit/textures/base_terra_map.png")
## Terra as hexagonal columns, like the PRTS map of Terra (基地建模改造案_v1 §十).
const HOLOGRAM_HEX := preload("res://world/base_hologram_hex.gdshader")
## The lowest a column stands, so the coast still shows as a step.
const HOLOGRAM_SEA := preload("res://world/base_hologram_sea.gdshader")
## The borders between regions on the sand table: nation to nation, nation
## to the unclaimed wilds (dimmer).
const BORDER_LOOK := [[Color(0.55, 0.95, 1.0), 1.6], [Color(0.4, 0.7, 0.9), 0.7]]
const HEX_FLOOR := 0.06
const HOLO_HEIGHT := 1.5
const SHIP_HOVER := 0.45
## Each region's own landscape on the table (用户 2026-10-18: 根据各地区自然
## 环境各自建模), tinted within the hologram's blue: [colour, strength].
const HOLO_LOOK := {
	"conifer": [Color(0.3, 0.85, 0.72), 0.6], "broadleaf": [Color(0.4, 0.85, 0.62), 0.5],
	"rainforest": [Color(0.28, 0.8, 0.5), 0.55], "peak": [Color(0.5, 0.78, 1.0), 0.55],
	"snow": [Color(0.92, 0.97, 1.0), 0.75], "dune": [Color(0.8, 0.86, 0.85), 0.35],
	"mesa": [Color(0.62, 0.74, 0.9), 0.5], "river": [Color(0.45, 0.9, 1.0), 1.2],
	"volcano": [Color(0.6, 0.85, 1.0), 0.8], "crater": [Color(1.0, 0.85, 0.6), 1.4],
	"crystal": [Color(0.75, 1.0, 1.0), 1.1],
}
const CITY_COLOUR := Color(0.55, 0.9, 1.0)
## Ceiling lamps over a modelled room: every LAMP_PITCH m, warm-white pools.
const LAMP_PITCH := 16.0
const LAMP := {"color": Color(0.32, 0.3, 0.24), "radius": 11.0}
const SCREEN_LAMP := {"color": Color(0.04, 0.2, 0.24), "radius": 4.0}

var interactables: Array[Dictionary] = []  # {id, kind, label, position}
var spawns := {}
var rooms := {}
var _navigation: NavigationRegion3D
var _textures := {}
## Lappland. Walls and props stay whole in front of her and simply hide her
## (用户 2026-10-18: 不要虚化；蓝色也不要，直接遮挡).
var player: Node3D
## The rooms' pieces' materials (walls and props).
var _see_through_kit: Array[ShaderMaterial] = []
## The modelled rooms' light (FieldLight over their rectangle).
var light: FieldLight
var _lamps: Array[Dictionary] = []
var _model_bounds := Rect2()
## The little Rhodes Island over the sand table, and where it is.
var ship_marker: MeshInstance3D
var ship_place := ""
var _ship_ring: MeshInstance3D
var _holo_centre := Vector2.ZERO
var _holo_time := 0.0
var _ship_base_y := 0.0
## Per room: what dims with its lights, the warehouse's racks and the pieces
## a view switches. {room_id: {"shaders": [ShaderMaterial] (deck first, then
## kit pieces), "sprites": [Sprite3D] (markers, the carried icon), "racks":
## {"shelf:<zone>:<slot>": {node, hatch, leaves, zone, cells, at}}, "roles":
## {"reception_alert": MeshInstance3D}}}
var room_visuals := {}
## The room whose pieces are being placed: their materials join its visuals,
## so its lights (set_room_bands) reach them.
var _building_room := ""
## While a room is built, its pieces that share a texture share their
## material (36 racks and 144 cells would otherwise make ~900): key
## "<room>@<texture id>", so one room's light strips never reach another.
## Pieces added later get their own, as they are freed again.
var _shared_kit := {}
var _share_materials := false
## The crew strolling between the stations (BaseCrew).
var crew: BaseCrew
## Entering the warehouse lights it in steps and raises the personal-storage shelves.
var warehouse_reveal: RoomReveal

func _process(_delta: float) -> void:
	if not is_instance_valid(player): return
	_shadow_pick -= _delta
	if _shadow_pick <= 0.0:
		_shadow_pick = SHADOW_PICK
		_pick_shadows()
	_tint_sprites()
	if ship_marker != null:
		# The hologram turns slowly and breathes up and down over its spot.
		_holo_time += _delta
		ship_marker.rotation.y = _holo_time * 0.6
		ship_marker.position.y = _ship_base_y + sin(_holo_time * 1.8) * 0.06
		_ship_ring.scale = Vector3.ONE * (1.0 + 0.25 * fmod(_holo_time, 1.6) / 1.6)

func _ready() -> void:
	position = ORIGIN
	_navigation = NavigationRegion3D.new()
	add_child(_navigation)
	_build_backdrop()
	for key in ROOMS:
		var path: String = DATA_DIR + "room_%s.json" % key
		if not FileAccess.file_exists(path):
			push_warning("Base room data missing: " + path)
			continue
		var room: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		rooms[key] = room
		_build_room(room)
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_height = 1.5
	nav_mesh.agent_radius = 0.75
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	_navigation.navigation_mesh = nav_mesh
	_navigation.bake_navigation_mesh(false)
	if rooms.has("store"): _add_closure()
	crew = BaseCrew.new()
	crew.setup(self)
	add_child(crew)
	if _model_bounds.has_area():
		light = FieldLight.new()
		light.build_area(_model_bounds.grow(4.0), "rhodes", _lamps)
		FieldLight.clear()
	_build_lights()
	if rooms.has("warehouse"):
		warehouse_reveal = RoomReveal.new()
		warehouse_reveal.setup(self, "warehouse", "shelf:")
		add_child(warehouse_reveal)
	set_active(false)

## Layout coordinates (x east, z north, ground units) to a global position.
func to_world(x: float, z: float, y: float = 0.0) -> Vector3:
	return ORIGIN + Vector3(EAST * x, y, z)

# --- Real lights (场景渲染统一改造案_v1 §4.3) ------------------------------------
## The lamps the light texture used to carry are lights: ceiling lamps, the
## screens' glow and the originium. The nearest SHADOW_LIGHTS ceiling lamps to
## her cast shadows, re-picked every SHADOW_PICK seconds as she walks.
const SHADOW_LIGHTS := 6
const SHADOW_PICK := 0.5
var lights: Array[OmniLight3D] = []
var _ceiling_lights: Array[OmniLight3D] = []
var _shadow_pick := 0.0

func _build_lights() -> void:
	for lamp in _lamps:
		var c: Color = lamp.color
		var peak := maxf(c.r, maxf(c.g, c.b))
		if peak <= 0.0: continue
		var at: Vector3 = lamp.at
		var ceiling := at.y > 3.0
		var o := OmniLight3D.new()
		o.name = "Lamp"
		o.light_color = Color(c.r / peak, c.g / peak, c.b / peak)
		o.omni_range = float(lamp.radius) * (1.7 if ceiling else 1.6)
		o.light_energy = (2.0 if ceiling else 0.9) * clampf(peak * 3.0, 0.4, 1.4)
		o.light_specular = 0.25 if ceiling else 0.5
		o.omni_attenuation = 1.2
		o.shadow_blur = 1.5
		o.distance_fade_enabled = true
		o.distance_fade_begin = 40.0
		o.distance_fade_length = 10.0
		add_child(o)
		o.global_position = at
		lights.append(o)
		if ceiling: _ceiling_lights.append(o)
	_pick_shadows()

## The colour the lamps around `at` cast, as a tint for a self-lit sprite:
## white pulled a little towards the nearby lights' hue and the room's cool
## ambient, never darker than the sprite as drawn (a dark tint read as a
## black face, 用户 2026-10-20).
const AMBIENT_TINT := Color(0.95, 0.97, 1.0)
const TINT_PULL := 0.28
func light_tint(at: Vector3) -> Color:
	var sum := Color(0, 0, 0)
	var weight := 0.0
	for o in lights:
		var d := o.global_position.distance_to(at)
		if d >= o.omni_range: continue
		var w := o.light_energy * pow(1.0 - d / o.omni_range, 2.0)
		sum += o.light_color * w
		weight += w
	if weight <= 0.0: return AMBIENT_TINT
	var hue := sum / weight
	return AMBIENT_TINT.lerp(hue, clampf(weight * TINT_PULL, 0.0, TINT_PULL))

## Tints the sprites walking the base, and shows their contact shadows.
func _tint_sprites() -> void:
	var sprites: Array = []
	if is_instance_valid(player) and player.get("_sprite") is LapplandAnimator3D: sprites.append(player._sprite)
	if is_instance_valid(crew):
		for w in crew.walkers:
			for c in (w.body as Node).get_children():
				if c is LapplandAnimator3D: sprites.append(c)
	for s: LapplandAnimator3D in sprites:
		s.scene_tint = light_tint(s.global_position)
		if is_instance_valid(s.contact_shadow): s.contact_shadow.visible = true

## A floor zone is self-lit paint, not a lamp: kept under the bloom threshold
## so it does not flare white under the real lights.
const ZONE_GLOW := 0.62
func _dim_glow(piece: MeshInstance3D, gain: float) -> void:
	for s in range(piece.mesh.get_surface_count()):
		var m := piece.get_active_material(s) as ShaderMaterial
		if m == null or m.shader != TerraceDressing.GLOW_SHADER: continue
		var dim := m.duplicate() as ShaderMaterial
		dim.set_shader_parameter("gain", gain)
		piece.set_surface_override_material(s, dim)

func _pick_shadows() -> void:
	var at: Vector3 = player.global_position if is_instance_valid(player) else global_position
	var order := _ceiling_lights.duplicate()
	order.sort_custom(func(a, b): return a.global_position.distance_squared_to(at) < b.global_position.distance_squared_to(at))
	for i in range(order.size()): (order[i] as OmniLight3D).shadow_enabled = i < SHADOW_LIGHTS

func set_active(active: bool) -> void:
	visible = active
	_navigation.enabled = active
	if active and light != null: light.apply("rhodes")
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	# Every return starts with the warehouse dark and its shelves stowed.
	if active and warehouse_reveal: warehouse_reveal.reset()

func spawn_point(name: String) -> Vector3:
	var p: Array = spawns.get(name, spawns.get("arrival", [64.0, -53.0]))
	return to_world(p[0], p[1], PLAYER_Y)

## Keeps a 640×360 view from showing the void past the outer walls.
## Half a screen is 320 px = 21.3 units across and 180 px ≈ 14.2 units down the ground.
## `zoom` is the camera's size over the default one; `yaw` its turn
## (GameManager.camera_yaw): the limits are taken across and up the screen,
## against the base's extent that way, so a turned view still stops at it.
## `tilt` stretches the reach up and down the ground (sin 58° over sin of the tilt).
func clamp_camera(target: Vector3, zoom: float = 1.0, yaw: float = 0.0, tilt: float = 1.0) -> Vector3:
	var local := target - ORIGIN
	var bounds := _bounds()
	# Layout x east, y north: screen right and screen up for this turn.
	var right := Vector2(1, 0).rotated(yaw)
	var up := Vector2(0, 1).rotated(yaw)
	var at := Vector2(EAST * local.x, local.z)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for corner in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
		var p := Vector2(corner.dot(right), corner.dot(up))
		lo = lo.min(p)
		hi = hi.max(p)
	var across := clampf(at.dot(right), lo.x + 21.3 * zoom, maxf(lo.x + 21.3 * zoom, hi.x - 21.3 * zoom))
	var along := clampf(at.dot(up), lo.y + 13.6 * zoom * tilt, maxf(lo.y + 13.6 * zoom * tilt, hi.y - 6.0 * zoom * tilt))
	var back := right * across + up * along
	return ORIGIN + Vector3(EAST * back.x, local.y, back.y)

var _cached_bounds := {}
## Which deck she is on (GameManager.deck): the camera keeps to its rooms.
var deck := 1
## Layout-space extent of the deck's ground quads: x east, y = z north.
func _bounds() -> Rect2:
	if _cached_bounds.has(deck): return _cached_bounds[deck]
	var out := Rect2()
	for room in rooms.values():
		if (str(room.id) in DECK2_ROOMS) != (deck == 2): continue
		var g: Dictionary = room.ground
		var r := Rect2(g.x, g.z - g.h_px / GROUND_PX_PER_UNIT, g.w_px * PX, g.h_px / GROUND_PX_PER_UNIT)
		out = r if not out.has_area() else out.merge(r)
	_cached_bounds[deck] = out
	return out

func navigation_map_rid() -> RID:
	return _navigation.get_navigation_map()

## Whether a global position stands on the room's floor (layout rectangle from its origin and size).
func room_contains(room_id: String, global: Vector3, margin: float = 0.0) -> bool:
	var room: Dictionary = rooms.get(room_id, {})
	if room.is_empty(): return false
	var x := (global.x - ORIGIN.x) / EAST
	var z := global.z - ORIGIN.z
	return x > room.origin[0] + margin and x < room.origin[0] + room.size[0] - margin 		and z < room.origin[1] - margin and z > room.origin[1] - room.size[1] + margin

## Room lights in strips across the room. `edges` are the layout x of the
## west edges of strips 0, 1 and 2 (strip 0 is the easternmost), `levels` the
## light level of strips 0..3. Floors, walls and overhead items do this per
## pixel (base_room_light.gdshaderinc); props take the level of the strip they stand in.
func set_room_bands(room_id: String, edges: Array, levels: Array) -> void:
	var visuals: Dictionary = room_visuals.get(room_id, {})
	if visuals.is_empty(): return
	visuals.bands = [edges, levels]  # for props and decals added later
	for material: ShaderMaterial in visuals.shaders: _light_material(material, edges, levels)
	for sprite: Sprite3D in visuals.sprites: _light_sprite(sprite, edges, levels)

func _light_material(material: ShaderMaterial, edges: Array, levels: Array) -> void:
	var world_edges := Vector3.ZERO
	for k in range(3): world_edges[k] = ORIGIN.x + EAST * float(edges[k])
	material.set_shader_parameter("band_edges", world_edges)
	material.set_shader_parameter("band_sign", EAST)
	material.set_shader_parameter("band_levels", Vector4(levels[0], levels[1], levels[2], levels[3]))

func _light_sprite(sprite: Sprite3D, edges: Array, levels: Array) -> void:
	var strip := 0
	for k in range(3):
		if sprite.position.x * EAST < float(edges[k]): strip = k + 1
	var level: float = levels[strip]
	sprite.modulate = Color(level, level, level)

## A prop added at run time (a receiving crate, a staging pallet): a billboard
## standing on its feet at layout (x, z), lit like the rest of the room. Moving
## it later is the caller's business; it keeps the light of where it was added.
func add_prop(room_id: String, texture: Texture2D, x: float, z: float, lift_px: float = 0.0) -> Sprite3D:
	var sprite := _billboard(texture, x, z, lift_px)
	get_node(NodePath(room_id)).add_child(sprite)
	var visuals: Dictionary = room_visuals[room_id]
	visuals.sprites.append(sprite)
	if visuals.has("bands"): _light_sprite(sprite, visuals.bands[0], visuals.bands[1])
	return sprite

## 可露希尔 behind the shop counter, left of the crate stack (NPC_brief_v3.md
## Part B). The counter is drawn in front of her, so her legs are hidden.
const CLOSURE_SPOT := Vector2(7.3, 7.0)

func _add_closure() -> void:
	var figure := FieldArt.npc_idle("closure")
	figure.name = "Closure"
	# Placed like _billboard(): pivot at SORT_PIVOT_Y, image bottom on the feet.
	figure.position = Vector3(EAST * CLOSURE_SPOT.x, SORT_PIVOT_Y, CLOSURE_SPOT.y)
	figure.offset.y -= PIVOT_SCREEN_PX
	figure.double_sided = true
	figure.add_to_group("upright_sprites")
	get_node("store").add_child(figure)

## Removes a prop added with add_prop().
func remove_prop(room_id: String, sprite: Sprite3D) -> void:
	room_visuals[room_id].sprites.erase(sprite)
	sprite.queue_free()

## Puts a billboard's image bottom on the feet at (x, z) again after its texture
## or lift changed (same placement as _billboard()).
func place_billboard(sprite: Sprite3D, x: float, z: float, lift_px: float = 0.0) -> void:
	sprite.position = Vector3(EAST * x, SORT_PIVOT_Y, z)
	sprite.offset = Vector2(0, sprite.texture.get_height() * 0.5 + lift_px - PIVOT_SCREEN_PX)
	sprite.set_meta("upright_shift", 0.0)

func texture_at(path: String) -> Texture2D: return _texture(path)

## The closest station within reach of `position`, or an empty dictionary.
func station_near(position: Vector3) -> Dictionary:
	var best := {}
	var best_distance := INTERACT_RANGE
	for station in interactables:
		var offset: Vector3 = station.position - position
		offset.y = 0
		if offset.length() < best_distance:
			best_distance = offset.length()
			best = station
	return best

func station(id: String) -> Dictionary:
	for entry in interactables:
		if entry.id == id: return entry
	return {}

func _build_backdrop() -> void:
	var backdrop := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	# Under both decks (the second stands 320 m east of the first).
	plane.size = Vector2(1100, 400)
	backdrop.mesh = plane
	backdrop.position = Vector3(EAST * 215.0, -0.05, -20.0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("0b0c0d")
	backdrop.material_override = material
	backdrop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(backdrop)

func _build_room(room: Dictionary) -> void:
	var root := Node3D.new()
	root.name = room.id
	add_child(root)
	var visuals := {"shaders": [], "sprites": [], "racks": {}, "roles": {}}
	room_visuals[room.id] = visuals
	var ground: Dictionary = room.ground
	var w: float = ground.w_px * PX
	var d: float = ground.h_px / GROUND_PX_PER_UNIT
	_add_floor_collider(ground.x, ground.z, w, d)
	_building_room = room.id
	_share_materials = true
	_build_model_room(root, room)
	_share_materials = false
	_building_room = ""
	_room_records(room)

## Walls, stations and spawn points.
func _room_records(room: Dictionary) -> void:
	for box in room.colliders:
		_add_box(box[0], box[1], box[2], box[3])
	for entry in room.interactables:
		if STATION_SPOTS.has(entry.id): continue
		interactables.append({"id": entry.id, "kind": entry.kind, "label": entry.label,
			"room": room.id, "position": to_world(entry.x, entry.z, PLAYER_Y)})
	# The stations the layout places (STATION_SPOTS), each with its room.
	for id in STATION_SPOTS:
		var spot: Array = STATION_SPOTS[id]
		if spot[0] != room.id: continue
		var kind: Array = STATION_LABELS.get(id, ["loadout", "整备台：装备"])
		interactables.append({"id": id, "kind": kind[0], "label": kind[1], "room": room.id, "position": to_world(spot[1], spot[2], PLAYER_Y)})
	for key in room.spawns:
		spawns[key] = room.spawns[key]
	if room.id == "hall":
		for key in SPAWN_SPOTS: spawns[key] = SPAWN_SPOTS[key]

func _texture(path: String) -> Texture2D:
	if _textures.has(path): return _textures[path]
	# Loaded from the PNG bytes so the generated folder needs no import step.
	var image := Image.new()
	image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	var texture := ImageTexture.create_from_image(image)
	_textures[path] = texture
	return texture

func _billboard(texture: Texture2D, x: float, z: float, lift_px: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = PX
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.double_sided = true
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.position = Vector3(EAST * x, SORT_PIVOT_Y, z)
	# Bottom edge on the feet (raised by lift for hanging items), corrected for the pivot height.
	sprite.offset = Vector2(0, texture.get_height() * 0.5 + lift_px - PIVOT_SCREEN_PX)
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.add_to_group("upright_sprites")
	return sprite

func _add_floor_collider(x: float, z: float, w: float, d: float) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, 1.0, d)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(EAST * (x + w * 0.5), -0.5, z - d * 0.5)
	_navigation.add_child(body)

## A prop footprint added at run time (a newly built rack). Navigation is rebaked
## on the next frame, once however many were added.
func add_runtime_collider(x0: float, z0: float, x1: float, z1: float) -> void:
	_add_box(x0, z0, x1, z1)
	if not _rebake_queued:
		_rebake_queued = true
		_rebake.call_deferred()

var _rebake_queued := false
func _rebake() -> void:
	_rebake_queued = false
	_navigation.bake_navigation_mesh(false)

## Wall or prop footprint in layout coordinates [x0, z0] - [x1, z1].
func _add_box(x0: float, z0: float, x1: float, z1: float) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(absf(x1 - x0), 2.0, absf(z1 - z0))
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(EAST * (x0 + x1) * 0.5, 1.0, (z0 + z1) * 0.5)
	_navigation.add_child(body)

# --- Modelled rooms (基地建模改造案_v1) -------------------------------------------

## A room of kit pieces: the deck, walls round its rectangle (open where its
## colliders leave gaps), and a model in place of each old pixel prop, on the
## same footprint. Collision is the room's own data, as for a pixel room.
func _build_model_room(root: Node3D, room: Dictionary) -> void:
	var x0: float = room.origin[0]
	var z0: float = room.origin[1]
	var size_x: float = room.size[0]
	var size_z: float = room.size[1]
	_add_deck(root, x0, z0, size_x, size_z, room.id, room.id in DECK_INLAY)
	for zone in FLOOR_ZONES.get(room.id, []):
		var piece := _place_kit(root, zone[0], Vector3(EAST * (zone[1] + zone[3]) * 0.5, 0.0, (zone[2] + zone[4]) * 0.5))
		piece.scale = Vector3(absf(zone[3] - zone[1]), 1.0, absf(zone[4] - zone[2]))
		_dim_glow(piece, ZONE_GLOW)
	var openings := _wall_openings(room)
	var north: Array = []
	for gap in openings.north: north.append([gap[0], gap[1], _door_model(room, "north", gap)])
	for entry in room.sprites:
		if _prop_spec(entry) == ["lift_gate"]:
			north.append([float(entry.x) - BRIDGE_HALF, float(entry.x) + BRIDGE_HALF, "bridge_wall"])
			_place_kit(root, "lift_gate", Vector3(EAST * float(entry.x), 0.0, z0))
			_lamps.append({"at": to_world(float(entry.x), z0 - 3.0, 1.0), "color": Color(0.05, 0.16, 0.26), "radius": 12.0})
	_wall_run(root, x0, x0 + size_x, func(t): return Vector3(EAST * t, 0.0, z0), 0.0, north, 1.0)
	# West and east walls run south; the south wall stays low so it hides
	# nobody standing in front of it.
	var west: Array = []
	for gap in openings.west: west.append([gap[0], gap[1], _door_model(room, "west", gap)])
	_wall_run(root, -z0, -z0 + size_z, func(t): return Vector3(EAST * x0, 0.0, -t), PI / 2.0, west, 1.0)
	var east: Array = []
	for gap in openings.east: east.append([gap[0], gap[1], _door_model(room, "east", gap)])
	_wall_run(root, -z0, -z0 + size_z, func(t): return Vector3(EAST * (x0 + size_x), 0.0, -t), -PI / 2.0, east, 1.0)
	# A room north of the hall (the store, the armory) has the hall's north
	# wall for its south side.
	if (room.id == "hall" or absf(z0 - size_z) > 0.01) and not room.id in SHARED_SOUTH:
		_wall_run(root, x0, x0 + size_x, func(t): return Vector3(EAST * t, 0.0, z0 - size_z), PI, [], SOUTH_WALL_SCALE)
	_partitions(root, room)
	# Ribs along the side walls, clear of the doors.
	var t := COLUMN_PITCH * 0.5
	while t < size_z - 2.0:
		var clear := true
		for gap in openings.west + openings.east:
			if t + 1.5 > gap[0] + z0 and t - 1.5 < gap[1] + z0: clear = false  # gaps run in -z
		if clear:
			_place_kit(root, "column", Vector3(EAST * x0, 0.0, z0 - t), PI / 2.0, Vector3(1.0, WALL_HEIGHT, 1.0))
			_add_box(x0, z0 - t - 0.65, x0 + 1.0, z0 - t + 0.65)
			_place_kit(root, "column", Vector3(EAST * (x0 + size_x), 0.0, z0 - t), -PI / 2.0, Vector3(1.0, WALL_HEIGHT, 1.0))
			_add_box(x0 + size_x - 1.0, z0 - t - 0.65, x0 + size_x, z0 - t + 0.65)
		t += COLUMN_PITCH
	for entry in room.sprites:
		var spec := _prop_spec(entry)
		if _cleared(room.id, float(entry.x), float(entry.z)): continue
		if spec == ["command_dais"]:
			_dais_colliders(float(entry.x), float(entry.z))
		elif entry.has("collide") and not spec.is_empty() and spec[0] in MODEL_BOXES:
			pass  # sized from the placed model below (_model_box)
		elif entry.has("collide") and spec != ["-"]:
			var box: Array = entry.collide
			_add_box(entry.x - box[0] * 0.5, entry.z - box[1] * 0.5, entry.x + box[0] * 0.5, entry.z + box[1] * 0.5)
		if spec.is_empty() or spec[0] in ["lift_gate", "-", "cells"]: continue
		if spec[0] == "rack":
			_add_rack(root, entry, spec[1])
			continue
		var height: float = spec[1] if spec.size() > 1 else 0.0
		var yaw := deg_to_rad(spec[2]) if spec.size() > 2 else 0.0
		var x: float = entry.x
		if spec.size() > 4: x += float(spec[4])
		var piece := _place_kit(root, spec[0], Vector3(EAST * x, height, float(entry.z) + (spec[3] if spec.size() > 3 else 0.0)), yaw)
		if entry.has("collide") and spec[0] in MODEL_BOXES: _model_box(piece)
		if spec[0] in ["med_bed", "med_bed_used"]: _dress_bed(root, piece.position, float(entry.z) > float(room.origin[1]) - 6.0, float(room.origin[1]))
		if entry.get("role", "") == "reception":
			# The desk's alert (MedicalView): a beacon and banner set on it.
			var alert := _place_kit(root, "med_alert", piece.position)
			room_visuals[room.id].roles["reception_alert"] = alert
		if spec[0] == "command_dais":
			# Two guide lines lead from the hall's south side up to the bridge.
			for side in [-1.0, 1.0]:
				var z := float(entry.z) - RING_RADIUS - 3.0
				while z > -26.0:
					_place_kit(root, "floor_stripe", Vector3(EAST * (x + side * 6.0), 0.0, z - 2.0), PI / 2.0)
					z -= 5.0
		if spec[0] in ["desk", "command_dais", "logistics_counter"]:
			_lamps.append({"at": to_world(x, float(entry.z) + 1.0, 1.0), "color": SCREEN_LAMP.color, "radius": SCREEN_LAMP.radius})
	var lx := x0 + LAMP_PITCH * 0.5
	while lx < x0 + size_x:
		var lz := z0 - LAMP_PITCH * 0.5
		while lz > z0 - size_z:
			_lamps.append({"at": to_world(lx, lz, 4.0), "color": LAMP_COLOURS.get(room.id, LAMP.color), "radius": LAMP.radius})
			lz -= LAMP_PITCH
		lx += LAMP_PITCH
	for d in DECOR.get(room.id, []):
		_place_kit(root, d[0], Vector3(EAST * float(d[1]), float(d[4]), float(d[2])), deg_to_rad(float(d[3])))
		var foot: Array = d[5]
		if not foot.is_empty():
			var grown := prop_scale(str(d[0]))
			var w: float = foot[0] * grown.x
			var dd: float = foot[1] * grown.z
			_add_box(d[1] - w * 0.5, d[2] - dd * 0.5, d[1] + w * 0.5, d[2] + dd * 0.5)
		if d[0] == "gantry_crane":
			for side in [-1.0, 1.0]:
				var leg: float = d[1] + side * CRANE_HALF_SPAN
				_add_box(leg - 0.4, d[2] - 0.4, leg + 0.4, d[2] + 0.4)
		if d[0] == "holo_table": _add_hologram(root, float(d[1]), float(d[2]))
		if d[0] == "research_holo": _add_research_holo(root, float(d[1]), float(d[2]))
		if d[0] == "originium_chamber": _lamps.append({"at": to_world(d[1], d[2], 1.8), "color": Color(0.5, 0.22, 0.07), "radius": 5.0})
		if d[0] == "holo_screen_frame": _add_market_holo(root, float(d[1]), float(d[2]))
		if d[0] == "trading_post":
			_add_quote_ring(root, float(d[1]), float(d[2]))
			_post_colliders(float(d[1]), float(d[2]))
		if d[0] in ["med_bed", "med_bed_used"]: _dress_bed(root, Vector3(EAST * float(d[1]), 0.0, float(d[2])), false, z0)
		if d[0] in ["holo_table", "intel_wall"]:
			_lamps.append({"at": to_world(d[1], d[2] - 1.0, 1.0), "color": SCREEN_LAMP.color, "radius": SCREEN_LAMP.radius * 1.6})
	if room.id == "farm": _farm_swirl(root)
	for line in GUIDE_LINES.get(room.id, []):
		var from := Vector2(line[1], line[2])
		var to := Vector2(line[3], line[4])
		var along_x := absf(to.x - from.x) > absf(to.y - from.y)
		var pieces := maxi(1, roundi(from.distance_to(to) / 2.0))
		for k in range(pieces):
			var p := from.lerp(to, (k + 0.5) / pieces)
			_place_kit(root, line[0], Vector3(EAST * p.x, 0.0, p.y), 0.0 if along_x else PI / 2.0, Vector3(from.distance_to(to) / pieces / 2.0, 1.0, 1.0))
	for lane in LANES.get(room.id, []):
		var lane_x: float = lane[0] + 2.0
		while lane_x < float(lane[1]):
			_place_kit(root, "floor_stripe", Vector3(EAST * lane_x, 0.0, lane[2]))
			lane_x += 5.0
	for cells in room.sprites:
		if _prop_spec(cells) == ["cells"]: _add_cells(room.id, cells)
	for jx in JOINTS.get(room.id, []):
		var jz := z0 - 2.0
		while jz > z0 - size_z + 1.0:
			_place_kit(root, "floor_joint", Vector3(EAST * jx, 0.0, jz), PI / 2.0)
			jz -= 4.0
	var rect := Rect2(ORIGIN.x + EAST * (x0 + size_x), ORIGIN.z + z0 - size_z, size_x, size_z)
	_model_bounds = rect if not _model_bounds.has_area() else _model_bounds.merge(rect)

## The exchange's hologram wall over its pylons at layout (x, z): the live
## board (MarketBoard "wall") on a 24 m screen leaning back towards the
## camera, and the running quotes on a strip along its foot. Each is drawn in
## a SubViewport that only renders while the base is shown.
const MARKET_WALL := Vector2(24.0, 6.2)
## Leant back from upright so the whole screen stays in view from the floor.
const MARKET_TILT := 42.0
const RING_TICKER := {"radius": 3.8, "height": 1.0, "lift": 5.3, "scroll": 0.02}
var market_boards: Array[MarketBoard] = []
var _ticker_texture: ViewportTexture

func _add_market_holo(root: Node3D, x: float, z: float) -> void:
	var wall := _board_viewport(root, "wall", Vector2i(1600, 414))
	var screen := MeshInstance3D.new()
	screen.name = "MarketHologram"
	var quad := QuadMesh.new()
	quad.size = MARKET_WALL
	screen.mesh = quad
	# A quad faces +Z; turned to face south (the camera) and leant back.
	var basis := Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, deg_to_rad(-MARKET_TILT))
	# Its foot just over the emitter rail, leaning back over the pylons.
	var half := MARKET_WALL.y * 0.5
	var centre := Vector3(EAST * x, 0.9 + half * cos(deg_to_rad(MARKET_TILT)), z + half * sin(deg_to_rad(MARKET_TILT)) - 0.6)
	screen.transform = Transform3D(basis, centre)
	screen.material_override = _hologram(Color.WHITE, 1.25, wall.get_texture())
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(screen)
	var strip := MeshInstance3D.new()
	strip.name = "MarketTicker"
	var band := QuadMesh.new()
	band.size = Vector2(MARKET_WALL.x, 0.75)
	strip.mesh = band
	strip.transform = Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, deg_to_rad(-50.0)), Vector3(EAST * x, 0.55, z - 1.2))
	var material := _hologram(Color.WHITE, 1.2, _ticker(root))
	material.set_shader_parameter("uv_scroll", Vector2(RING_TICKER.scroll * 0.6, 0.0))
	strip.material_override = material
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(strip)

## The trading post's footprint (base_trading_post, shown at PROP_SCALE): its
## horseshoe counter segment by segment, open to the south so she walks in to
## the terminal, and the central column.
func _post_colliders(x: float, z: float) -> void:
	var k := prop_scale("trading_post").x
	for i in range(9):
		var a := deg_to_rad(-120.0 + i * 30.0)
		var cx := x - 2.2 * k * sin(a)
		var cz := z + 2.2 * k * cos(a)
		_add_box(cx - 0.6 * k, cz - 0.45 * k, cx + 0.6 * k, cz + 0.45 * k)
	_add_box(x - 0.4 * k, z - 0.4 * k, x + 0.4 * k, z + 0.4 * k)

## The quote ring over the trading post (after the Tokyo Stock Exchange's):
## an open cylinder showing the running quotes on its outer face, turning.
func _add_quote_ring(root: Node3D, x: float, z: float) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "QuoteRing"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = RING_TICKER.radius
	cylinder.bottom_radius = RING_TICKER.radius
	cylinder.height = RING_TICKER.height
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	cylinder.radial_segments = 48
	ring.mesh = cylinder
	ring.position = Vector3(EAST * x, RING_TICKER.lift, z)
	var material := ShaderMaterial.new()
	material.shader = HOLOGRAM_RING
	material.set_shader_parameter("use_map", true)
	material.set_shader_parameter("map_tex", _ticker(root))
	material.set_shader_parameter("strength", 1.3)
	material.set_shader_parameter("uv_scroll", Vector2(RING_TICKER.scroll, 0.0))
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)

## The ticker's texture, drawn once and shared by the strip and the ring.
func _ticker(root: Node3D) -> ViewportTexture:
	if _ticker_texture == null: _ticker_texture = _board_viewport(root, "ticker", Vector2i(2048, 96)).get_texture()
	return _ticker_texture

func _board_viewport(root: Node3D, mode: String, px: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "MarketBoard_" + mode
	viewport.size = px
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	var board := MarketBoard.new()
	board.mode = mode
	board.size = Vector2(px)
	viewport.add_child(board)
	root.add_child(viewport)
	market_boards.append(board)
	return viewport

## The live market the exchange hologram shows (GameManager.market).
func set_market(source: MarketState) -> void:
	for board in market_boards: board.market = source

## Terra over a holo table at layout (x, z), as a 3D hologram (基地建模改造案_v1
## §九): the relief of each region (make_terra_height.py), its forests, the
## capitals and the mobile cities, the sea round it, the lines dividing the
## regions (用户 2026-10-18: 用分割线分出各区域，海也建模), and the little
## Rhodes Island over where the ship is.
## 科研部's research tree over its console: one light per node, seven
## departments across and six tiers up, lit by set_research (no text).
var research_lights := {}
const RESEARCH_HOLO_HEIGHT := 1.3
const RESEARCH_HOLO_PITCH := Vector2(0.55, 0.42)

func _add_research_holo(root: Node3D, x: float, z: float) -> void:
	var dot := BoxMesh.new()
	dot.size = Vector3(0.22, 0.22, 0.05)
	for c in range(ResearchCatalog.DEPARTMENTS.size()):
		var department: String = ResearchCatalog.DEPARTMENTS[c]
		for t in range(1, 7):
			var mi := MeshInstance3D.new()
			mi.mesh = dot
			mi.position = Vector3(EAST * (x + (c - 3) * RESEARCH_HOLO_PITCH.x), RESEARCH_HOLO_HEIGHT + (t - 1) * RESEARCH_HOLO_PITCH.y, z)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(mi)
			research_lights[ResearchCatalog.node_id(department, t)] = mi
	_lamps.append({"at": to_world(x, z - 1.0, 1.5), "color": Color(0.9, 0.55, 0.25), "radius": 5.0})
	set_research([], [])

## Done nodes in their department's colour, running ones bright, the rest faint.
func set_research(done: Array, running: Array) -> void:
	for id in research_lights:
		var colour: Color = ResearchCatalog.DEPARTMENT_COLORS[ResearchCatalog.department_of(id)]
		var strength := 1.4 if id in done else (2.2 if id in running else 0.25)
		(research_lights[id] as MeshInstance3D).material_override = _hologram(colour if id in done or id in running else Color(0.55, 0.75, 0.85), strength)

func _add_hologram(root: Node3D, x: float, z: float) -> void:
	_holo_centre = Vector2(x, z)
	var origin := Vector3(EAST * x, HOLO_HEIGHT, z)
	root.add_child(_holo_hexes(origin))
	root.add_child(_holo_sea(origin))
	_holo_borders(root, origin)
	_holo_landscape(root, origin)
	root.add_child(_holo_cities(origin))
	ship_marker = MeshInstance3D.new()
	ship_marker.name = "HoloRhodes"
	ship_marker.mesh = load(KIT % "holo_rhodes").instantiate().find_children("*", "MeshInstance3D", true, false)[0].mesh
	ship_marker.material_override = _hologram(Color(0.55, 0.9, 1.0), 1.5)
	root.add_child(ship_marker)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.6
	ring.outer_radius = 0.7
	_ship_ring = MeshInstance3D.new()
	_ship_ring.mesh = ring
	_ship_ring.material_override = ship_marker.material_override
	root.add_child(_ship_ring)
	set_ship_at(TerraMap.START)

## Forests by kind, peaks (snow-capped where the chain is), dunes, mesas,
## rivers and the volcano, from make_terra_height.py's features.
func _holo_landscape(root: Node3D, origin: Vector3) -> void:
	var f := TerraMap.features()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 6
	cone.rings = 1
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 6
	ball.rings = 3
	var drum := CylinderMesh.new()
	drum.top_radius = 0.5
	drum.bottom_radius = 0.55
	drum.height = 1.0
	drum.radial_segments = 7
	drum.rings = 1
	var bar := BoxMesh.new()
	var sets := {
		"conifer": [cone, func(p): return Transform3D(Basis.from_scale(Vector3(0.26, 0.6, 0.26)), _on_table(origin, p, 0.3))],
		"broadleaf": [ball, func(p): return Transform3D(Basis.from_scale(Vector3(0.34, 0.3, 0.34)), _on_table(origin, p, 0.2))],
		"rainforest": [ball, func(p): return Transform3D(Basis.from_scale(Vector3(0.4, 0.55, 0.4)), _on_table(origin, p, 0.3))],
	}
	for kind in sets:
		var points: Array = f.forests.get(kind, [])
		var node := _holo_multimesh(sets[kind][0], points.size(), HOLO_LOOK[kind][0], HOLO_LOOK[kind][1])
		node.name = "Holo_" + kind
		for k in range(points.size()): node.multimesh.set_instance_transform(k, sets[kind][1].call(points[k]))
		root.add_child(node)
	var peaks: Array = f.peaks
	var rock := _holo_multimesh(cone, peaks.size(), HOLO_LOOK.peak[0], HOLO_LOOK.peak[1])
	rock.name = "Holo_peaks"
	var caps: Array[Transform3D] = []
	for k in range(peaks.size()):
		var p: Array = peaks[k]
		var tall := float(p[3])
		rock.multimesh.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3(1.1, tall, 1.1)), _on_table(origin, p, tall * 0.5)))
		if int(p[4]) == 1:
			caps.append(Transform3D(Basis.from_scale(Vector3(0.36, tall * 0.32, 0.36)), _on_table(origin, p, tall * 0.84 + 0.01)))
	root.add_child(rock)
	var snow := _holo_multimesh(cone, caps.size(), HOLO_LOOK.snow[0], HOLO_LOOK.snow[1])
	snow.name = "Holo_snow"
	for k in range(caps.size()): snow.multimesh.set_instance_transform(k, caps[k])
	root.add_child(snow)
	var dunes: Array = f.dunes
	var sand := _holo_multimesh(ball, dunes.size(), HOLO_LOOK.dune[0], HOLO_LOOK.dune[1])
	sand.name = "Holo_dunes"
	for k in range(dunes.size()):
		var p: Array = dunes[k]
		sand.multimesh.set_instance_transform(k, Transform3D(Basis(Vector3.UP, float(p[3])).scaled(Vector3(0.7, 0.12, 0.2)), _on_table(origin, p, 0.03)))
	root.add_child(sand)
	var mesas: Array = f.mesas
	var butte := _holo_multimesh(drum, mesas.size(), HOLO_LOOK.mesa[0], HOLO_LOOK.mesa[1])
	butte.name = "Holo_mesas"
	for k in range(mesas.size()):
		var p: Array = mesas[k]
		var tall := float(p[3])
		butte.multimesh.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3(float(p[4]), tall, float(p[4]))), _on_table(origin, p, tall * 0.5)))
	root.add_child(butte)
	var segments: Array[Transform3D] = []
	for line in f.rivers:
		for k in range(line.size() - 1):
			var a := _on_table(origin, line[k], 0.06)
			var b := _on_table(origin, line[k + 1], 0.06)
			var mid := (a + b) * 0.5
			var length := a.distance_to(b)
			var basis := Basis.looking_at((b - a).normalized(), Vector3.UP).scaled(Vector3(0.12, 0.05, length))
			segments.append(Transform3D(basis, mid))
	var water := _holo_multimesh(bar, segments.size(), HOLO_LOOK.river[0], HOLO_LOOK.river[1])
	water.name = "Holo_rivers"
	for k in range(segments.size()): water.multimesh.set_instance_transform(k, segments[k])
	root.add_child(water)
	# 雷姆必拓南岸的晶体无人区: shards leaning every way.
	var shard := CylinderMesh.new()
	shard.top_radius = 0.0
	shard.bottom_radius = 0.5
	shard.height = 1.0
	shard.radial_segments = 4
	shard.rings = 1
	var crystals: Array = f.get("crystals", [])
	var field := _holo_multimesh(shard, crystals.size(), HOLO_LOOK.crystal[0], HOLO_LOOK.crystal[1])
	field.name = "Holo_crystals"
	for k in range(crystals.size()):
		var p: Array = crystals[k]
		var tall := float(p[3])
		var lean := Basis(Vector3.UP, float(p[4]) * 3.0) * Basis(Vector3.RIGHT, float(p[4]))
		field.multimesh.set_instance_transform(k, Transform3D(lean.scaled(Vector3(0.14, tall, 0.14)), _on_table(origin, p, tall * 0.5)))
	root.add_child(field)
	for p in f.volcanoes:
		var mount := MeshInstance3D.new()
		mount.mesh = cone
		mount.transform = Transform3D(Basis.from_scale(Vector3(1.6, 1.3, 1.6)), _on_table(origin, p, 0.65))
		mount.material_override = _hologram(HOLO_LOOK.volcano[0], HOLO_LOOK.volcano[1])
		root.add_child(mount)
		var mouth := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.12
		ring.outer_radius = 0.2
		mouth.mesh = ring
		mouth.position = _on_table(origin, p, 1.3)
		mouth.material_override = _hologram(HOLO_LOOK.crater[0], HOLO_LOOK.crater[1])
		root.add_child(mouth)

## A feature point [x, height, z, ...] on the table, `lift` above its land.
func _on_table(origin: Vector3, p: Array, lift: float) -> Vector3:
	return origin + Vector3(p[0], maxf(float(p[1]), HEX_FLOOR) + lift, p[2])

## One column per land cell (make_terra_height.py): a six-sided prism, as
## tall as the land there, its map colour and height in its custom data.
func _holo_hexes(origin: Vector3) -> MultiMeshInstance3D:
	var f := TerraMap.features()
	var hexes: Array = f.hexes
	var prism := CylinderMesh.new()
	prism.top_radius = float(f.hex) * 0.94
	prism.bottom_radius = float(f.hex) * 0.94
	prism.height = 1.0
	prism.radial_segments = 6
	prism.rings = 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = prism
	mm.instance_count = hexes.size()
	var top := float(f.top)
	for k in range(hexes.size()):
		var c: Array = hexes[k]
		var h := maxf(float(c[1]), HEX_FLOOR)
		# Pointy-topped: the prism's corner to the north.
		var basis := Basis(Vector3.UP, PI / 6.0).scaled(Vector3(1, h, 1))
		mm.set_instance_transform(k, Transform3D(basis, origin + Vector3(c[0], h * 0.5, c[2])))
		mm.set_instance_custom_data(k, Color(c[3], c[4], h / top, 0))
	var node := MultiMeshInstance3D.new()
	node.name = "HoloTerra"
	node.multimesh = mm
	var material := ShaderMaterial.new()
	material.shader = HOLOGRAM_HEX
	material.set_shader_parameter("map_tex", TERRA_MAP)
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

## The sea as low columns (make_terra_height.py "sea"): shallows by the
## coasts, deep further out, swells rolling across (base_hologram_sea).
func _holo_sea(origin: Vector3) -> MultiMeshInstance3D:
	var f := TerraMap.features()
	var cells: Array = f.get("sea", [])
	var prism := CylinderMesh.new()
	prism.top_radius = float(f.hex) * 0.94
	prism.bottom_radius = float(f.hex) * 0.94
	prism.height = 1.0
	prism.radial_segments = 6
	prism.rings = 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = prism
	mm.instance_count = cells.size()
	for k in range(cells.size()):
		var c: Array = cells[k]
		var h := float(c[1])
		mm.set_instance_transform(k, Transform3D(Basis(Vector3.UP, PI / 6.0).scaled(Vector3(1, h, 1)), origin + Vector3(c[0], h * 0.5, c[2])))
		mm.set_instance_custom_data(k, Color(c[3], c[4], 0, c[5]))
	var node := MultiMeshInstance3D.new()
	node.name = "HoloOcean"
	node.multimesh = mm
	var material := ShaderMaterial.new()
	material.shader = HOLOGRAM_SEA
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

## The lines dividing the regions (make_terra_height.py "borders"): a bright
## strip along each shared edge of two columns of different regions, on the
## taller one's top.
func _holo_borders(root: Node3D, origin: Vector3) -> void:
	var f := TerraMap.features()
	var edge := BoxMesh.new()
	edge.size = Vector3.ONE
	var length := float(f.hex) * 1.15
	var sets := [[], []]
	for b in f.get("borders", []):
		var along := Vector3(b[3], 0, b[4])
		var basis := Basis(along, Vector3.UP, along.cross(Vector3.UP)).scaled(Vector3(length, 0.05, 0.06))
		sets[int(b[5])].append(Transform3D(basis, origin + Vector3(b[0], maxf(float(b[1]), HEX_FLOOR) + 0.02, b[2])))
	for kind in range(2):
		var node := _holo_multimesh(edge, sets[kind].size(), BORDER_LOOK[kind][0], BORDER_LOOK[kind][1])
		node.name = "HoloBorders" if kind == 0 else "HoloWildBorders"
		for k in range(sets[kind].size()): node.multimesh.set_instance_transform(k, sets[kind][k])
		root.add_child(node)

func _hologram(colour: Color, strength: float, map: Texture2D = null) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = HOLOGRAM_SHADER
	material.set_shader_parameter("colour", colour)
	material.set_shader_parameter("strength", strength)
	if map != null:
		material.set_shader_parameter("use_map", true)
		material.set_shader_parameter("map_tex", map)
	return material

func _holo_multimesh(mesh: Mesh, count: int, colour: Color, strength: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = _hologram(colour, strength)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

## Each capital a cluster of towers; each mobile city its blocks on a tracked
## platform, brighter. Laid out from a seed per place, so they never change.
func _holo_cities(origin: Vector3) -> Node3D:
	var boxes: Array[Transform3D] = []
	var f := TerraMap.features()
	for name in f.capitals:
		var p: Array = f.capitals[name]
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(name)
		for k in range(6):
			var h := rng.randf_range(0.2, 0.7) * (1.6 if k == 0 else 1.0)
			var off := Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.28, 0.28)) if k > 0 else Vector3.ZERO
			boxes.append(Transform3D(Basis.from_scale(Vector3(0.18, h, 0.18)), origin + Vector3(p[0], float(p[1]) + h * 0.5, p[2]) + off))
	for name in f.mobile_cities:
		var p: Array = f.mobile_cities[name]
		var base := origin + Vector3(p[0], float(p[1]) + 0.12, p[2])
		boxes.append(Transform3D(Basis.from_scale(Vector3(0.8, 0.08, 0.5)), base))
		for side in [-1.0, 1.0]:
			boxes.append(Transform3D(Basis.from_scale(Vector3(0.82, 0.08, 0.1)), base + Vector3(0, -0.07, side * 0.27)))
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(name)
		for k in range(9):
			var h := rng.randf_range(0.12, 0.5)
			boxes.append(Transform3D(Basis.from_scale(Vector3(0.12, h, 0.12)), base + Vector3(rng.randf_range(-0.32, 0.32), h * 0.5 + 0.04, rng.randf_range(-0.18, 0.18))))
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var node := _holo_multimesh(cube, boxes.size(), CITY_COLOUR, 0.4)
	node.name = "HoloCities"
	for k in range(boxes.size()):
		node.multimesh.set_instance_transform(k, boxes[k])
	return node

## Puts the marker over `place` (TerraMap) on the table, at the land's height.
func set_ship_at(place: String) -> void:
	if ship_marker == null: return
	ship_place = place
	var p := TerraMap.place_local(place)
	var at := Vector3(EAST * _holo_centre.x, HOLO_HEIGHT, _holo_centre.y) + p
	_ship_base_y = at.y + SHIP_HOVER
	ship_marker.position = Vector3(at.x, _ship_base_y, at.z)
	_ship_ring.position = at + Vector3(0, 0.04, 0)

## Under way: the ship `t` (0–1) along the leg from `from` to `to`.
func set_ship_between(from: String, to: String, t: float) -> void:
	if ship_marker == null: return
	ship_place = to
	var p := TerraMap.place_local(from).lerp(TerraMap.place_local(to), clampf(t, 0.0, 1.0))
	var at := Vector3(EAST * _holo_centre.x, HOLO_HEIGHT, _holo_centre.y) + p
	_ship_base_y = at.y + SHIP_HOVER
	ship_marker.position = Vector3(at.x, _ship_base_y, at.z)
	_ship_ring.position = at + Vector3(0, 0.04, 0)

## Whether a pixel prop stands where the layout has put a new area (PROP_CLEAR).
func _cleared(room_id: String, x: float, z: float) -> bool:
	for r in PROP_CLEAR.get(room_id, []):
		if x >= r[0] and x <= r[2] and z >= r[1] and z <= r[3]: return true
	return false

## The command dais's footprint: its crescent desk, segment by segment, and the
## hologram's emitter in the middle (the Doctor stands beside it). The dais
## itself is a low step she walks onto.
func _dais_colliders(x: float, z: float) -> void:
	for k in range(7):
		var a := deg_to_rad(-60.0 + k * 20.0)
		var cx := x - DAIS_DESK * sin(a)
		var cz := z + DAIS_DESK * cos(a)
		_add_box(cx - 0.85, cz - 0.55, cx + 0.85, cz + 0.55)
	_add_box(x - 0.7, z - 0.7, x + 0.7, z + 0.7)

## A placed prop's footprint as it now stands (scaled and turned), a little
## inside its outline so she can walk up to it (用户 2026-10-18: 这里会发生
## 重叠，修复 — the old pixel boxes were smaller than the models).
func _model_box(piece: MeshInstance3D) -> void:
	var box := piece.transform * piece.mesh.get_aabb()
	var inset := 0.12
	var x0 := (box.position.x + box.size.x) * EAST
	var x1 := box.position.x * EAST
	_add_box(minf(x0, x1) + inset, box.position.z + inset, maxf(x0, x1) - inset, box.position.z + box.size.z - inset)

## A ward bed's surroundings (用户 2026-10-18: 医疗部太空了): its bedside
## cabinet with a monitor and a visitor's chair on its east side, the privacy
## curtain on its rail further east, and on the north wards the service panel
## on the wall over its head. `at` is the bed's centre (world, room-local).
func _dress_bed(root: Node3D, at: Vector3, north_ward: bool, z0: float) -> void:
	var x := at.x * EAST
	var k := PROP_SCALE
	_place_kit(root, "med_bed_side", Vector3(EAST * (x + 1.5 * k), 0.0, at.z + 0.4 * k))
	_add_box(x + 1.5 * k - 0.45 * k, at.z + 0.1 * k, x + 1.5 * k + 0.45 * k, at.z + 0.7 * k)
	_place_kit(root, "med_curtain", Vector3(EAST * (x + 3.3), 0.0, at.z), PI / 2.0)
	if north_ward: _place_kit(root, "med_head_panel", Vector3(EAST * x, 1.05 * k, z0 - 0.02))

## A warehouse rack (B-M2), stowed below the deck under its hatch until
## RoomReveal raises it: the rack, the hatch frame round its pit and the two
## leaves that swing up out of the way. Kept per group ("shelf:<zone>:<slot>").
func _add_rack(root: Node3D, entry: Dictionary, zone: String) -> void:
	var at := Vector3(EAST * float(entry.x), 0.0, float(entry.z))
	var rack := _place_kit(root, "rack_" + zone, at)
	var hatch := _place_kit(root, "rack_hatch", at + Vector3(0, 0.002, 0))
	var leaves: Array[MeshInstance3D] = []
	for side in [1.0, -1.0]:
		var leaf := _place_kit(root, "rack_hatch_leaf", at)
		leaf.set_meta("side", side)
		leaves.append(leaf)
	var rack_entry := {"node": rack, "hatch": hatch, "leaves": leaves, "zone": zone, "cells": [], "at": at}
	room_visuals[_building_room].racks[str(entry.group)] = rack_entry
	set_hatch(rack_entry, 0.0)

## The cells on a front-row rack's shelves: one item model each, shown as the
## zone fills (WarehouseView). Children of the rack, so they rise with it.
func _add_cells(room_id: String, entry: Dictionary) -> void:
	var rack: Dictionary = room_visuals[room_id].racks.get(str(entry.group), {})
	if rack.is_empty(): return
	var node: MeshInstance3D = rack.node
	var previous := _building_room
	_building_room = room_id
	for row in CELL_ROWS:
		for column in CELL_COLUMNS:
			var cell := _place_kit(node, "cell_" + str(rack.zone), Vector3(column, row, -0.05))
			cell.visible = false
			rack.cells.append(cell)
	_building_room = previous

## Swings a rack's hatch leaves: 0 shut flat over the pit, 1 stood up at its
## front and back. Each leaf runs from its inner edge (its origin) along its
## own +z, and turns about its outer edge.
func set_hatch(rack: Dictionary, open: float) -> void:
	var angle := clampf(open, 0.0, 1.0) * deg_to_rad(95.0)
	for leaf: MeshInstance3D in rack.leaves:
		var side: float = leaf.get_meta("side")  # 1 the north leaf, -1 the south
		var outer: Vector3 = rack.at + Vector3(0.0, 0.0, side * HATCH_LEAF)
		var face := Basis.IDENTITY if side > 0.0 else Basis(Vector3.UP, PI)
		var turn := Basis(Vector3.RIGHT, side * angle) * face
		leaf.transform = Transform3D(turn * Basis.from_scale(prop_scale("rack_hatch_leaf")), outer - turn * Vector3(0.0, 0.0, HATCH_LEAF))

## Thin wall colliders inside a room (the medical bay's corridor and wards)
## stand as partitions: half walls with glazing bars, so the rooms behind show.
func _partitions(root: Node3D, room: Dictionary) -> void:
	var x0: float = room.origin[0]
	var z0: float = room.origin[1]
	var x1: float = x0 + float(room.size[0])
	var z1: float = z0 - float(room.size[1])
	for box in room.colliders:
		var a := Vector2(minf(box[0], box[2]), minf(box[1], box[3]))
		var b := Vector2(maxf(box[0], box[2]), maxf(box[1], box[3]))
		var on_edge := absf(a.y - z0) < EDGE_SLACK or absf(b.y - z1) < EDGE_SLACK or absf(b.x - x0) < EDGE_SLACK or absf(a.x - x1) < EDGE_SLACK
		if on_edge: continue
		var along_x := b.x - a.x > b.y - a.y
		var length := maxf(b.x - a.x, b.y - a.y)
		if length < 0.5: continue
		var mid := (a + b) * 0.5
		_place_kit(root, "med_partition", Vector3(EAST * mid.x, 0.0, mid.y), 0.0 if along_x else PI / 2.0, Vector3(length / 4.0, 1.0, 1.0))

## A model added at run time (a receiving crate, a pallet's load): placed at
## layout (x, z), `y` above the floor, lit with the room. Free it with
## remove_model().
func add_model(room_id: String, model: String, x: float, z: float, yaw: float = 0.0, y: float = 0.0) -> MeshInstance3D:
	_building_room = room_id
	var piece := _place_kit(get_node(NodePath(room_id)), model, Vector3(EAST * x, y, z), yaw)
	_building_room = ""
	var visuals: Dictionary = room_visuals[room_id]
	if visuals.has("bands"):
		for material in _materials_of(piece): _light_material(material, visuals.bands[0], visuals.bands[1])
	return piece

func remove_model(room_id: String, piece: MeshInstance3D) -> void:
	for material in _materials_of(piece):
		room_visuals[room_id].shaders.erase(material)
		_see_through_kit.erase(material)
	piece.queue_free()

## A placed kit piece's own (see-through) materials.
func _materials_of(piece: MeshInstance3D) -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for surface in range(piece.mesh.get_surface_count()):
		var material := piece.get_surface_override_material(surface) as ShaderMaterial
		if material: out.append(material)
	return out

func _prop_spec(entry: Dictionary) -> Array:
	return PROP_MODELS.get(str(entry.tex).get_file().left(8), [])

## Where a room's walls are open: the gaps its wall colliders leave along each
## side, [from, to] in run coordinates (layout x for the north wall, -z for
## the west and east).
func _wall_openings(room: Dictionary) -> Dictionary:
	var x0: float = room.origin[0]
	var z0: float = room.origin[1]
	var size_x: float = room.size[0]
	var size_z: float = room.size[1]
	var spans := {"north": [], "west": [], "east": []}
	for box in room.colliders:
		var a := Vector2(minf(box[0], box[2]), minf(box[1], box[3]))
		var b := Vector2(maxf(box[0], box[2]), maxf(box[1], box[3]))
		# The rooms' exported walls sit up to a few cm off their edge.
		if absf(a.y - z0) < EDGE_SLACK and b.y - a.y < 1.0: spans.north.append([a.x, b.x])
		elif absf(b.x - x0) < EDGE_SLACK: spans.west.append([-b.y, -a.y])
		elif absf(a.x - (x0 + size_x)) < EDGE_SLACK: spans.east.append([-b.y, -a.y])
	var ends := {"north": [x0, x0 + size_x], "west": [-z0, -z0 + size_z], "east": [-z0, -z0 + size_z]}
	var out := {"north": [], "west": [], "east": []}
	for side in spans:
		var list: Array = spans[side]
		list.sort_custom(func(p, q): return p[0] < q[0])
		var at: float = ends[side][0]
		for span in list:
			if span[0] - at > 1.0: out[side].append([at, span[0]])
			at = maxf(at, span[1])
		if float(ends[side][1]) - at > 1.0: out[side].append([at, ends[side][1]])
	return out

## The doorway at `gap` on `side` ([from, to] along the run): an airlock,
## or a blast door when it is sealed (SEALED_DOORS), which a collider shuts.
func _door_model(room: Dictionary, side: String, gap: Array) -> String:
	var mid: float = (float(gap[0]) + float(gap[1])) * 0.5
	if float(gap[1]) - float(gap[0]) > OPENING: return "-"
	for entry in SEALED_DOORS.get(room.id, []):
		if entry[0] != side: continue
		var at: float = float(entry[1]) if side == "north" else -float(entry[1])
		if absf(at - mid) > 1.6: continue
		var x0: float = room.origin[0]
		var z0: float = room.origin[1]
		match side:
			"north": _add_box(mid - 2.0, z0 - 0.7, mid + 2.0, z0 + 0.7)
			"west": _add_box(x0 - 0.7, -mid - 2.0, x0 + 0.7, -mid + 2.0)
			"east": _add_box(x0 + float(room.size[0]) - 0.7, -mid - 2.0, x0 + float(room.size[0]) + 0.7, -mid + 2.0)
		return "sealed_door"
	return "wall_door"

## Lays a wall from `from` to `to` (run coordinates; `place` turns one into a
## local position): the pieces in `fixed` ([from, to, model]; a doorway sits
## centred in a 4 m bay) and plain bays between them, stretched to fit.
func _wall_run(root: Node3D, from: float, to: float, place: Callable, yaw: float, fixed: Array, height: float) -> void:
	var pieces: Array = []
	for f in fixed:
		# "-": an opening, left without a wall.
		if f[2] == "-":
			pieces.append([f[0], f[1], ""])
			continue
		var mid: float = (f[0] + f[1]) * 0.5
		var half: float = PIECE_HALF.get(f[2], WALL_BAY * 0.5)
		pieces.append([mid - half, mid + half, f[2]])
	pieces.sort_custom(func(p, q): return p[0] < q[0])
	pieces.append([to, to, ""])
	var at := from
	for p in pieces:
		var gap: float = p[0] - at
		if gap > 0.2:
			var count := maxi(1, roundi(gap / WALL_BAY))
			var bay := gap / count
			for k in range(count):
				_place_kit(root, WALL_MODELS.get(_building_room, "wall_panel"), place.call(at + (k + 0.5) * bay), yaw, Vector3(bay / WALL_BAY, height * WALL_HEIGHT, 1.0))
		if p[2] != "":
			_place_kit(root, p[2], place.call((p[0] + p[1]) * 0.5), yaw, Vector3(1.0, height * (WALL_HEIGHT if p[2] in ["wall_door", "sealed_door"] else 1.0), 1.0))
		at = maxf(at, p[1])

## The deck: one quad over the room, the plate tiled in world space and the
## logo laid into the floor's middle.
## The room's deck plate and the metres one tile covers: Sol's if it is in, else the stand-in.
static func deck_tile(room_id: String) -> Array:
	var path: String = PAINTED + DECK_PAINTED.get(room_id, "base_deck") + ".png"
	if ResourceLoader.exists(path): return [load(path), 6.0]
	return [DECK_TILES.get(room_id, DECK_TILE), 2.0]

## A plate's mean colour, linear (the logo inlay keeps the plate's seams by
## dividing by it).
static func _mean_linear(tile: Texture2D) -> Color:
	var image := tile.get_image()
	if image == null: return Color(0.0766, 0.0927, 0.107)
	image = image.duplicate()
	if image.is_compressed(): image.decompress()
	image.resize(1, 1, Image.INTERPOLATE_BILINEAR)
	return image.get_pixel(0, 0).srgb_to_linear()

func _add_deck(root: Node3D, x0: float, z0: float, size_x: float, size_z: float, room_id := "hall", inlay_logo := true) -> void:
	var plate := deck_tile(room_id)
	var tile: Texture2D = plate[0]
	var plane := PlaneMesh.new()
	plane.size = Vector2(size_x, size_z)
	var mesh := MeshInstance3D.new()
	mesh.mesh = plane
	mesh.position = Vector3(EAST * (x0 + size_x * 0.5), 0.0, z0 - size_z * 0.5)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = DECK_SHADER
	material.set_shader_parameter("deck_tex", tile)
	material.set_shader_parameter("metres_per_tile", plate[1])
	# The plate's relief (场景渲染统一改造案_v1 S2), made from its colour beside it.
	var relief_path := tile.resource_path.replace(".png", "_normal.png")
	if ResourceLoader.exists(relief_path): material.set_shader_parameter("deck_normal", load(relief_path))
	material.set_shader_parameter("inlay_tex", LOGO)
	if _building_room != "": room_visuals[_building_room].shaders.append(material)
	# The logo lies whole between the command ring and the waiting benches.
	var inlay := minf(size_z * 0.46, 26.0)
	var centre := to_world(x0 + size_x * 0.5, z0 - size_z * 0.68)
	var spot: Array = DECK_INLAY.get(room_id, [])
	if not spot.is_empty():
		centre = to_world(spot[0], spot[1])
		inlay = spot[2]
		material.set_shader_parameter("inlay_colour", spot[3])
	if inlay_logo:
		material.set_shader_parameter("inlay_rect", Vector4(centre.x - inlay * 0.5, centre.z - inlay * 0.5, inlay, inlay))
		var mean := _mean_linear(tile)
		material.set_shader_parameter("plate_mean", Vector3(mean.r, mean.g, mean.b))
	mesh.material_override = material
	root.add_child(mesh)

## A kit model's mesh, looked up once: load() and the kit cache's key cost
## about 3 ms a call, and the base places some 900 pieces.
static var _kit_meshes := {}
static func _kit_mesh(model: String) -> Mesh:
	if not ResourceLoader.exists(KIT % model) and STAND_INS.has(model): model = str(STAND_INS[model])
	if not _kit_meshes.has(model): _kit_meshes[model] = TerraceDressing.kit_mesh(load(KIT % model))
	return _kit_meshes[model]

## One kit piece, turned `yaw` about the vertical and stretched by `scale` on
## its own axes. Its baked surfaces draw with the base's kit shader (lit by
## the light map and the room's strips); glow parts stay self-lit.
func _place_kit(root: Node3D, model: String, at: Vector3, yaw: float = 0.0, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = model
	mi.set_meta("model", model)
	mi.mesh = _kit_mesh(model)
	mi.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(scale * prop_scale(model)), at)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for surface in range(mi.mesh.get_surface_count()):
		var source := mi.mesh.surface_get_material(surface) as ShaderMaterial
		if source == null or source.shader != TerraceDressing.KIT_SHADER: continue
		var albedo: Texture2D = source.get_shader_parameter("albedo_tex")
		var key := "%s@%d" % [_building_room, albedo.get_instance_id() if albedo else 0]
		if _share_materials and _shared_kit.has(key):
			mi.set_surface_override_material(surface, _shared_kit[key])
			continue
		var material := ShaderMaterial.new()
		material.shader = KIT_SEE_THROUGH
		material.set_shader_parameter("albedo_tex", albedo)
		var relief: Texture2D = source.get_shader_parameter("normal_tex")
		if relief != null: material.set_shader_parameter("normal_tex", relief)
		if _share_materials: _shared_kit[key] = material
		mi.set_surface_override_material(surface, material)
		_see_through_kit.append(material)
		if _building_room != "": room_visuals[_building_room].shaders.append(material)
	root.add_child(mi)
	return mi

# --- 农业部 (势力特供策划案_v0_2 §四) ----------------------------------------------

## Basins by group (a group a 农业部 level; BaseWorks shows them as built).
var farm_basins: Array = []
## Basin -> {crop, stage, piece, light} for what set_farm drew there.
var _crops := {}

## Layout spot of basin `i`'s middle, and whether it runs east–west.
static func basin_spot(i: int) -> Array:
	var r := Provisions.basin_rect(i)
	var c := r.get_center()
	return [FARM_CENTRES[Provisions.swirl_of(i)] + c * FARM_TILE, r.size.x > r.size.y]

## The basins of the three swirls round their sun lamps, each one solid.
func _farm_swirl(root: Node3D) -> void:
	for i in range(Provisions.BASINS):
		var spot := basin_spot(i)
		var at: Vector2 = spot[0]
		var across: bool = spot[1]
		var piece := _place_kit(root, "hydro_basin", Vector3(EAST * at.x, 0.0, at.y), 0.0 if across else PI / 2.0)
		var group := i / Provisions.GROUP
		while farm_basins.size() <= group: farm_basins.append([])
		farm_basins[group].append(piece)
		var half := Vector2(2.0, 0.5) * FARM_TILE if across else Vector2(0.5, 2.0) * FARM_TILE
		_add_box(at.x - half.x + 0.1, at.y - half.y + 0.1, at.x + half.x - 0.1, at.y + half.y - 0.1)

## Draws what grows in each basin: its crop, taller as it grows (four
## stages), the shining ones lit once ripe.
func set_farm(provisions: Provisions) -> void:
	if not rooms.has("farm"): return
	var root := get_node_or_null("farm")
	if root == null: return
	for i in range(Provisions.BASINS):
		var plot := provisions.plot(i) if i < provisions.basins() else {}
		var crop := str(plot.get("crop", ""))
		var ripe := provisions.ripe(i) if not crop.is_empty() else false
		var stage := 0 if crop.is_empty() else (4 if ripe else 1 + mini(2, floori(provisions.growth(i) * 3.0)))
		var drawn: Dictionary = _crops.get(i, {})
		if drawn.get("crop", "") == crop and int(drawn.get("stage", 0)) == stage: continue
		if is_instance_valid(drawn.get("piece")): drawn.piece.queue_free()
		if is_instance_valid(drawn.get("light")): drawn.light.queue_free()
		_crops[i] = {"crop": crop, "stage": stage}
		if crop.is_empty(): continue
		var spot := basin_spot(i)
		var at: Vector2 = spot[0]
		var model: String = CROP_MODELS.get(crop, "crop_wheat")
		if ripe and CROP_GLOW.has(crop): model += "_ripe"
		var piece := _place_kit(root, model, Vector3(EAST * at.x, CROP_Y, at.y), 0.0 if spot[1] else PI / 2.0)
		piece.scale.y *= [0.0, 0.3, 0.55, 0.8, 1.0][stage]
		_crops[i].piece = piece
		if ripe and CROP_GLOW.has(crop):
			var light := OmniLight3D.new()
			light.light_color = CROP_GLOW[crop]
			light.light_energy = 0.9
			light.omni_range = 3.5
			light.shadow_enabled = false
			light.position = Vector3(EAST * at.x, 1.2, at.y)
			root.add_child(light)
			_crops[i].light = light

## The camera's deck (GameManager.ride_lift).
func set_deck(value: int) -> void:
	deck = value
