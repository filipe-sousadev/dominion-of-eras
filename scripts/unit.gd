class_name Unit
extends Entity
## A citizen or soldier: walking, gathering, building, fighting.

var def: Dictionary
var state := "idle"
var path: Array = []
var path_i := 0
var target = null            # Entity being attacked
var work_target = null       # resource / building being gathered, built or worked
var carry_type := ""
var carry_amt := 0.0
var last_node_kind := ""
var last_node_pos := Vector3.ZERO
var cooldown := 0.0
var repath := 0.0
var scan := 0.0
var anim := 0.0
var moving := false
var goal := Vector3.ZERO
var stuck_t := 0.0
var last_pos := Vector3.ZERO
var legs_a: Array = []
var legs_b: Array = []
var arm_l: Node3D
var arm_r: Node3D
var sling: Node3D
var stride := 0.6
var arm_l_rest := 0.0
var work_anim := 0.0
var amove := false           # attack-move: fight whatever is met on the way to `goal`
var strike := 0.0            # > 0 while the attack swing plays

func is_unit() -> bool:
	return true

func is_citizen() -> bool:
	return kind == "citizen"

func is_military() -> bool:
	return kind != "citizen"

func cls() -> String:
	return def["cls"]

func setup(g, k: String, owner: int, p: Vector3) -> void:
	game = g
	kind = k
	owner_id = owner
	def = Defs.UNITS[k]
	position = p
	radius = 0.9 if k in ["cavalry", "catapult"] else 0.45
	max_hp = float(def["hp"]) * game.hp_mult(owner, k)
	hp = max_hp
	model = Meshes.unit_model(k, Defs.TEAM_COLORS[owner])
	add_child(model)
	legs_a = model.get_meta("legs_a", [])
	legs_b = model.get_meta("legs_b", [])
	arm_l = model.get_meta("arm_l") if model.has_meta("arm_l") else null
	arm_r = model.get_meta("arm_r") if model.has_meta("arm_r") else null
	sling = model.get_meta("sling") if model.has_meta("sling") else null
	stride = model.get_meta("stride", 0.6)
	arm_l_rest = arm_l.rotation.x if arm_l else 0.0
	make_ring(Color(0.2, 1.0, 0.3) if owner == 0 else Color(1.0, 0.25, 0.2))
	rotation.y = randf() * TAU
	last_pos = p

func display_name() -> String:
	return def["name"]

func speed() -> float:
	return float(def["speed"]) * Defs.SPEED_SCALE * game.season_speed()

func atk_range() -> float:
	return float(def["range"])

# ---------------------------------------------------------------- orders
func stop() -> void:
	state = "idle"
	amove = false
	path.clear()
	target = null
	work_target = null
	moving = false

func order_move(p: Vector3) -> void:
	stop()
	state = "move"
	goal = p
	_path_to(p)

func order_attack(t) -> void:
	stop()
	if t == null or t.dead:
		return
	state = "attack"
	target = t
	_path_to_entity(t)

## Walk to a point, fighting any enemy met on the way.
func order_attack_move(p: Vector3) -> void:
	if not is_military():
		order_move(p)
		return
	stop()
	state = "move"
	amove = true
	goal = p
	_path_to(p)

## Switch to a new target without forgetting an attack-move in progress.
func engage(t) -> void:
	if t == null or not is_instance_valid(t) or t.dead:
		return
	state = "attack"
	target = t
	work_target = null
	_path_to_entity(t)

func order_gather(n) -> void:
	if not is_citizen():
		order_move(n.position)
		return
	stop()
	state = "gather"
	work_target = n
	if n is ResNode:
		last_node_kind = n.kind
	elif n.kind == "farm":
		last_node_kind = "farm"
	last_node_pos = n.position
	_path_to_entity(n)

func order_build(b) -> void:
	if not is_citizen():
		order_move(b.position)
		return
	stop()
	state = "build"
	work_target = b
	_path_to_entity(b)

func order_work(b) -> void:
	# university: produce tech
	if not is_citizen():
		order_move(b.position)
		return
	stop()
	state = "work"
	work_target = b
	_path_to_entity(b)

func order_return() -> void:
	var d = game.nearest_dropsite(owner_id, position)
	if d == null:
		state = "idle"
		return
	state = "return"
	target = d
	_path_to_entity(d)

