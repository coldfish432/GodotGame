extends SceneTree

## 龙门城区与叙拉古地图改造案 v1.1: 龙门城区 is 上城 or 下城 by a roll on each
## floor's seed, half and half; 下城 is the same plan in other pieces, light,
## filter and materials (all that collides placed exactly as in 上城); and
## Siracusa at dusk has its bell tower, arched houses and string lights.

var SEEDS := 6 if OS.get_environment("DOWNFALL_FULL") == "1" else 3

var failures := 0

func _initialize() -> void: call_deferred("run")

func check(label: String, passed: bool) -> void:
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label)

func run() -> void:
	_check_roll()
	_check_looks()
	var map := ContinuousWorldMap.new()
	root.add_child(map)
	_check_lungmen(map)
	_check_siracusa(map)
	ContinuousWorldMap.force_city_variant = ""
	print("failures %d" % failures)
	quit(1 if failures > 0 else 0)

func _check_roll() -> void:
	var lower := 0
	var same := true
	for i in range(1000):
		var floor_seed := 9137 + i * 7919
		var v := ContinuousWorldMap.city_variant_of(floor_seed)
		if v == "lower": lower += 1
		if ContinuousWorldMap.city_variant_of(floor_seed) != v: same = false
	print("lower %d of 1000" % lower)
	check("a floor seed always rolls the same city", same)
	check("about half the floors are 下城 (%d of 1000)" % lower, lower >= 440 and lower <= 560)
	check("the region is 龙门城区", FieldCatalog.REGIONS.city.name == "龙门城区")
	check("the top bar says 上城 or 下城 in Lungmen", FieldCatalog.place_name("city", "upper") == "龙门城区 · 上城" and FieldCatalog.place_name("city", "lower") == "龙门城区 · 下城")
	check("and nothing of it elsewhere or in a camp", FieldCatalog.place_name("city", "") == "龙门城区" and FieldCatalog.place_name("mine", "lower") == FieldCatalog.REGIONS.mine.name)

func _strength(key: String) -> float:
	var look: Dictionary = GameManager.FIELD_LOOK[key]
	return FieldLight.REGIONS[key].ambient.v * float(look.ambient)

func _check_looks() -> void:
	check("下城 has its own light, darker than 上城", FieldLight.REGIONS.has("city_lower") and GameManager.FIELD_LOOK.has("city_lower") and _strength("city_lower") < _strength("city"))
	check("叙拉古 is at dusk: colder and darker than it was", FieldLight.REGIONS.siracusa.ambient.b > FieldLight.REGIONS.siracusa.ambient.r and _strength("siracusa_rain") < _strength("siracusa"))
	var e := GameManager.field_environment("city_lower")
	check("下城's filter: its saturation, contrast and grade", is_equal_approx(e.adjustment_saturation, 0.9) and is_equal_approx(e.adjustment_contrast, 1.1) and e.adjustment_color_correction is GradientTexture1D)
	var grade := (e.adjustment_color_correction as GradientTexture1D).gradient
	check("blue in the shadows, warm in the highlights", grade.sample(0.0).b > grade.sample(0.0).r and grade.sample(1.0).r > grade.sample(1.0).b)
	check("叙拉古 has a filter too", GameManager.field_environment("siracusa").adjustment_color_correction != null)
	var ground := FieldArt.terrain_material("city", "city_lower")
	check("下城's street is wet and a shade darker", float(ground.get_shader_parameter("wet")) > 0.5 and float(ground.get_shader_parameter("ground_gain")) < 1.0)
	var upper := FieldArt.terrain_material("city", "city")
	check("上城's street is as it was", upper.get_shader_parameter("wet") == null or float(upper.get_shader_parameter("wet")) == 0.0)

## What collides, as placed: the props' footprints and the dressing's counts.
func _plan(map: ContinuousWorldMap) -> Array:
	var city: CityDressing = map.terrace_dressing.city
	var blockers := []
	for b in map.prop_blockers: blockers.append(str(b))
	return [blockers, city.frontage_count, city.building_count, city.barricade_count, city.neon_count, city.furniture_count, map.cache_positions, map.enemy_spawn_points.size()]

