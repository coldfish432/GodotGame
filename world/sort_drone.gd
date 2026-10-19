class_name SortDrone
extends Node

## The engineering department's cargo drone (基地玩法策划案 §3.5): after "sort
## everything", it flies from receiving to each zone that got something and
## back, along the forklift lane, hanging under the overhead. Only a show: the
## items are already on their shelves when it takes off, and it never blocks
## Lappland. A run is capped so it never lasts long.

const ROOM := "warehouse"
const HEIGHT := 3.2            # flying height above the deck (m), over the racks
const LEG_SECONDS := 0.9       # receiving to a zone, or back
const MAX_SECONDS := 6.0

var map: BaseMap
var model: MeshInstance3D
var _route: Array[Vector2] = []   # layout points, receiving first
var _time := 0.0
var _duration := 0.0

func setup(p_map: BaseMap) -> void:
	map = p_map
	model = map.add_model(ROOM, "cargo_drone", 0, 0, 0.0, HEIGHT)
	model.visible = false

func flying() -> bool: return model != null and model.visible

## Flies receiving -> each of `stops` -> receiving.
func fly(start: Vector2, stops: Array[Vector2]) -> void:
	if model == null or stops.is_empty(): return
	_route = [start]
	for stop in stops:
		_route.append(stop)
		_route.append(start)
	_duration = minf(LEG_SECONDS * (_route.size() - 1), MAX_SECONDS)
	_time = 0.0
	model.visible = true
	_place(start)

func _process(delta: float) -> void:
	if not flying(): return
	_time += delta
	if _time >= _duration:
		model.visible = false
		return
	var legs := _route.size() - 1
	var at := _time / _duration * legs
	var leg := mini(int(at), legs - 1)
	var t := at - leg
	t = t * t * (3.0 - 2.0 * t)
	_place(_route[leg].lerp(_route[leg + 1], t))

func _place(p: Vector2) -> void:
	model.position = Vector3(BaseMap.EAST * p.x, HEIGHT + sin(_time * 9.0) * 0.04, p.y)
