class_name SaveSlots
extends RefCounted

## Three save slots (用户 2026-10-23: 最多三个存档，可以删除和开新存档).
## Slot 0 keeps the old single save's file, so that save is slot 1 now. The
## slot last played is settings.save_slot: the exchange terminal and ticker
## follow it.

const COUNT := 3
## Where the slots live; tests point it elsewhere.
static var folder := "user://"
## Every file a save writes beside itself (save_base, market, SaveLock).
const SUFFIXES := ["", ".bak", ".tmp", ".market", ".market.tmp", ".lock", ".release"]

static func path(slot: int) -> String:
	return folder.path_join("field_contract_v1.json" if slot == 0 else "field_contract_v1_slot%d.json" % (slot + 1))

static func used(slot: int) -> bool:
	for p in [path(slot), path(slot) + ".bak"]:
		if FileAccess.file_exists(p) and not FileAccess.get_file_as_string(p).strip_edges().is_empty(): return true
	return false

static func first_free() -> int:
	for slot in range(COUNT):
		if not used(slot): return slot
	return -1

## What the title shows of a used slot: {lmd, operators, saved (unix time)}.
static func summary(slot: int) -> Dictionary:
	var p := path(slot)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else null
	if not parsed is Dictionary: return {}
	var lmd := int(parsed.get("gold", 0)) * (1 if int(parsed.get("version", 1)) >= 3 else Economy.LMD_PER_VALUE)
	var roster: Array = parsed.get("base", {}).get("roster", [Operators.AMIYA_GUARD, Operators.LAPPLAND])
	return {"lmd": lmd, "operators": roster.size(), "saved": FileAccess.get_modified_time(p)}

## A terminal or ticker of another process writes it now.
static func busy(slot: int) -> bool:
	var lock := SaveLock.new(path(slot), "game")
	var d := lock.current()
	return SaveLock.alive(d) and int(d.get("pid", 0)) != OS.get_process_id()

## Removes the slot's files; false (nothing removed) while another process writes it.
static func delete(slot: int) -> bool:
	if busy(slot): return false
	var p := path(slot)
	for suffix in SUFFIXES:
		if FileAccess.file_exists(p + suffix): DirAccess.remove_absolute(p + suffix)
	var dir := DirAccess.open(p.get_base_dir())
	if dir != null:
		for file in dir.get_files():
			if file.begins_with(p.get_file() + ".reader."): dir.remove(file)
	return true
