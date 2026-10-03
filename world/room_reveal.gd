class_name RoomReveal
extends Node

## The warehouse lights come on the way a big storage hall's do: bank by bank
## from the door inward, each bank with a short fluorescent flicker, and a
## pause before the next. Once a bank is lit, the floor hatch under each shelf
## in it opens, and the shelf rises slowly out of it. Leaving stows the shelves,
## shuts the hatches and switches everything off. The racks are Lappland's
## personal storage, brought up when she walks in (基地玩法策划案_v1_0.md §3.6).
##
## Shelves wait for the screen before rising: the warehouse is wider than one,
## and from the east door the far racks are past the edge of the view. By the
## time she walks over, their bank is lit and their hatch open, so the rise is
## all she sees and all she waits for.
##
## Everything is quantised: a bank is either lit or dark, the hatch jumps
## between frames, and a shelf rises a whole pixel at a time by cropping its
## sprite at the floor line (region_rect), keeping the pixel grid.
##
## The signals mark the moments that will get sounds (not yet made).

signal bank_lit(index: int)      # a bank's lights clunk on (after its flicker)
signal hatch_opening(shelf: int)
signal shelf_rising(shelf: int)
signal lights_out

const BANKS := 4                 # equal strips across the room, door side first
const BANK_PAUSE := 0.45         # from one bank switching on to the next
const FLICKER := [0.0, 0.07, 0.14]  # on, off, on again (seconds after the bank's turn)
const IDLE := 0.6               # the whole room before she walks in: dim, never black
## Strips not yet lit catch light from the lit ones: the next strip over, the
## one after, and anything further. So each bank brightens the whole room a step.
const SPILL := [0.85, 0.75, 0.68]
const HATCH_DELAY := 0.25        # a beat after the bank lights up
const HATCH_OPEN := 0.5          # the hatch's frames, evenly
const SHELF_RISE := 1.2          # slow and mechanical
const SHELF_STAGGER := 0.3       # each row further back starts this much later
const COLUMN_STAGGER := 0.1      # and each rack along a row this much
const LEAVE_SPEED := 2.5
## Hysteresis around the room edge so standing in the doorway does not flicker.
const EDGE := 0.3
## A shelf rises once its centre is this far inside the view (half a screen is 21.3 units).
const VIEW_HALF_WIDTH := 21.3 - 3.0

var base_map: BaseMap
var room_id := ""
var t := 0.0                     # lights clock: 0 dark .. lights_time all banks on
var lights_time := 0.0
var inside := false
var hatch_frames: Array[Texture2D] = []
var bank_edges: Array[float] = []  # layout x of each bank's west edge, door side first
## Per shelf: {sprites, hatch, height_px, east, south, bank, hold, clock}. clock
## starts once its bank is lit: hatch from HATCH_DELAY, rise from `hold`
## (end of the hatch plus any stagger), but it stops at `hold` until the shelf
## is on screen.
var _shelves: Array[Dictionary] = []
## Whether a rack slot is built: func(category_key: String, slot: int) -> bool.
## Unbuilt racks stay hidden with their hatch; without a check every rack is built.
var built_check := Callable()
var _lit_banks := 0
var _announced := 0              # banks whose clunk has been signalled
var _last_lit := -1

