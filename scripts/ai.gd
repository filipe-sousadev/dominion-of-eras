class_name AIPlayer
extends RefCounted
## Computer opponent.
## Economy: keeps workers on what its shopping list needs, adds farms, storehouses and houses ahead of time.
## Army: trains what beats the rival's troops, gathers before marching, focuses targets, pulls back from
## lost fights, defends its towns, raids workers and expands. How much of this it does depends on the
## difficulty (see Defs.DIFFICULTY).

var game
var p
var t := 0.0
var acc := 0.0               # time since the last decision (Game adds to it)
var diff: Dictionary
var next_attack := 0.0
var wave := 6
var phase := "build"         # build | gather | attack | retreat
var phase_t := 0.0
var army: Array = []         # soldiers committed to the current attack
var army_start_power := 0.0
var rally := Vector3.ZERO
var target_pid := -1
var raid: Array = []         # cavalry sent after enemy workers
var raid_cd := 240.0
var defend_until := -1.0
var defend_pos := Vector3.ZERO
var build_cd := 0.0
var store_cd := 45.0
var rot := 0
var rebalance_t := 0.0
var fled := {}               # citizen id -> time it may work again
var attacks_sent := 0

const BASE_RATIO := {"food": 0.40, "wood": 0.32, "gold": 0.14, "stone": 0.07, "tech": 0.07}
## kind, earliest time (s), how many
const ORDER := [["barracks", 50.0, 1], ["university", 110.0, 1], ["archery", 170.0, 1],
	["stable", 0.0, 1], ["barracks", 420.0, 2], ["workshop", 0.0, 1], ["archery", 600.0, 2],
	["stable", 660.0, 2], ["university", 700.0, 2], ["barracks", 840.0, 3]]

func _init(g, pl) -> void:
	game = g
	p = pl
	diff = Defs.DIFFICULTY[p.difficulty]
	next_attack = diff["first_attack"]
	wave = diff["wave"]

# ------------------------------------------------------------------ helpers
func _mine(kind: String, built_only := true) -> Array:
	var out: Array = []
	for b in game.buildings:
		if b.owner_id == p.id and not b.dead and b.kind == kind and (b.built or not built_only):
			out.append(b)
	return out

func _ok(u) -> bool:
	return u != null and is_instance_valid(u) and not u.dead

func _power(u) -> float:
	## Rough fighting value of a soldier or a shooting building.
	if u.is_building():
		if not u.def.has("atk"):
			return 0.0
		return 140.0 if u.kind == "tower" else 110.0
	if u.is_citizen():
		return 6.0
	var c: Dictionary = u.def["cost"]
	var v := 0.0
	for k in c:
		v += float(c[k])
	return v * clamp(u.hp / max(u.max_hp, 1.0), 0.2, 1.0)

func _power_of(list: Array) -> float:
	var v := 0.0
	for u in list:
		if _ok(u):
			v += _power(u)
	return v

func _enemy_power_near(pos: Vector3, r: float, with_buildings := true) -> float:
	var v := 0.0
	for u in game.units:
		if u.owner_id != p.id and not u.dead and u.is_military() and u.position.distance_to(pos) <= r:
			v += _power(u)
	if with_buildings:
		for b in game.buildings:
			if b.owner_id != p.id and not b.dead and b.built and b.position.distance_to(pos) <= r:
				v += _power(b)
	return v

func _centroid(list: Array) -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	for u in list:
		if _ok(u):
			c += u.position
			n += 1
	return c / float(n) if n > 0 else p.start_pos

func _nearest_cc(ccs: Array, pos: Vector3, fallback: Vector3) -> Vector3:
	var best := fallback
	var bd := 1e18
	for cc in ccs:
		var d: float = cc.position.distance_squared_to(pos)
		if d < bd:
			bd = d
			best = cc.position
	return best

# ------------------------------------------------------------------ main
func tick(dt: float) -> void:
	t += dt
	build_cd -= dt
	store_cd -= dt
	raid_cd -= dt
	rebalance_t -= dt
	phase_t += dt
	var cits: Array = []
	var mil: Array = []
	for u in game.units:
		if u.owner_id == p.id and not u.dead:
			if u.is_citizen():
				cits.append(u)
			else:
				mil.append(u)
	var ccs := _mine("city_center")
	var home: Vector3 = ccs[0].position if not ccs.is_empty() else p.start_pos
	_economy(cits, ccs, home)
	if build_cd <= 0.0:
		build_cd = 3.0 if float(diff["think"]) >= 1.0 else 2.0
		_build(cits, ccs, home)
	_train(mil, cits)
	_military(mil, ccs, home)

