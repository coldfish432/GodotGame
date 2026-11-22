extends SceneTree

## 动画工程整理案 v0.1 §2 (用户 2026-11-22 "全部默认"): an enemy's, a boss's and a
## 叙拉古 civilian's sprite colour has one writer, _refresh_look(), which composes
## base tint × the one highest-priority state colour × the hit flash, with the
## alpha from stealth. (a) a source scan: nothing outside _refresh_look() assigns
## or tweens `_sprite.modulate`; (b) the real game: a silenced stealth enemy keeps
## its stealth alpha on the same frame, silence has no colour of its own, a hit
## flash overrides and hands back the right colour, a boss's rage, 清算时刻 and
## kneel tints, and a civilian's flash.
## Run: ./scripts/run-test.sh test_modulate_writer.gd 60 300

const FLASH := Color(3.0, 3.0, 3.0)

var rig: Node
var game: GameManager
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = null) -> void:
	checks += 1
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label + ("" if detail == null or passed else "  %s" % str(detail)))

func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null

func same(a: Color, b: Color) -> bool:
	return a.is_equal_approx(b)

func run() -> void:
	_scan()
	BossShow.enabled = false
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(10)
	game = find_game(rig)
	game.save_enabled = false
	game.fixed_map_seed = 1729
	await game.start_contract("siracusa")
	await step(6)
	game.player.invulnerable = true
	await _stealth_and_flash()
	await _boss_and_civilian()
	print("MODULATE WRITER RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

# --- (a) The source scan ------------------------------------------------------------------

const OWNERS := ["res://entities/enemy.gd", "res://entities/boss.gd", "res://entities/civilian.gd"]
## Writes to a sprite's modulate: assignment (any operator, any channel), set(), a tween.
var _assign := RegEx.create_from_string("_sprite\\.modulate(\\.[rgba])?\\s*[-+*/]?=(?!=)")
var _set := RegEx.create_from_string("_sprite\\.set\\(\\s*\"modulate")
var _tween := RegEx.create_from_string("tween_property\\(\\s*[\\w.]*_sprite\\s*,\\s*\"modulate")
var _func := RegEx.create_from_string("^(static\\s+)?func\\s+(\\w+)")
var _own_sprite := RegEx.create_from_string("(?m)^var\\s+_sprite\\b")

func _scan() -> void:
	var files: Array[String] = []
	_collect("res://", files)
	check("the scan sees the scripts (%d)" % files.size(), files.size() > 100 and OWNERS.all(func(o): return o in files))
	var bad: Array[String] = []
	var inside := {}
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		var owner := path in OWNERS
		# Another class's own `_sprite` (the player's animator, loot) is its business;
		# reaching into an enemy's (`x._sprite.modulate`) from anywhere is not.
		if not owner and _own_sprite.search(text) != null and text.find("._sprite.modulate") < 0: continue
		var where := ""
		var lines := text.split("\n")
		for i in range(lines.size()):
			var line := lines[i]
			var m := _func.search(line)
			if m != null: where = m.get_string(2)
			var code := line.split("#")[0]
			if _assign.search(code) == null and _set.search(code) == null and _tween.search(code) == null: continue
			if owner and where == "_refresh_look":
				inside[path] = int(inside.get(path, 0)) + 1
				continue
			bad.append("%s:%d (%s) %s" % [path, i + 1, where, line.strip_edges()])
	check("nothing outside _refresh_look() writes _sprite.modulate", bad.is_empty(), "\n  " + "\n  ".join(bad))
	check("enemy.gd's _refresh_look() is the one writer", int(inside.get("res://entities/enemy.gd", 0)) >= 1, inside)
	var boss_text := FileAccess.get_file_as_string("res://entities/boss.gd")
	var civilian_text := FileAccess.get_file_as_string("res://entities/civilian.gd")
	check("Boss composes its states through _state_tint, Civilian inherits the writer", boss_text.find("func _state_tint(") >= 0 and civilian_text.find("func _refresh_look") < 0)

func _collect(dir: String, out: Array[String]) -> void:
	for sub in DirAccess.get_directories_at(dir):
		if sub.begins_with(".") or (dir == "res://" and sub in ["tests", "addons"]): continue
		_collect(dir.path_join(sub), out)
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "gd": out.append(dir.path_join(file))

# --- (b) The real game --------------------------------------------------------------------

func _spot(gap: float) -> Vector3:
	var from := game.player.global_position
	for i in range(16):
		var p: Vector3 = game.world_map.nearest_walkable(from + Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 16.0) * gap)
		if absf(Vector2(p.x - from.x, p.z - from.z).length() - gap) < 0.8: return p
	return from + Vector3(gap, 0, 0)

