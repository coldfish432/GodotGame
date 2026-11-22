extends SceneTree

## A7 read-back of res://animations/lappland_wave_rig.tscn (clip `wave_release`,
## route keyed 2D cutout rig in a SubViewport drawn by a Sprite3D billboard).
## Expected values are the brief's (CHANGE-BRIEF.md "Clip 2", "The phase table
## — wave_release", "The two clocks"), not read from the scene.
## Run: ./scripts/run-test.sh test_wave_rig_readback.gd 60

const Readback := preload("res://tests/anim_readback.gd")

const SCENE := "res://animations/lappland_wave_rig.tscn"
const LIBRARY := &""
const CLIP := &"wave_release"
const RESET := &"RESET"
# Brief: 30 fps; keys on every rig track at the phase boundaries f0 (startup),
# f6 (active), f10 (recovery), f20 (end = length); LOOP_NONE.
const FPS := 30.0
const KEY_FRAMES := [0, 6, 10, 20]
const LENGTH_FRAMES := 20
# The rig tracks (paths relative to root_node = ../Viewport/Rig).
const TRACKS := [
	"Body:position", "ArmBack:position", "ArmBack:rotation",
	"ArmFront:position", "ArmFront:rotation",
]
# Rotation tracks: ease-in into f6 (transition > 1), ease-out from f10 (< 1).
const ROTATION_TRACKS := ["ArmBack:rotation", "ArmFront:rotation"]
# The game's operator sprite scale (godot_assets/lappland_animator_3d.gd:29).
const PIXEL_SIZE := 0.06
const VIEWPORT_SIZE := Vector2i(96, 96)
const PARTS := {
	"Body": "res://animations/lappland_rig/body.png",
	"ArmBack/BladeBack": "res://animations/lappland_rig/blade_back.png",
	"ArmFront/BladeFront": "res://animations/lappland_rig/blade_front.png",
}

var failures := 0

