class_name GameMusic
extends Node
## Two looping tracks and a sting for a failed run, cut from Gemini downloads by
## audio/tools/cut_audio.py (cut points in audio/asset_log.json). Behavior
## predicted in CHANGE-BRIEF.md, "Generated audio — predictions".
##
## Each loop file starts with its intro; Godot jumps back to `loop_offset` at
## the end, so the intro plays once and the seam needs no second file.

const TRACKS := {
	"base": ["res://audio/music/base_loop.ogg", 40.171],
	"mine": ["res://audio/music/mine_loop.ogg", 13.3034],
}
# No sting on a successful extraction (用户 2026-10-23: 移除行动成功的背景音乐):
# the base track simply comes back.
const STINGS := {false: "res://audio/music/sting_fail.ogg"}
## Each region's boss track (audio/BOSS_AUDIO_BRIEF.md §1.1: one generation cut
## in two — p1 = intro + A, looping from LOOP_OFFSET; p2 = B, phase 2 on), and
## the boss stings. Missing files: the region's track simply plays on.
const BOSS_TRACK := "res://audio/music/boss_%s_%s.ogg"
const BOSS_LOOP_OFFSET := {}
const BOSS_STINGS := {"down": "res://audio/music/sting_boss_down.ogg", "win": "res://audio/music/sting_boss_win.ogg"}
const BOSS_FADE := 0.6
const LEVEL_DB := -6.0
const PAUSE_DUCK_DB := -10.0     # the base does not freeze on pause, so it ducks
const LEAVE_BASE_FADE := 1.0
const END_FADE := {true: 1.0, false: 0.3}  # extraction, death
const SILENT_DB := -60.0

var game: GameManager
## What is playing: "base", "mine" or "" (between tracks, or a sting holding the base).
var track := ""
var sting := ""                  # "fail" while it plays (STINGS has no extraction sting)
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
	var boss := _boss_track()
	if not boss.is_empty(): want = boss
	if not sting.is_empty(): want = ""
	if want != track and not (want.is_empty() and track.is_empty()):
		_switch(want, BOSS_FADE if want.begins_with("boss_") or track.begins_with("boss_") else LEAVE_BASE_FADE)
	_set_paused(game.modal == "pause")

## Called by GameManager.settle() before it sends the operator home. Only a run
## whose field music was playing gets a sting (not the boot-time settle of an
## interrupted contract).
## The boss track this fight wants ("boss_<region>_p1"/"_p2"), if it is there.
func _boss_track() -> String:
	if game.in_base or not game.boss_fight(): return ""
	var figure := game.outpost_boss
	var part := "p2" if figure.phase >= 2 or figure.life >= 2 else "p1"
	var key := "boss_%s_%s" % [game.region_id, part]
	if not _streams.has(key):
		var path := BOSS_TRACK % [game.region_id, part]
		if not ResourceLoader.exists(path):
			_streams[key] = null
		else:
			var stream: AudioStreamOggVorbis = load(path)
			stream.loop = true
			stream.loop_offset = float(BOSS_LOOP_OFFSET.get(key, 0.0))
			_streams[key] = stream
	return key if _streams[key] != null else ""

## A boss sting over whatever plays ("down": its fall; "win": her fall in its fight).
func boss_sting(kind: String) -> void:
	var path: String = BOSS_STINGS.get(kind, "")
	if path.is_empty() or not ResourceLoader.exists(path): return
	stings_played += 1
	var player := AudioStreamPlayer.new()
	player.bus = "Music"
	player.volume_db = LEVEL_DB
	player.stream = load(path)
	add_child(player)
	player.finished.connect(player.queue_free)
	if not _silent: player.play()

func end_run(extracted: bool) -> void:
	if track != "mine" and not track.begins_with("boss_"): return
	_switch("", END_FADE[extracted])
	if not _streams.has(extracted): return
	sting = "extract" if extracted else "fail"
	stings_played += 1
	_sting_player.stream = _streams[extracted]
	if not _silent: _sting_player.play()

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
	if track == "mine" or track.begins_with("boss_"):
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
