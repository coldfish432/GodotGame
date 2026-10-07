class_name LootContainer
extends Node3D

## A point of interest (掉落物策划案 §4): a weapon box, a construction pile, an
## ore vein … Press E nearby to open it: a short channel (Tarkov's search)
## that walking away or taking damage interrupts. Its contents then spill on
## the ground around it. Vault chests stay sealed until the guardians fall.

const OPEN_SECONDS := 1.0
const VAULT_OPEN_SECONDS := 1.5
const REACH := 2.4

var game: GameManager
var kind := "construction"
var guarded := false
var sealed := false
var opened := false
var vault := false
var _progress := -1.0
var _hp_at_start := 0.0
var _mesh: MeshInstance3D
var _label: Label3D

func _ready() -> void:
	add_to_group("loot_containers")
	add_to_group("search_points")
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.25, 0.8, 0.85) if not kind in ["ore_vein", "camp"] else Vector3(1.3, 0.9, 1.3)
	_mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color()
	_mesh.material_override = material
	_mesh.position.y = 0.1
	add_child(_mesh)
	_label = Label3D.new()
	_label.position.y = 1.2
	_label.font_size = 24
	_label.pixel_size = 0.01
	_label.outline_size = 6
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)
	_refresh()

func title() -> String:
	if vault: return {"vault_weapon": "密室武器箱", "vault_gear": "密室装备箱", "vault_base": "密室物资箱"}.get(kind, "密室宝箱")
	return str(LootTables.POI.get(kind, {}).get("name", "补给点"))

func color() -> Color:
	if vault: return Color("c9a43a")
	return LootTables.POI.get(kind, {}).get("color", Color("827357"))

## Name and state, as the HUD draws it over the box.
func status_text() -> String:
	var text := title()
	if opened: text += "（已开启）"
	elif sealed: text += " · 封印中"
	elif _progress >= 0.0: text += " · 开启中 %d%%" % roundi(progress() * 100.0)
	else: text += " [E]"
	return text

## Channel progress 0..1, or -1 when not opening.
func progress() -> float:
	return _progress / _duration() if _progress >= 0.0 else -1.0

func _refresh() -> void:
	if not is_instance_valid(_label): return
	var text := status_text()
	_label.text = text
	_label.modulate = Color("8a8f96") if opened or sealed else Color("f3dca0")
	(_mesh.material_override as StandardMaterial3D).albedo_color = color().darkened(0.55) if opened else color()

func _duration() -> float:
	return VAULT_OPEN_SECONDS if vault else OPEN_SECONDS

## The vault guardians fell.
func unseal() -> void:
	sealed = false
	_refresh()

func can_open() -> bool:
	return not opened and not sealed and _progress < 0.0

func is_channeling() -> bool:
	return _progress >= 0.0

## Starts the channel. GameManager calls this when E is pressed nearby.
func begin_open() -> bool:
	if not can_open() or not is_instance_valid(game): return false
	_progress = 0.0
	_hp_at_start = game.player.hp
	_refresh()
	return true

func cancel(reason: String) -> void:
	if _progress < 0.0: return
	_progress = -1.0
	_refresh()
	if is_instance_valid(game): game.set_message("%s的开启被打断：%s" % [title(), reason])

func _process(delta: float) -> void:
	if _progress < 0.0 or not is_instance_valid(game) or not game.simulation_active(): return
	if game.player.global_position.distance_to(global_position) > REACH:
		cancel("离开了")
		return
	if game.player.hp < _hp_at_start - 0.5:
		cancel("受到攻击")
		return
	_progress += delta
	_refresh()
	if _progress >= _duration(): open_now()

## Rolls the contents and spills them. Also used directly by tests.
func open_now() -> void:
	if opened: return
	_progress = -1.0
	opened = true
	_refresh()
	if is_instance_valid(game): game.on_container_opened(self)