func check(label: String, ok: bool, detail: String = "") -> void:
	print("%s  %s%s" % ["PASS" if ok else "FAIL", label, ("  (" + detail + ")") if detail != "" else ""])
	if not ok: failures += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var period := 1.0 / FPS
	var tol := 0.5 * period

	var packed: PackedScene = load(SCENE)
	check("scene loads", packed != null)
	if packed == null:
		_finish()
		return
	var rig_root := packed.instantiate()
	root.add_child(rig_root)

	# Structure (brief "Clip 2 ... Scene").
	check("root is a Node3D named WaveRig", rig_root is Node3D and rig_root.name == "WaveRig", rig_root.get_class())
	var billboard := rig_root.get_node_or_null("Billboard") as Sprite3D
	var viewport := rig_root.get_node_or_null("Viewport") as SubViewport
	var rig := rig_root.get_node_or_null("Viewport/Rig") as Node2D
	var player := rig_root.get_node_or_null("AnimationPlayer") as AnimationPlayer
	check("Billboard is a Sprite3D", billboard != null)
	check("Viewport is a SubViewport", viewport != null)
	check("Viewport/Rig is a Node2D", rig != null)
	check("AnimationPlayer is a child of WaveRig", player != null)
	if billboard == null or viewport == null or rig == null or player == null:
		_finish()
		return
	check("Rig/Body is a Sprite2D", rig.get_node_or_null("Body") is Sprite2D)
	check("Rig/ArmBack is a Node2D pivot (not a Sprite2D)", rig.get_node_or_null("ArmBack") is Node2D and not (rig.get_node_or_null("ArmBack") is Sprite2D))
	check("Rig/ArmFront is a Node2D pivot (not a Sprite2D)", rig.get_node_or_null("ArmFront") is Node2D and not (rig.get_node_or_null("ArmFront") is Sprite2D))
	check("Rig/ArmBack/BladeBack is a Sprite2D", rig.get_node_or_null("ArmBack/BladeBack") is Sprite2D)
	check("Rig/ArmFront/BladeFront is a Sprite2D", rig.get_node_or_null("ArmFront/BladeFront") is Sprite2D)
	for part in PARTS:
		var sprite := rig.get_node_or_null(part) as Sprite2D
		var want: String = PARTS[part]
		check("%s texture is %s" % [part, want.get_file()],
			sprite != null and sprite.texture != null and sprite.texture.resource_path == want,
			sprite.texture.resource_path if sprite != null and sprite.texture != null else "null")

	check("Viewport size == 96x96", viewport.size == VIEWPORT_SIZE, str(viewport.size))
	check("Viewport transparent_bg", viewport.transparent_bg)
	check("Viewport updates (not UPDATE_DISABLED)", viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED,
		str(viewport.render_target_update_mode))

	var vtex := billboard.texture as ViewportTexture
	check("Billboard texture is a ViewportTexture", vtex != null, billboard.texture.get_class() if billboard.texture else "null")
	if vtex != null:
		check("ViewportTexture points at Viewport", rig_root.get_node_or_null(vtex.viewport_path) == viewport, str(vtex.viewport_path))
	check("Billboard pixel_size == 0.06 (operator sprite scale)", is_equal_approx(billboard.pixel_size, PIXEL_SIZE), "%.7f" % billboard.pixel_size)
	check("Billboard billboard == BILLBOARD_ENABLED", billboard.billboard == BaseMaterial3D.BILLBOARD_ENABLED)
	check("Billboard texture_filter == NEAREST", billboard.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)
	check("Billboard alpha_cut == ALPHA_CUT_DISCARD", billboard.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD)
	check("Billboard starts hidden", billboard.visible == false)

	# Player settings (brief "The two clocks": manual, advanced from the physics tick).
	check("root_node == ../Viewport/Rig", player.root_node == NodePath("../Viewport/Rig"), str(player.root_node))
	check("root_node resolves to Rig", player.get_node_or_null(player.root_node) == rig)
	check("callback_mode_process == PROCESS_MANUAL",
		player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL, str(player.callback_mode_process))
	check("no autoplay (the state machine plays it)", player.autoplay == "", player.autoplay)
	var lib: AnimationLibrary = player.get_animation_library(LIBRARY) if player.has_animation_library(LIBRARY) else null
	check("library \"\" holds RESET and wave_release", lib != null and lib.has_animation(RESET) and lib.has_animation(CLIP))

	# Every track resolves to a real node and property / bone / blend shape.
	var problems := Readback.track_problems(player)
	check("track_problems is empty", problems.is_empty(), "; ".join(problems))

	# Authority: Billboard.visible and Rig.scale.x are never keyed, and no track
	# leaves the rig parts.
	for clip_name in player.get_animation_list():
		var c := player.get_animation(clip_name)
		for t in c.get_track_count():
			var path := c.track_get_path(t)
			var node := rig.get_node_or_null(NodePath(path.get_concatenated_names()))
			var prop := path.get_concatenated_subnames()
			check("%s track %d (%s) does not key Rig.scale" % [clip_name, t, path], not (node == rig and prop.begins_with("scale")))
			check("%s track %d (%s) does not key Billboard" % [clip_name, t, path], node != billboard)
			check("%s track %d (%s) targets a rig part" % [clip_name, t, path],
				node != null and String(node.name) in ["Body", "ArmBack", "ArmFront", "BladeBack", "BladeFront"])

	var clip := player.get_animation(CLIP)
	var reset := player.get_animation(RESET)
	if clip == null or reset == null:
		check("clips wave_release and RESET exist", false)
		_finish()
		return

	check("step == 1/30 s (one frame period at 30 fps)", Readback.near(clip.step, period, 1e-5), "%.7f" % clip.step)
	check("length == 20/30 s", Readback.near(clip.length, LENGTH_FRAMES * period, tol) and Readback.near(clip.length, LENGTH_FRAMES * period, 1e-5),
		"%.7f" % clip.length)
	check("loop_mode == LOOP_NONE", clip.loop_mode == Animation.LOOP_NONE, str(clip.loop_mode))
	check("%d tracks" % TRACKS.size(), clip.get_track_count() == TRACKS.size(), str(clip.get_track_count()))

	var seen: Array[String] = []
	for t in clip.get_track_count():
		var path_s := String(clip.track_get_path(t))
		seen.append(path_s)
		var kind := clip.track_get_type(t)
		check("%s is a value track" % path_s, kind == Animation.TYPE_VALUE, str(kind))
		# value_track_get_update_mode applies only to value tracks.
		if kind == Animation.TYPE_VALUE:
			check("%s update mode == UPDATE_CONTINUOUS" % path_s,
				clip.value_track_get_update_mode(t) == Animation.UPDATE_CONTINUOUS, str(clip.value_track_get_update_mode(t)))
		var n := clip.track_get_key_count(t)
		check("%s has %d keys" % [path_s, KEY_FRAMES.size()], n == KEY_FRAMES.size(), str(n))
		for k in range(mini(n, KEY_FRAMES.size())):
			var time := clip.track_get_key_time(t, k)
			var want: float = KEY_FRAMES[k] * period
			check("%s key %d time %.4f ~= frame %d (%.4f)" % [path_s, k, time, KEY_FRAMES[k], want], Readback.near(time, want, tol))
		if n == KEY_FRAMES.size():
			check("%s last key at length" % path_s, Readback.near(clip.track_get_key_time(t, n - 1), clip.length, tol))
			if path_s in ROTATION_TRACKS:
				check("%s f0 key eases in (transition > 1)" % path_s, clip.track_get_key_transition(t, 0) > 1.0, str(clip.track_get_key_transition(t, 0)))
				check("%s f10 key eases out (0 < transition < 1)" % path_s,
					clip.track_get_key_transition(t, 2) > 0.0 and clip.track_get_key_transition(t, 2) < 1.0, str(clip.track_get_key_transition(t, 2)))
			# Starts and ends on the rest pose that RESET holds.
			var r := reset.find_track(clip.track_get_path(t), kind)
			check("RESET has a track for %s" % path_s, r != -1)
			if r != -1:
				var rest = reset.track_get_key_value(r, 0)
				check("%s f0 value == RESET value" % path_s, clip.track_get_key_value(t, 0) == rest, str(clip.track_get_key_value(t, 0)))
				check("%s f20 value == RESET value" % path_s, clip.track_get_key_value(t, n - 1) == rest, str(clip.track_get_key_value(t, n - 1)))
				var node := rig.get_node_or_null(NodePath(clip.track_get_path(t).get_concatenated_names()))
				var prop := clip.track_get_path(t).get_concatenated_subnames()
				check("RESET value for %s == scene's rest value" % path_s, node != null and node.get(prop) == rest, str(node.get(prop) if node else null))
	for want_path in TRACKS:
		check("track %s exists" % want_path, want_path in seen)
	check("RESET has exactly the same tracks", reset.get_track_count() == clip.get_track_count(), str(reset.get_track_count()))

	# Manual clock: the clip moves only when advance() is called.
	player.play(CLIP)
	player.advance(0.0)
	for i in range(3): await process_frame
	check("manual clock: process frames do not move the clip", Readback.near(player.current_animation_position, 0.0, 1e-5),
		"%.5f" % player.current_animation_position)
	for f in range(6): player.advance(period)
	check("after 6 x advance(1/30): position ~= 0.2 (frame 6)", Readback.near(player.current_animation_position, 6 * period, 1e-4),
		"%.5f" % player.current_animation_position)
	player.stop()

	_finish()

func _finish() -> void:
	print("test_wave_rig_readback: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)