func setup(map: BaseMap, room: String, group_prefix: String) -> void:
	base_map = map
	room_id = room
	var data: Dictionary = map.rooms[room]
	var west: float = data.origin[0]
	var width: float = data.size[0]
	for k in range(BANKS):
		bank_edges.append(west + width * (1.0 - float(k + 1) / BANKS))
	bank_edges[BANKS - 1] = -INF  # the last bank reaches past the wall
	lights_time = BANK_PAUSE * (BANKS - 1) + FLICKER.back()
	for path in data.get("anim", {}).get("shelf_hatch", []):
		hatch_frames.append(map.texture_at(path))
	var groups: Dictionary = map.room_visuals[room].groups
	for name in groups:
		if not str(name).begins_with(group_prefix): continue
		var sprites: Array = groups[name]
		var height := 0.0
		var rack: Sprite3D = sprites[0]
		for sprite: Sprite3D in sprites:
			sprite.region_enabled = true
			sprite.set_meta("lift_px", _lift_px(sprite))
			height = maxf(height, sprite.texture.get_height() + sprite.get_meta("lift_px"))
			if sprite.texture.get_width() * sprite.texture.get_height() > rack.texture.get_width() * rack.texture.get_height(): rack = sprite
		var east := rack.position.x * BaseMap.EAST
		var hatch_mesh: MeshInstance3D = null
		if not hatch_frames.is_empty():
			# The hatch's front lip lies on the rack's feet line, where the rising sprite is cropped.
			hatch_mesh = map.add_floor_decal(room, hatch_frames[0], east, rack.position.z)
		# Group names are "shelf:<category>:<slot>"; slot 0-8 in build order, 3 per row from the front.
		var parts := str(name).split(":")
		var slot := int(parts[2]) if parts.size() > 2 else 0
		_shelves.append({"sprites": sprites, "hatch": hatch_mesh.material_override if hatch_mesh else null, "hatch_mesh": hatch_mesh,
			"height_px": height, "east": east, "south": -rack.position.z, "bank": bank_of(east), "clock": 0.0, "frame": -1, "rows": -1.0,
			"category": parts[1] if parts.size() > 1 else "", "slot": slot, "built": true,
			"hold": HATCH_DELAY + HATCH_OPEN + SHELF_STAGGER * (slot / 3) + COLUMN_STAGGER * (slot % 3)})
	# Nearest the door first, front row before back.
	_shelves.sort_custom(func(a, b): return a.east > b.east if not is_equal_approx(a.east, b.east) else a.south > b.south)
	reset()

## Re-reads which racks are built. A newly built rack starts stowed with its
## hatch shut, and rises like the others once its bank is lit and it is on screen.
func refresh_built() -> void:
	for shelf in _shelves:
		var built: bool = not built_check.is_valid() or built_check.call(shelf.category, shelf.slot)
		if built == shelf.built: continue
		shelf.built = built
		shelf.clock = 0.0
		shelf.frame = -1
		shelf.rows = -1.0
	_apply()

func built_shelves() -> Array[Dictionary]:
	return _shelves.filter(func(s): return s.built)

func bank_of(layout_x: float) -> int:
	for k in range(BANKS):
		if layout_x >= bank_edges[k]: return k
	return BANKS - 1

## Light level of each bank while `lit` banks are on.
func bank_levels(lit: int) -> Array:
	var levels := []
	for k in range(BANKS):
		if lit == 0: levels.append(IDLE)
		elif k < lit: levels.append(1.0)
		else: levels.append(SPILL[mini(k - lit, SPILL.size() - 1)])
	return levels

## When bank k's turn comes on the lights clock.
func bank_time(k: int) -> float:
	return BANK_PAUSE * k

## Lights out, hatches shut, shelves stowed: the state every return to base starts from.
func reset() -> void:
	t = 0.0
	inside = false
	_lit_banks = 0
	_announced = 0
	_last_lit = -1
	for shelf in _shelves:
		shelf.clock = 0.0
		shelf.frame = -1
		shelf.rows = -1.0
	_apply()

## True once every bank is lit and every built shelf stands.
func settled() -> bool:
	return t >= lights_time and built_shelves().all(func(s): return s.clock >= s.hold + SHELF_RISE)

## True once everything is dark, shut and stowed.
func stowed() -> bool:
	return t <= 0.0 and _shelves.all(func(s): return s.clock <= 0.0)

## How many banks are lit now, counting the flicker's off beat as dark.
func lit_banks() -> int:
	if t <= 0.0: return 0
	var lit := 0
	for k in range(BANKS):
		var since := t - bank_time(k)
		if since < 0.0: break
		if since >= FLICKER[1] and since < FLICKER[2]: break  # the flicker's off beat
		lit = k + 1
	return lit

