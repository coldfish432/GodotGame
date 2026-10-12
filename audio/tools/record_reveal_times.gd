extends SceneTree

## Walks Lappland into the warehouse and back out (as tests/test_audio.gd does)
## and writes when each reveal cue fired, so cut_audio.py can mix a preview
## of the sequence as the game plays it: audio/_check/warehouse_times.json.
##   godot --headless --path downfall-godot --script res://audio/tools/record_reveal_times.gd

var game: GameManager
var events: Array = []
var t0 := 0

func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func mark(cue: String) -> void:
	events.append([cue, (Time.get_ticks_usec() - t0) / 1e6])

func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(8)
	var base := game.base_map
	var reveal := base.warehouse_reveal
	reveal.bank_lit.connect(func(_k): mark("lights_on"))
	reveal.hatch_opening.connect(func(_i): mark("hatch"))
	reveal.shelf_rising.connect(func(_i): mark("shelf"))
	reveal.lights_out.connect(func(): mark("lights_off"))
	game.player.teleport(base.spawn_point("arrival"))
	await step(4)
	t0 = Time.get_ticks_usec()
	game.player.teleport(base.station("stash").position)
	await step(150)
	game.player.teleport(base.to_world(-40.0, -30.0, BaseMap.PLAYER_Y))
	await step(90)
	game.player.teleport(base.to_world(-50.0, -30.0, BaseMap.PLAYER_Y))
	await step(240)
	mark("walk_out")
	game.player.teleport(base.spawn_point("arrival"))
	await step(240)
	FileAccess.open("res://audio/_check/warehouse_times.json", FileAccess.WRITE).store_string(JSON.stringify(events, "  "))
	print(events)
	game.queue_free()
	await create_timer(0.3).timeout
	quit()
