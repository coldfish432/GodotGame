extends SceneTree
## 敌人攻击帧数表策划案 v0.1 (用户 2026-11-22 "全部默认"): enemy windup and
## recovery are whole frames at 30 fps, the seconds come from them, half frames
## were rounded up, START is 4 frames and the strike 3, and the pose cells each
## profile shows are in its sheet and not blank. Exits non-zero on failure.

const Sheets := preload("res://tests/test_sheet_cells.gd")
## The profiles the rounding changed: [field, old seconds, new frames].
## Half frames rounded up (待拍板 2), each 1/60 s longer, never shorter.
const ROUNDED := {
	"thug": ["recovery", 0.25, 8], "slug": ["recovery", 0.25, 8], "brawler": ["recovery", 0.25, 8],
	"greytail": ["recovery", 0.25, 8], "family_soldier": ["recovery", 0.25, 8],
	"ice_warrior": ["recovery", 0.35, 11], "ice_hunter": ["recovery", 0.35, 11],
	"fallen_snowpriest": ["recovery", 0.35, 11], "family_capo": ["recovery", 0.35, 11],
	"family_eraser": ["windup", 0.55, 17],
}

var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(label: String, passed: bool, seen: Variant = null) -> void:
	checks += 1
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label)
	if not passed and seen != null: print("   seen: ", seen)

## Each authored attack: the profile, plus 家族角头's "close" palm.
func parts(type: String) -> Array:
	var authored: Dictionary = EnemyAttacks.AUTHORED[type]
	var out := [[type, authored, EnemyAttacks.PROFILES[type]]]
	if authored.has("close"): out.append([type + ".close", authored.close, EnemyAttacks.PROFILES[type].close])
	return out

func run() -> void:
	var fps := EnemyAttacks.DESIGN_FPS
	check("design rate is 30 fps", fps == 30.0)
	check("PROFILES and the authored table list the same %d enemies" % EnemyAttacks.AUTHORED.size(), EnemyAttacks.PROFILES.keys() == EnemyAttacks.AUTHORED.keys())
	check("START is 4 frames (0.1333 s), the strike 3 (0.10 s)", Enemy.START_F == 4 and Enemy.STRIKE_F == 3
		and Enemy.START_TIME == 4 / fps and Enemy.STRIKE_TIME == 3 / fps and is_equal_approx(Enemy.STRIKE_TIME, 0.10), [Enemy.START_TIME, Enemy.STRIKE_TIME])
	var not_int := []
	var seconds_authored := []
	var start_late := []
	var mismatch := []
	for type in EnemyAttacks.AUTHORED:
		for part in parts(type):
			var label: String = part[0]
			var authored: Dictionary = part[1]
			var derived: Dictionary = part[2]
			if authored.has("windup") or authored.has("recovery"): seconds_authored.append(label)
			var fields := ["windup_f"] + (["recovery_f"] if not label.ends_with(".close") else [])
			for field in fields:
				if typeof(authored.get(field)) != TYPE_INT or int(authored.get(field, -1)) < 0: not_int.append("%s.%s=%s" % [label, field, authored.get(field)])
			if typeof(authored.get("windup_f")) == TYPE_INT and int(authored.windup_f) <= Enemy.START_F: start_late.append("%s windup_f %d" % [label, authored.windup_f])
			for key in ["windup", "recovery"]:
				if not authored.has(key + "_f"): continue
				if derived.get(key) != int(authored[key + "_f"]) / fps: mismatch.append("%s.%s %s vs %d f" % [label, key, derived.get(key), authored[key + "_f"]])
	check("every profile authors integer windup_f and recovery_f (and the close palm its windup_f)", not_int.is_empty(), not_int)
	check("no profile authors seconds: the frame table is the only source", seconds_authored.is_empty(), seconds_authored)
	check("START_F < windup_f for every profile", start_late.is_empty(), start_late)
	check("seconds == frames / 30 for every profile", mismatch.is_empty(), mismatch)
	check("PROFILES are read-only like the old const", EnemyAttacks.PROFILES.is_read_only() and EnemyAttacks.PROFILES.thug.is_read_only() and EnemyAttacks.PROFILES.family_capo.close.is_read_only())
	# The rounding rule, listed profile by profile.
	for type in ROUNDED:
		var row: Array = ROUNDED[type]
		var field: String = row[0]
		var old: float = row[1]
		var frames: int = row[2]
		var authored := int(EnemyAttacks.AUTHORED[type][field + "_f"])
		var seconds := float(EnemyAttacks.PROFILES[type][field])
		check("%s %s %.2f s (%.1f f) rounds up to %d f = %.4f s, +1/60 s" % [type, field, old, old * fps, frames, frames / fps],
			authored == frames and frames == floori(old * fps + 0.5) and seconds > old and is_equal_approx(seconds - old, 1.0 / 60.0), [authored, seconds])
	# Every other value was a whole frame already and keeps its seconds.
	var off_grid := []
	for type in EnemyAttacks.AUTHORED:
		for part in parts(type):
			for key in ["windup", "recovery"]:
				var label: String = part[0]
				if ROUNDED.has(label) and ROUNDED[label][0] == key: continue
				if part[1].has(key + "_f") and not is_equal_approx(float(part[2][key]) * fps, roundf(float(part[2][key]) * fps)): off_grid.append("%s.%s" % [label, key])
	check("only the ten listed values changed; the rest were whole frames", off_grid.is_empty(), off_grid)
	# The pose cells each profile shows (START / CHARGE / STRIKE / RECOVER and the sixth row).
	for type in EnemyAttacks.PROFILES:
		var problems: Array = Sheets.enemy_problems(type)
		check("%s pose cells exist and are not blank" % type, problems.is_empty(), problems)
	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)
