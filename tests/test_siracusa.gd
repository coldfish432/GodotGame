extends SceneTree

## 叙拉古 · 沃尔西尼旧城区, stage S2 (叙拉古地图调研与方案_v1.md §5): the region
## is listed and drops its own things, and its floors are an old town —
## crooked narrow lanes, small piazzas, mansions walled round one gate,
## at most one theatre and one court — dressed in its own way (用户 2026-10-16:
## 和龙门风格不同) on Lungmen's placeholder models.

var SEEDS := 20 if OS.get_environment("DOWNFALL_FULL") == "1" else 8

var failures := 0

func _initialize() -> void: call_deferred("run")

func check(label: String, passed: bool) -> void:
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ") + label)

func run() -> void:
	_check_catalogs()
	var map := ContinuousWorldMap.new()
	root.add_child(map)
	var connected := 0
	var narrow := 0
	var kinked := 0
	var lanes := 0
	var with_mansion := 0
	var mansions_ok := 0
	var mansions := 0
	var mansion_safes := 0
	var landmark_ok := 0
	var landmark_count := 0
	var landmark_built := 0
	var dressed := 0
	var angled := 0
	var lungmen_furniture := 0
	var fountains := 0
	var lanterns := 0
	var banners := 0
	var turfs_ok := 0
	var weathers := {}
	var rain_ok := 0
	var stone_ground := 0
	var buildings := 0
	for i in range(SEEDS):
		map.region_id = "siracusa"
		var seed_value := (i + 1) * 104729
		map.generate(seed_value, 1)
		if map._surface.connects(map._reach_targets()): connected += 1
		# Lanes: 5.2–6.6 m wall to wall, kinked off the straight line.
		var all_narrow := true
		for link in map._links:
			if not link.alive or link.has("bridge"): continue
			lanes += 1
			if float(link.width) < ContinuousWorldMap.LANE_WIDTH.x or float(link.width) > ContinuousWorldMap.LANE_WIDTH.y: all_narrow = false
			var a: Vector2 = map._centre(int(link.a))
			var b: Vector2 = map._centre(int(link.b))
			var off := Geometry2D.get_closest_point_to_segment(link.middle, a, b).distance_to(link.middle)
			if off >= a.distance_to(b) * ContinuousWorldMap.LANE_KINK.x * 0.95: kinked += 1
		if all_narrow: narrow += 1
		# Mansions: dead ends, one way in, a safe's cache in the court.
		if not map.mansion_rooms.is_empty(): with_mansion += 1
		var ok := true
		for room in map.mansion_rooms:
			mansions += 1
			if map._degree(room) != 1 or map.circle_kinds[room] != "spur": ok = false
			if room in [map.exit_chamber, map.extraction_chamber]: ok = false
			for at in map.cache_positions:
				if map.room_at(Vector2(at.x, at.z)) == room:
					mansion_safes += 1
					break
		if ok: mansions_ok += 1
		# Landmarks: one theatre and one court at most, in no mansion.
		var seen := {}
		var lm_ok := true
		for l in map.landmarks:
			if seen.has(l.kind) or map.is_mansion(int(l.room)): lm_ok = false
			seen[l.kind] = true
			landmark_count += 1
		if lm_ok: landmark_ok += 1
		var city = map.terrace_dressing.city
		if city is SiracusaDressing:
			dressed += 1
			landmark_built += city.landmark_kinds.size()
			angled += city.angled_fronts
			buildings += city.building_count
			fountains += city.fountain_count
			lanterns += city.lantern_count
			banners += city.banner_count
			lungmen_furniture += city.traffic_light_count + city.zebra_count + city.cable_count + city.side_streets.size() + city.culvert_count + city.scaffold_count + city.gate_count + city.neon_count
		# Turfs: two or three of the families.
		var kinds := {}
		for d in map.districts:
			if d.kind in ContinuousWorldMap.FAMILIES: kinds[d.kind] = true
		if map.districts.size() >= 2 and map.districts.size() <= 3 and kinds.size() == map.districts.size(): turfs_ok += 1
		weathers[map.weather] = int(weathers.get(map.weather, 0)) + 1
		var falling = map.terrace_dressing.weather
		if (map.weather == "rain") == (falling != null and is_instance_valid(falling) and falling.name == "Rainfall"): rain_ok += 1
		var ground := map.find_child("WalkableTerrain", true, false) as MeshInstance3D
		if ground != null:
			var material := ground.material_override as ShaderMaterial
			if material != null and material.get_shader_parameter("road_tex") == FieldArt.painted("siracusa_road"): stone_ground += 1
		print("seed %d lanes %d mansions %s landmarks %s fronts %d angled %d fountains %d lanterns %d banners %d weather %s turfs %s" % [seed_value, map._links.size(), map.mansion_rooms, map.landmarks, city.frontage_count if city != null else -1, city.angled_fronts if city is SiracusaDressing else -1, city.fountain_count if city is SiracusaDressing else -1, city.lantern_count if city is SiracusaDressing else -1, city.banner_count if city is SiracusaDressing else -1, map.weather, kinds.keys()])
	check("every floor connects (%d/%d)" % [connected, SEEDS], connected == SEEDS)
	check("every lane is 5.2–6.6 m wide (%d/%d floors)" % [narrow, SEEDS], narrow == SEEDS)
	check("lanes kink off the straight line (%d/%d)" % [kinked, lanes], kinked >= lanes * 0.9)
	check("most floors have a mansion (%d/%d)" % [with_mansion, SEEDS], with_mansion >= SEEDS * 0.6)
	check("mansions are dead ends with one way in, no exit in them (%d/%d)" % [mansions_ok, SEEDS], mansions_ok == SEEDS)
	check("each reachable mansion keeps a cache in its court (%d/%d)" % [mansion_safes, mansions], mansion_safes >= mansions - 1)
	check("one theatre and one court at most (%d/%d)" % [landmark_ok, SEEDS], landmark_ok == SEEDS)
	check("landmarks appear (%d over %d floors)" % [landmark_count, SEEDS], landmark_count >= SEEDS / 2)
	check("most landmarks get their front (%d/%d)" % [landmark_built, landmark_count], landmark_built >= landmark_count * 0.6)
	check("every floor is dressed by SiracusaDressing (%d/%d)" % [dressed, SEEDS], dressed == SEEDS)
	check("buildings line the lanes (%d)" % buildings, buildings >= SEEDS * 60)
	check("fronts follow lanes at an angle (%d)" % angled, angled >= SEEDS * 5)
	check("no Lungmen street furniture: crossings, lights, cables, side streets, gates, neon (%d)" % lungmen_furniture, lungmen_furniture == 0)
	check("fountains in the piazzas (%d)" % fountains, fountains >= SEEDS / 2)
	check("wall lanterns along the lanes (%d)" % lanterns, lanterns >= SEEDS * 15)
	check("family banners where turfs meet (%d)" % banners, banners >= SEEDS)
	check("two or three family turfs a floor (%d/%d)" % [turfs_ok, SEEDS], turfs_ok == SEEDS)
	check("rain and overcast both turn up %s" % [weathers], weathers.has("rain") and weathers.has("overcast"))
	check("rain falls exactly when the floor's weather is rain (%d/%d)" % [rain_ok, SEEDS], rain_ok == SEEDS)
	check("its own stone paving wall to wall (%d/%d)" % [stone_ground, SEEDS], stone_ground == SEEDS)
	# Other regions are untouched by the old town.
	map.region_id = "city"
	map.generate(2026, 1)
	check("Lungmen keeps no mansions, landmarks or weather", map.mansion_rooms.is_empty() and map.landmarks.is_empty() and map.weather == "" and not (map.terrace_dressing.city is SiracusaDressing))
	# 用户 2026-10-16: 龙门加霓虹灯. Lungmen's signs, tinted, each with its pool.
	var lungmen = map.terrace_dressing.city
	var neon_sets := 0
	for child in lungmen.root.get_children():
		if child.name.begins_with("city_neon_") and child is MultiMeshInstance3D and (child as MultiMeshInstance3D).multimesh.use_colors: neon_sets += 1
	check("Lungmen's streets carry tinted neon (%d signs, %d sets)" % [lungmen.neon_count, neon_sets], lungmen.neon_count >= 40 and neon_sets >= 2)
	var slum_neon: int = lungmen.neon_districts.count("slum")
	check("no neon in the slums (%d)" % slum_neon, slum_neon == 0)
	map.region_id = "mine"
	map.generate(2026, 1)
	check("the mine is not a town", not map.urban and map.terrace_dressing.city == null)
	print("RESULT %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)

func _check_catalogs() -> void:
	check("Siracusa is a region", FieldCatalog.REGIONS.has("siracusa") and FieldCatalog.REGIONS.siracusa.name == "叙拉古 · 沃尔西尼旧城区")
	check("Siracusa is a town and borrows Lungmen's art", FieldCatalog.urban("siracusa") and FieldCatalog.art_region("siracusa") == "city" and FieldCatalog.art_region("snow") == "snow")
	var crest := FieldCatalog.exclusive("siracusa")
	check("its exclusive is the Saluzzo crest", crest.item_name == "萨卢佐家族的旧徽记" and crest.effect == "saluzzo_crest" and crest.exclusive_region == "siracusa")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var regions := {}
	for k in range(200):
		var id := GearCatalog.pick(Item.Category.ARMOR, "siracusa", 4, "box", "", rng)
		regions[GearCatalog.base(id).region] = true
	check("its armour draws from every region's tables %s" % [regions.keys()], regions.size() == 3)
	var own := true
	for k in range(200):
		if GearCatalog.base(GearCatalog.pick(Item.Category.WEAPON, "siracusa", 4, "box", "", rng)).region != "siracusa": own = false
	check("its weapons come from its own table (装备策划案 §11)", own)
	var pool: Dictionary = EnemyAttacks.REGION_POOLS.get("siracusa", {})
	check("it has an enemy pool", pool.has("normal") and pool.has("ranged") and pool.has("elite"))
	var kinds := LootTables.plan_points("siracusa", 40, rng)
	check("its points of interest lean to safes and tool boxes, no depots or ore", kinds.count("safe") + kinds.count("tool_box") >= 12 and not kinds.has("depot") and not kinds.has("ore_vein") and not kinds.has("camp"))
	var crests := 0
	for k in range(200):
		for drop in LootTables.container_drops("safe", {"rng": rng, "region": "siracusa", "depth": 3}):
			if drop.has("item") and (drop.item as Item).effect == "saluzzo_crest": crests += 1
	check("its safes give up the crest now and then (%d/200)" % crests, crests >= 15 and crests <= 70)
	check("its floors read SR", AK.REGION_CODE.get("siracusa", "") == "SR")
	check("its light is its own, darker in the rain", FieldLight.REGIONS.has("siracusa") and FieldLight.REGIONS.siracusa_rain.ambient.v < FieldLight.REGIONS.siracusa.ambient.v)
