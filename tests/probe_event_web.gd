extends SceneTree
## Shape of the event web (交易所事件表_v1_4.md §15): explicit links as a graph,
## factor coupling, and a ripple across regions. Prints; not part of run_all.
## Also writes evidence/event-web.json for the diagram.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	var ids: Array = MarketEvents.EVENTS.keys()
	var adj := {}
	var directed := 0
	for id in ids: adj[id] = {}
	for id in MarketLinks.LINKS:
		for link in MarketLinks.LINKS[id]:
			var to := str(link.get("f", link.get("b", "")))
			if not adj.has(to) or to == id: continue
			adj[id][to] = true
			adj[to][id] = true
			directed += 1
	# Components.
	var seen := {}
	var sizes: Array = []
	for id in ids:
		if seen.has(id): continue
		var stack := [id]
		var n := 0
		seen[id] = true
		while not stack.is_empty():
			var v = stack.pop_back()
			n += 1
			for w in adj[v]:
				if not seen.has(w):
					seen[w] = true
					stack.append(w)
		sizes.append(n)
	sizes.sort()
	sizes.reverse()
	# Average distance inside the largest component (BFS from every node).
	var total := 0.0
	var pairs := 0
	var diameter := 0
	for s in ids:
		var dist := {s: 0}
		var queue := [s]
		while not queue.is_empty():
			var v = queue.pop_front()
			for w in adj[v]:
				if not dist.has(w):
					dist[w] = dist[v] + 1
					queue.append(w)
		if dist.size() < sizes[0]: continue
		for w in dist:
			if w != s:
				total += dist[w]
				pairs += 1
				diameter = maxi(diameter, dist[w])
	# Cycles in the directed follow-up graph (a node reaching itself).
	var cyclic := 0
	for s in MarketLinks.LINKS:
		var reach := {}
		var stack: Array = []
		for link in MarketLinks.LINKS[s]: stack.append(str(link.get("f", link.get("b", ""))))
		while not stack.is_empty():
			var v: String = stack.pop_back()
			if reach.has(v): continue
			reach[v] = true
			for link in MarketLinks.LINKS.get(v, []): stack.append(str(link.get("f", link.get("b", ""))))
		if reach.has(s): cyclic += 1
	var with_aff := ids.filter(func(id): return not MarketLinks.affinity(id).is_empty()).size()
	print("events %d, directed links %d, undirected edges %d" % [ids.size(), directed, adj.values().reduce(func(a, b): return a + b.size(), 0) / 2])
	print("components: %s" % [sizes.slice(0, 6)])
	print("largest component %d, average distance %.2f, diameter %d" % [sizes[0], total / maxf(pairs, 1), diameter])
	print("events on a loop: %d" % cyclic)
	print("events with a world-state affinity: %d" % with_aff)
	var per_factor := {}
	for id in ids:
		for f in MarketLinks.affinity(id): per_factor[f] = int(per_factor.get(f, 0)) + 1
	print("events per factor: %s" % [per_factor])
	# Ripple: Ursus unrest, then the odds elsewhere.
	MarketState.tz_override = 0
	var m := MarketState.new()
	m.start(2000000000, 4)
	var probe := ["C9", "L17", "S16", "X21", "K15", "Z3"]
	var before := probe.map(func(id): return m.lean(id))
	for id in ["U2", "U3", "U13", "U19", "U14"]: m.fire(id)
	var after := probe.map(func(id): return m.lean(id))
	for k in range(probe.size()):
		print("%s %s odds ×%.2f → ×%.2f" % [probe[k], MarketEvents.EVENTS[probe[k]].title, before[k], after[k]])
	# Data for the diagram: arcs, factors, cross edges between arcs.
	var arc_of := {}
	for arc in MarketLinks.ARCS:
		if arc == "跨线": continue
		for id in MarketLinks.ARCS[arc]: arc_of[id] = arc
	var arc_edges := {}
	for id in MarketLinks.LINKS:
		for link in MarketLinks.LINKS[id]:
			var to := str(link.get("f", link.get("b", "")))
			var a := str(arc_of.get(id, ""))
			var b := str(arc_of.get(to, ""))
			if a.is_empty() or b.is_empty() or a == b: continue
			var key: String = (a + "|" + b) if a < b else (b + "|" + a)
			arc_edges[key] = int(arc_edges.get(key, 0)) + 1
	var arc_factor := {}
	for id in arc_of:
		for f in MarketLinks.affinity(id):
			var key: String = str(arc_of[id]) + "|" + str(f)
			arc_factor[key] = float(arc_factor.get(key, 0.0)) + float(MarketLinks.affinity(id)[f])
	var out := FileAccess.open("res://../evidence/event-web.json", FileAccess.WRITE)
	out.store_string(JSON.stringify({"arcs": MarketLinks.ARCS.keys().filter(func(a): return a != "跨线"), "factors": MarketLinks.FACTORS, "arc_edges": arc_edges, "arc_factor": arc_factor,
		"stats": {"events": ids.size(), "links": directed, "largest": sizes[0], "avg": total / maxf(pairs, 1), "diameter": diameter, "loops": cyclic}}))
	out.close()
	quit()