# ---------------------------------------------------------------- movement
func _path_to(p: Vector3) -> void:
	path = game.find_path(position, p)
	path_i = 0
	moving = not path.is_empty()

func _path_to_entity(e) -> void:
	if e is Building and e.def.get("walkable", false):
		var off := Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
		_path_to(e.position + off)
		return
	_path_to(game.approach_point(e, position))

func _follow(delta: float) -> bool:
	## Moves along the path; returns true while still walking.
	if path_i >= path.size():
		moving = false
		return false
	var wp: Vector3 = path[path_i]
	var to := wp - position
	to.y = 0
	var d := to.length()
	var step := speed() * delta
	if d <= step or d < 0.05:
		position = Vector3(wp.x, 0, wp.z)
		path_i += 1
		if path_i >= path.size():
			moving = false
			return false
	else:
		var dir := to / d
		position += dir * step
		rotation.y = atan2(dir.x, dir.z)
	moving = true
	return true

func _face(p: Vector3) -> void:
	var d := p - position
	if Vector2(d.x, d.z).length() > 0.01:
		rotation.y = atan2(d.x, d.z)

# ---------------------------------------------------------------- update
func tick(delta: float) -> void:
	cooldown = max(0.0, cooldown - delta)
	repath -= delta
	scan -= delta
	match state:
		"idle":
			moving = false
			if scan <= 0.0:
				scan = 0.5
				if is_military():
					var e = game.nearest_enemy(owner_id, position, def["sight"], false)
					if e:
						order_attack(e)
		"move":
			if amove and scan <= 0.0:
				scan = 0.4
				var e2 = game.nearest_enemy(owner_id, position, def["sight"], false)
				if e2:
					engage(e2)
					return
			if not _follow(delta):
				state = "idle"
				amove = false
		"attack":
			_do_attack(delta)
		"gather":
			_do_gather(delta)
		"return":
			_do_return(delta)
		"build":
			_do_build(delta)
		"work":
			_do_work(delta)
	_animate(delta)

func _animate(delta: float) -> void:
	if not visible:
		return
	var swing := 0.0
	if moving:
		anim += delta * (9.0 if kind != "cavalry" else 12.0) * speed() / 3.3
		swing = sin(anim) * stride
		model.position.y = abs(sin(anim)) * (0.05 if kind != "cavalry" else 0.1)
	else:
		model.position.y = 0.0
	for l in legs_a:
		l.rotation.x = swing
	for l in legs_b:
		l.rotation.x = -swing
	if arm_l:
		arm_l.rotation.x = arm_l_rest + (swing * 0.7 if arm_l_rest == 0.0 else 0.0)
	var arm := -swing * 0.7
	if strike > 0.0:
		strike = max(0.0, strike - delta)
		var k: float = sin((1.0 - strike / 0.3) * PI)
		arm = -0.4 - k * 1.5
		if sling:
			sling.rotation.x = deg_to_rad(-25.0 + 95.0 * k)
	elif not moving and state in ["gather", "build", "work"]:
		work_anim += delta * 6.5
		arm = -0.5 - abs(sin(work_anim)) * 1.1
	elif not moving and state == "attack" and kind == "archer":
		arm = -1.2
	if arm_r:
		arm_r.rotation.x = arm

