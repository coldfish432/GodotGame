extends SceneTree
## Not a test — what the new GPU effects cost (GPU粒子特效推广策划案 v0.6 §9),
## A6-style: the same build, the same view, effects on and off in turns
## (ROUNDS × FRAMES each), the viewport's measured GPU time per frame, plus the
## frame rate. Real renderer, no Movie Maker:
##   godot --path downfall-godot --script res://tests/measure_gpu_fx.gd --resolution 1280x720
## Prints "COST <case> on <ms> off <ms> delta <ms> fps_on <n> fps_off <n>".

const FRAMES := 180
const ROUNDS := 3

var rig: Node
var game: GameManager

func _initialize() -> void: call_deferred("run")

func step(n := 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame

func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for c in node.get_children():
		var f := find_game(c)
		if f != null: return f
	return null

## Turns every new effect on the floor on or off (presentation only).
func set_fx(on: bool) -> void:
	var w := game.field_weather
	if is_instance_valid(w):
		w.collider.visible = on
		w.set_process(on)
	var weather = game.world_map.terrace_dressing.weather if is_instance_valid(game.world_map.terrace_dressing) else null
	if is_instance_valid(weather): weather.visible = on
	if is_instance_valid(game.status_post): game.status_post.quad.visible = on and game.status_post.quad.visible
	game.status_post.set_process(on)
	for n in game.find_children("*", "GPUParticles3D", true, false): (n as GPUParticles3D).visible = on

func gpu_ms(frames: int) -> Array:
	var vp := root.get_viewport().get_viewport_rid()
	var sub := game.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	RenderingServer.viewport_set_measure_render_time(sub, true)
	var total := 0.0
	var start := Time.get_ticks_usec()
	for i in range(frames):
		await process_frame
		total += RenderingServer.viewport_get_measured_render_time_gpu(sub) + RenderingServer.viewport_get_measured_render_time_gpu(vp)
	var secs := (Time.get_ticks_usec() - start) / 1e6
	return [total / frames, frames / secs]

func busy() -> void:
	# A crowd with buffs and debuffs, a few bursts and hits going on.
	var p := game.player
	for i in range(16):
		var e := game._spawn_enemy(game.world_map.nearest_walkable(p.global_position + Vector3(cos(i) * 5.0, 0, sin(i) * 5.0)), false, false)
		e.set_physics_process(false)
		e.apply_status("slow" if i % 2 == 0 else "haste", 600.0, 0.3)
	p.add_hex("potion_F", {"atk": 0.2}, 600.0)
	p.add_hex("boss_shred", {"def": -0.3}, 600.0)

func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(10)
	game = find_game(rig)
	game.fixed_map_seed = 2026
	print("DEVICE ", RenderingServer.get_video_adapter_name())
	for case in ["mine", "city", "snow_blizzard", "siracusa_rain"]:
		var region: String = String(case).split("_")[0]
		if region == "siracusa": ContinuousWorldMap.force_weather = "rain"
		await game.start_contract(region)
		ContinuousWorldMap.force_weather = ""
		await step(30)
		game.player.invulnerable = true
		if case == "snow_blizzard":
			game.features.values.cold = 100.0
			game.field_weather.snap()
		if case == "mine": game.features.values.contamination = 70.0
		busy()
		await step(60)
		var on_sum := 0.0
		var off_sum := 0.0
		var fps_on := 0.0
		var fps_off := 0.0
		for r in range(ROUNDS):
			set_fx(true)
			await step(20)
			var a: Array = await gpu_ms(FRAMES)
			set_fx(false)
			await step(20)
			var b: Array = await gpu_ms(FRAMES)
			on_sum += a[0]
			off_sum += b[0]
			fps_on += a[1]
			fps_off += b[1]
		set_fx(true)
		print("COST %s on %.3f off %.3f delta %.3f fps_on %.0f fps_off %.0f" % [case, on_sum / ROUNDS, off_sum / ROUNDS, (on_sum - off_sum) / ROUNDS, fps_on / ROUNDS, fps_off / ROUNDS])
		game.settle(true)
		await step(10)
	rig.queue_free()
	await create_timer(0.3).timeout
	quit()
