class_name MedicalView
extends Node

## The medical bay drawn from GameManager.base (基地玩法策划案_v1_0.md §4):
## the front desk switches to its alert state while there is an unread
## recovery report or an untreated injury. The contamination scan gate is
## scenery only, always green: contamination stays in the field
## (用户 2026-10-15: 污染不带出局外，删除检测门功能).

const ROOM := "medical"

var game: GameManager
var map: BaseMap
## The front desk's alert beacon and banner (a model on the desk, shown while
## something waits), and the scan gate.
var _reception: MeshInstance3D
var _gate: MeshInstance3D

func setup(p_game: GameManager, p_map: BaseMap) -> void:
	game = p_game
	map = p_map
	var room: Dictionary = map.rooms.get(ROOM, {})
	if room.is_empty(): return
	_reception = map.room_visuals[ROOM].roles.get("reception_alert")
	for piece in map.get_node(ROOM).get_children():
		if piece.get_meta("model", "") == "scan_gate": _gate = piece
	refresh()

func ready() -> bool: return _reception != null

func _process(_delta: float) -> void:
	if not ready() or not is_instance_valid(game): return
	refresh()

func refresh() -> void:
	var base: BaseState = game.base
	var alert := base.report_unread or base.any_injured()
	if _reception: _reception.visible = alert