## Fallen soldiers and workers stay on the ground for a moment.
func die(attacker) -> void:
	if dead:
		return
	if visible and model != null and is_inside_tree() and kind != "catapult":
		var xf := model.global_transform
		remove_child(model)
		game.add_child(model)
		model.global_transform = xf
		var m := model
		var tw := m.create_tween()
		tw.tween_property(m, "rotation:x", -PI * 0.5, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(m, "position:y", 0.2, 0.35)
		tw.tween_interval(5.0)
		tw.tween_property(m, "position:y", -0.8, 2.0)
		tw.tween_callback(m.queue_free)
	elif visible and kind == "catapult" and game != null:
		Fx.puff(game, position + Vector3(0, 1, 0), "dust", 1.4)
	super.die(attacker)

func _valid(e) -> bool:
	return e != null and is_instance_valid(e) and not e.dead

func _do_attack(delta: float) -> void:
	if not _valid(target) or target.owner_id == owner_id:
		target = null
		var e = game.nearest_enemy(owner_id, position, def["sight"], false) if is_military() else null
		if e:
			engage(e)
		elif amove and position.distance_to(goal) > 3.0:
			order_attack_move(goal)
		else:
			stop()
		return
	var dist: float = target.edge_distance(position)
	if dist <= atk_range() + radius + 0.2:
		moving = false
		path.clear()
		_face(target.position)
		if cooldown <= 0.0:
			cooldown = def["rate"]
			strike = 0.3
			if atk_range() > 3.0:
				game.shoot(self, target, game.damage(self, target), "stone" if kind == "catapult" else "arrow")
			else:
				target.take_damage(game.damage(self, target), self)
		return
	if repath <= 0.0 or path_i >= path.size():
		repath = 0.8
		_path_to_entity(target)
	_follow(delta)

func _find_similar_node():
	var n = game.nearest_resource(last_node_kind, last_node_pos, 25.0, owner_id)
	return n

func _do_gather(delta: float) -> void:
	if not _valid(work_target):
		var n = _find_similar_node()
		if n:
			order_gather(n)
		elif carry_amt > 0.0:
			order_return()
		else:
			stop()
		return
	var res_type: String = work_target.res_type if work_target is ResNode else "food"
	if carry_type != res_type:
		carry_type = res_type
		carry_amt = 0.0
	if work_target.edge_distance(position) > 2.0 and not (work_target is Building and work_target.edge_distance(position) <= 0.01):
		if not _follow(delta):
			if repath <= 0.0:
				repath = 1.0
				_path_to_entity(work_target)
		return
	moving = false
	_face(work_target.position)
	var node_kind: String = work_target.kind
	var rate: float = Defs.GATHER.get(node_kind, 0.5) * game.gather_mult(owner_id, res_type)
	var amt := rate * delta
	if work_target is ResNode:
		carry_amt += work_target.take(amt)
	else:
		carry_amt += amt
	if carry_amt >= Defs.CARRY:
		carry_amt = Defs.CARRY
		last_node_pos = work_target.position if _valid(work_target) else last_node_pos
		order_return()

func _do_return(delta: float) -> void:
	if not _valid(target):
		order_return()
		if state != "return":
			state = "idle"
		return
	if target.edge_distance(position) > 2.0:
		if not _follow(delta):
			if repath <= 0.0:
				repath = 1.0
				_path_to_entity(target)
		return
	game.deposit(owner_id, carry_type, carry_amt)
	carry_amt = 0.0
	target = null
	if _valid(work_target):
		state = "gather"
		_path_to_entity(work_target)
	else:
		var n = _find_similar_node()
		if n:
			order_gather(n)
		else:
			stop()

func _do_build(delta: float) -> void:
	if not _valid(work_target):
		stop()
		return
	var b = work_target
	if b.built and b.hp >= b.max_hp:
		_after_build(b)
		return
	if b.edge_distance(position) > 2.0:
		if not _follow(delta):
			if repath <= 0.0:
				repath = 1.0
				_path_to_entity(b)
		return
	moving = false
	_face(b.position)
	b.add_build(Defs.BUILD_RATE * delta * game.build_mult(owner_id))
	if b.built and b.hp >= b.max_hp * 0.98:
		_after_build(b)

func _after_build(b) -> void:
	if b.kind == "farm" and b.workers.size() < 3:
		b.workers.append(self)
		order_gather(b)
		return
	if b.kind == "university" and b.workers.size() < Defs.UNIVERSITY_WORKERS:
		b.workers.append(self)
		order_work(b)
		return
	var other = game.nearest_unfinished(owner_id, position, 20.0)
	if other:
		order_build(other)
	else:
		stop()

func _do_work(delta: float) -> void:
	if not _valid(work_target) or work_target.owner_id != owner_id:
		stop()
		return
	if work_target.edge_distance(position) > 2.0:
		if not _follow(delta):
			if repath <= 0.0:
				repath = 1.0
				_path_to_entity(work_target)
		return
	moving = false
	_face(work_target.position)
	if not work_target.workers.has(self):
		if work_target.workers.size() >= Defs.UNIVERSITY_WORKERS:
			stop()
			return
		work_target.workers.append(self)
	if work_target.built:
		var rate: float = Defs.GATHER["university"] * game.gather_mult(owner_id, "tech")
		game.deposit(owner_id, "tech", rate * delta)

func on_attacked(by) -> void:
	if by == null or not is_instance_valid(by) or by.dead:
		return
	if state == "idle" or (is_military() and state == "move" and false):
		order_attack(by)
