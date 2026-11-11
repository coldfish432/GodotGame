extends SceneTree
## GPU粒子特效推广策划案 v0.6 state test (headless; what it looks like is the
## captures' job). The real game: main.tscn, real contracts, the real loop.
##   P0b  HitSpark per operator palette and style, the cap, crit size
##   P1   BossVfx.burst on the GPU: settings carried over, keeping clear, cache
##   P3   HazardFx: fire ratio by time left and the last second, fuse then blast;
##        the bottle's glass
##   P2   FieldWeather: lying snow by the cold, the 5 s stage easing, snap on
##        entry, blizzard 90 in / 85 out and its occlusion, fire melt, tracks,
##        snow intensity; rain puddles filling, fixed per seed; Lungmen lower wet
##   P4   the converted emitters are GPU
##   P5   StatusPost levels, stage curve, render priority under the markers
##   P6   StatusRings: timed only, one layer, both at once, enemies, cap 24, pool
##   P7   StatusBar: order of appearance, meal and stages listed, clock share,
##        a refresh starts the clock again; KEY_GOOD covers every hex key
## Run: TEST_TIMEOUT=900 ./scripts/run-test.sh test_gpu_fx.gd 60

var rig: Node
var game: GameManager
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(label: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed: failures += 1

func step(n: int = 1) -> void:
	for i in range(n):
		await physics_frame
		await process_frame

func find_game(node: Node) -> GameManager:
	if node is GameManager: return node
	for child in node.get_children():
		var found := find_game(child)
		if found != null: return found
	return null

func emitters(node: Node) -> Array:
	return node.find_children("*", "GPUParticles3D", true, false)

func run() -> void:
	rig = load("res://game/main.tscn").instantiate()
	rig.persist_sessions = false
	root.add_child(rig)
	await step(10)
	game = find_game(rig)
	game.fixed_map_seed = 2026
	scenes()
	catalog()
	await game.start_contract("mine")
	await step(30)
	await hit_sparks()
	await bursts()
	await hazards()
	await post_and_rings()
	await bar()
	await snow_floor()
	await rain_floor()
	print("GPU_FX: %d failures" % failures)
	rig.queue_free()
	await create_timer(0.3).timeout
	quit(1 if failures else 0)

# --- Scenes ------------------------------------------------------------------------

func scenes() -> void:
	var list := ["hit_spark", "fire_pit_flames", "hazard_fire", "molotov_shards", "hazard_fuse", "hazard_blast", "snowfall", "rainfall", "snow_kick", "status_lines", "vault_grit", "barrier_shards"]
	var all_ok := true
	for name in list:
		var packed := load("res://effects/%s.tscn" % name) as PackedScene
		var node := packed.instantiate() if packed != null else null
		var ok := node != null and not emitters(node).is_empty()
		for p in (emitters(node) if node != null else []):
			ok = ok and not (p as GPUParticles3D).local_coords and (p as GPUParticles3D).process_material is ParticleProcessMaterial
		if not ok: print("  scene ", name, " not right")
		all_ok = all_ok and ok
		if node != null: node.free()
	check("every effect scene loads as GPU emitters in world space (%d scenes)" % list.size(), all_ok)
	var fire := (load("res://effects/hazard_fire.tscn") as PackedScene).instantiate()
	var snow := (load("res://effects/snowfall.tscn") as PackedScene).instantiate()
	var rain := (load("res://effects/rainfall.tscn") as PackedScene).instantiate()
	var lines := (load("res://effects/status_lines.tscn") as PackedScene).instantiate()
	check("bottle fire flames and snowfall waver (turbulence on)", (fire.get_node("Flames").process_material as ParticleProcessMaterial).turbulence_enabled and (snow.get_node("Fall").process_material as ParticleProcessMaterial).turbulence_enabled)
	check("snow and rain stop where they meet the ground (collision hide on contact)",
		(snow.get_node("Fall").process_material as ParticleProcessMaterial).collision_mode == ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
		and (rain.get_node("Rain").process_material as ParticleProcessMaterial).collision_mode == ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT)
	check("rain splashes through a sub-emitter at collision", (rain.get_node("Rain") as GPUParticles3D).sub_emitter == NodePath("../Splash")
		and (rain.get_node("Rain").process_material as ParticleProcessMaterial).sub_emitter_mode == ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION)
	var up := lines.get_node("Up") as GPUParticles3D
	var down := lines.get_node("Down") as GPUParticles3D
	var um := up.process_material as ParticleProcessMaterial
	var dm := down.process_material as ParticleProcessMaterial
	check("status lines: a ring, vertical only (no orbit, no spread), random times (explosiveness 0)",
		um.emission_shape == ParticleProcessMaterial.EMISSION_SHAPE_RING and um.spread == 0.0 and um.direction == Vector3.UP and dm.direction == Vector3.DOWN
		and um.orbit_velocity_min == 0.0 and um.orbit_velocity_max == 0.0 and um.tangential_accel_max == 0.0 and up.explosiveness == 0.0 and up.randomness > 0.0)
	var shader := (up.draw_pass_1.surface_get_material(0) as ShaderMaterial)
	var names := []
	for u in shader.shader.get_shader_uniform_list(): names.append(u.name)
	check("status lines drawn as narrowing triangles (status_line.gdshader, falls flips them)",
		shader.shader.resource_path == "res://effects/status_line.gdshader" and names.has("falls") and float(shader.get_shader_parameter("falls")) == 0.0
		and float((down.draw_pass_1.surface_get_material(0) as ShaderMaterial).get_shader_parameter("falls")) == 1.0)
	check("status lines see-through: 35% in front, 60% behind", true and names.has("back_alpha"))
	for n in [fire, snow, rain, lines]: n.free()

func catalog() -> void:
	# Every share any hex source carries is classed good or bad.
	var keys := {}
	for type in BaseCatalog.POTIONS:
		var fx: Dictionary = BaseCatalog.POTIONS[type].get("fx", {})
		for part in ["hex", "after"]:
			for k in fx.get(part, {}): keys[k] = true
	for k in ["def", "atk", "aspd"]: keys[k] = true
	var missing := []
	for k in keys:
		if not StatusCatalog.KEY_GOOD.has(k) and not (k in StatusCatalog.META): missing.append(k)
	check("KEY_GOOD classes every hex share used (%s)" % [keys.keys()], missing.is_empty())
	var sides := StatusCatalog.hex_sides({"atk": 0.2, "aspd": 0.1})
	var after := StatusCatalog.hex_sides({"taken": 0.15})
	var shred := StatusCatalog.hex_sides({"def": -0.3, "time": 5.0})
	check("atk+ is a buff; taken+ and def− are debuffs; time is not an effect", sides == [true, false] and after == [false, true] and shred == [false, true])
	var enemy_kinds := ["haste", "slow", "frozen", "fragile", "res_down", "weaken", "burn"]
	check("every enemy status kind is classed", enemy_kinds.all(func(k): return StatusCatalog.ENEMY_GOOD.has(k)) and StatusCatalog.ENEMY_GOOD.haste and not StatusCatalog.ENEMY_GOOD.slow)
	check("stage curve: faint below 60, marked at 60, heavy at 90", is_equal_approx(StatusPost.staged(0.0), 0.0) and StatusPost.staged(59.0) < 0.26 and is_equal_approx(StatusPost.staged(60.0), 0.5) and is_equal_approx(StatusPost.staged(90.0), 0.8))
	check("lying snow 0.15 at cold 0, 1 at 90", is_equal_approx(FieldWeather.cover_for(0.0), 0.15) and is_equal_approx(FieldWeather.cover_for(90.0), 1.0) and FieldWeather.cover_for(45.0) > 0.5)

# --- P0b --------------------------------------------------------------------------

func hit_sparks() -> void:
	for n in get_nodes_in_group(HitSpark.GROUP): n.queue_free()
	await step(2)
	var at := game.player.global_position + Vector3(2, 0.4, 0)
	var a := HitSpark.spawn(game, at, "lappland", false, "melee")
	var b := HitSpark.spawn(game, at, "hellagur", true, "melee")
	var c := HitSpark.spawn(game, at, "typhon", false, "ranged", Vector3.RIGHT)
	var d := HitSpark.spawn(game, at, "lin", false, "arts")
	await step(1)
	var sa := (a.get_node("Sparks") as GPUParticles3D)
	var sb := (b.get_node("Sparks") as GPUParticles3D)
	var ga: Gradient = (sa.process_material as ParticleProcessMaterial).color_ramp.gradient
	var gb: Gradient = (sb.process_material as ParticleProcessMaterial).color_ramp.gradient
	check("P0b each operator's sparks in her own colours (Lappland pale blue ≠ Hellagur red)", ga.get_color(1).is_equal_approx(OperatorVfx.PALETTES.lappland.main) and gb.get_color(1).is_equal_approx(OperatorVfx.PALETTES.hellagur.main))
	check("P0b a crit fills the emitters and is a third larger", is_equal_approx(sb.amount_ratio, 1.0) and is_equal_approx(sa.amount_ratio, HitSpark.NORMAL_RATIO) and b.global_basis.get_scale().x > 1.25)
	var mc := (c.get_node("Sparks") as GPUParticles3D).process_material as ParticleProcessMaterial
	var md := (d.get_node("Sparks") as GPUParticles3D).process_material as ParticleProcessMaterial
	check("P0b ranged chips fly on along the shot (root +Y turned to it)", c.global_basis.y.normalized().distance_to(Vector3.RIGHT) < 0.01 and mc.spread < 40.0)
	check("P0b arts hits are motes without gravity", md.gravity == Vector3.ZERO)
	check("P0b op hit styles: bow/launcher ranged, arts arts, rest melee", OperatorVfx.hit_style("typhon", "phys") == "ranged" and OperatorVfx.hit_style("lin", "arts") == "arts" and OperatorVfx.hit_style("hellagur", "phys") == "melee")
	for i in range(12): HitSpark.spawn(game, at, "lappland")
	await step(1)
	check("P0b at most %d HitSparks alive at once" % HitSpark.LIMIT, get_nodes_in_group(HitSpark.GROUP).size() == HitSpark.LIMIT)
	check("P0b shared materials per palette+style (cached)", HitSpark._materials("lappland", "melee") == HitSpark._materials("lappland", "melee"))
	await step(40)
	check("P0b every HitSpark freed after its life", get_nodes_in_group(HitSpark.GROUP).is_empty())

# --- P1 ---------------------------------------------------------------------------

func bursts() -> void:
	var spot := game.player.global_position + Vector3(6, 0, 6)
	var fx := BossVfx.make(game, spot)
	var p := fx.burst({"at": Vector3.UP * 0.3, "amount": 20, "time": 0.5, "speed": [1.0, 2.0], "radius": 0.3, "near_ok": true, "colours": [Color.WHITE, Color.RED, Color(1, 0, 0, 0)]})
	var m := p.process_material as ParticleProcessMaterial
	check("P1 burst is a GPU one-shot with the opts' amount, life, speed, sphere", p is GPUParticles3D and p.one_shot and p.amount == 20 and is_equal_approx(p.lifetime, 0.5)
		and m.emission_shape == ParticleProcessMaterial.EMISSION_SHAPE_SPHERE and is_equal_approx(m.emission_sphere_radius, 0.3) and is_equal_approx(m.initial_velocity_max, 2.0))
	var q := fx.burst({"at": Vector3.UP * 0.3, "amount": 20, "time": 0.5, "speed": [1.0, 2.0], "radius": 0.3, "near_ok": true, "colours": [Color.WHITE, Color.RED, Color(1, 0, 0, 0)]})
	check("P1 identical looks share one cached process material", q.process_material == p.process_material)
	var r := fx.burst({"ring": [0.5, 1.2], "amount": 8})
	check("P1 ring opts carried over", (r.process_material as ParticleProcessMaterial).emission_shape == ParticleProcessMaterial.EMISSION_SHAPE_RING and is_equal_approx((r.process_material as ParticleProcessMaterial).emission_ring_radius, 1.2))
	# A figure at its heart: thrown from a ring round her instead (keeping clear).
	var near := BossVfx.make(game, game.player.global_position)
	var n := near.burst({"at": Vector3.ZERO, "amount": 10, "radius": 0.4})
	var nm := n.process_material as ParticleProcessMaterial
	check("P1 a burst on a figure moves out to a ring round her (inner >= CLEAR - d)", nm.emission_shape == ParticleProcessMaterial.EMISSION_SHAPE_RING and nm.emission_ring_inner_radius >= BossVfx.CLEAR - 0.5 and nm.radial_accel_min > 0.0)
	var aabb := p.visibility_aabb
	check("P1 visibility box set by hand from speed, time and gravity", aabb.size.x > 1.0 and aabb.size.x < 40.0)
	var delayed := fx.burst({"amount": 4, "delay": 0.3, "near_ok": true})
	# (Headless one-shots read emitting false once started, so only the wait is checked.)
	check("P1 a delayed burst waits (not emitting yet)", not delayed.emitting)
	await step(80)

# --- P3 ---------------------------------------------------------------------------

func hazards() -> void:
	var at := game.player.global_position + Vector3(4, 0, 0)
	var fire := game.spawn_hazard(at, 1.3, 0.0, 3.0, 1.0, "arts", false, null)
	await step(1)
	var hfx: HazardFx = fire.find_children("*", "HazardFx", true, false)[0] if not fire.find_children("*", "HazardFx", true, false).is_empty() else null
	check("P3 a burning patch carries HazardFx with flames, embers and smoke", hfx != null and hfx.get_child_count() == 1 and emitters(hfx).size() == 3)
	var flames := hfx.find_child("Flames", true, false) as GPUParticles3D
	check("P3 a fresh fire burns full (ratio %.3f)" % flames.amount_ratio, flames.amount_ratio > 0.98)
	await step(90)
	var mid := flames.amount_ratio
	var expect := (HazardFx.LOW_RATIO + (1.0 - HazardFx.LOW_RATIO) * fire.lasting / 3.0)
	check("P3 mid-fire the ratio follows time left (%.3f vs %.3f)" % [mid, expect], absf(mid - expect) < 0.02)
	await step(66)
	var late := flames.amount_ratio if is_instance_valid(flames) else -1.0
	check("P3 in its last second it dies away (%.3f, lasting %.2f)" % [late, fire.lasting if is_instance_valid(fire) else -1.0], is_instance_valid(fire) and late < 0.4 * 0.5 + 0.01)
	await step(30)
	check("P3 damage timer unchanged: the hazard is gone at its time", not is_instance_valid(fire))
	var before := get_nodes_in_group("oneshot:hazard_blast.tscn").size()
	var fused := game.spawn_hazard(at, 1.5, 0.5, 0.0, 1.0, "arts", false, null)
	await step(2)
	check("P3 a fused blast draws motes in while it counts down", fused.find_child("HazardFuse", true, false) != null)
	var seen_blast := false
	for i in range(45):
		await step()
		if get_nodes_in_group("oneshot:hazard_blast.tscn").size() > before: seen_blast = true
	check("P3 and bursts when it goes off", seen_blast)
	var shards_before := get_nodes_in_group("oneshot:molotov_shards.tscn").size()
	var bottle := Molotov.new()
	bottle.game = game
	bottle.start = at + Vector3.UP
	bottle.target = at
	game.add_child(bottle)
	bottle._land()
	await step(1)
	check("P3 a bottle shattering throws glass (molotov_shards)", get_nodes_in_group("oneshot:molotov_shards.tscn").size() > shards_before)
	await step(60)

# --- P5 / P6 ----------------------------------------------------------------------

func post_and_rings() -> void:
	var post := game.status_post
	check("P5 one status overlay on the camera, under the markers (priority %d < 20)" % StatusPost.STATUS_PRIORITY, is_instance_valid(post) and post.quad.get_parent() == game.camera and post.material.render_priority < 20)
	game.features.values.contamination = 70.0
	await step(150)
	check("P5 contamination 70 in the mine eases to its stage look (%.2f)" % post.levels.contamination, absf(post.levels.contamination - StatusPost.staged(70.0)) < 0.02 and post.quad.visible)
	game.features.values.contamination = 0.0
	# Read at once: below 30% the auto-potion slot would drink and heal her.
	var hp := game.player.hp
	game.player.hp = game.player.max_hp * 0.1
	var low: float = post.targets().low_life
	game.player.hp = hp
	check("P5 low life darkens the edges (target %.2f)" % low, low > 0.6)
	var rings := game.status_rings
	var p := game.player
	p.hexes.clear()
	await step(8)
	check("P6 nothing on her without a timed buff or debuff", rings.ring_on(p) == null)
	p.add_hex("potion_F", {"atk": 0.2, "aspd": 0.1}, 20.0)
	await step(8)
	var ring := rings.ring_on(p)
	check("P6 a timed buff: rising lines only", ring != null and ring.up().emitting and not ring.down().emitting)
	p.add_hex("potion_G", {"move": 0.25}, 20.0)
	await step(8)
	check("P6 two buffs: still one ring, one layer", p.find_children("*", "StatusLines", true, false).size() == 1 and rings.ring_on(p).up().emitting)
	p.add_hex("boss_shred", {"def": -0.3}, 5.0)
	await step(8)
	check("P6 a buff and a debuff: both at once", rings.ring_on(p).up().emitting and rings.ring_on(p).down().emitting)
	p.hexes.clear()
	p.add_hex("meal", {"atk": 0.1}, -1.0)
	await step(8)
	check("P6 the canteen meal (untimed) brings no lines", rings.ring_on(p) == null)
	p.hexes.clear()
	# Enemies: haste up, slow down, stun down; and the cap.
	var made: Array = []
	for i in range(30):
		var e := game._spawn_enemy(p.global_position + Vector3(3 + (i % 6), 0, 3 + i / 6), false, false)
		e.set_physics_process(false)
		made.append(e)
	await step(3)
	made[0].apply_status("haste", 10.0, 0.3)
	made[1].apply_status("slow", 10.0, 0.3)
	made[2].stun_timer = 5.0
	made[3].apply_status("haste", 10.0, 0.3)
	made[3].apply_status("slow", 10.0, 0.3)
	await step(8)
	var r0 := rings.ring_on(made[0])
	var r1 := rings.ring_on(made[1])
	var r2 := rings.ring_on(made[2])
	var r3 := rings.ring_on(made[3])
	check("P6 enemy haste rises, slow falls, stun falls, both shows both", r0 != null and r0.up().emitting and not r0.down().emitting and r1 != null and r1.down().emitting and not r1.up().emitting
		and r2 != null and r2.down().emitting and r3 != null and r3.up().emitting and r3.down().emitting)
	for e in made: e.apply_status("slow", 10.0, 0.3)
	await step(8)
	var on := 0
	for e in made: if rings.ring_on(e) != null: on += 1
	check("P6 at most %d enemies wear rings (%d)" % [StatusRings.ENEMY_LIMIT, on], on == StatusRings.ENEMY_LIMIT)
	for e in made: e.statuses.clear()
	for e in made: e.stun_timer = 0.0
	await step(8)
	var pooled := rings._pool.size()
	for e in made: e.apply_status("slow", 10.0, 0.3)
	await step(8)
	check("P6 rings go back to the pool and are reused (pool %d)" % pooled, pooled >= StatusRings.ENEMY_LIMIT - 1 and rings._pool.size() <= 1)
	for e in made: e.queue_free()
	await step(10)

# --- P7 ---------------------------------------------------------------------------

func bar() -> void:
	var p := game.player
	var sb: StatusBar = game._hud.status_bar if is_instance_valid(game._hud) else null
	check("P7 the status bar sits in the HUD", sb != null)
	if sb == null: return
	p.hexes.clear()
	p.add_hex("potion_G", {"move": 0.25, "stamina": 0.6}, 20.0)
	await step(2)
	p.add_hex("boss_shred", {"def": -0.3}, 5.0)
	await step(2)
	p.add_hex("potion_F", {"atk": 0.2, "aspd": 0.1}, 20.0)
	game.features.values.contamination = 65.0
	await step(3)
	sb.refresh(game)
	var ids: Array = sb.entries.map(func(e): return e.id)
	print("BAR ", ids)
	check("P7 icons in the order they turned up, left to right", ids.slice(0, 3) == ["potion_G", "boss_shred", "potion_F"])
	check("P7 a meter stage is listed (污染·中度), untimed", ids.has("stage_contamination_1") and sb.entries.filter(func(e): return e.id == "stage_contamination_1")[0].time < 0.0)
	var r0 := sb.icon_rect(0)
	var r1 := sb.icon_rect(1)
	check("P7 above the hotbar, from its left edge, left to right", r0.end.y < game._hud.hotbar_rect().position.y and is_equal_approx(r0.position.x, game._hud.hotbar_rect().position.x) and r1.position.x > r0.position.x)
	var g: Dictionary = sb.entries[0]
	var share := StatusBar.elapsed(g)
	await step(60)
	sb.refresh(game)
	var later := StatusBar.elapsed(sb.entries[0])
	check("P7 the clock sweeps on (%.3f -> %.3f)" % [share, later], later > share + 0.04)
	p.add_hex("potion_G", {"move": 0.25, "stamina": 0.6}, 20.0)
	await step(2)
	sb.refresh(game)
	check("P7 a refreshed buff keeps its place, its clock starts over", sb.entries[0].id == "potion_G" and StatusBar.elapsed(sb.entries[0]) < 0.02)
	check("P7 frames: buff white, debuff dark red-brown (boss_shred bad, potion_F good)", not sb.entries[1].good and sb.entries[2].good)
	var shred: Dictionary = sb.entries[1]
	check("P7 hover text from the numbers (防御 −30%)", shred.effect.has("防御 −30%"))
	p.add_hex("meal", {"atk": 0.1}, -1.0)
	await step(2)
	sb.refresh(game)
	check("P7 the canteen meal shows in the bar", sb.entries.any(func(e): return e.id == "meal"))
	p.hexes.clear()
	game.features.values.contamination = 0.0
	await step(2)

# --- P2 ---------------------------------------------------------------------------

func snow_floor() -> void:
	await _restart("snow")
	await step(40)
	var w := game.field_weather
	print("SNOW weather ", w, " snow ", w.snow if is_instance_valid(w) else null, " region ", game.region_id)
	check("P2 a snow floor has its FieldWeather and the particle ground", is_instance_valid(w) and w.snow and is_instance_valid(w.collider) and w.collider.follow_camera_enabled)
	var weather: WeatherFx = game.world_map.terrace_dressing.weather
	check("P2 the snowfall is the GPU scene", weather is WeatherFx and weather.name == "Snowfall")
	game.features.values.cold = 0.0
	w.snap()
	check("P2 snap: shown cold equals the real one, cover 0.15", is_equal_approx(w.shown_cold, 0.0) and is_equal_approx(w.cover, 0.15))
	game.features.values.cold = 60.0
	await step(60)
	var after_1s := w.shown_cold
	await step(300)
	print("SNOW stage ease 0->60: 1 s %.1f, 6 s %.1f" % [after_1s, w.shown_cold])
	check("§5.5 a stage change eases in over ~5 s (1 s: %.1f < 50; 6 s: within 5%%)" % after_1s, after_1s > 5.0 and after_1s < 50.0 and absf(w.shown_cold - 60.0) < 3.0)
	game.features.values.cold = 92.0
	await step(2)
	check("P2 blizzard from cold 90", w.blizzard_on)
	game.features.values.cold = 87.0
	await step(2)
	check("P2 still a blizzard at 87 (ends below 85)", w.blizzard_on)
	game.features.values.cold = 84.0
	await step(2)
	check("P2 over below 85", not w.blizzard_on)
	game.features.values.cold = 100.0
	w.snap()
	check("P2 occlusion medium (1) at cold 100", is_equal_approx(w.blizzard, 1.0))
	game.features.values.cold = 90.0
	w.snap()
	check("P2 occlusion light (0.4) at cold 90", is_equal_approx(w.blizzard, 0.4))
	check("P2 blizzard layers run, normal fall thinned", weather.layer("Driving").amount_ratio > 0.3 and weather.layer("Fall").amount_ratio < weather.intensity)
	var env: Environment = game.world_environment.environment
	check("P2 the fog whitens in a blizzard", env.fog_light_color.v > w._base_fog_colour.v + 0.02)
	# Footprints.
	var p := game.player
	var from := Vector2(p.global_position.x, p.global_position.z)
	p.global_position += Vector3(1.0, 0, 0)
	await step(3)
	check("P2 her steps leave tracks stamped with the game time", w.track_at(Vector2(p.global_position.x, p.global_position.z)) > 0.0)
	var before := w.trail_origin
	var stamped := Vector2(p.global_position.x, p.global_position.z)
	p.global_position += Vector3(20.0, 0, 0)
	await step(3)
	check("P2 the track window follows her and keeps the old tracks", w.trail_origin != before and w.track_at(stamped) > 0.0)
	# Fires melt.
	var fires: Array = game.map_features.fires
	if not fires.is_empty():
		fires[0].feed(60.0)
		await step(3)
		var g0: Vector4 = w.pushed.get("field_fire_0", Vector4.ZERO)
		check("P2 a lit fire melts a ring (field_fire_0 at a fire, radius > 0)", g0.w > 0.0)
	game.features.values.cold = 0.0
	w.snap()
	check("P2 after the blizzard everything back to calm", not w.blizzard_on and is_equal_approx(w.blizzard, 0.0))

func rain_floor() -> void:
	await _restart("siracusa")
	await step(20)
	game.world_map.weather = "rain"
	if is_instance_valid(game.field_weather): game.field_weather.free()
	await step(3)
	var w := game.field_weather
	check("P2 叙拉古 rain floor: FieldWeather knows it rains", is_instance_valid(w) and w.rain)
	var start := w.puddle_fill
	var offset := w._puddle
	await step(60 * 45)
	print("RAIN puddle fill %.3f -> %.3f over 45 s" % [start, w.puddle_fill])
	check("P2 puddles start at 0.4 and fill while it rains", absf(start - FieldWeather.PUDDLE_START) < 0.01 and w.puddle_fill > 0.65 and w.puddle_fill < 0.75)
	var again := FieldWeather.new()
	again.game = game
	again.map = game.world_map
	game.world_map.add_child(again)
	check("P2 the floor's puddles lie in the same place for the same seed", again._puddle.x == offset.x and again._puddle.z == offset.z)
	again.free()
	var wet: float = float(w.pushed.get("field_wet", 0.0))
	check("P2 every surface wet in the rain (field_wet %.2f)" % wet, wet > 0.3)
	var p4 := []
	for n in game.world_map.find_children("*", "CPUParticles3D", true, false): p4.append(n.name)
	check("P4 no CPU particles left on the floor (%s)" % [p4], p4.is_empty())

func _restart(region: String) -> void:
	game.settle(true)
	await step(5)
	await game.start_contract(region)
