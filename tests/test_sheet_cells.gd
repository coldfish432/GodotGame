extends SceneTree
## 动画工程整理案 v0.1 §1: every sheet cell the game draws is inside its sheet
## and not fully transparent. Operator combat sheets (each action-table entry,
## all five COMBAT_ROWS), operator walk / idle sheets, crew walk / idle sheets
## (those that have arrived), NPC idles, and the enemy pose cells each
## EnemyAttacks profile actually shows. Exits non-zero on any problem.
## The static helpers are shared with tests/test_enemy_frames.gd.

## Cells left blank on purpose: "<sheet path>@x,y" -> reason. None so far.
const BLANK_OK := {}
## The sixth-row extras enemy.gd _update_attack_visual switches to pose 5 for
## (lasso throw, glide, incite); the other EXTRA_ROW names are not drawn from there.
const USED_EXTRAS := ["lasso", "glide", "incite"]
const ENEMY_POSES := 5
const ENEMY_CELL := 64
const WALK_COLUMNS := 4
const IDLE_COLUMNS := 2

static var _images := {}

var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")

func check(label: String, passed: bool, seen: Variant = null) -> void:
	checks += 1
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label)
	if not passed and seen != null: print("   seen: ", seen)

## The pixels of a sheet, decompressed, read once.
static func image_of(texture: Texture2D) -> Image:
	var key := texture.resource_path if texture.resource_path != "" else str(texture.get_instance_id())
	if _images.has(key): return _images[key]
	var image := texture.get_image()
	if image.is_compressed(): image.decompress()
	_images[key] = image
	return image

## "" when the cell is inside the sheet and has a visible pixel, else what is wrong.
static func cell_problem(texture: Texture2D, rect: Rect2i) -> String:
	if texture == null: return "no sheet"
	var image := image_of(texture)
	var bounds := Rect2i(Vector2i.ZERO, image.get_size())
	if rect.size.x <= 0 or rect.size.y <= 0 or not bounds.encloses(rect):
		return "cell %s outside %dx%d" % [rect, image.get_width(), image.get_height()]
	if image.get_region(rect).get_used_rect().size == Vector2i.ZERO:
		var key := "%s@%d,%d" % [texture.resource_path, rect.position.x, rect.position.y]
		if BLANK_OK.has(key): return ""
		return "cell %s blank" % rect
	return ""

static func atlas_problem(atlas: AtlasTexture) -> String:
	if atlas == null: return "no frame"
	return cell_problem(atlas.atlas, Rect2i(atlas.region))

## [label, problem] for every cell of a columns x rows grid of `cell` px.
static func grid_problems(texture: Texture2D, columns: int, rows: int, cell: int, label: String) -> Array:
	var out := []
	for row in range(rows):
		for column in range(columns):
			var problem := cell_problem(texture, Rect2i(column * cell, row * cell, cell, cell))
			if problem != "": out.append("%s col %d row %d: %s" % [label, column, row, problem])
	return out

## The pose indices enemy.gd _update_attack_visual can show for `type`, with
## the sheet they come from: {"kind": "dir"|"row"|"elite", ...}.
static func enemy_look(type: String) -> Dictionary:
	var art := EnemyAttacks.art_type(type)
	var elite := EnemyAttacks.is_elite_type(type)
	var sheet_type := type if FieldArt.has_directional(type) else art
	var directional := FieldArt.has_directional(sheet_type) and (not elite or sheet_type == type)
	var poses := range(ENEMY_POSES)
	if directional:
		if str(EnemyN2Data.EXTRA_ROW.get(sheet_type, "")) in USED_EXTRAS: poses.append(5)
		return {"kind": "dir", "sheet": sheet_type, "poses": poses, "walk": FieldArt.has_walk(sheet_type)}
	if elite: return {"kind": "elite"}
	return {"kind": "row", "row": int(EnemyAttacks.PROFILES[art].get("row", -1)), "poses": poses}

## Problems with the pose cells one profile uses (empty when all is well).
static func enemy_problems(type: String) -> Array:
	var look := enemy_look(type)
	var out := []
	match str(look.kind):
		"dir":
			for column in range(8):
				for pose in look.poses:
					var problem := atlas_problem(FieldArt.enemy_dir_pose(look.sheet, column, pose))
					if problem != "": out.append("%s (dir %s) col %d pose %d: %s" % [type, look.sheet, column, pose, problem])
				if look.walk:
					for frame in range(4):
						var problem := atlas_problem(FieldArt.enemy_walk_pose(look.sheet, column, frame))
						if problem != "": out.append("%s (walk %s) col %d frame %d: %s" % [type, look.sheet, column, frame, problem])
		"row":
			if int(look.row) < 0: out.append("%s: no row on ENEMY_ATTACKS and no board" % type)
			else:
				for pose in look.poses:
					var problem := atlas_problem(FieldArt.enemy_pose(int(look.row), pose))
					if problem != "": out.append("%s row %d pose %d: %s" % [type, look.row, pose, problem])
		"elite":
			# The old single elite picture (Enemy._build_visual), one per art region.
			for region in ["mine", "city", "snow"]:
				var problem := atlas_problem(FieldArt.enemy(region, true, false))
				if problem != "": out.append("%s elite picture %s: %s" % [type, region, problem])
	return out

## The columns one action-table entry plays: [first, count] or [[cols], count].
static func entry_columns(entry: Array) -> Array:
	return entry[0] if entry[0] is Array else range(int(entry[0]), int(entry[0]) + int(entry[1]))

