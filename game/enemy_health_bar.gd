class_name EnemyHealthBar
extends Node3D

## A thin bar over an enemy, shown once it has been hurt. With enemies at
## thousands of HP, this is how the player sees how far a fight has gone.

const WIDTH := 1.3
const HEIGHT := 0.2
var _fill: MeshInstance3D
var _back: MeshInstance3D

func _ready() -> void:
	_back = _quad(Color(0.05, 0.05, 0.06, 0.85), WIDTH + 0.06, HEIGHT + 0.05, 24)
	_fill = _quad(Color("e0574a"), WIDTH, HEIGHT, 25)
	visible = false

func _quad(color: Color, width: float, height: float, priority: int) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(width, height)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.render_priority = priority
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	add_child(node)
	return node

func set_ratio(ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	visible = ratio < 0.999 and ratio > 0.0
	if not is_instance_valid(_fill): return
	# Resized in the billboard's own plane, so it shrinks toward its left
	# end on screen whichever way the camera faces.
	var mesh := _fill.mesh as QuadMesh
	mesh.size.x = maxf(WIDTH * ratio, 0.001)
	mesh.center_offset = Vector3((mesh.size.x - WIDTH) * 0.5, 0, 0)