# ------------------------------------------------------------------ economy
func _job(u) -> String:
	match u.state:
		"gather", "return":
			if u.work_target != null and is_instance_valid(u.work_target) and u.work_target is ResNode:
				return u.work_target.res_type
			if u.work_target != null and is_instance_valid(u.work_target) and u.work_target is Building:
				return "food"
			return u.carry_type
		"work":
			return "tech"
		"build":
			return "build"
		"move":
			return "busy"
	return ""

## What the computer wants to buy soon, per resource.
func _shopping() -> Dictionary:
	var need := {"food": 150.0, "wood": 150.0, "gold": 60.0, "stone": 40.0, "tech": 0.0}
	if _saving():
		var e: Dictionary = Defs.EPOCHS[p.epoch]["cost"]
		for k in e:
			need[k] += float(e[k])
	for o in ORDER:
		if t < float(o[1]) or p.epoch < int(Defs.BUILDINGS[o[0]]["epoch"]):
			continue
		if _mine(o[0], false).size() < int(o[2]):
			var c: Dictionary = Defs.BUILDINGS[o[0]]["cost"]
			for k in c:
				need[k] += float(c[k])
			break
	if _mine("city_center").size() < int(diff["bases"]) and t > float(diff["expand_at"]) - 60.0:
		need["wood"] += 300.0
		need["stone"] += 200.0
	# a few soldiers of each kind it can make
	need["food"] += 160.0
	need["gold"] += 120.0 + 40.0 * p.epoch
	need["wood"] += 80.0
	return need

func _economy(cits: Array, ccs: Array, home: Vector3) -> void:
	var queued := 0
	for cc in ccs:
		queued += cc.queue.size()
	var want_cits: int = int(diff["citizens"]) + 4 * max(0, ccs.size() - 1)
	if cits.size() + queued < want_cits and game.pop_used(p.id) + queued < p.pop_cap:
		for cc in ccs:
			if cc.queue.is_empty() and not (cc.researching and p.res["food"] < 120.0):
				game.train(cc, "citizen")
	var counts := {"food": 0, "wood": 0, "gold": 0, "stone": 0, "tech": 0}
	var idle: Array = []
	for u in cits:
		var j := _job(u)
		if counts.has(j):
			counts[j] += 1
		elif j == "":
			if fled.get(u.get_instance_id(), 0.0) > t:
				continue
			idle.append(u)
	var unis := _mine("university")
	var need := _shopping()
	var want := {}
	var total := 0.0
	for k in BASE_RATIO:
		var w: float = BASE_RATIO[k]
		if k == "tech" and (unis.is_empty() or p.epoch >= Defs.EPOCHS.size()):
			w = 0.0
		else:
			# short of what it plans to buy -> more workers; sitting on a pile -> fewer
			var have: float = p.res[k]
			var goal: float = max(need[k], 1.0)
			w *= clamp(1.7 - have / goal, 0.25, 2.2)
			if k == "tech" and have >= goal * 1.2:
				w = 0.0
			if k != "food" and have > 700.0:
				w *= 0.3
			if k == "food" and have > 1800.0:
				w *= 0.3
		want[k] = w
		total += w
	for k in want:
		want[k] = want[k] / max(total, 0.001) * cits.size()
	if want["tech"] > float(unis.size() * Defs.UNIVERSITY_WORKERS):
		want["tech"] = float(unis.size() * Defs.UNIVERSITY_WORKERS)
	for u in idle:
		var best := _most_needed(want, counts)
		var near := _nearest_cc(ccs, u.position, home)
		if _assign(u, best, near, unis):
			counts[best] += 1
		elif _assign(u, "wood", near, unis):
			counts["wood"] += 1
		elif _assign(u, "food", near, unis):
			counts["food"] += 1
	# move workers from the most over-staffed job to the most needed one
	if rebalance_t <= 0.0:
		rebalance_t = 12.0 if float(diff["think"]) >= 2.0 else (8.0 if float(diff["think"]) >= 1.0 else 5.0)
		var need_k := _most_needed(want, counts)
		var over := ""
		var over_by := 1.0
		for k in counts:
			if counts[k] - want.get(k, 0.0) > over_by:
				over_by = counts[k] - want.get(k, 0.0)
				over = k
		if over != "" and over != need_k and want[need_k] - counts[need_k] >= 1.0:
			var moves: int = clamp(int(over_by / 2.0), 1, 4)
			var pool: Array = cits.filter(func(u): return _job(u) == over)
			pool.sort_custom(func(x, y): return x.carry_amt < y.carry_amt)
			for u in pool:
				if moves <= 0:
					break
				if u.work_target != null and is_instance_valid(u.work_target) and u.work_target is Building:
					u.work_target.workers.erase(u)
				if _assign(u, need_k, _nearest_cc(ccs, u.position, home), unis):
					moves -= 1
	if store_cd <= 0.0:
		store_cd = 25.0
		_storehouses(cits, home)

