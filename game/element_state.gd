class_name ElementState
extends RefCounted

## One target's 损伤 ring and damage over time (属性伤害与地区装备策划案 v1.1
## §5, §6): an enemy owns one, so does she. The owner ticks it, feeds it the
## elemental damage it takes and acts on what `tick` / `fill` hand back.

## One gauge (元素反应策划案 v0.2 §2): kind → its part of the one ring; the
## parts add up against one threshold.
var gauges := {}
## Seconds before the ring fills again (after a burst or reaction).
var cooldown_left := 0.0
## Seconds since the ring's last fill (decay starts at Elements.DECAY_DELAY).
var idle := 0.0
## The shares (kind → 0–1) the ring held when it last went off, and its
## leading kind (the cooling ring's colour).
var last_shares := {}
var last_kind := ""
## dot → {"left": s, "per_tick": damage, "kind": damage kind, "tick": s}.
var dots := {}

## Adds `amount` of `kind` to the ring against `threshold`; true when it goes
## off (the ring empties, `last_shares` holds what it held, and it cools down).
func fill(kind: String, amount: float, threshold: float, cooldown: float) -> bool:
	if amount <= 0.0 or threshold <= 0.0 or not kind in Elements.GAUGE_KINDS: return false
	if cooling(): return false
	idle = 0.0
	gauges[kind] = float(gauges.get(kind, 0.0)) + amount
	if total() < threshold: return false
	last_shares = shares()
	last_kind = Elements.leading(last_shares)
	gauges.clear()
	cooldown_left = cooldown
	return true

## Adds `amount` split by `split` (kind → share), as the 爆发 family's 连锁 does.
func spill(split: Dictionary, amount: float, threshold: float, cooldown: float) -> bool:
	var went := false
	for kind in split:
		if not went and fill(kind, amount * float(split[kind]), threshold, cooldown): went = true
	return went

func total() -> float:
	var sum := 0.0
	for kind in gauges: sum += float(gauges[kind])
	return sum

## kind → its share of what the ring holds now.
func shares() -> Dictionary:
	var sum := total()
	var out := {}
	if sum <= 0.0: return out
	for kind in gauges: out[kind] = float(gauges[kind]) / sum
	return out

## One kind's part of `threshold`, 0–1 (its arc on the ring).
func ratio(kind: String, threshold: float) -> float:
	return clampf(float(gauges.get(kind, 0.0)) / maxf(threshold, 0.001), 0.0, 1.0)

## The ring cools as a whole; `kind` is ignored (older callers name one).
func cooling(_kind: String = "") -> bool:
	return cooldown_left > 0.0

func is_idle() -> bool:
	return gauges.is_empty() and not cooling()

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
	cooldown_left = maxf(0.0, cooldown_left - delta)
	if not gauges.is_empty():
		idle += delta
		if idle > Elements.DECAY_DELAY:
			# The ring drops as a whole: every part by the same share.
			var sum := total()
			var keep := maxf(0.0, sum - threshold * Elements.DECAY_RATE * delta) / sum
			for kind in gauges.keys(): gauges[kind] = float(gauges[kind]) * keep
			if keep <= 0.0: gauges.clear()
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

## The ring for the HUD: its arcs in Elements.GAUGE_KINDS order as
## [[kind, share of threshold]], whether it cools and in which colour.
func ring(threshold: float) -> Dictionary:
	var arcs: Array = []
	for kind in Elements.GAUGE_KINDS:
		var r := ratio(kind, threshold)
		if r > 0.0: arcs.append([kind, r])
	return {"arcs": arcs, "cooling": cooling(), "kind": last_kind}

func clear() -> void:
	gauges.clear()
	cooldown_left = 0.0
	idle = 0.0
	last_shares = {}
	last_kind = ""
	dots.clear()
