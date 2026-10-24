class_name ElementState
extends RefCounted

## One target's 损伤 gauges and damage over time (属性伤害与地区装备策划案 v1.1
## §5, §6): an enemy owns one, so does she. The owner ticks it, feeds it the
## elemental damage it takes and acts on what `tick` / `fill` hand back.

## kind → 0..threshold, filled by elemental damage after resistance.
var gauges := {}
## kind → seconds before that gauge fills again (after a burst).
var cooldowns := {}
## kind → seconds since its last fill (decay starts at Elements.DECAY_DELAY).
var idle := {}
## dot → {"left": s, "per_tick": damage, "kind": damage kind, "tick": s}.
var dots := {}

## Adds `amount` to `kind`'s gauge against `threshold`; true when it bursts
## (the gauge empties and cools down).
func fill(kind: String, amount: float, threshold: float, cooldown: float) -> bool:
	if amount <= 0.0 or threshold <= 0.0 or not kind in Elements.GAUGE_KINDS: return false
	if float(cooldowns.get(kind, 0.0)) > 0.0: return false
	idle[kind] = 0.0
	gauges[kind] = float(gauges.get(kind, 0.0)) + amount
	if float(gauges[kind]) < threshold: return false
	gauges.erase(kind)
	cooldowns[kind] = cooldown
	return true

## The gauge's share of `threshold`, 0–1 (the HUD's ring).
func ratio(kind: String, threshold: float) -> float:
	return clampf(float(gauges.get(kind, 0.0)) / maxf(threshold, 0.001), 0.0, 1.0)

func cooling(kind: String) -> bool:
	return float(cooldowns.get(kind, 0.0)) > 0.0

## A new DoT replaces the running one of its kind only if it would deal more
## of what is left (§6: no stacking).
func apply_dot(dot: String, total: float, seconds: float, kind: String) -> void:
	if total <= 0.0 or seconds <= 0.0: return
	var ticks := maxf(1.0, seconds / Elements.DOT_TICK)
	if dots.has(dot):
		var running: Dictionary = dots[dot]
		var left := float(running.per_tick) * float(running.left) / Elements.DOT_TICK
		if left >= total: return
	dots[dot] = {"left": seconds, "per_tick": total / ticks, "kind": kind, "tick": Elements.DOT_TICK}

func has_dot(dot: String) -> bool:
	return dots.has(dot)

## Advances everything by `delta`; returns the DoT ticks due now as
## [{"dot", "kind", "damage"}] for the owner to apply.
func tick(delta: float, threshold: float) -> Array:
	for kind in cooldowns.keys():
		cooldowns[kind] = float(cooldowns[kind]) - delta
		if float(cooldowns[kind]) <= 0.0: cooldowns.erase(kind)
	for kind in gauges.keys():
		idle[kind] = float(idle.get(kind, 0.0)) + delta
		if float(idle[kind]) > Elements.DECAY_DELAY:
			gauges[kind] = float(gauges[kind]) - threshold * Elements.DECAY_RATE * delta
			if float(gauges[kind]) <= 0.0:
				gauges.erase(kind)
				idle.erase(kind)
	var due: Array = []
	for dot in dots.keys():
		var d: Dictionary = dots[dot]
		d.left = float(d.left) - delta
		d.tick = float(d.tick) - delta
		if float(d.tick) <= 0.0:
			d.tick = float(d.tick) + Elements.DOT_TICK
			due.append({"dot": dot, "kind": str(d.kind), "damage": float(d.per_tick)})
		if float(d.left) <= 0.0: dots.erase(dot)
	return due

## The (at most) `count` fullest gauges, for the HUD: [[kind, ratio, cooling]].
func top(threshold: float, count: int = 2) -> Array:
	var out: Array = []
	for kind in Elements.GAUGE_KINDS:
		var r := ratio(kind, threshold)
		if r > 0.0 or cooling(kind): out.append([kind, r, cooling(kind)])
	out.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	return out.slice(0, count)

func clear() -> void:
	gauges.clear()
	cooldowns.clear()
	idle.clear()
	dots.clear()
