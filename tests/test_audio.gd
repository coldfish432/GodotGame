extends SceneTree

## Generated audio (CHANGE-BRIEF.md, "Generated audio — predictions"): each
## warehouse event sound fires once per event, the music follows the predicted
## pause / death / extraction behavior, the loop points match the asset log,
## and mute silences the Master bus.

var game: GameManager
var failures := 0
var checks: Array = []
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool) -> void:
	if not passed: failures += 1
	checks.append({"label": label, "passed": passed})
	print(("PASS " if passed else "FAIL ") + label)
func n(cue: String) -> int: return int(game.sound.counts.get(cue, 0))

func run() -> void:
	game = GameManager.new()
	game.save_enabled = false
	game.fixed_map_seed = 1729
	root.add_child(game)
	await step(8)
	var music := game.music

	# --- Files and loop points ------------------------------------------------
	var log: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://audio/asset_log.json"))
	for key in ["base", "mine"]:
		var stream: AudioStreamOggVorbis = music._streams.get(key)
		var entry: Dictionary = log["audio/music/%s_loop.ogg" % key]
		check("%s loop loads, loops, and jumps back to the logged point (%.4f s)" % [key, entry.loop_offset],
			stream != null and stream.loop and is_equal_approx(stream.loop_offset, float(entry.loop_offset)))
	check("both stings load and do not loop", music._streams.has(true) and music._streams.has(false)
		and not music._streams[true].loop and not music._streams[false].loop)
	check("generated light cues load", game.sound.streams.has("lights_on") and game.sound.streams.has("lights_off"))
	check("Music and SFX buses feed Master", AudioServer.get_bus_index("Music") > 0 and AudioServer.get_bus_index("SFX") > 0
		and AudioServer.get_bus_send(AudioServer.get_bus_index("Music")) == "Master")

	# --- Base music and pause -------------------------------------------------
	check("the base plays its track from the start", music.track == "base" and music._loop != null and music._loop.stream == music._streams.base)
	game.toggle_panel("pause")
	await step(30)
	check("pause in the base ducks the music 10 dB, keeps it going", music.paused and not music._loop.stream_paused
		and is_equal_approx(music._loop.volume_db, GameMusic.LEVEL_DB + GameMusic.PAUSE_DUCK_DB))
	game.toggle_panel("pause")
	await step(30)
	check("closing the pause menu brings the base music back", not music.paused and is_equal_approx(music._loop.volume_db, GameMusic.LEVEL_DB))
	game.toggle_panel("inventory")
	await step(2)
	check("other panels leave the music alone", not music.paused)
	game.close_modal()

	# --- Warehouse: one sound per event ---------------------------------------
	var base := game.base_map
	var reveal := base.warehouse_reveal
	var built := reveal.built_shelves().size()
	game.player.teleport(base.spawn_point("arrival"))
	await step(4)
	game.sound.counts.clear()
	game.player.teleport(base.station("stash").position)  # just inside the east door
	var frames := 0
	while frames < 900 and reveal.t < reveal.lights_time:
		await process_frame
		frames += 1
	await step(60)
	check("walking in: one light sound per bank (%d)" % n("lights_on"), n("lights_on") == RoomReveal.BANKS)
	check("one hatch sound per built rack (%d of %d)" % [n("hatch"), built], n("hatch") == built)
	game.player.teleport(base.to_world(-40.0, -30.0, BaseMap.PLAYER_Y))
	await step(90)
	game.player.teleport(base.to_world(-50.0, -30.0, BaseMap.PLAYER_Y))
	await step(120)
	check("one shelf sound per built rack as it rises (%d of %d)" % [n("shelf"), built], n("shelf") == built)
	await step(120)
	check("standing in the lit room repeats nothing", n("lights_on") == RoomReveal.BANKS and n("hatch") == built and n("shelf") == built and n("lights_off") == 0)
	game.player.teleport(base.spawn_point("arrival"))
	frames = 0
	while frames < 900 and reveal.t > 0.0:
		await process_frame
		frames += 1
	await step(30)
	check("walking out: lights off once, after the hatches shut (%d)" % n("lights_off"), n("lights_off") == 1)
	check("leaving plays no light, hatch or shelf sound", n("lights_on") == RoomReveal.BANKS and n("hatch") == built and n("shelf") == built)

	# --- Field music, pause, floors -------------------------------------------
	await game.start_contract("mine")
	await step(3)
	check("a contract switches to the mine track from its intro", music.track == "mine" and music._loop.stream == music._streams.mine)
	var mine_player := music._loop
	# Headless never starts playback (GameMusic._silent), so the player-level
	# checks run in the windowed pass of run_all.ps1 -Visual (Dummy audio driver).
	var live := not music._silent
	await step(30)
	game.toggle_panel("pause")
	# get_playback_position() trails the mixer by one block (~12 ms), so let the
	# pause settle before reading; 30 frames of real playback would move ~0.5 s.
	await step(10)
	var held := music.loop_position()
	await step(30)
	var drift := music.loop_position() - held
	check("pause in the field pauses the loop in place%s" % (" (moved %.3f s in 30 frames)" % drift if live else " (state only, headless)"),
		music.paused and (not live or (mine_player.stream_paused and held > 0.0 and absf(drift) < 0.03)))
	game.toggle_panel("pause")
	await step(30)
	check("closing the pause menu resumes it from the same point%s" % ("" if live else " (state only, headless)"),
		not music.paused and (not live or (not mine_player.stream_paused and music.loop_position() > held)))
	await game._advance_floor(0)
	await step(3)
	check("the next floor carries the same loop on, no restart", music.track == "mine" and music._loop == mine_player)

	# --- Death ----------------------------------------------------------------
	game.close_modal()
	var played := music.stings_played
	game.settle(false)
	game.settle(false)
	await step(3)
	check("death: one STING-FAIL, the field loop fading out", music.stings_played == played + 1 and music.sting == "fail" and music._sting_player.stream == music._streams[false])
	check("the base track waits for the sting", game.in_base and music.track == "")
	music._sting_player.stop()
	music._on_sting_finished()
	await step(3)
	check("after the sting the base track starts", music.track == "base")

	# --- Extraction -----------------------------------------------------------
	game.close_modal()
	await game.start_contract("mine")
	await step(3)
	played = music.stings_played
	game.settle(true)
	await step(3)
	check("extraction: one extract sting", music.stings_played == played + 1 and music.sting == "extract" and music._sting_player.stream == music._streams[true])
	music._sting_player.stop()
	music._on_sting_finished()
	await step(3)

	# --- Boot-time settle of an interrupted contract ---------------------------
	played = music.stings_played
	music.end_run(false)
	check("a settle without field music (interrupted contract on boot) plays no sting", music.stings_played == played and music.track == "base")

	# --- Mute -----------------------------------------------------------------
	var master := AudioServer.get_bus_index("Master")
	SystemScreens.settings.mute = true
	SystemScreens.apply_audio()
	check("mute silences the Master bus", AudioServer.is_bus_mute(master))
	SystemScreens.settings.mute = false
	SystemScreens.apply_audio()
	check("unmute restores it", not AudioServer.is_bus_mute(master))

	# Free the game and give the audio thread a moment to drop its playbacks
	# (same teardown as test_ui_v1); quitting straight away reports them as leaked.
	game.queue_free()
	await create_timer(0.3).timeout
	var report := {"checks": checks, "failures": failures, "playback": "real (windowed, Dummy driver)" if live else "state only (headless)"}
	FileAccess.open("res://../evidence/downfall-audio-tests%s.json" % ("" if live else "-headless"), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("audio: %d failures" % failures)
	quit(1 if failures else 0)
