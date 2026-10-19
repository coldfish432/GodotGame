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
var _label: Label3D
var _age := 0.0
const MODELS := {"vault": "res://art/kit/relic_cache_vault.glb", "cache": "res://art/kit/relic_cache_field.glb"}
const MODEL_SCALE := 1.3

func _ready() -> void:
	add_to_group("relic_caches")
	# A reliquary, amber for the vault's, blue for a combat cache's
	# (tools/blender/kit/build_trap_kit.py, 用户 2026-10-17: 掉落的藏品从几何体换成建模).
	_mesh = MeshInstance3D.new()
	_mesh.mesh = TerraceDressing.kit_mesh(load(MODELS[source] if MODELS.has(source) else MODELS.cache))
	_mesh.scale = Vector3.ONE * MODEL_SCALE
	add_child(_mesh)
	# No name over it (用户 2026-10-13: 不要中文label了，只提示e即可): the HUD shows the E key when near.

func _process(delta: float) -> void:
	_age += delta
	# It turns slowly while it can be taken; sealed, it stands still.
	if is_instance_valid(_mesh) and not sealed: _mesh.rotation.y = _age * 0.6
	_refresh_label()

func _refresh_label() -> void:
	if not is_instance_valid(_label): return
	_label.text = ("密室藏品 · 封印中" if sealed else "密室藏品 [E]") if source == "vault" else "战斗缴获 [E]"
	_label.modulate = Color("8a8f96") if sealed else Color("f3dca0")

func claim() -> void:
	remove_from_group("relic_caches")
	queue_free()