func _stealth_and_flash() -> void:
	for e in game.floor_enemies(): e.global_position += Vector3(200, 0, 200)
	var eraser: Enemy = game._spawn_enemy(_spot(9.0), true, false, "family_eraser")
	eraser.global_position = game.player.global_position + Vector3(9, 0, 0)
	eraser.state = Enemy.State.IDLE
	await step(2)
	check("a 灭迹人 far off is unseen (alpha 0)", eraser.stealthed() and eraser._sprite.modulate.a == 0.0, eraser._sprite.modulate)
	var before := eraser._sprite.modulate
	eraser.silence(1.0)
	# The same frame: no physics tick in between to write the alpha back.
	check("silenced, it keeps its stealth alpha on the same frame", eraser.silenced() and eraser._sprite.modulate.a == 0.0, eraser._sprite.modulate)
	check("silence brings no colour of its own (none in the code)", same(eraser._sprite.modulate, before), [before, eraser._sprite.modulate])
	eraser.queue_free()
	# An ordinary enemy with a borrowed sheet's tint.
	var grunt: Enemy = game._spawn_enemy(_spot(5.0), false, false, "")
	grunt.state = Enemy.State.IDLE
	await step(2)
	var tint := Color(0.55, 0.8, 1.0)
	grunt._tint = tint
	grunt._refresh_look()
	check("its resting colour is its tint", same(grunt._sprite.modulate, tint), grunt._sprite.modulate)
	grunt.silence(0.3)
	check("silenced, still its tint", same(grunt._sprite.modulate, tint), grunt._sprite.modulate)
	grunt.take_hit(1.0, "true")
	check("a hit flashes it white", same(grunt._sprite.modulate, FLASH), grunt._sprite.modulate)
	grunt.silence(1.0)
	check("…and silence on top does not cut the flash (flash > silence)", same(grunt._sprite.modulate, FLASH), grunt._sprite.modulate)
	await step(12)
	check("after the flash it is its tint again", same(grunt._sprite.modulate, tint), grunt._sprite.modulate)
	await step(70)
	check("silence over, still its tint", not grunt.silenced() and same(grunt._sprite.modulate, tint), grunt._sprite.modulate)
	grunt.queue_free()

func _boss_and_civilian() -> void:
	game.settle(true)
	await step(2)
	await game.start_contract("siracusa")
	await step(2)
	game.floor_number = 19
	await game.advance(0)
	await step(4)
	game.player.invulnerable = true
	var figure: Boss = game.outpost_boss
	check("扎罗 is on floor 20", is_instance_valid(figure) and figure.figure_id == "zaro", figure)
	if not is_instance_valid(figure): return
	check("awake and calm, his rest tint", same(figure._sprite.modulate, figure._rest_tint()), [figure._sprite.modulate, figure._rest_tint()])
	figure.asleep = true
	figure._rest_look()
	var rest := figure._rest_tint()
	check("asleep, he rests darkened", figure.asleep and same(figure._sprite.modulate, rest) and rest.v < figure._tint.v, [figure._sprite.modulate, rest])
	figure.empower()
	figure._refresh_look()
	var k := 0.5 + 0.5 * sin(figure.fight_time * 9.0)
	var rage := rest.lerp(Color(1.7, 0.45, 0.38), 0.5 + 0.3 * k)
	check("raging, he glows red over his rest tint", same(figure._sprite.modulate, rage), [figure._sprite.modulate, rage])
	figure.take_hit(1.0, "true")
	check("a hit flashes over the rage", same(figure._sprite.modulate, FLASH), figure._sprite.modulate)
	await step(12)
	k = 0.5 + 0.5 * sin(figure.fight_time * 9.0)
	check("after the flash, back to the rage glow", same(figure._sprite.modulate, figure._rest_tint().lerp(Color(1.7, 0.45, 0.38), 0.5 + 0.3 * k)), figure._sprite.modulate)
	figure.rage_left = 0.0
	figure._reckoning_look = true
	figure._refresh_look()
	check("清算时刻 shows its red once the rage is gone (rage > 清算)", same(figure._sprite.modulate, Color("c04050")), figure._sprite.modulate)
	figure._down_look = true
	figure._refresh_look()
	check("清算 red still shows over a kneel (清算 > kneel)", same(figure._sprite.modulate, Color("c04050")), figure._sprite.modulate)
	figure._reckoning_look = false
	figure._refresh_look()
	check("kneeling, he is his tint darkened", same(figure._sprite.modulate, figure._tint.darkened(0.4)), figure._sprite.modulate)
	figure._down_look = false
	figure._refresh_look()
	check("up again, his rest tint", same(figure._sprite.modulate, figure._rest_tint()), figure._sprite.modulate)
	var townsfolk := game.get_tree().get_nodes_in_group("civilians").filter(func(n): return n.get("game") == game)
	check("叙拉古 has its civilians", townsfolk.size() > 0)
	if townsfolk.is_empty(): return
	var one: Civilian = townsfolk[0]
	check("a civilian rests white", same(one._sprite.modulate, Color.WHITE), one._sprite.modulate)
	one.take_hit(1.0, "phys")
	check("struck, it flashes", same(one._sprite.modulate, FLASH), one._sprite.modulate)
	await step(12)
	check("…then white again", not is_instance_valid(one) or same(one._sprite.modulate, Color.WHITE), one._sprite.modulate if is_instance_valid(one) else null)
