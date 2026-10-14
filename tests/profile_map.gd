extends SceneTree
## Map load timing: generates one floor per region with DOWNFALL_PROFILE=1 and
## prints each generate() stage. Run:
##   DOWNFALL_PROFILE=1 godot --headless --path . --script res://tests/profile_map.gd
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var map := ContinuousWorldMap.new()
	root.add_child(map)
	for region in ["mine", "snow", "city"]:
		map.region_id = region
		var start := Time.get_ticks_msec()
		map.generate(46302, 1)
		print("%s floor (scale %.2f): %.1f s" % [region, map.map_scale, (Time.get_ticks_msec() - start) / 1000.0])
	quit()