func _most_needed(want: Dictionary, counts: Dictionary) -> String:
	var best := "wood"
	var best_gap := -1e9
	for k in want:
		if want[k] <= 0.0:
			continue
		var gap: float = want[k] - counts[k]
		if gap > best_gap:
			best_gap = gap
			best = k
	return best

func _assign(u, job: String, home: Vector3, unis: Array) -> bool:
	if job == "tech":
		for un in unis:
			if un.workers.size() < Defs.UNIVERSITY_WORKERS:
				un.workers.append(u)
				u.order_work(un)
				return true
		return false
	if job == "food":
		var farm = game.nearest_resource("farm", home, 60.0, p.id)
		if farm:
			farm.workers.append(u)
			u.order_gather(farm)
			return true
		var n = game.nearest_resource_of_type("food", home, 40.0)
		if n and _safe(n.position):
			u.order_gather(n)
			return true
		if p.res["wood"] >= 60:
			var tl = _spot("farm", home)
			if tl != null and game.order_construct(p.id, "farm", tl, [u]) == "":
				return true
		return false
	var r = game.nearest_resource_of_type(job, u.position.lerp(home, 0.5), 70.0 if job == "wood" else 130.0)
	if r:
		u.order_gather(r)
		return true
	return false

## Not right next to an enemy tower or town.
func _safe(pos: Vector3) -> bool:
	for b in game.buildings:
		if b.owner_id != p.id and not b.dead and b.built and b.def.has("atk"):
			if b.position.distance_to(pos) < float(b.def["range"]) + 3.0:
				return false
	return true

## A storehouse next to wood, gold or stone that is a long walk from the nearest drop-off point.
func _storehouses(cits: Array, home: Vector3) -> void:
	if float(diff["think"]) >= 2.0 or p.res["wood"] < 140.0:
		return
	if _mine("storehouse", false).size() >= 2 + _mine("city_center").size():
		return
	var far := {}
	for u in cits:
		if u.state != "gather" or not (u.work_target is ResNode) or not _ok(u.work_target):
			continue
		var d = game.nearest_dropsite(p.id, u.work_target.position)
		if d == null:
			continue
		if d.edge_distance(u.work_target.position) > 16.0:
			var key: String = u.work_target.res_type
			if not far.has(key):
				far[key] = []
			far[key].append(u)
	var best_k := ""
	var best_n := 2
	for k in far:
		if far[k].size() > best_n:
			best_n = far[k].size()
			best_k = k
	if best_k == "":
		return
	var c := _centroid(far[best_k].map(func(u): return u.work_target))
	var tl = _spot("storehouse", c, 1)
	if tl != null:
		game.order_construct(p.id, "storehouse", tl, [far[best_k][0]])

# ------------------------------------------------------------------ building
func _spot(kind: String, near: Vector3, first_ring := 3):
	var s: int = Defs.BUILDINGS[kind]["size"]
	var start := int(rot)
	rot = (rot + 5) % 16
	for ring in range(first_ring, 16):
		var r := ring * 2.2
		for i in 16:
			var a := TAU * float((i + start) % 16) / 16.0
			var pos := near + Vector3(cos(a) * r, 0, sin(a) * r)
			var tl: Vector2i = game.snap_cells(kind, pos)
			if game.placement_error(p.id, kind, tl) != "":
				continue
			if kind != "farm" and not _clear_around(tl, s):
				continue
			return tl
	return null

