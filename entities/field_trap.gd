class_name FieldTrap
extends Node3D

## A trap on the floor (密室与陷阱修订案_v1 §2.2, 用户 2026-10-17: 能致死、扣固定
## 数值、涨威胁值). It goes off once when she steps over it: a fixed blow
## (true damage, so armour and evasion do not change it; a shield still
## takes it), and the 威胁值 rises. Seen if looked for: a region's own small
## thing on the ground, no name, not on the minimap.

## kind -> its reach, its blow, the 威胁值 it adds.
const KINDS := {
	"heavy": {"radius": 1.5, "damage": 600.0, "threat": 8.0},
	"light": {"radius": 0.8, "damage": 300.0, "threat": 4.0},
}
## The model per region and kind (art/kit/trap_<region>_<kind>.glb), when built.
const MODEL := "res://art/kit/trap_%s_%s.glb"

var game: GameManager
var kind := "light"
var spent := false

func setup(p_game: GameManager, p_kind: String, region: String) -> void:
	game = p_game
	kind = p_kind
	var path := MODEL % [FieldCatalog.art_region(region) if region != "siracusa" else region, kind]
	var model := MeshInstance3D.new()
	model.name = "Look"
	model.mesh = TerraceDressing.kit_mesh(load(path))
	add_child(model)

func radius() -> float:
	return float(KINDS[kind].radius)

## Called each physics frame while the floor runs.
func check(player: Player) -> void:
	if spent or not is_instance_valid(player) or player.invulnerable or player.invuln_timer > 0.0: return
	var offset := player.global_position - global_position
	if Vector2(offset.x, offset.z).length() > radius(): return
	spent = true
	var data: Dictionary = KINDS[kind]
	CombatVfx.spawn(game, global_position + Vector3(0, 0.3, 0), Vector3.FORWARD, "burst", 0, kind == "heavy")
	game.sound.play("hit")
	player.take_damage(float(data.damage), "true")
	game.trap_sprung(float(data.threat))
	# Sprung, it is spent: it sinks out of the way.
	var look := get_node_or_null("Look") as Node3D
	if look != null: look.position.y -= 0.03
