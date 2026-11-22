extends SceneTree
## 动画工程整理案 §3: every operator and crew member with sheets has a baked
## SpriteFrames (godot_assets/frames/<id>.tres), and each baked file matches a
## fresh LapplandAnimator3D.build_frames(id) exactly: animation names, speed,
## loop, frame count, each frame's sheet and region. A stale bake fails here;
## rerun tools/bake_sprite_frames.gd. Run: ./scripts/run-test.sh test_baked_frames.gd 60
var failures := 0
func check(label: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func _initialize() -> void:
	var ids: Array = LapplandAnimator3D.CHARACTERS.keys() + LapplandAnimator3D.CREW
	for id in ids:
		if not LapplandAnimator3D.has_sheets(id): continue
		var path := LapplandAnimator3D.baked_path(id)
		if not ResourceLoader.exists(path):
			check("%s has a baked file" % id, false)
			continue
		var baked := load(path) as SpriteFrames
		var fresh := LapplandAnimator3D.build_frames(id)
		var names_b := Array(baked.get_animation_names()); names_b.sort()
		var names_f := Array(fresh.get_animation_names()); names_f.sort()
		var same := names_b == names_f
		var diffs: Array[String] = []
		if same:
			for anim in names_f:
				if baked.get_animation_speed(anim) != fresh.get_animation_speed(anim) or baked.get_animation_loop(anim) != fresh.get_animation_loop(anim) or baked.get_frame_count(anim) != fresh.get_frame_count(anim):
					diffs.append(anim); continue
				for i in fresh.get_frame_count(anim):
					var a := baked.get_frame_texture(anim, i) as AtlasTexture
					var b := fresh.get_frame_texture(anim, i) as AtlasTexture
					if a == null or b == null or a.atlas.resource_path != b.atlas.resource_path or a.region != b.region or not is_equal_approx(baked.get_frame_duration(anim, i), fresh.get_frame_duration(anim, i)):
						diffs.append("%s#%d" % [anim, i]); break
		check("%s baked frames match the action table and sheets (%d animations)%s" % [id, names_f.size(), "" if same and diffs.is_empty() else " — stale: " + (", ".join(diffs.slice(0, 5)) if same else "animation list differs")], same and diffs.is_empty())
	# The animator uses the baked file.
	var a := LapplandAnimator3D.new()
	root.add_child(a)
	a.set_character("texas")
	check("set_character loads the baked resource", a.sprite_frames.resource_path == LapplandAnimator3D.baked_path("texas"))
	print("TEST_BAKED_FRAMES: %d failures" % failures)
	quit(1 if failures else 0)
