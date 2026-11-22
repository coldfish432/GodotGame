extends SceneTree
## Bake every operator's and crew member's SpriteFrames to
## godot_assets/frames/<id>.tres (动画工程整理案 §3). LapplandAnimator3D loads
## the baked file instead of building hundreds of AtlasTextures on each swap.
## Rerun after changing an action table or a sheet; tests/test_baked_frames.gd
## fails while a bake is stale.
##   godot --headless --path . --script res://tools/bake_sprite_frames.gd
func _initialize() -> void:
	var ids: Array = LapplandAnimator3D.CHARACTERS.keys() + LapplandAnimator3D.CREW
	var saved := 0
	for id in ids:
		if not LapplandAnimator3D.has_sheets(id): continue
		var frames := LapplandAnimator3D.build_frames(id)
		var err := ResourceSaver.save(frames, LapplandAnimator3D.baked_path(id))
		print("%-18s %d animations -> %s (%s)" % [id, frames.get_animation_names().size(), LapplandAnimator3D.baked_path(id), error_string(err)])
		if err == OK: saved += 1
	print("baked %d" % saved)
	quit(0 if saved > 0 else 1)