func _clear_around(tl: Vector2i, s: int) -> bool:
	for x in range(-1, s + 1):
		for y in range(-1, s + 1):
			if x >= 0 and y >= 0 and x < s and y < s:
				continue
			if not game.is_free(tl + Vector2i(x, y)):
				return false
	return true

func _builders(cits: Array, home: Vector3, n: int) -> Array:
	var pool := cits.filter(func(u): return u.state != "build")
	pool.sort_custom(func(a, b): return a.position.distance_squared_to(home) < b.position.distance_squared_to(home))
	return pool.slice(0, n)

func _try_build(kind: String, cits: Array, near: Vector3, n := 2) -> bool:
	if p.epoch < int(Defs.BUILDINGS[kind]["epoch"]):
		return false
	if not Defs.can_afford(p.res, Defs.BUILDINGS[kind]["cost"]):
		return false
	var tl = _spot(kind, near)
	if tl == null:
		return false
	return game.order_construct(p.id, kind, tl, _builders(cits, near, n)) == ""

func _build(cits: Array, ccs: Array, home: Vector3) -> void:
	if cits.is_empty():
		return
	# finish what's started first
	var unfinished := 0
	for b in game.buildings:
		if b.owner_id == p.id and not b.built and not b.dead:
			unfinished += 1
			var busy := false
			for u in cits:
				if u.state == "build" and u.work_target == b:
					busy = true
					break
			if not busy:
				for u in _builders(cits, b.position, 3 if b.kind == "city_center" else 2):
					u.order_build(b)
	var parallel: int = 1 if float(diff["think"]) >= 2.0 else (2 if float(diff["think"]) >= 1.0 else 3)
	if unfinished >= parallel:
		return
	if ccs.is_empty():
		_expand(cits, home)
		return
	# repairs
	for b in game.buildings:
		if b.owner_id == p.id and b.built and not b.dead and b.hp < b.max_hp * 0.6 and t >= defend_until:
			var fixing := false
			for u in cits:
				if u.state == "build" and u.work_target == b:
					fixing = true
					break
			if not fixing:
				for u in _builders(cits, b.position, 2):
					u.order_build(b)
				break
	var room: int = p.pop_cap - game.pop_used(p.id)
	var margin: int = 3 if float(diff["think"]) >= 2.0 else 6
	if room <= margin and p.pop_cap < Defs.POP_LIMIT:
		var pending := 0
		for b in _mine("house", false):
			if not b.built:
				pending += 1
		if pending < (1 if room > 1 else 2) and _try_build("house", cits, home, 2):
			return
	# era advancement
	var era_wait: float = 300.0 if float(diff["think"]) >= 2.0 else 140.0
	if t > era_wait and game.epoch_progress(p.id) < 0.0 and p.epoch < Defs.EPOCHS.size():
		if Defs.can_afford(p.res, Defs.EPOCHS[p.epoch]["cost"]):
			game.advance_epoch(p.id)
			return
	# towers near each town, on the side the rivals come from
	var towers_now := _mine("tower", false).size()
	if t > 240.0 and towers_now < int(diff["towers"]) * ccs.size() and Defs.can_afford(p.res, Defs.BUILDINGS["tower"]["cost"]):
		var cc = ccs[towers_now % ccs.size()]
		var dir: Vector3 = (Vector3(Defs.MAP_SIZE * 0.5, 0, Defs.MAP_SIZE * 0.5) - cc.position)
		dir.y = 0
		dir = dir.normalized().rotated(Vector3.UP, (towers_now / ccs.size()) * 1.3 - 0.6)
		var tl = _spot("tower", cc.position + dir * 9.0, 0)
		if tl != null and game.order_construct(p.id, "tower", tl, _builders(cits, cc.position, 2)) == "":
			return
	if t > float(diff["expand_at"]) and ccs.size() < int(diff["bases"]) and t >= defend_until:
		if Defs.can_afford(p.res, Defs.BUILDINGS["city_center"]["cost"]):
			_expand(cits, home)
			return
		if p.res["wood"] < 500.0 and ccs.size() < 2:
			# keep the wood and stone for the new town
			pass
	for o in ORDER:
		var kind: String = o[0]
		if t < float(o[1]):
			continue
		if p.epoch < int(Defs.BUILDINGS[kind]["epoch"]):
			continue
		if _mine(kind, false).size() >= int(o[2]):
			continue
		if int(o[2]) > 1 and float(diff["mil_scale"]) < 1.0:
			continue
		if _try_build(kind, cits, home):
			return
		break

