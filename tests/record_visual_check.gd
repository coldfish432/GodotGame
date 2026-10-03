extends SceneTree

## Not a test — a short (few-second) recording purely to visually verify the
## pixel-art render pipeline and the new character sprites, using the same
## AiDriver as record_demo.gd but cut short since this is just a look, not
## a full playthrough.

const Game = preload("res://game/game_manager.gd")
const Driver = preload("res://tests/ai_driver.gd")

const MAX_FRAMES := 420  # 7s at 60 FPS — enough to show movement + a fight

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
	await step(30)  # let NavMesh baking + sync settle

	var frame_count := 0
	while frame_count < MAX_FRAMES:
		driver.decide(game)
		await step(1)
		frame_count += 1

	quit()
