class_name BaseMarkers
extends Node

## The base's interaction markers (美术策划案 v2.0 §3.3, 基地玩法策划案 §5.2): a
## small cyan diamond over every station, yellow while that station has
## something to do. Which stations want attention is GameManager's call
## (station_needs_attention); this node only draws.

## Pixels above the station's spot. Tall consoles get their marker higher; spots
## the player walks onto (no prop) get it lower.
const LIFT_PX := 50.0
const LIFT_BY_STATION := {"lift": 80.0, "outbound": 36.0, "pharmacy": 36.0, "decon": 36.0, "receiving_bays": 46.0}
const BOB_PX := 2.0          # a slow two-pixel bob so the eye finds them
const BOB_SECONDS := 1.2

var game: GameManager
var map: BaseMap
var cyan: Texture2D
var yellow: Texture2D
var _markers := {}           # station id -> Sprite3D
var _time := 0.0

func setup(p_game: GameManager, p_map: BaseMap) -> void:
	game = p_game
	map = p_map
	var hall: Dictionary = map.rooms.get("hall", {})
	var textures: Dictionary = hall.get("textures", {})
	if not textures.has("marker_cyan") or not textures.has("marker_yellow"): return
	cyan = map.texture_at(textures.marker_cyan)
	yellow = map.texture_at(textures.marker_yellow)
	for station in map.interactables:
		var p := _layout(station.position)
		var sprite := map.add_prop(station.room, cyan, p.x, p.y, _lift(station.id))
		sprite.no_depth_test = true    # over props and people, like a HUD element in the world
		sprite.render_priority = 9
		_markers[station.id] = sprite
	_extra("receiving_bays")

## A marker at a warehouse spot that is not an exported station (the receiving bays).
func _extra(id: String) -> void:
	var anchors: Dictionary = map.rooms.get("warehouse", {}).get("anchors", {})
	if not anchors.has("bays"): return
	var bay: Array = anchors.bays[1]
	var sprite := map.add_prop("warehouse", cyan, bay[0], bay[1], _lift(id))
	sprite.no_depth_test = true
	sprite.render_priority = 9
	_markers[id] = sprite

func _process(delta: float) -> void:
	if not is_instance_valid(game) or _markers.is_empty(): return
	_time += delta
	var bob := roundf(sin(_time * TAU / BOB_SECONDS) * BOB_PX)
	for id in _markers:
		var sprite: Sprite3D = _markers[id]
		var attention := game.station_needs_attention(id)
		sprite.visible = attention or id != "receiving_bays"
		sprite.texture = yellow if attention else cyan
		sprite.modulate = Color.WHITE  # markers ignore the room lights
		sprite.offset.y = sprite.texture.get_height() * 0.5 + _lift(id) + bob - BaseMap.PIVOT_SCREEN_PX

func marker(id: String) -> Sprite3D:
	return _markers.get(id)

static func _lift(id: String) -> float:
	return LIFT_BY_STATION.get(id, LIFT_PX)

func _layout(global: Vector3) -> Vector2:
	return Vector2((global.x - BaseMap.ORIGIN.x) / BaseMap.EAST, global.z - BaseMap.ORIGIN.z)
