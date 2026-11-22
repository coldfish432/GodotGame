extends SceneTree

## A7 read-back of res://animations/npc_idle.tscn (clip `npc_idle`, route
## Sprite3D + AnimationPlayer frame track). Expected values are the brief's
## (CHANGE-BRIEF.md "The sheets" and "The cycle spec — npc_idle"), not read
## from the scene. Run: ./scripts/run-test.sh test_npc_idle_readback.gd 60

const Readback := preload("res://tests/anim_readback.gd")

const SCENE := "res://animations/npc_idle.tscn"
const DEFAULT_SHEET := "res://art/characters/npc/npc_closure_idle.png"
const SHEETS := [
	"res://art/characters/npc/npc_closure_idle.png",
	"res://art/characters/npc/npc_cannot_idle.png",
	"res://art/characters/npc/npc_squad_melee_idle.png",
	"res://art/characters/npc/npc_squad_sniper_idle.png",
	"res://art/characters/npc/npc_squad_logistics_idle.png",
]
# Brief: cell 64x64, hframes 4, vframes 1 (256x64), order 0 1 2 3.
const CELL := Vector2i(64, 64)
const HFRAMES := 4
const VFRAMES := 1
# Brief: 12 fps, keys at design frames 0/4/8/12 with values 0/1/2/3,
# length 16 frames, LOOP_LINEAR.
const FPS := 12.0
const KEY_FRAMES := [0, 4, 8, 12]
const KEY_VALUES := [0, 1, 2, 3]
const LENGTH_FRAMES := 16
const LIBRARY := &""
const CLIP := &"idle"
# FieldArt.npc_idle() today (art/field_art.gd:176-181).
const PIXEL_SIZE := 1.0 / 15.0
const NPC_FEET_PX := 2

var failures := 0

