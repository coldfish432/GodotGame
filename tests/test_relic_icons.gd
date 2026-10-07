extends SceneTree

## Relic icons (美术补全案 §5): every catalog relic has an icon id, every id is
## unique, every runtime icon is 72×72 and drawn at a whole multiple, and relics
## without art keep the first-character plate.

var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(label: String, passed: bool, seen: Variant = null) -> void:
	checks += 1
	if not passed:
		failures += 1
		if seen != null: print("   seen: ", seen)
	print(("PASS " if passed else "FAIL ") + label)

func run() -> void:
	var relics := RelicCatalog.all()
	var missing: Array = relics.filter(func(r): return RelicIcons.icon_id(r).is_empty()).map(func(r): return r.name)
	check("every catalog relic has an icon id", missing.is_empty(), missing)
	var names := relics.map(func(r): return r.name)
	var stale: Array = RelicIcons.BY_NAME.keys().filter(func(n): return not names.has(n))
	check("every icon id belongs to a catalog relic", stale.is_empty(), stale)
	var ids := {}
	for id in RelicIcons.BY_NAME.values(): ids[id] = true
	check("icon ids are unique", ids.size() == RelicIcons.BY_NAME.size(), ids.size())

	var with_art := 0
	var bad_size := []
	for relic in relics:
		var texture := RelicIcons.texture_for(relic)
		if texture == null: continue
		with_art += 1
		if texture.get_size() != Vector2(72, 72): bad_size.append(relic.name)
	check("all 96 relics have art in runtime", with_art == relics.size() and relics.size() == 96, with_art)
	check("every icon is 72×72", bad_size.is_empty(), bad_size)

	var emperor := RelicCatalog.get_relic("皇帝的恩宠")
	for side in [72, 144]:
		var tile := AK.relic_icon(emperor, side)
		var art: TextureRect = null
		for child in tile.get_children():
			if child is TextureRect: art = child
		check("relic_icon(%d) draws the icon" % side, art != null)
		if art != null:
			check("relic_icon(%d) is %d× and centred" % [side, side / 72], art.size == Vector2(side, side) and art.position == Vector2.ZERO, [art.size, art.position])
			check("relic_icon(%d) uses nearest filtering" % side, art.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST)
		tile.free()

	var fake := {"name": "测试用无图藏品", "rarity": 0}
	var plate := AK.relic_icon(fake, 72)
	var glyph: Label = null
	for child in plate.get_children():
		if child is Label: glyph = child
	check("a relic without art keeps the first-character plate", glyph != null and glyph.text == "测")
	plate.free()

	print("relic icons: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
