class_name MedicalView
extends Node

## The medical bay drawn from GameManager.base (基地玩法策划案_v1_0.md §4):
##   - the front desk switches to its alert state while there is an unread
##     recovery report or an untreated injury;
##   - the contamination scan gate shows red at 40 or more, green below;
##   - walking through the gate gives a free reading. It is the only way
##     between the lobby and the wards, so after a death she always sees it.

const ROOM := "medical"
const GATE_HALF_DEPTH := 2.0   # units north and south of the gate's centre that count as passing it

var game: GameManager
var map: BaseMap
var tex := {}
var _reception: Sprite3D
var _gate: MeshInstance3D
var _gate_x := 0.0
var _gate_z := 0.0
var _last_side := 0             # which side of the gate she was on: -1 west (lobby), 1 east (wards)

func setup(p_game: GameManager, p_map: BaseMap) -> void:
	game = p_game
	map = p_map
	var room: Dictionary = map.rooms.get(ROOM, {})
	for name in room.get("textures", {}):
		tex[name] = map.texture_at(room.textures[name])
	if tex.is_empty(): return
	for sprite: Sprite3D in map.room_visuals[ROOM].sprites:
		if sprite.get_meta("role", "") == "reception": _reception = sprite
	var gate: Array = room.anchors.gate
	_gate_x = gate[0]
	_gate_z = gate[1] + tex.gate_red.get_height() * 0.5 / BaseMap.GROUND_PX_PER_UNIT
	_gate = map.add_floor_decal(ROOM, tex.gate_red, gate[0], gate[1])
	_gate.position.y += 0.001  # over the copy baked into the floor
	refresh()

func ready() -> bool: return not tex.is_empty()

func _process(_delta: float) -> void:
	if not ready() or not is_instance_valid(game): return
	refresh()
	if not game.in_base: return
	var p := _layout(game.player.global_position)
	if absf(p.y - _gate_z) > GATE_HALF_DEPTH or absf(p.x - _gate_x) > 3.0:
		_last_side = 0
		return
	var side := -1 if p.x < _gate_x else 1
	if _last_side != 0 and side != _last_side: game.set_message(reading())
	_last_side = side

func refresh() -> void:
	var base: BaseState = game.base
	var alert := base.report_unread or base.injured
	if _reception: _reception.texture = tex.reception_alert if alert else tex.reception_idle
	if _gate: _gate.material_override.set_shader_parameter("tex", tex.gate_red if gate_red() else tex.gate_green)

func gate_red() -> bool:
	return game.base.contamination_tier() >= 1

## The scan readout: "污染 52 · 轻度：生命上限 −10%".
func reading() -> String:
	var base: BaseState = game.base
	var tier := base.contamination_tier()
	var t: Array = BaseCatalog.CONTAMINATION_TIERS[tier]
	var effects: Array[String] = []
	if float(t[1]) > 0: effects.append("生命上限 −%d%%" % roundi(float(t[1]) * 100))
	if float(t[2]) > 0: effects.append("药瓶回复 −%d%%" % roundi(float(t[2]) * 100))
	if bool(t[3]): effects.append("自身回血停止")
	return "检测门：污染 %d · %s%s" % [roundi(base.contamination), BaseCatalog.CONTAMINATION_TIER_NAMES[tier],
		("：" + "，".join(effects)) if not effects.is_empty() else "，无影响"]

func _layout(global: Vector3) -> Vector2:
	return Vector2((global.x - BaseMap.ORIGIN.x) / BaseMap.EAST, global.z - BaseMap.ORIGIN.z)
