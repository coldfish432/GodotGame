extends SceneTree
## Probe: how long the market takes to catch up a span at a given scale.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	MarketState.tz_override = 0
	BaseState.frozen_clock = 1791972000
	var game := GameManager.new()
	game.save_enabled = false
	game.fixed_market_seed = 77
	root.add_child(game)
	for i in range(8): await process_frame
	for row in [[1, 2 * 86400 - 3600], [8, 8 * 86400]]:
		BaseState.set_time_scale(int(row[0]))
		var m := game.market
		var n := [0]
		m.on_step = func(_t, _dt): n[0] += 1
		var t0 := Time.get_ticks_msec()
		m.advance_to(m.t + int(row[1]))
		print("scale %d span %.1f days: %d steps %d ms" % [row[0], row[1] / 86400.0, n[0], Time.get_ticks_msec() - t0])
	quit(0)