func _check_lungmen(map: ContinuousWorldMap) -> void:
	var same_plan := 0
	var fewer_lamps := 0
	var swapped := 0
	var no_pink := 0
	var skybridges := 0
	var bridges_clear := true
	var lights := 0
	var laundry := 0
	for i in range(SEEDS):
		var seed_value := (i + 3) * 15485863
		map.region_id = "city"
		ContinuousWorldMap.force_city_variant = "upper"
		map.generate(seed_value, 1)
		var upper := _plan(map)
		var upper_lamps: int = map.terrace_dressing.city.street_lamp_count
		ContinuousWorldMap.force_city_variant = "lower"
		map.generate(seed_value, 1)
		var city: CityDressing = map.terrace_dressing.city
		if _plan(map) == upper: same_plan += 1
		if FieldLight.key(map) == "city_lower" and city.lower and city.street_lamp_count * 2 < upper_lamps: fewer_lamps += 1
		var lower_paths := 0
		var plain_paths := 0
		for path in city.transforms:
			var name := String(path).get_file().get_basename()
			if name.ends_with("_lower"): lower_paths += 1
			if CityDressing.LOWER_PIECES.has(name): plain_paths += 1
		if lower_paths > 0 and plain_paths == 0: swapped += 1
		var pink := false
		for path in city._neon_colours:
			for c in city._neon_colours[path]:
				if CityDressing.LOWER_NEON.has(c): pink = true
		if not pink: no_pink += 1
		skybridges += city.skybridge_count
		if city.skybridge_count > CityDressing.SKYBRIDGE_COUNT.y: bridges_clear = false
		for p in city.skybridge_points:
			if is_instance_valid(map.exit_node) and p.distance_to(Vector2(map.exit_node.position.x, map.exit_node.position.z)) < CityDressing.SKYBRIDGE_CLEAR: bridges_clear = false
			if map._surface.distance_near(p) < 0.0: bridges_clear = false
		lights += city.window_light_count + city.red_lantern_count
		laundry += city.laundry_count
		print("seed %d lamps %d/%d skybridges %d windows %d lanterns %d laundry %d" % [seed_value, city.street_lamp_count, upper_lamps, city.skybridge_count, city.window_light_count, city.red_lantern_count, city.laundry_count])
	check("下城 is 上城's plan to the metre (%d/%d)" % [same_plan, SEEDS], same_plan == SEEDS)
	check("下城 keeps a third of the street lamps (%d/%d)" % [fewer_lamps, SEEDS], fewer_lamps == SEEDS)
	check("下城 builds the lower-city copies of the buildings (%d/%d)" % [swapped, SEEDS], swapped == SEEDS)
	check("no pink or violet neon in 下城 (%d/%d)" % [no_pink, SEEDS], no_pink == SEEDS)
	check("牌楼连廊 over her roads, 1–2 a floor, clear of the way down (%d)" % skybridges, skybridges >= SEEDS and bridges_clear)
	check("window and lantern light, laundry over the streets", lights > 0 and laundry > 0)

func _check_siracusa(map: ContinuousWorldMap) -> void:
	ContinuousWorldMap.force_city_variant = ""
	var towers := 0
	var towers_ok := true
	var arches := 0
	var strings := 0
	for i in range(SEEDS):
		map.region_id = "siracusa"
		map.generate((i + 1) * 104729, 1)
		check("叙拉古 is no 上城 or 下城", map.city_variant == "")
		var town: SiracusaDressing = map.terrace_dressing.city
		towers += town.bell_tower_count
		if town.bell_tower_count > 1: towers_ok = false
		if town.bell_tower_count == 1 and is_instance_valid(map.exit_node) and town.bell_tower_point.distance_to(Vector2(map.exit_node.position.x, map.exit_node.position.z)) < SiracusaDressing.BELL_TOWER_CLEAR: towers_ok = false
		arches += town.arch_count
		if town.arch_count > SiracusaDressing.ARCH_COUNT.y: towers_ok = false
		strings += town.string_count
		print("siracusa seed %d tower %d arches %d strings %d bulbs %d lines %d" % [(i + 1) * 104729, town.bell_tower_count, town.arch_count, town.string_count, town.bulb_count, town.line_count])
	check("a bell tower on the floors, one at most, away from the way down (%d/%d)" % [towers, SEEDS], towers >= SEEDS - 1 and towers_ok)
	check("arched houses over the lanes (%d)" % arches, arches >= SEEDS)
	check("string lights over the lanes (%d)" % strings, strings > 0)
