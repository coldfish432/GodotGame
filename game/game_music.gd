class_name GameMusic
extends Node
## Two looping tracks and two stings, cut from Gemini downloads by
## audio/tools/cut_audio.py (cut points in audio/asset_log.json). Behavior
## predicted in CHANGE-BRIEF.md, "Generated audio — predictions".
##
## Each loop file starts with its intro; Godot jumps back to `loop_offset` at
## the end, so the intro plays once and the seam needs no second file.

const TRACKS := {
	"base": ["res://audio/music/base_loop.ogg", 40.171],
	"mine": ["res://audio/music/mine_loop.ogg", 13.3034],
}
const STINGS := {true: "res://audio/music/sting_extract.ogg", false: "res://audio/music/sting_fail.ogg"}
const LEVEL_DB := -6.0
const PAUSE_DUCK_DB := -10.0     # the base does not freeze on pause, so it ducks
const LEAVE_BASE_FADE := 1.0
const END_FADE := {true: 1.0, false: 0.3}  # extraction, death
const SILENT_DB := -60.0

var game: GameManager
## What is playing: "base", "mine" or "" (between tracks, or a sting holding the base).
var track := ""
var sting := ""                  # "extract" / "fail" while one plays
var paused := false
var stings_played := 0
var _loop: AudioStreamPlayer
var _sting_player: AudioStreamPlayer
var _streams := {}
## Headless runs (the tests) switch tracks and streams but never start playback,
## like FieldAudio: a stream still playing at quit is reported as leaked.
var _silent := DisplayServer.get_name() == "headless"

static func ensure_buses() -> void:
	for name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(name) >= 0: continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, name)
		AudioServer.set_bus_send(index, "Master")

func _ready() -> void:
	GameMusic.ensure_buses()
	for key in TRACKS:
		var path: String = TRACKS[key][0]
		if not ResourceLoader.exists(path): continue
		var stream: AudioStreamOggVorbis = load(path)
		stream.loop = true
		stream.loop_offset = TRACKS[key][1]
		_streams[key] = stream
	for extracted in STINGS:
		if ResourceLoader.exists(STINGS[extracted]):
			var stream: AudioStreamOggVorbis = load(STINGS[extracted])
			stream.loop = false
			_streams[extracted] = stream
	_sting_player = AudioStreamPlayer.new()
	_sting_player.bus = "Music"
	_sting_player.volume_db = LEVEL_DB
	_sting_player.finished.connect(_on_sting_finished)
	add_child(_sting_player)

func _process(_delta: float) -> void:
	if not is_instance_valid(game): return
	var want := "base" if game.in_base else "mine"
	if not sting.is_empty(): want = ""
	if want != track and not (want.is_empty() and track.is_empty()):
		_switch(want, LEAVE_BASE_FADE)
	_set_paused(game.modal == "pause")

## Called by GameManager.settle() before it sends Lappland home. Only a run
## whose field music was playing gets a sting (not the boot-time settle of an
## interrupted contract).
func end_run(extracted: bool) -> void:
	if track != "mine": return
	_switch("", END_FADE[extracted])
	sting = "extract" if extracted else "fail"
	stings_played += 1
	if _streams.has(extracted):
		_sting_player.stream = _streams[extracted]
		if not _silent: _sting_player.play()
	else:
		_on_sting_finished()

func _on_sting_finished() -> void:
	sting = ""

func _switch(to: String, fade: float) -> void:
	if is_instance_valid(_loop):
		var old := _loop
		old.stream_paused = false
		var tween := create_tween()
		tween.tween_property(old, "volume_db", SILENT_DB, fade)
		tween.tween_callback(old.stop)
		tween.tween_callback(old.queue_free)
	_loop = null
	track = to
	paused = false
	if to.is_empty(): return
	_loop = AudioStreamPlayer.new()
	_loop.bus = "Music"
	_loop.volume_db = LEVEL_DB
	add_child(_loop)
	if _streams.has(to):
		_loop.stream = _streams[to]
		if not _silent: _loop.play()

func _set_paused(value: bool) -> void:
	if value == paused or not is_instance_valid(_loop): return
	paused = value
	if track == "mine":
		_loop.stream_paused = value
	else:
		create_tween().tween_property(_loop, "volume_db", LEVEL_DB + (PAUSE_DUCK_DB if value else 0.0), 0.25)

func _exit_tree() -> void:
	for player in get_children():
		if player is AudioStreamPlayer:
			player.stop()
			player.stream = null
	_streams.clear()

## Playback position of the loop, for tests and the seam check.
func loop_position() -> float:
	return _loop.get_playback_position() if is_instance_valid(_loop) and (_loop.playing or _loop.stream_paused) else -1.0