func _process(delta: float) -> void:
	var player := base_map.player
	if not is_instance_valid(player): return
	inside = base_map.room_contains(room_id, player.global_position, EDGE if not inside else -EDGE)
	var view_east := BaseMap.EAST * (base_map.clamp_camera(player.global_position).x - BaseMap.ORIGIN.x)
	var any_out := false
	for i in range(_shelves.size()):
		var shelf: Dictionary = _shelves[i]
		var before: float = shelf.clock
		if not shelf.built: continue
		if inside:
			var lit_for: float = t - bank_time(shelf.bank) - FLICKER.back()
			if lit_for >= 0.0:
				var on_screen := absf(shelf.east - view_east) < VIEW_HALF_WIDTH
				var limit: float = shelf.hold + SHELF_RISE if on_screen or before > shelf.hold else shelf.hold
				shelf.clock = minf(before + delta, limit)
		else:
			shelf.clock = maxf(before - delta * LEAVE_SPEED, 0.0)
		if before < HATCH_DELAY and shelf.clock >= HATCH_DELAY: hatch_opening.emit(i)
		if before <= shelf.hold and shelf.clock > shelf.hold: shelf_rising.emit(i)
		if shelf.clock > 0.0: any_out = true
	# On the way out the lights stay on until every hatch is shut.
	if inside: t = minf(t + delta, lights_time)
	elif not any_out and t > 0.0:
		t = 0.0
		lights_out.emit()
	_apply()

func _apply() -> void:
	var lit := lit_banks()
	# Once per bank, when it comes back on after the flicker's off beat.
	if lit > _announced and t - bank_time(lit - 1) >= FLICKER.back():
		_announced = lit
		bank_lit.emit(lit - 1)
	if lit == 0: _announced = 0
	_lit_banks = lit
	if lit != _last_lit:
		_last_lit = lit
		base_map.set_room_bands(room_id, bank_edges.slice(0, 3), bank_levels(lit))
	for shelf in _shelves:
		if shelf.hatch_mesh: shelf.hatch_mesh.visible = shelf.built
		if not shelf.built:
			if shelf.rows != INF:
				shelf.rows = INF
				for sprite: Sprite3D in shelf.sprites: sprite.visible = false
			continue
		var frame := 0
		if not hatch_frames.is_empty():
			var open := clampf((shelf.clock - HATCH_DELAY) / HATCH_OPEN, 0.0, 1.0)
			frame = clampi(floori(open * (hatch_frames.size() - 1) + 0.0001), 0, hatch_frames.size() - 1)
			if frame != shelf.frame and shelf.hatch:
				shelf.frame = frame
				shelf.hatch.set_shader_parameter("tex", hatch_frames[frame])
		var p := clampf((shelf.clock - shelf.hold) / SHELF_RISE, 0.0, 1.0)
		var eased := p * p * (3.0 - 2.0 * p)  # slow start and stop, like a lift
		var hidden := ceilf(shelf.height_px * (1.0 - eased))
		if hidden != shelf.rows:
			shelf.rows = hidden
			for sprite: Sprite3D in shelf.sprites:
				_crop(sprite, hidden)

func hatch_frame(index: int) -> int: return maxi(_shelves[index].frame, 0)

## Shows the part of the sprite above the floor line once the whole shelf has
## sunk by `hidden` pixels: the top rows, bottom edge on the floor line.
func _crop(sprite: Sprite3D, hidden: float) -> void:
	var size := sprite.texture.get_size()
	var lift: float = sprite.get_meta("lift_px")
	var rows := clampf(roundf(size.y + lift - hidden), 0.0, size.y)
	sprite.visible = rows > 0.0
	if not sprite.visible: return
	sprite.region_rect = Rect2(0, 0, size.x, rows)
	sprite.offset = Vector2(0, rows * 0.5 + maxf(lift - hidden, 0.0) - BaseMap.PIVOT_SCREEN_PX)

## Inverse of BaseMap._billboard(): offset.y = height / 2 + lift - pivot.
static func _lift_px(sprite: Sprite3D) -> float:
	return sprite.offset.y - sprite.texture.get_height() * 0.5 + BaseMap.PIVOT_SCREEN_PX
