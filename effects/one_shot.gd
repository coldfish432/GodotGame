class_name OneShotFx
extends Node3D
## A one-shot GPU burst scene (GPU粒子特效推广策划案 v0.6 §8): restarts its
## emitters when it enters the tree and frees itself after the longest one has
## finished (its own clock; `finished` never fires headlessly). Every particle
## setting lives in the scene.

var _age := 0.0
var _life := 0.0

## Instances `scene` at `at` (world) under `parent`. A shared cap per scene
## keeps a crowd from piling up bursts: past `limit` alive, none is added.
static func spawn(scene: PackedScene, parent: Node, at: Vector3, limit: int = 12) -> OneShotFx:
	if scene == null or not is_instance_valid(parent) or not parent.is_inside_tree(): return null
	var group := StringName("oneshot:" + scene.resource_path.get_file())
	if parent.get_tree().get_nodes_in_group(group).size() >= limit: return null
	var fx := scene.instantiate() as OneShotFx
	fx.add_to_group(group)
	var p3 := parent as Node3D
	fx.position = p3.global_transform.affine_inverse() * at if p3 != null else at
	parent.add_child(fx)
	return fx

func _ready() -> void:
	for child in get_children():
		var p := child as GPUParticles3D
		if p == null: continue
		_life = maxf(_life, p.lifetime * (1.0 + p.randomness))
		if p.one_shot: p.restart()
	_life += 0.1

func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