func _expand(cits: Array, home: Vector3) -> void:
	if not Defs.can_afford(p.res, Defs.BUILDINGS["city_center"]["cost"]):
		return
	var best := -1
	var bs := 1e18
	for i in game.seeds.size():
		if game.terr_owner[i] != -1:
			continue
		var s: Vector2 = game.seeds[i]
		var sp3 := Vector3(s.x, 0, s.y)
		var taken := false
		for b in game.buildings:
			if b.kind == "city_center" and game.territory_at(b.position) == i:
				taken = true
				break
		if taken:
			continue
		var score: float = Vector2(home.x, home.z).distance_to(s)
		# stay away from rival towns, like land with things to gather
		for b in game.buildings:
			if b.owner_id != p.id and b.kind == "city_center" and b.position.distance_to(sp3) < 45.0:
				score += 25.0
		var rich := 0
		for r in game.resources:
			if r.kind != "tree" and r.position.distance_to(sp3) < 22.0:
				rich += 1
		score -= min(rich, 8) * 2.5
		if score < bs:
			bs = score
			best = i
	if best < 0:
		return
	var sp: Vector2 = game.seeds[best]
	var tl = _spot("city_center", Vector3(sp.x, 0, sp.y), 0)
	if tl == null:
		return
	game.order_construct(p.id, "city_center", tl, _builders(cits, Vector3(sp.x, 0, sp.y), 3))

# ------------------------------------------------------------------ training
## How many rival soldiers of each class it is facing.
func _enemy_mix() -> Dictionary:
	var mix := {"infantry": 0.0, "ranged": 0.0, "cavalry": 0.0, "siege": 0.0, "towers": 0.0}
	for u in game.units:
		if u.owner_id != p.id and not u.dead and u.is_military() and game.players[u.owner_id].alive:
			if target_pid < 0 or u.owner_id == target_pid or u.position.distance_to(p.start_pos) < 50.0:
				mix[u.cls()] += 1.0
	for b in game.buildings:
		if b.owner_id != p.id and not b.dead and b.kind == "tower":
			if target_pid < 0 or b.owner_id == target_pid:
				mix["towers"] += 1.0
	return mix

func _train(mil: Array, cits: Array) -> void:
	var mil_cap: int = int((4.0 + 4.0 * p.epoch + t / 90.0) * float(diff["mil_scale"]))
	mil_cap = max(mil_cap, wave + 2)
	if phase != "build":
		mil_cap += 6
	if t < defend_until:
		mil_cap += 8
	if cits.size() < 8 or game.pop_used(p.id) >= p.pop_cap or mil.size() >= mil_cap:
		return
	var have := {"spearman": 0, "swordsman": 0, "archer": 0, "cavalry": 0, "catapult": 0}
	for u in mil:
		have[u.kind] = have.get(u.kind, 0) + 1
	for b in game.buildings:
		if b.owner_id == p.id and not b.dead:
			for q in b.queue:
				if have.has(q):
					have[q] += 1
	var wt := {"spearman": 1.0, "swordsman": 1.0, "archer": 1.0, "cavalry": 1.0}
	if diff["counter"]:
		var mix := _enemy_mix()
		var n: float = mix["infantry"] + mix["ranged"] + mix["cavalry"] + mix["siege"]
		if n >= 3.0:
			wt["spearman"] = 0.6 + 3.0 * mix["cavalry"] / n
			wt["swordsman"] = 0.7 + 1.6 * mix["infantry"] / n + 0.4 * mix["ranged"] / n
			wt["archer"] = 0.6 + 1.8 * mix["infantry"] / n - 0.8 * mix["cavalry"] / n
			wt["cavalry"] = 0.6 + 2.6 * (mix["ranged"] + mix["siege"]) / n
		var cat_goal: int = clamp(1 + int(mix["towers"] * 0.6) + (p.epoch - 3), 1, 6)
		wt["catapult_goal"] = float(cat_goal)
	else:
		wt["catapult_goal"] = 2.0
	var total_w: float = wt["spearman"] + wt["swordsman"] + max(wt["archer"], 0.1) + wt["cavalry"]
	var total_n: float = float(have["spearman"] + have["swordsman"] + have["archer"] + have["cavalry"]) + 1.0
	var urgent: bool = t < defend_until
	var spare_gold: bool = urgent or not _saving() or p.res["gold"] > float(Defs.EPOCHS[p.epoch]["cost"].get("gold", 0)) + 80.0
	var max_queue: int = 1 if float(diff["think"]) >= 2.0 else 2
	# with some army standing, keep what the next era costs instead of spending it on soldiers
	var reserve: Dictionary = {}
	if _saving() and not urgent and (mil.size() >= int(wave * 0.5) or t < next_attack - 60.0):
		reserve = Defs.EPOCHS[p.epoch]["cost"]
	for b in game.buildings:
		if b.owner_id != p.id or b.dead or not b.built or b.queue.size() >= max_queue:
			continue
		if b.trains().is_empty() or b.kind == "city_center":
			continue
		if b.kind == "workshop":
			if have["catapult"] < int(wt["catapult_goal"]) and spare_gold and p.epoch >= 3 and _can_spend(Defs.UNITS["catapult"]["cost"], reserve):
				if game.train(b, "catapult") == "":
					have["catapult"] += 1
			continue
		# the unit this building makes that the army is shortest of
		var pick := ""
		var pick_gap := -1e9
		for k in b.trains():
			if p.epoch < int(Defs.UNITS[k]["epoch"]):
				continue
			var cost: Dictionary = Defs.UNITS[k]["cost"]
			if cost.has("gold") and not spare_gold:
				continue
			if not _can_spend(cost, reserve):
				continue
			var gap: float = max(wt[k], 0.1) / total_w - float(have[k]) / total_n
			if not diff["counter"]:
				gap += randf() * 0.5
			if gap > pick_gap:
				pick_gap = gap
				pick = k
		if pick != "" and game.train(b, pick) == "":
			have[pick] += 1
			total_n += 1.0

