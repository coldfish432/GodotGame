extends SceneTree
## A test save with everything open (用户 2026-10-20: 给我一个测试什么都开好的存档).
## Backs up the current save first (user://field_contract_v1.json and its
## .market / .bak beside it → *.before_test_save), then writes:
## - all nine operators recruited, each at 精英 2, top level, module 3, every
##   skill-tree node and transmuter bought (transmuters switch freely), 30
##   spare skill and attribute points, and her Rhodes kit in the bays;
## - base at top rank, every rack built, largest pack and safe, drone and
##   console, an order reroll; camps every 10 floors to 100 in each region;
## - every faction at the top relation; 10 000 000 龙门币; a full stack of
##   every material on the shelves.
## Writes into OUT_DIR (TEST_SAVE_OUT, default ../evidence/test_save), never
## over the live save: copy field_contract_v1.json and its .market into the
## game's user folder yourself. Each file is read back and checked, since a
## full disk leaves empty files without an error (2026-10-20: C: was full and
## an earlier version of this script emptied the live save).
## Run:  godot --headless --path downfall-godot --script res://tools/make_test_save.gd

const NAME := "field_contract_v1.json"
const CAMP_DEPTH := 100
const GOLD := 10000000
const SPARE_POINTS := 30

func _initialize() -> void: call_deferred("run")

func out_dir() -> String:
	var dir := OS.get_environment("TEST_SAVE_OUT")
	if dir.is_empty(): dir = ProjectSettings.globalize_path("res://").path_join("../evidence/test_save").simplify_path()
	return dir

func run() -> void:
	var dir := out_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var game := GameManager.new()
	# Build from nothing: point it at an empty path in OUT_DIR while it starts up.
	game.save_path = dir.path_join("_scratch.json")
	game.save_enabled = true
	root.add_child(game)
	for i in range(3): await process_frame
	var base := game.base
	for id in Operators.ORDER: base.recruit(id)
	for id in Operators.ORDER:
		var p := base.progress_for(id)
		p.elite = 2
		p.level = p.level_cap()
		p.exp = 0
		p.module_level = 3
		for node_id in SkillTrees.tree(id):
			var data: Dictionary = SkillTrees.tree(id)[node_id]
			p.ranks[node_id] = SkillTrees.max_rank(data)
			if str(data.type) == "transmuter" and str(p.transmuters.get(data.group, "")).is_empty(): p.transmuters[data.group] = node_id
		p.skill_points = SPARE_POINTS
		p.attribute_points = SPARE_POINTS
	base.max_facilities()
	for category in base.racks: base.racks[category] = BaseCatalog.RACK_SLOTS
	base.pack_level = BaseCatalog.PACK_SIZES.size() - 1
	base.safe_level = BaseCatalog.SAFE_SIZES.size() - 1
	base.drone = true
	base.console = true
	base.reroll_available = true
	for region in FieldCatalog.REGIONS: base.unlock_camp(region, CAMP_DEPTH)
	for faction in FactionCatalog.FACTIONS: game.exchange.relations[faction] = Exchange.RELATION_MAX
	game.gold = GOLD
	var stocked := 0
	for id in MaterialCatalog.MATERIALS:
		if not base.store(MaterialCatalog.create(id, MaterialCatalog.stack_size(id))).is_empty(): stocked += 1
	game.issue_kits()
	base.operator = Operators.LAPPLAND
	game.player.set_operator(base.operator)
	game.save_path = dir.path_join(NAME)
	game.save_base()
	for scratch in ["_scratch.json", "_scratch.json.market", "_scratch.json.bak"]:
		if FileAccess.file_exists(dir.path_join(scratch)): DirAccess.remove_absolute(dir.path_join(scratch))
	var written := FileAccess.get_file_as_string(game.save_path)
	var parsed: Variant = JSON.parse_string(written)
	if not parsed is Dictionary or FileAccess.get_file_as_string(game.save_path + ".market").is_empty():
		push_error("TEST SAVE FAILED: %s is empty or unreadable (disk full?)" % game.save_path)
		quit(1)
		return
	print("TEST SAVE written: %s (%d bytes)" % [game.save_path, written.length()])
	print("operators %d, materials stocked %d / %d" % [base.roster.size(), stocked, MaterialCatalog.MATERIALS.size()])
	quit()
