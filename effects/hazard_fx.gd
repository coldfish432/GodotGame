class_name HazardFx
extends Node3D
## Particles on a GroundHazard (GPU粒子特效推广策划案 v0.6 §6 P3). Presentation
## only: it reads the hazard's fuse, lasting and radius and never writes them.
##   a burning patch (fuse 0, lasting > 0): flames, embers, smoke
##     (hazard_fire.tscn), amount_ratio following the fire's time left and
##     dying away over its last second (用户裁决 5) — the damage still stops on
##     the hazard's own timer;
##   a fused blast: motes drawn in while it counts down (hazard_fuse.tscn),
##     then one burst when it goes off (hazard_blast.tscn).
## The A5 FireFlame face and the Decal scorch stay as they are.

const FIRE := preload("res://effects/hazard_fire.tscn")
const FUSE := preload("res://effects/hazard_fuse.tscn")
const BLAST := preload("res://effects/hazard_blast.tscn")
## The scenes are sized for this radius; the root scales to the hazard's.
const BASE_RADIUS := 1.3
const FADE := 1.0
const LOW_RATIO := 0.4

var hazard: GroundHazard
var initial_lasting := 0.0
var _fire: Node3D
var _fuse: Node3D
var _blasted := false

func _ready() -> void:
	hazard = get_parent() as GroundHazard
	if hazard == null: return
	# Read after the hazard's own physics step.
	process_physics_priority = 10
	var s := clampf(hazard.radius / BASE_RADIUS, 0.3, 3.0)
	if hazard.fuse <= 0.0 and hazard.lasting > 0.0:
		initial_lasting = hazard.lasting
		_fire = FIRE.instantiate()
		_fire.scale = Vector3(s, 1.0, s)
		add_child(_fire)
		_show()
	elif hazard.fuse > 0.0:
		_fuse = FUSE.instantiate()
		_fuse.scale = Vector3(s, 1.0, s)
		add_child(_fuse)

func _physics_process(_delta: float) -> void:
	if hazard == null: return
	if _fire != null: _show()
	if _fuse != null and hazard.fuse <= 0.0 and not _blasted:
		_blasted = true
		_fuse.queue_free()
		_fuse = null
		if hazard.lasting <= 0.0 and is_instance_valid(hazard.game):
			OneShotFx.spawn(BLAST, hazard.game, hazard.global_position, 8)

## The fire's share: 0.4–1 by time left, times the last second's fade.
func fire_ratio() -> float:
	if initial_lasting <= 0.0: return 0.0
	var left := clampf(hazard.lasting / initial_lasting, 0.0, 1.0)
	return (LOW_RATIO + (1.0 - LOW_RATIO) * left) * clampf(hazard.lasting / FADE, 0.0, 1.0)

func _show() -> void:
	var ratio := fire_ratio()
	for child in _fire.get_children():
		var p := child as GPUParticles3D
		if p != null: p.amount_ratio = ratio