# ------------------------------------------------------------------ military
func _pick_target() -> int:
	var best := -1
	var bs := 1e18
	for o in game.players:
		if o.id == p.id or not o.alive:
			continue
		var d: float = o.start_pos.distance_to(p.start_pos)
		for b in game.buildings:
			if b.owner_id == o.id and b.kind == "city_center":
				d = min(d, b.position.distance_to(p.start_pos))
		var score := d
		if diff["pick_weak"]:
			var pw := 0.0
			for u in game.units:
				if u.owner_id == o.id and not u.dead and u.is_military():
					pw += _power(u)
			for b in game.buildings:
				if b.owner_id == o.id and not b.dead:
					pw += _power(b)
			score = d * 0.6 + pw * 0.12
		if score < bs:
			bs = score
			best = o.id
	return best

func _attack_target(from: Vector3, siege := false):
	var best = null
	var bd := 1e18
	for b in game.buildings:
		if b.owner_id == p.id or b.dead or not game.players[b.owner_id].alive:
			continue
		var d: float = b.position.distance_to(from)
		if target_pid >= 0 and b.owner_id != target_pid:
			d += 60.0
		if b.kind == "city_center":
			d *= 0.7
		elif siege and b.kind == "tower":
			d *= 0.5
		elif not b.trains().is_empty():
			d *= 0.9
		elif b.kind == "farm":
			d *= 1.6
		if d < bd:
			bd = d
			best = b
	if best == null:
		for u in game.units:
			if u.owner_id != p.id and not u.dead and game.players[u.owner_id].alive:
				var d2: float = u.position.distance_to(from)
				if d2 < bd:
					bd = d2
					best = u
	return best

## Best thing for this soldier to hit right now: what its weapon is good against, the weakest first.
func _focus(u) -> void:
	if u.kind == "catapult":
		var bt = null
		var bd := 1e18
		for b in game.buildings:
			if b.owner_id != p.id and not b.dead and game.players[b.owner_id].alive:
				var d: float = b.edge_distance(u.position)
				if d > 26.0:
					continue
				if b.kind == "tower":
					d *= 0.4
				elif b.def.has("atk"):
					d *= 0.7
				if d < bd:
					bd = d
					bt = b
		if bt != null and u.target != bt:
			u.engage(bt)
		return
	var sight: float = float(u.def["sight"]) + 2.0
	var best = null
	var bs := -1e18
	var bonus: Dictionary = u.def.get("bonus", {})
	for e in game.units:
		if e.owner_id == p.id or e.dead or not game.players[e.owner_id].alive:
			continue
		var d: float = e.position.distance_to(u.position)
		if d > sight:
			continue
		var s: float = float(bonus.get(e.cls(), 1.0)) * 2.0 + (1.0 - e.hp / max(e.max_hp, 1.0)) * 1.5 - d / 8.0
		if e.is_citizen():
			s -= 1.5
		if e == u.target:
			s += 0.6
		if s > bs:
			bs = s
			best = e
	if best != null and best != u.target:
		u.engage(best)

