class_name CombatMarker
extends MeshInstance3D
var life := 1.0
var hitstop_owner: Enemy
func _process(delta: float) -> void:
	if get_parent() is GameManager and not get_parent().simulation_active(): return
	if is_instance_valid(hitstop_owner) and hitstop_owner.hitstop_remaining > 0: return
	life -= delta
	if life <= 0: queue_free()
