extends SceneTree

## Not a test — drives an automated, decision-based playthrough (via
## AiDriver) for Godot's built-in Movie Maker mode to record to video. The
## bot re-reads real game state every tick and reacts (dodge a telegraph,
## heal, fight the nearest enemy, take the buff, dive) rather than following
## fixed positions/timings, so what gets recorded is actually playing the
## game by its rules, not a canned animation. Run with:
##   godot --path downfall-godot --script res://tests/record_demo.gd
##        --write-movie ../evidence/downfall-demo.avi --fixed-fps 60
## (Movie Maker needs a real rendering backend, so no --headless here.)

const Game = preload("res://game/game_manager.gd")
const Driver = preload("res://tests/ai_driver.gd")

const TARGET_FLOOR := 3
const MAX_FRAMES := 5400  # 90s safety cap at 60 FPS in case the bot ever stalls

var game: Node3D
var driver: AiDriver

func _initialize() -> void:
	call_deferred("run")

func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame

func run() -> void:
	game = Game.new()
	game.start_at_base = false
	game.save_enabled = false
	root.add_child(game)
	driver = Driver.new()
	await step(30)  # let NavMesh baking + sync settle before the bot starts issuing move targets

	var frame_count := 0
	while game.floor_number < TARGET_FLOOR and frame_count < MAX_FRAMES:
		driver.decide(game)
		await step(1)
		frame_count += 1

	await step(60)  # linger a moment on the new floor before the recording ends
	quit()