func _send(list: Array, pos: Vector3, attack_move := true) -> void:
	var n := list.size()
	var cols := int(ceil(sqrt(max(n, 1))))
	var i := 0
	for u in list:
		if not _ok(u):
			continue
		var off := Vector3((i % cols - (cols - 1) * 0.5) * 1.8, 0, (i / cols - (cols - 1) * 0.5) * 1.8)
		if attack_move:
			u.order_attack_move(pos + off)
		else:
			u.order_move(pos + off)
		i += 1

func _military(mil: Array, ccs: Array, home: Vector3) -> void:
	army = army.filter(func(u): return _ok(u))
	raid = raid.filter(func(u): return _ok(u))
	var free: Array = mil.filter(func(u): return not army.has(u) and not raid.has(u))
	# ---- defence
	if t < defend_until:
		var threat := _enemy_power_near(defend_pos, 28.0, false)
		if threat <= 0.0:
			defend_until = t
		else:
			for u in free:
				if u.state == "idle" or (u.state == "move" and not u.amove):
					u.order_attack_move(defend_pos)
			# the town matters more than the raid: call the army back when the guards can't cope
			if diff["retreat"] and phase in ["gather", "attack"] and threat > _power_of(free) * 1.3 + 100.0 * ccs.size():
				if _centroid(army).distance_to(defend_pos) > 30.0 or phase == "gather":
					_end_attack(true)
					_send(army, defend_pos)
					army.clear()
	else:
		for u in free:
			if u.state == "idle" and u.position.distance_to(_nearest_cc(ccs, u.position, home)) > 22.0:
				var hc := _nearest_cc(ccs, u.position, home)
				u.order_move(hc + Vector3(randf_range(-9, 9), 0, randf_range(-9, 9)))
	# ---- worker raids
	if diff["harass"]:
		_raids(free, home)
	# ---- attack waves
	match phase:
		"build":
			if t >= next_attack and free.size() >= wave and t >= defend_until:
				target_pid = _pick_target()
				if target_pid < 0:
					return
				army = free.duplicate()
				army_start_power = _power_of(army)
				attacks_sent += 1
				var tgt = _attack_target(home)
				var tp: Vector3 = tgt.position if tgt != null else game.players[target_pid].start_pos
				if diff["regroup"]:
					var dir: Vector3 = (tp - home)
					dir.y = 0
					rally = home + dir.normalized() * min(20.0, dir.length() * 0.3)
					_send(army, rally, false)
					_set_phase("gather")
				else:
					_set_phase("attack")
		"gather":
			var close := 0
			for u in army:
				if u.position.distance_to(rally) < 12.0:
					close += 1
			if army.is_empty():
				_end_attack(false)
			elif close >= int(army.size() * 0.8) or phase_t > 40.0:
				_set_phase("attack")
		"attack":
			_run_attack(free, home)
		"retreat":
			var back := 0
			for u in army:
				if u.position.distance_to(home) < 24.0:
					back += 1
			if army.is_empty() or back >= int(army.size() * 0.7) or phase_t > 30.0:
				army.clear()
				_set_phase("build")

func _set_phase(ph: String) -> void:
	phase = ph
	phase_t = 0.0

func _end_attack(lost: bool) -> void:
	var every: float = float(diff["wave_every"])
	next_attack = t + (every * 0.7 if lost else every)
	wave = min(wave + int(diff["wave_step"]), int(diff["wave_max"]))
	_set_phase("build")

