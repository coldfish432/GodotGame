extends SceneTree
## How long building the base takes (基地建模改造案_v1: 加载时间): BaseMap's
## _ready from nothing, then a second build with the kit already cached.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for k in range(2):
		var start := Time.get_ticks_usec()
		var base := BaseMap.new()
		root.add_child(base)
		var built := Time.get_ticks_usec()
		await process_frame
		await RenderingServer.frame_post_draw
		var drawn := Time.get_ticks_usec()
		var nodes := base.find_children("*", "", true, false).size()
		print("base build %d: ready %.0f ms, first frame %.0f ms, %d nodes" % [k, (built - start) / 1000.0, (drawn - built) / 1000.0, nodes])
		base.queue_free()
		await process_frame
	quit()