func run() -> void:
	var A := LapplandAnimator3D
	var cell := int(A.CELL_TEXELS)
	# The checker itself: a clear cell, a cell past the edge, and a painted one.
	var probe := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	probe.set_pixel(5, 1, Color.WHITE)
	var probe_tex := ImageTexture.create_from_image(probe)
	check("checker flags a blank cell, a cell outside, and passes a painted one",
		cell_problem(probe_tex, Rect2i(0, 0, 4, 4)).ends_with("blank") and cell_problem(probe_tex, Rect2i(4, 2, 4, 4)).contains("outside") and cell_problem(probe_tex, Rect2i(4, 0, 4, 4)) == "")
	# Operator combat sheets.
	for id in A.CHARACTERS:
		var config: Dictionary = A.CHARACTERS[id]
		var combat := A.sheet(id, "combat") as Texture2D
		check("%s has a combat sheet" % id, combat != null)
		if combat == null: continue
		var problems := []
		for action in config.actions:
			var entry: Array = config.actions[action]
			var columns := entry_columns(entry)
			if columns.size() != int(entry[1]): problems.append("%s: %d columns listed, count %d" % [action, columns.size(), entry[1]])
			if entry.size() > 2 and int(entry[2]) >= columns.size(): problems.append("%s: loop offset %d >= %d frames" % [action, entry[2], columns.size()])
			for row in range(A.COMBAT_ROWS.size()):
				for column in columns:
					var problem := cell_problem(combat, Rect2i(int(column) * A.COMBAT_CELL, row * A.COMBAT_CELL, A.COMBAT_CELL, A.COMBAT_CELL))
					if problem != "": problems.append("%s %s col %d: %s" % [action, A.COMBAT_ROWS[row], column, problem])
		check("%s combat: %d actions x 5 rows inside the sheet, none blank" % [id, config.actions.size()], problems.is_empty(), problems)
	# Operator walk (4 x 8) and idle (2 x 8) sheets.
	for id in A.CHARACTERS:
		var walk := A.sheet(id, "walk")
		var problems := []
		if walk is SpriteFrames:
			var frames := walk as SpriteFrames
			for direction in A.IDLE_ROWS:
				var animation := StringName("walk_" + direction)
				if not frames.has_animation(animation) or frames.get_frame_count(animation) != WALK_COLUMNS:
					problems.append("%s: missing or not %d frames" % [animation, WALK_COLUMNS])
					continue
				for i in range(WALK_COLUMNS):
					var problem := atlas_problem(frames.get_frame_texture(animation, i) as AtlasTexture)
					if problem != "": problems.append("%s frame %d: %s" % [animation, i, problem])
		elif walk is Texture2D: problems = grid_problems(walk, WALK_COLUMNS, A.IDLE_ROWS.size(), cell, "walk")
		else: problems.append("no walk sheet")
		check("%s walk: 8 directions x 4 frames, none blank" % id, problems.is_empty(), problems)
		var idle := A.sheet(id, "idle") as Texture2D
		problems = grid_problems(idle, IDLE_COLUMNS, A.IDLE_ROWS.size(), cell, "idle") if idle != null else ["no idle sheet"]
		check("%s idle: 8 directions x 2 frames, none blank" % id, problems.is_empty(), problems)
	# Base crew whose sheets have arrived.
	var waiting := []
	for id in A.CREW:
		if not A.has_sheets(id):
			waiting.append(id)
			continue
		var problems := grid_problems(A.sheet(id, "walk") as Texture2D, WALK_COLUMNS, A.IDLE_ROWS.size(), cell, "walk")
		problems.append_array(grid_problems(A.sheet(id, "idle") as Texture2D, IDLE_COLUMNS, A.IDLE_ROWS.size(), cell, "idle"))
		check("crew %s walk 4x8 / idle 2x8: none blank" % id, problems.is_empty(), problems)
	print("   crew without sheets yet (not drawn): ", waiting)
	# NPC idles: 4 x 1, a cell = width / 4.
	for kind in FieldArt.NPC_IDLES:
		var sheet: Texture2D = load(FieldArt.NPC_IDLES[kind])
		var problems := []
		if sheet == null: problems.append("no sheet")
		else:
			var width := sheet.get_width() / FieldArt.NPC_FRAMES
			check("npc %s width splits into %d frames" % [kind, FieldArt.NPC_FRAMES], sheet.get_width() % FieldArt.NPC_FRAMES == 0, sheet.get_width())
			for i in range(FieldArt.NPC_FRAMES):
				var problem := cell_problem(sheet, Rect2i(i * width, 0, width, sheet.get_height()))
				if problem != "": problems.append("frame %d: %s" % [i, problem])
		check("npc %s idle: 4 frames, none blank" % kind, problems.is_empty(), problems)
	# Enemy pose cells each profile shows.
	for type in EnemyAttacks.PROFILES:
		var look := enemy_look(type)
		var problems := enemy_problems(type)
		var what := "elite picture" if look.kind == "elite" else ("%s poses %s" % [("board " + str(look.sheet)) if look.kind == "dir" else ("ENEMY_ATTACKS row %d" % look.row), look.poses])
		check("enemy %s: %s, none blank" % [type, what], problems.is_empty(), problems)
	# The side-view ENEMY_ATTACKS rows (the fallback when a board is missing).
	for type in EnemyAttacks.PROFILES:
		var row := int(EnemyAttacks.PROFILES[type].get("row", -1))
		if row < 0: continue
		var problems := []
		for pose in range(ENEMY_POSES):
			var problem := atlas_problem(FieldArt.enemy_pose(row, pose))
			if problem != "": problems.append("pose %d: %s" % [pose, problem])
		check("enemy %s: ENEMY_ATTACKS row %d poses 0-4, none blank" % [type, row], problems.is_empty(), problems)
	print("%d checks, %d failed" % [checks, failures])
	quit(1 if failures > 0 else 0)