func check(label: String, ok: bool, detail: String = "") -> void:
	print("%s  %s%s" % ["PASS" if ok else "FAIL", label, ("  (" + detail + ")") if detail != "" else ""])
	if not ok: failures += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var period := 1.0 / FPS
	var tol := 0.5 * period

	# The sheets: every one has the brief's layout.
	for path in SHEETS:
		var tex: Texture2D = load(path)
		check("sheet %s loads" % path.get_file(), tex != null)
		if tex != null:
			check("sheet %s is %dx%d" % [path.get_file(), CELL.x * HFRAMES, CELL.y * VFRAMES],
				tex.get_width() == CELL.x * HFRAMES and tex.get_height() == CELL.y * VFRAMES,
				"%dx%d" % [tex.get_width(), tex.get_height()])

	var packed: PackedScene = load(SCENE)
	check("scene loads", packed != null)
	if packed == null:
		_finish()
		return
	var npc := packed.instantiate()
	root.add_child(npc)

	# Root node and sprite settings.
	var sprite := npc as Sprite3D
	check("root is a Sprite3D named NpcIdle", sprite != null and npc.name == "NpcIdle", npc.get_class())
	if sprite == null:
		_finish()
		return
	check("default texture is npc_closure_idle.png", sprite.texture != null and sprite.texture.resource_path == DEFAULT_SHEET,
		sprite.texture.resource_path if sprite.texture else "null")
	check("hframes == %d, vframes == %d" % [HFRAMES, VFRAMES], sprite.hframes == HFRAMES and sprite.vframes == VFRAMES,
		"%d x %d" % [sprite.hframes, sprite.vframes])
	if sprite.texture != null:
		check("cell is %dx%d" % [CELL.x, CELL.y],
			sprite.texture.get_width() / sprite.hframes == CELL.x and sprite.texture.get_height() / sprite.vframes == CELL.y)
	check("pixel_size == 1/15", is_equal_approx(sprite.pixel_size, PIXEL_SIZE), "%.7f" % sprite.pixel_size)
	check("billboard == BILLBOARD_ENABLED", sprite.billboard == BaseMaterial3D.BILLBOARD_ENABLED)
	check("texture_filter == NEAREST", sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)
	check("alpha_cut == ALPHA_CUT_DISCARD", sprite.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD)
	check("shaded == false", sprite.shaded == false)
	check("offset == (0, cell height / 2 - feet)", sprite.offset.is_equal_approx(Vector2(0, CELL.y * 0.5 - NPC_FEET_PX)), str(sprite.offset))

	# Player.
	var player := npc.get_node_or_null("AnimationPlayer") as AnimationPlayer
	check("child AnimationPlayer exists", player != null)
	if player == null:
		_finish()
		return
	check("root_node == ..", player.root_node == NodePath(".."), str(player.root_node))
	check("library \"\" holds clip idle", player.has_animation_library(LIBRARY) and player.get_animation_library(LIBRARY).has_animation(CLIP))
	check("autoplay == idle", player.autoplay == String(CLIP), player.autoplay)
	check("callback_mode_process == PROCESS_IDLE",
		player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE, str(player.callback_mode_process))

	# Every track resolves to a real node and property.
	var problems := Readback.track_problems(player)
	check("track_problems is empty", problems.is_empty(), "; ".join(problems))

	var clip := player.get_animation(CLIP)
	if clip == null:
		check("clip idle exists", false)
		_finish()
		return
	check("step == 1/%d s (tolerance half a period)" % int(FPS), Readback.near(clip.step, period, tol) and is_equal_approx(clip.step, period),
		"%.7f" % clip.step)
	check("length == %d/%d s" % [LENGTH_FRAMES, int(FPS)], Readback.near(clip.length, LENGTH_FRAMES * period, tol), "%.7f" % clip.length)
	check("loop_mode == LOOP_LINEAR", clip.loop_mode == Animation.LOOP_LINEAR, str(clip.loop_mode))
	check("exactly one track", clip.get_track_count() == 1, str(clip.get_track_count()))

	var cells := sprite.hframes * sprite.vframes
	for t in clip.get_track_count():
		var kind := clip.track_get_type(t)
		check("track %d is a value track" % t, kind == Animation.TYPE_VALUE, str(kind))
		check("track %d path == .:frame" % t, clip.track_get_path(t) == NodePath(".:frame"), str(clip.track_get_path(t)))
		# value_track_get_update_mode applies only to value tracks.
		if kind == Animation.TYPE_VALUE:
			check("track %d update mode == UPDATE_DISCRETE" % t,
				clip.value_track_get_update_mode(t) == Animation.UPDATE_DISCRETE, str(clip.value_track_get_update_mode(t)))
		check("track %d interpolation == NEAREST" % t,
			clip.track_get_interpolation_type(t) == Animation.INTERPOLATION_NEAREST, str(clip.track_get_interpolation_type(t)))
		var n := clip.track_get_key_count(t)
		check("track %d has %d keys" % [t, KEY_FRAMES.size()], n == KEY_FRAMES.size(), str(n))
		for k in range(mini(n, KEY_FRAMES.size())):
			var time := clip.track_get_key_time(t, k)
			var want: float = KEY_FRAMES[k] * period
			check("track %d key %d time %.4f ~= frame %d (%.4f)" % [t, k, time, KEY_FRAMES[k], want], Readback.near(time, want, tol))
			var value = clip.track_get_key_value(t, k)
			check("track %d key %d value == %d" % [t, k, KEY_VALUES[k]], int(value) == KEY_VALUES[k], str(value))
			check("track %d key %d value inside the sheet (0..%d)" % [t, k, cells - 1], int(value) >= 0 and int(value) < cells, str(value))

		# Seam rule (frame track): no duplicate across the wrap, and the gap
		# from the last key to length equals the key interval.
		if n >= 2:
			var first_v := int(clip.track_get_key_value(t, 0))
			var last_v := int(clip.track_get_key_value(t, n - 1))
			check("seam: last key value (%d) != first key value (%d)" % [last_v, first_v], last_v != first_v)
			check("seam: no key at length", not Readback.near(clip.track_get_key_time(t, n - 1), clip.length, tol))
			var interval := clip.track_get_key_time(t, 1) - clip.track_get_key_time(t, 0)
			var gap := clip.length - clip.track_get_key_time(t, n - 1)
			check("seam: gap last key -> length (%.4f) == key interval (%.4f)" % [gap, interval], Readback.near(gap, interval, tol))
			for k in range(1, n):
				var step_k := clip.track_get_key_time(t, k) - clip.track_get_key_time(t, k - 1)
				check("seam: interval %d->%d (%.4f) == %.4f" % [k - 1, k, step_k, interval], Readback.near(step_k, interval, tol))

	# Autoplay runs on the process tick headless.
	for i in range(3): await process_frame
	check("autoplay started idle", player.is_playing() and player.current_animation == String(CLIP), str(player.current_animation))

	_finish()

func _finish() -> void:
	print("test_npc_idle_readback: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)
