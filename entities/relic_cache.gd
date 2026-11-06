class_name RelicCache
extends Node3D

## A one-off relic choice standing in the field (局内构筑与数值策划案 §8.2):
## the combat cache that appears once a segment's threat quota is defeated,
## and the vault's sealed relic. Its offer is rolled the first time it is
## opened and kept, so walking away and back never rerolls it.

var game: GameManager
var source := "cache"
var sealed := false
var offers: Array[Dictionary] = []
var _mesh: MeshInstance3D
var _age := 0.0
const MODELS := {"vault": "res://art/kit/relic_cache_vault.glb", "cache": "res://art/kit/relic_cache_field.glb"}
const MODEL_SCALE := 1.3
## A combat cache stands out from afar (用户 2026-11-02: 敌人掉落的藏品选择装置在地图上需要明显):
## a tall column of light, a pool on the ground and a light of its own, in
## the HUD's cache colour; they breathe while it waits. Vault relics keep to
## the vault's own glow.
const BEACON := Color("27a6ef")
const COLUMN := Vector3(0.55, 7.0, 0.0)
const COLUMN_GAIN := Vector2(0.45, 0.8)
const BREATH := 1.6
var _column: ShaderMaterial
var _light: OmniLight3D

func _ready() -> void:
	add_to_group("relic_caches")
	# A reliquary, amber for the vault's, blue for a combat cache's
	# (tools/blender/kit/build_trap_kit.py, 用户 2026-10-17: 掉落的藏品从几何体换成建模).
	_mesh = MeshInstance3D.new()
	_mesh.mesh = TerraceDressing.kit_mesh(load(MODELS[source] if MODELS.has(source) else MODELS.cache))
	_mesh.scale = Vector3.ONE * MODEL_SCALE
	add_child(_mesh)
	if source == "cache": _add_beacon()
	# No name over it (用户 2026-10-13: 不要中文label了，只提示e即可): the HUD shows the E key when near.

func _add_beacon() -> void:
	_column = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = BossVfx.SHAFT_CODE
	_column.shader = shader
	_column.set_shader_parameter("noise_tex", BossVfx.tex("noise"))
	_column.set_shader_parameter("colour", BEACON)
	var tube := CylinderMesh.new()
	tube.top_radius = COLUMN.x * 0.6
	tube.bottom_radius = COLUMN.x
	tube.height = COLUMN.y
	tube.cap_top = false
	tube.cap_bottom = false
	tube.radial_segments = 16
	var column := MeshInstance3D.new()
	column.name = "Beacon"
	column.mesh = tube
	column.material_override = _column
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	column.position.y = tube.height * 0.5
	add_child(column)
	var pool := TracePoint.halo(3.2)
	pool.name = "BeaconPool"
	(pool.material_override as StandardMaterial3D).albedo_color = BEACON * 0.6
	add_child(pool)
	_light = OmniLight3D.new()
	_light.light_color = BEACON
	_light.omni_range = 6.0
	_light.light_energy = 1.6
	_light.shadow_enabled = false
	_light.position.y = 1.2
	add_child(_light)

func _process(delta: float) -> void:
	_age += delta
	if _column != null:
		var breath := 0.5 + 0.5 * sin(_age * TAU / BREATH)
		_column.set_shader_parameter("gain", lerpf(COLUMN_GAIN.x, COLUMN_GAIN.y, breath))
		_column.set_shader_parameter("flow", -_age * 0.3)
		_light.light_energy = lerpf(1.2, 2.0, breath)
	# It turns slowly while it can be taken; sealed, it stands still.
	if is_instance_valid(_mesh) and not sealed: _mesh.rotation.y = _age * 0.6

func claim() -> void:
	remove_from_group("relic_caches")
	queue_free()
