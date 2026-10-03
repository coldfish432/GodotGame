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

func _ready() -> void:
	add_to_group("relic_caches")
	_mesh = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.7, 0.9, 0.7)
	_mesh.mesh = prism
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("f3b04a") if source == "vault" else Color("72b8ff")
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 0.6
	_mesh.material_override = material
	_mesh.position.y = 0.8
	add_child(_mesh)
	_label = Label3D.new()
	_label.position.y = 1.7
	_label.font_size = 24
	_label.pixel_size = 0.01
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_size = 6
	add_child(_label)
	_refresh_label()

func _process(delta: float) -> void:
	_age += delta
	if is_instance_valid(_mesh):
		_mesh.rotation.y = _age * (0.4 if sealed else 1.6)
		_mesh.position.y = 0.8 + 0.08 * sin(_age * 3.0)
	_refresh_label()

func _refresh_label() -> void:
	if not is_instance_valid(_label): return
	_label.text = ("密室藏品 · 封印中" if sealed else "密室藏品 [E]") if source == "vault" else "战斗缴获 [E]"
	_label.modulate = Color("8a8f96") if sealed else Color("f3dca0")

func claim() -> void:
	remove_from_group("relic_caches")
	queue_free()
