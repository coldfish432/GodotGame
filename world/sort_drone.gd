class_name SortDrone
extends Node

## The engineering department's cargo drone (基地玩法策划案 §3.5): after "sort
## everything", it flies from receiving to each zone that got something and
## back, along the forklift lane, hanging under the overhead. Only a show: the
## items are already on their shelves when it takes off, and it never blocks
## Lappland. A run is capped so it never lasts long.

const ROOM := "warehouse"
const LIFT_PX := 44.0          # flying height above the floor
const LEG_SECONDS := 0.9       # receiving to a zone, or back
const MAX_SECONDS := 6.0

var map: BaseMap
var sprite: Sprite3D
var _route: Array[Vector2] = []   # layout points, receiving first
var _time := 0.0
var _duration := 0.0

func setup(p_map: BaseMap, texture: Texture2D) -> void:
	map = p_map
	sprite = map.add_prop(ROOM, texture, 0, 0, LIFT_PX)
	sprite.visible = false
	sprite.no_depth_test = true
	sprite.render_priority = 8

func flying() -> bool: return sprite != null and sprite.visible

## Flies receiving -> each of `stops` -> receiving.
func fly(start: Vector2, stops: Array[Vector2]) -> void:
	if sprite == null or stops.is_empty(): return
	_route = [start]
	for stop in stops:
		_route.append(stop)
		_route.append(start)
	_duration = minf(LEG_SECONDS * (_route.size() - 1), MAX_SECONDS)
	_time = 0.0
	sprite.visible = true
	_place(start)

func _process(delta: float) -> void:
	if not flying(): return
	_time += delta
	if _time >= _duration:
		sprite.visible = false
		return
	var legs := _route.size() - 1
	var at := _time / _duration * legs
	var leg := mini(int(at), legs - 1)
	var t := at - leg
	t = t * t * (3.0 - 2.0 * t)
	_place(_route[leg].lerp(_route[leg + 1], t))

func _place(p: Vector2) -> void:
	# Whole layout pixels, so it moves on the art's grid.
	map.place_billboard(sprite, roundf(p.x * 15.0) / 15.0, roundf(p.y * 12.7) / 12.7, LIFT_PX)
	sprite.modulate = Color.WHITE