func _run_attack(free: Array, home: Vector3) -> void:
	if army.is_empty() or (not diff["retreat"] and army.size() < 3):
		for u in army:
			u.order_move(home)
		army.clear()
		_end_attack(true)
		return
	if target_pid < 0 or not game.players[target_pid].alive:
		target_pid = _pick_target()
		if target_pid < 0:
			army.clear()
			_set_phase("build")
			return
	var c := _centroid(army)
	if diff["retreat"] and phase_t > 6.0:
		var mine := _power_of(army)
		var theirs := _enemy_power_near(c, 24.0)
		if mine < army_start_power * 0.3 or (theirs > mine * 1.8 and theirs > 200.0):
			_send(army, home, false)
			_end_attack(true)
			_set_phase("retreat")
			return
	# fresh troops join a fight that is going well
	if diff["harass"] and free.size() >= 4 and phase_t > 20.0 and t >= defend_until:
		for u in free:
			army.append(u)
		army_start_power = max(army_start_power, _power_of(army))
	var has_siege := false
	for u in army:
		if u.kind == "catapult":
			has_siege = true
	for u in army:
		if u.state == "idle" or (u.state == "move" and not u.amove):
			var tgt = _attack_target(u.position, u.kind == "catapult")
			if tgt == null:
				continue
			if u.kind == "catapult":
				u.order_attack(tgt)
			elif u.position.distance_to(tgt.position) > float(u.def["sight"]) + 6.0:
				u.order_attack_move(tgt.position)
			else:
				u.order_attack(tgt)
		elif diff["focus"] and u.state == "attack":
			_focus(u)
	# don't run ahead of the slow siege weapons: the fast ones wait when the group is strung out
	if has_siege and diff["regroup"] and phase_t < 60.0:
		for u in army:
			if u.kind == "cavalry" and u.state == "move" and u.position.distance_to(c) > 22.0:
				u.order_attack_move(c)

func _raids(free: Array, home: Vector3) -> void:
	if not raid.is_empty():
		var hp := 0.0
		var mhp := 0.0
		for u in raid:
			hp += u.hp
			mhp += u.max_hp
		var c := _centroid(raid)
		if hp < mhp * 0.45 or _enemy_power_near(c, 16.0) > _power_of(raid) * 1.5:
			_send(raid, home, false)
			raid.clear()
			raid_cd = 90.0
			return
		for u in raid:
			if u.state == "idle" or (u.state == "attack" and _ok(u.target) and u.target.is_building()):
				var w = _worker_target(u.position)
				if w != null:
					u.order_attack(w)
				else:
					u.order_move(home)
		return
	if raid_cd > 0.0 or phase != "build":
		return
	var cav: Array = free.filter(func(u): return u.kind == "cavalry")
	if cav.size() < 3:
		return
	var w0 = _worker_target(home)
	if w0 == null:
		return
	raid = cav.slice(0, 5)
	raid_cd = 150.0
	for u in raid:
		u.order_attack(w0)

## A rival worker away from towers and town centres.
func _worker_target(from: Vector3):
	var best = null
	var bs := 1e18
	for u in game.units:
		if u.owner_id == p.id or u.dead or not u.is_citizen() or not game.players[u.owner_id].alive:
			continue
		if not _safe(u.position):
			continue
		var s: float = u.position.distance_to(from)
		if s < bs:
			bs = s
			best = u
	return best

func _can_spend(cost: Dictionary, reserve: Dictionary) -> bool:
	for k in cost:
		if p.res[k] - float(cost[k]) < float(reserve.get(k, 0)):
			return false
	return true

func _saving() -> bool:
	return t > 140.0 and p.epoch < Defs.EPOCHS.size() and game.epoch_progress(p.id) < 0.0

func on_attacked(e, attacker) -> void:
	if not _ok(e) or not _ok(attacker):
		return
	# workers run to the nearest town and come back later
	if e.is_unit() and e.is_citizen() and diff["flee"] and attacker.is_unit():
		var until: float = t + 10.0
		for u in game.units:
			if u.owner_id == p.id and u.is_citizen() and not u.dead and u.state != "build" and u.position.distance_to(e.position) < 7.0:
				if fled.get(u.get_instance_id(), 0.0) > t:
					continue
				var d = game.nearest_dropsite(p.id, u.position)
				if d != null and d.position.distance_to(u.position) > 6.0:
					fled[u.get_instance_id()] = until
					u.order_move(d.position + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)))
		if fled.size() > 200:
			fled.clear()
	# only what happens at home is a reason to defend: soldiers hit while raiding are not
	var at_home: bool = e.is_building() or (e.is_unit() and e.is_citizen())
	if not at_home:
		for b in game.buildings:
			if b.owner_id == p.id and b.kind == "city_center" and b.position.distance_to(e.position) < 35.0:
				at_home = true
				break
	if at_home:
		defend_pos = e.position
		defend_until = t + 15.0
