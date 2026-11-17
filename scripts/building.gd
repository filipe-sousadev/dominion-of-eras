class_name Building
extends Entity
## A building: construction, unit training, era research, towers shooting, capture loyalty.

var def: Dictionary
var built := false
var build_done := 0.0        # seconds of building work done
var queue: Array = []        # unit kinds waiting to be trained
var train_time := 0.0
var rally := Vector3.ZERO
var has_rally := false
var loyalty := 100.0
var capture_by := -1
var workers: Array = []      # citizens working here (university, farm)
var cooldown := 0.0
var researching := false     # city center: advancing to the next era
var research_time := 0.0
var cells: Array = []        # occupied path cells
var size_m := 4.0
var last_loyalty_msg := 100
var smoke_fx: CPUParticles3D
var fire_fx: CPUParticles3D
var scaffold: MeshInstance3D
const ROOF := {"house": 3.1, "storehouse": 2.8, "barracks": 3.6, "archery": 3.2, "stable": 3.0, "workshop": 3.5,
	"university": 4.3, "tower": 6.6, "city_center": 4.4}
const CHIMNEY := {"city_center": Vector3(0, 7.0, 0), "house": Vector3(0.9, 3.8, -0.6), "workshop": Vector3(-2.0, 4.9, -1.2)}

func is_building() -> bool:
	return true

func setup(g, k: String, owner: int, p: Vector3, complete: bool) -> void:
	game = g
	kind = k
	owner_id = owner
	def = Defs.BUILDINGS[k]
	size_m = def["size"] * Defs.CELL
	radius = size_m * 0.5
	position = p
	max_hp = def["hp"]
	model = Meshes.building_model(k, Defs.TEAM_COLORS[owner])
	add_child(model)
	make_ring(Color(0.2, 1.0, 0.3) if owner == 0 else Color(1.0, 0.25, 0.2))
	sel_ring.scale = Vector3.ONE * 1.1
	if complete:
		built = true
		build_done = def["time"]
		hp = max_hp
	else:
		hp = max_hp * 0.1
	_update_model()

func display_name() -> String:
	return def["name"]

func edge_distance(p: Vector3) -> float:
	var dx: float = max(abs(p.x - position.x) - radius, 0.0)
	var dz: float = max(abs(p.z - position.z) - radius, 0.0)
	return sqrt(dx * dx + dz * dz)

func _update_model() -> void:
	var f: float = 1.0 if built else clamp(build_done / float(def["time"]), 0.0, 1.0)
	model.scale = Vector3(1.0, lerp(0.12, 1.0, f), 1.0)
	if not built and scaffold == null and kind != "farm":
		# posts and planks around the site while it is being built
		var bk := Meshes.Bake.new()
		var r: float = radius + 0.15
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				bk.add(Meshes.box(Vector3(0.14, 2.6, 0.14)), Meshes.WOOD.lightened(0.15), Vector3(sx * r, 1.3, sz * r))
		for y in [1.0, 2.2]:
			for s2 in [-1.0, 1.0]:
				bk.add(Meshes.box(Vector3(r * 2.0, 0.08, 0.1)), Meshes.WOOD.lightened(0.25), Vector3(0, y, s2 * r))
				bk.add(Meshes.box(Vector3(0.1, 0.08, r * 2.0)), Meshes.WOOD.lightened(0.25), Vector3(s2 * r, y, 0))
		scaffold = MeshInstance3D.new()
		scaffold.mesh = bk.mesh()
		scaffold.material_override = Meshes.world_mat()
		add_child(scaffold)
	elif built:
		if scaffold != null:
			scaffold.queue_free()
			scaffold = null
		if smoke_fx == null and CHIMNEY.has(kind):
			smoke_fx = Fx.smoke(CHIMNEY[kind])
			add_child(smoke_fx)

## A builder adds work; returns true when the building is finished.
func add_build(amount: float) -> bool:
	if built:
		if hp < max_hp:
			hp = min(max_hp, hp + max_hp * amount / float(def["time"]) * 0.5)
		return true
	var t: float = def["time"]
	build_done += amount
	hp = min(max_hp, hp + max_hp * 0.9 * amount / t)
	if build_done >= t:
		built = true
		hp = max(hp, max_hp * 0.98)
		game.on_building_finished(self)
	_update_model()
	return built

func trains() -> Array:
	return def.get("trains", [])

func can_train(u: String) -> bool:
	return built and trains().has(u)

func current_train_total() -> float:
	if queue.is_empty():
		return 1.0
	return float(Defs.UNITS[queue[0]]["time"]) * game.time_mult(owner_id)

func tick(delta: float) -> void:
	if not built:
		return
	# fire on badly damaged buildings
	var burning: bool = hp < max_hp * 0.5 and kind != "farm"
	if burning and fire_fx == null:
		fire_fx = Fx.fire(Vector3(randf_range(-0.35, 0.35) * radius, ROOF.get(kind, 3.0), randf_range(-0.35, 0.35) * radius), clamp(radius * 0.55, 0.9, 2.0))
		add_child(fire_fx)
	elif not burning and fire_fx != null:
		fire_fx.queue_free()
		fire_fx = null
	# training
	if not queue.is_empty():
		var u: String = queue[0]
		var p = game.players[owner_id]
		if u == "citizen" or game.pop_used(owner_id) < p.pop_cap:
			train_time += delta
			if train_time >= current_train_total():
				train_time = 0.0
				queue.pop_front()
				game.spawn_trained(self, u)
	# era research
	if researching:
		research_time -= delta
		if research_time <= 0.0:
			researching = false
			game.finish_epoch(owner_id)
	# shooting
	if def.has("atk"):
		cooldown -= delta
		if cooldown <= 0.0:
			var t = game.nearest_enemy(owner_id, position, def["range"], true)
			if t:
				cooldown = def["rate"]
				game.shoot(self, t, def["atk"], "arrow")
			else:
				cooldown = 0.5
	# university tech
	if kind == "university":
		workers = workers.filter(func(w): return is_instance_valid(w) and not w.dead and w.work_target == self)
	if kind == "farm":
		workers = workers.filter(func(w): return is_instance_valid(w) and not w.dead and w.work_target == self)
