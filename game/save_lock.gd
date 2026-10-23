class_name SaveLock
extends RefCounted

## One writer per save (交易终端与盯盘小窗策划案_v1_0.md §3): the game, the
## exchange terminal and the ticker can be open at once, but only one of them
## writes the save and the market file; the others read and follow it.
##
##   <save>.lock      the writer: {id, pid, mode, beat, seq}; beat every BEAT s,
##                    seq bumped on every save so readers know to reload
##   <save>.release   the game asks a terminal or ticker writer to step down
##   <save>.reader.*  readers' beats: while any is fresh the writer saves the
##                    market more often
##
## A lock whose beat is older than STALE seconds (a crash) is free to take;
## long enough for the game to build a floor without beating.

const BEAT := 2.0
const STALE := 30

var path := ""
var mode := ""          # "game", "exchange", "ticker"
var id := ""
var holder := false
var seq := 0
## When this one last became the writer: older release requests are not for it.
var claimed_at := 0

func _init(p_path: String, p_mode: String) -> void:
	path = p_path
	mode = p_mode
	id = "%d-%d" % [OS.get_process_id(), randi()]

static func now() -> int:
	return int(Time.get_unix_time_from_system())

func lock_path() -> String:
	return path + ".lock"

func release_path() -> String:
	return path + ".release"

func reader_path() -> String:
	return path + ".reader." + id

static func _read(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	return parsed if parsed is Dictionary else {}

func _write(file_path: String, data: Dictionary) -> void:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify(data))
	file.close()

## The writer as recorded, {} when there is none.
func current() -> Dictionary:
	return _read(lock_path())

## Whether a recorded writer is still there: its beat is fresh. (Not the pid:
## the console build runs the game in a child process, so a pid check across
## processes cannot be trusted.)
static func alive(d: Dictionary) -> bool:
	return not d.is_empty() and now() - int(d.get("beat", 0)) <= STALE

## Still the writer on file? Another process may have taken a lock it thought stale.
func still_holder() -> bool:
	if not holder: return false
	if str(current().get("id", id)) != id: holder = false
	return holder

## Becomes the writer if there is none (or only a stale one). True if it is now.
func try_claim() -> bool:
	var d := current()
	if not d.is_empty() and str(d.get("id", "")) != id and alive(d): return false
	holder = true
	claimed_at = now()
	seq = int(d.get("seq", 0))
	_write_lock()
	if FileAccess.file_exists(reader_path()): DirAccess.remove_absolute(reader_path())
	return true

## Takes the lock whoever has it (the game after waiting for a step-down).
func force_claim() -> void:
	holder = true
	claimed_at = now()
	seq = int(current().get("seq", 0))
	_write_lock()

func _write_lock() -> void:
	_write(lock_path(), {"id": id, "pid": OS.get_process_id(), "mode": mode, "beat": now(), "seq": seq})

## The writer's heartbeat, or a reader's.
func beat() -> void:
	if holder: _write_lock()
	else: _write(reader_path(), {"id": id, "beat": now()})

## The writer saved: readers reload when seq moves.
func saved() -> void:
	if not holder: return
	# Milliseconds since the epoch: never repeats when the writer changes hands.
	seq = maxi(seq + 1, int(Time.get_unix_time_from_system() * 1000.0))
	_write_lock()

func release() -> void:
	if holder and str(current().get("id", "")) == id: DirAccess.remove_absolute(lock_path())
	holder = false
	if FileAccess.file_exists(release_path()) and mode != "game": DirAccess.remove_absolute(release_path())

## Gone for good (on exit): the lock if held, the reader beat otherwise.
func leave() -> void:
	release()
	if FileAccess.file_exists(reader_path()): DirAccess.remove_absolute(reader_path())

## The game asks the writer to step down.
func request_release() -> void:
	_write(release_path(), {"by": id, "at": now()})

## For a terminal or ticker writer: has the game asked for the save?
func release_requested() -> bool:
	return holder and mode != "game" and int(_read(release_path()).get("at", -1)) >= claimed_at

## Whether any reader beat is fresh (the writer then saves the market often).
func readers_present() -> bool:
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null: return false
	var prefix := path.get_file() + ".reader."
	for f in dir.get_files():
		if not f.begins_with(prefix): continue
		var d := _read(path.get_base_dir().path_join(f))
		if now() - int(d.get("beat", 0)) <= STALE: return true
		dir.remove(f)
	return false
