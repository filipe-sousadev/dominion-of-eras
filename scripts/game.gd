class_name Game
extends Node3D
## The match: map, territories, players, fog of war, seasons, crowns, capture and victory.

signal notify(text: String, color: Color)
signal ended(won: bool)

const TERRAIN_SHADER := """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec2 seeds[16];
uniform vec4 tcol[16];
uniform int seed_count = 12;
uniform float snow = 0.0;
uniform float map_size = 160.0;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = wpos.xz;
	float n = texture(noise_tex, p / 57.0).r;
	float n2 = texture(noise_tex, p / 14.0 + vec2(0.37, 0.71)).r;
	float n3 = texture(noise_tex, p / 3.3 + vec2(0.11, 0.53)).r;
	float n4 = texture(noise_tex, p / 0.9 + vec2(0.63, 0.29)).r;
	// meadow: dark and light grass, dry patches, bare earth
	vec3 grass = mix(vec3(0.11, 0.21, 0.06), vec3(0.22, 0.33, 0.10), smoothstep(0.30, 0.70, n));
	grass = mix(grass, vec3(0.34, 0.36, 0.13), smoothstep(0.52, 0.78, n2) * 0.5);
	grass *= 0.80 + 0.25 * n3 + 0.18 * n4;
	vec3 dirt = vec3(0.36, 0.29, 0.18) * (0.80 + 0.35 * n3);
	grass = mix(grass, dirt, smoothstep(0.66, 0.80, n * 0.55 + n2 * 0.5) * 0.6);
	// beach and sea around the map
	float e = min(min(p.x, map_size - p.x), min(p.y, map_size - p.y)) + (n2 - 0.5) * 6.0;
	vec3 sand = vec3(0.62, 0.55, 0.38) * (0.88 + 0.22 * n3);
	vec3 land = mix(sand, grass, smoothstep(1.5, 5.5, e));
	vec3 snowc = vec3(0.66, 0.68, 0.75) * (0.84 + 0.16 * n2 + 0.08 * n4);
	vec3 col = mix(land, snowc, snow * smoothstep(0.5, 4.0, e) * (0.75 + 0.25 * smoothstep(0.35, 0.6, n3)));
	float wave = texture(noise_tex, p / 24.0 + vec2(TIME * 0.011, TIME * 0.007)).r;
	float wave2 = texture(noise_tex, p / 9.0 - vec2(TIME * 0.015, TIME * 0.006)).r;
	float depth = clamp(-e / 26.0, 0.0, 1.0);
	vec3 sea = mix(vec3(0.10, 0.32, 0.36), vec3(0.02, 0.10, 0.20), smoothstep(0.0, 0.5, depth));
	sea += vec3(0.03, 0.05, 0.05) * smoothstep(0.50, 0.80, wave * 0.6 + wave2 * 0.5);
	float water = 1.0 - smoothstep(-2.6, -0.8, e);
	float foam = smoothstep(0.55, 1.0, 1.0 - abs(e + 1.7 + sin(TIME * 0.7 + n * 25.0) * 0.5) * 1.6);
	col = mix(col, sea, water);
	col = mix(col, vec3(0.80, 0.86, 0.86), foam * 0.5);
	// territories
	float d1 = 1e9; float d2 = 1e9; int i1 = 0; int i2 = 0;
	for (int i = 0; i < 16; i++) {
		if (i >= seed_count) { break; }
		float d = distance(p, seeds[i]);
		if (d < d1) { d2 = d1; i2 = i1; d1 = d; i1 = i; }
		else if (d < d2) { d2 = d; i2 = i; }
	}
	vec4 tc = tcol[i1];
	float sep = max(distance(seeds[i1], seeds[i2]), 0.001);
	float edge = (d2 * d2 - d1 * d1) / (2.0 * sep);
	float inland = smoothstep(-1.0, 1.0, e);
	float border = (1.0 - smoothstep(0.10, 0.30, edge)) * inland;
	float glow = (1.0 - smoothstep(0.3, 3.0, edge)) * inland;
	col = mix(col, tc.rgb, tc.a * 0.05 * inland);
	col = mix(col, tc.rgb, tc.a * glow * 0.16);
	vec3 bcol = tc.a > 0.5 ? mix(tc.rgb, vec3(1.0), 0.15) : vec3(0.70, 0.68, 0.58);
	float dash = tc.a > 0.5 ? 1.0 : step(0.5, fract((p.x + p.y) * 0.22));
	col = mix(col, bcol, border * (tc.a > 0.5 ? 0.8 : 0.4) * dash);
	// fog of war
	float f = texture(fog_tex, clamp(p / map_size, vec2(0.004), vec2(0.996))).r;
	float explored = clamp(f * 2.2, 0.0, 1.0);
	float visible = clamp(f * 2.0 - 1.0, 0.0, 1.0);
	float lum = dot(col, vec3(0.3, 0.5, 0.2));
	col = mix(mix(vec3(lum), col, 0.55) * 0.5, col, visible) * explored;
	ALBEDO = col;
}
"""

var players: Array = []
var units: Array = []
var buildings: Array = []
var resources: Array = []
var selected: Array = []
var astar: AStarGrid2D
var occ := PackedInt32Array()
var fog := PackedByteArray()
var fog_img: Image
var fog_tex: ImageTexture
var terrain_mat: ShaderMaterial
var seeds: Array = []          # Vector2 per territory
var terr_owner: Array = []     # owner id per territory (-1 none)
var time := 0.0
var rng := RandomNumberGenerator.new()
var cam: CameraRig
var hud
var controls
var snow := 0.0
var snow_fx: GPUParticles3D
var crown_holder := {}         # crown -> player id
var over := false
var attack_msg_t := -100.0
var fog_t := 0.0
var cap_t := 0.0
var ai_t := 0.0
var projectiles: Array = []
var last_alert := Vector3.ZERO
var fog_enabled := true
var config := {}
var sun: DirectionalLight3D
var env: Environment
var decor := {}                # path cell index -> [[MultiMesh, instance], ...]
var stats := {}                # per player: units made / lost, buildings made / lost

# ------------------------------------------------------------------ setup
func setup(cfg: Dictionary) -> void:
	config = cfg
	rng.seed = int(cfg.get("seed", 1234))
	_make_environment()
	_make_grid()
	var opponents: int = int(cfg.get("opponents", 1))
	var starts := [Vector3(30, 0, 130), Vector3(130, 0, 30), Vector3(130, 0, 130), Vector3(30, 0, 30)]
	for i in opponents + 1:
		var p := PlayerData.new(i, i != 0 or cfg.get("sim", false))
		p.start_pos = starts[i]
		p.difficulty = cfg.get("difficulty", "Normal")
		var per: Array = cfg.get("diffs", [])
		if i < per.size():
			p.difficulty = per[i]
		if p.is_ai:
			p.ai = AIPlayer.new(self, p)
		players.append(p)
	fog.resize(Defs.GRID * Defs.GRID)
	fog.fill(0)
	fog_img = Image.create(Defs.GRID, Defs.GRID, false, Image.FORMAT_L8)
	fog_tex = ImageTexture.create_from_image(fog_img)
	Meshes.set_world(fog_tex)
	Meshes.set_snow(0.0)
	var mult: float = float(cfg.get("resources", 1.0))
	for p in players:
		stats[p.id] = {"trained": 0, "lost": 0, "built": 0, "razed": 0}
		for k in p.res:
			p.res[k] = float(Defs.START_RES[k]) * mult
	_make_territories(starts)
	_make_terrain()
	for p in players:
		_make_start(p)
	_scatter_resources(starts)
	_scatter_decor()
	_update_territories(true)
	terrain_mat.set_shader_parameter("fog_tex", fog_tex)
	_update_fog()
	cam = CameraRig.new()
	add_child(cam)
	cam.look_at_point(players[0].start_pos + Vector3(4, 0, -6))
	_make_snow()

func _make_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.66, 0.72, 0.86)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.05
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 152, 0)
	sun.light_energy = 0.95
	sun.light_color = Color(1.0, 0.95, 0.84)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 150.0
	add_child(sun)
	# soft light from the other side so shaded walls keep their colour
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, -40, 0)
	fill.light_energy = 0.16
	fill.light_color = Color(0.62, 0.74, 1.0)
	fill.shadow_enabled = false
	add_child(fill)

func _make_grid() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, Defs.GRID, Defs.GRID)
	astar.cell_size = Vector2(Defs.CELL, Defs.CELL)
	astar.offset = Vector2(Defs.CELL * 0.5, Defs.CELL * 0.5)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	occ.resize(Defs.GRID * Defs.GRID)
	occ.fill(0)

func _make_territories(starts: Array) -> void:
	for i in players.size():
		seeds.append(Vector2(starts[i].x, starts[i].z))
	# empty corners still get a territory
	for i in range(players.size(), 4):
		seeds.append(Vector2(starts[i].x, starts[i].z))
	var tries := 0
	while seeds.size() < 13 and tries < 2000:
		tries += 1
		var c := Vector2(rng.randf_range(14, Defs.MAP_SIZE - 14), rng.randf_range(14, Defs.MAP_SIZE - 14))
		var ok := true
		for s in seeds:
			if s.distance_to(c) < 34.0:
				ok = false
				break
		if ok:
			seeds.append(c)
	for i in seeds.size():
		terr_owner.append(-1)

func _make_terrain() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(Defs.MAP_SIZE + 520.0, Defs.MAP_SIZE + 520.0)
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position = Vector3(Defs.MAP_SIZE * 0.5, 0, Defs.MAP_SIZE * 0.5)
	var sh := Shader.new()
	sh.code = TERRAIN_SHADER
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = sh
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	var fn := FastNoiseLite.new()
	fn.seed = rng.randi()
	fn.frequency = 0.012
	nt.noise = fn
	terrain_mat.set_shader_parameter("noise_tex", nt)
	terrain_mat.set_shader_parameter("map_size", Defs.MAP_SIZE)
	mi.material_override = terrain_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _make_start(p: PlayerData) -> void:
	var tl := snap_cells("city_center", p.start_pos)
	var cc = place_building(p.id, "city_center", tl, true)
	cc.rally = cc.position + Vector3(0, 0, -7)
	for i in Defs.START_CITIZENS:
		var a := TAU * i / Defs.START_CITIZENS
		var pos: Vector3 = cc.position + Vector3(cos(a) * 6.5, 0, sin(a) * 6.5)
		spawn_unit(p.id, "citizen", pos)
	_recount_pop(p.id)

func _scatter_resources(starts: Array) -> void:
	for i in starts.size():
		var s: Vector3 = starts[i]
		var toward := (Vector3(80, 0, 80) - s).normalized()
		var side := Vector3(-toward.z, 0, toward.x)
		_cluster("berries", s + toward * 12 + side * 8, 3, 2.5)
		_cluster("cattle", s + toward * 14 - side * 9, 4, 3.0)
		_cluster("stone", s - toward * 3 + side * 15, 2, 2.0)
		_cluster("gold", s - toward * 2 - side * 15, 3, 2.0)
		_cluster("tree", s + side * 22 + toward * 6, 14, 6.0)
		_cluster("tree", s - side * 22 + toward * 4, 12, 6.0)
	var kinds := ["tree", "tree", "tree", "stone", "gold", "gold", "berries", "cattle", "tree"]
	var placed := 0
	var tries := 0
	while placed < 26 and tries < 500:
		tries += 1
		var c := Vector3(rng.randf_range(8, Defs.MAP_SIZE - 8), 0, rng.randf_range(8, Defs.MAP_SIZE - 8))
		var near := false
		for s in starts:
			if s.distance_to(c) < 26.0:
				near = true
		if near:
			continue
		var k: String = kinds[rng.randi() % kinds.size()]
		var count := 10 if k == "tree" else (3 if k in ["berries", "cattle"] else 2)
		_cluster(k, c, count, 6.0 if k == "tree" else 2.5)
		placed += 1

func _cluster(kind: String, center: Vector3, count: int, spread: float) -> void:
	var n := 0
	var tries := 0
	while n < count and tries < count * 8:
		tries += 1
		var p := center + Vector3(rng.randf_range(-spread, spread), 0, rng.randf_range(-spread, spread))
		var c := cell_of(p)
		if not in_grid(c) or c.x < 1 or c.y < 1 or c.x > Defs.GRID - 2 or c.y > Defs.GRID - 2:
			continue
		if occ[idx(c)] > 0:
			continue
		var r := ResNode.new()
		r.setup(self, kind, cell_center(c), rng)
		r.cell = c
		add_child(r)
		resources.append(r)
		if kind != "cattle":
			_occupy(c, 1)
		else:
			_occupy(c, 1)
		n += 1

## Grass tufts, flowers and pebbles (decoration only; hidden where a building goes).
func _scatter_decor() -> void:
	var drng := RandomNumberGenerator.new()
	drng.seed = rng.seed + 77
	var plan := [["tuft", 2600], ["flower", 520], ["pebble", 320], ["bush", 150]]
	if OS.has_feature("mobile"):
		# lighter scenery on phones
		plan = [["tuft", 1100], ["flower", 260], ["pebble", 160], ["bush", 80]]
	var flower_cols := [Color(1, 1, 1), Color(1.0, 0.88, 0.25), Color(0.95, 0.35, 0.35), Color(0.75, 0.5, 0.95), Color(1.0, 0.65, 0.8)]
	for item in plan:
		var kind: String = item[0]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = Meshes.decor_mesh(kind)
		mm.instance_count = int(item[1])
		var n := 0
		var tries := 0
		var patch := Vector3.ZERO
		while n < mm.instance_count and tries < mm.instance_count * 6:
			tries += 1
			# flowers and tufts come in patches
			if n % 9 == 0 or kind == "pebble" or kind == "bush":
				patch = Vector3(drng.randf_range(3, Defs.MAP_SIZE - 3), 0, drng.randf_range(3, Defs.MAP_SIZE - 3))
			var pos := patch + Vector3(drng.randf_range(-2.5, 2.5), 0, drng.randf_range(-2.5, 2.5))
			var c := cell_of(pos)
			if not in_grid(c) or occ[idx(c)] > 0:
				continue
			var s := drng.randf_range(0.75, 1.35)
			var b := Basis(Vector3.UP, drng.randf() * TAU).scaled(Vector3(s, s * drng.randf_range(0.8, 1.3), s))
			mm.set_instance_transform(n, Transform3D(b, pos))
			var col := Color(1, 1, 1)
			if kind == "flower":
				col = flower_cols[drng.randi() % flower_cols.size()]
			elif kind == "tuft":
				col = Color(1, 1, 1).lerp(Color(1.25, 1.15, 0.7), drng.randf() * 0.5)
			mm.set_instance_color(n, col)
			if not decor.has(idx(c)):
				decor[idx(c)] = []
			decor[idx(c)].append([mm, n])
			n += 1
		mm.visible_instance_count = n
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = Meshes.world_mat()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

func _clear_decor(c: Vector2i) -> void:
	if not in_grid(c) or not decor.has(idx(c)):
		return
	for d in decor[idx(c)]:
		d[0].set_instance_transform(d[1], Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(0, -50, 0)))
	decor.erase(idx(c))

func _make_snow() -> void:
	snow_fx = GPUParticles3D.new()
	snow_fx.amount = 600
	snow_fx.lifetime = 6.0
	snow_fx.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(45, 1, 45)
	pm.direction = Vector3(0.2, -1, 0)
	pm.spread = 10.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 6.0
	pm.gravity = Vector3(0, -1, 0)
	snow_fx.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.18)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1, 0.9)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	snow_fx.draw_pass_1 = q
	snow_fx.position = Vector3(0, 28, 0)
	snow_fx.visibility_aabb = AABB(Vector3(-60, -40, -60), Vector3(120, 80, 120))
	cam.add_child(snow_fx)

# ------------------------------------------------------------------ grid helpers
func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / Defs.CELL)), int(floor(p.z / Defs.CELL)))

func cell_center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * Defs.CELL, 0, (c.y + 0.5) * Defs.CELL)

func in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < Defs.GRID and c.y < Defs.GRID

func idx(c: Vector2i) -> int:
	return c.y * Defs.GRID + c.x

func _occupy(c: Vector2i, d: int) -> void:
	if not in_grid(c):
		return
	var i := idx(c)
	occ[i] = max(0, occ[i] + d)
	astar.set_point_solid(c, occ[i] > 0)

func is_free(c: Vector2i) -> bool:
	return in_grid(c) and occ[idx(c)] == 0

func nearest_free(c: Vector2i) -> Vector2i:
	if is_free(c):
		return c
	for r in range(1, 14):
		var best := Vector2i(-1, -1)
		var bd := 1e9
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if is_free(n):
					var d := float(dx * dx + dy * dy)
					if d < bd:
						bd = d
						best = n
		if best.x >= 0:
			return best
	return c

func find_path(from: Vector3, to: Vector3) -> Array:
	var fc := nearest_free(cell_of(from))
	var tcell := cell_of(to)
	var tc := nearest_free(tcell)
	var out: Array = []
	if not in_grid(fc) or not in_grid(tc):
		return out
	var pts := astar.get_point_path(fc, tc, true)
	for i in range(1, pts.size()):
		out.append(Vector3(pts[i].x, 0, pts[i].y))
	if tc == tcell and in_grid(tcell):
		var exact := Vector3(clamp(to.x, 0.2, Defs.MAP_SIZE - 0.2), 0, clamp(to.z, 0.2, Defs.MAP_SIZE - 0.2))
		if out.is_empty():
			out.append(exact)
		else:
			out[out.size() - 1] = exact
	elif out.is_empty():
		out.append(cell_center(tc))
	return out

func approach_point(e, from: Vector3) -> Vector3:
	var cells: Array = []
	if e is Building:
		cells = e.cells
	elif e is ResNode:
		cells = [e.cell]
	else:
		return e.position
	var best := Vector3(e.position)
	var bd := 1e9
	for c in cells:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var n: Vector2i = c + Vector2i(dx, dy)
				if not is_free(n):
					continue
				var w := cell_center(n)
				var d := w.distance_squared_to(from)
				if d < bd:
					bd = d
					best = w
	if bd > 1e8:
		# nothing free right around it: walk to the nearest free cell
		return cell_center(nearest_free(cell_of(e.position)))
	return best

# ------------------------------------------------------------------ territories
func territory_at(p: Vector3) -> int:
	var q := Vector2(p.x, p.z)
	var best := 0
	var bd := 1e18
	for i in seeds.size():
		var d: float = q.distance_squared_to(seeds[i])
		if d < bd:
			bd = d
			best = i
	return best

func territory_name(i: int) -> String:
	return Defs.TERRITORY_NAMES[i % Defs.TERRITORY_NAMES.size()]

func territories_of(pid: int) -> int:
	var n := 0
	for o in terr_owner:
		if o == pid:
			n += 1
	return n

func _update_territories(silent := false) -> void:
	var new_owner: Array = []
	for i in seeds.size():
		new_owner.append(-1)
	for b in buildings:
		if b.kind == "city_center" and b.built and not b.dead:
			var t := territory_at(b.position)
			if new_owner[t] == -1:
				new_owner[t] = b.owner_id
	for i in seeds.size():
		if new_owner[i] != terr_owner[i] and not silent and new_owner[i] >= 0:
			var who: String = players[new_owner[i]].name
			emit_signal("notify", "%s assumiu o controle de %s" % [who, territory_name(i)], players[new_owner[i]].color.lightened(0.3))
		terr_owner[i] = new_owner[i]
	var sp := PackedVector2Array()
	var cols := PackedColorArray()
	for i in 16:
		if i < seeds.size():
			sp.append(seeds[i])
			var o: int = terr_owner[i]
			cols.append(Color(players[o].color, 1.0) if o >= 0 else Color(0.3, 0.3, 0.4, 0.0))
		else:
			sp.append(Vector2(-9999, -9999))
			cols.append(Color(0, 0, 0, 0))
	terrain_mat.set_shader_parameter("seeds", sp)
	terrain_mat.set_shader_parameter("tcol", cols)
	terrain_mat.set_shader_parameter("seed_count", seeds.size())

# ------------------------------------------------------------------ placing buildings
func snap_cells(kind: String, p: Vector3) -> Vector2i:
	var s: int = Defs.BUILDINGS[kind]["size"]
	return Vector2i(int(round(p.x / Defs.CELL - s / 2.0)), int(round(p.z / Defs.CELL - s / 2.0)))

func footprint_center(kind: String, tl: Vector2i) -> Vector3:
	var s: int = Defs.BUILDINGS[kind]["size"]
	return Vector3((tl.x + s / 2.0) * Defs.CELL, 0, (tl.y + s / 2.0) * Defs.CELL)

## "" when the building may go there, otherwise the reason.
func placement_error(pid: int, kind: String, tl: Vector2i) -> String:
	var d: Dictionary = Defs.BUILDINGS[kind]
	var s: int = d["size"]
	if players[pid].epoch < int(d["epoch"]):
		return "%s requer a %s" % [d["name"], Defs.EPOCHS[int(d["epoch"]) - 1]["name"]]
	for x in s:
		for y in s:
			var c := tl + Vector2i(x, y)
			if not in_grid(c) or c.x < 1 or c.y < 1 or c.x > Defs.GRID - 2 or c.y > Defs.GRID - 2:
				return "Fora do mapa"
			if occ[idx(c)] > 0:
				return "Há algo no caminho"
	var center := footprint_center(kind, tl)
	if pid == 0 and fog_enabled and fog[idx(cell_of(center))] == 0:
		return "Não é possível construir em terra inexplorada"
	var t := territory_at(center)
	if kind == "city_center":
		if terr_owner[t] != -1:
			return "Este território já tem um Centro da Cidade"
		for b in buildings:
			if b.kind == "city_center" and territory_at(b.position) == t:
				return "Este território já tem um Centro da Cidade"
	elif terr_owner[t] != pid:
		return "Só é possível construir isto dentro do seu território"
	return ""

func place_building(pid: int, kind: String, tl: Vector2i, complete := false):
	var b := Building.new()
	b.setup(self, kind, pid, footprint_center(kind, tl), complete)
	var s: int = Defs.BUILDINGS[kind]["size"]
	for x in s:
		for y in s:
			var c := tl + Vector2i(x, y)
			b.cells.append(c)
			_clear_decor(c)
			if not Defs.BUILDINGS[kind].get("walkable", false):
				_occupy(c, 1)
	b.rally = b.position + Vector3(0, 0, b.radius + 3.0)
	add_child(b)
	buildings.append(b)
	b.visible = pid == 0 or not fog_enabled or fog[idx(cell_of(b.position))] == 2
	# push units out of the new footprint
	if not Defs.BUILDINGS[kind].get("walkable", false):
		for u in units:
			if b.cells.has(cell_of(u.position)):
				u.position = cell_center(nearest_free(cell_of(u.position)))
	if complete:
		_recount_pop(pid)
	return b

## Places a foundation (paid) and sends builders. Returns "" or a reason.
func order_construct(pid: int, kind: String, tl: Vector2i, builders: Array) -> String:
	var err := placement_error(pid, kind, tl)
	if err != "":
		return err
	var cost: Dictionary = Defs.BUILDINGS[kind]["cost"]
	if not players[pid].pay(cost):
		return "Recursos insuficientes (%s) para construir: %s" % [Defs.missing_text(players[pid].res, cost), Defs.BUILDINGS[kind]["name"]]
	var b = place_building(pid, kind, tl, false)
	for u in builders:
		if is_instance_valid(u) and not u.dead and u.is_citizen():
			u.order_build(b)
	return ""

# ------------------------------------------------------------------ units
func spawn_unit(pid: int, kind: String, pos: Vector3):
	var u := Unit.new()
	var c := nearest_free(cell_of(pos))
	var p := pos if is_free(cell_of(pos)) else cell_center(c)
	u.setup(self, kind, pid, Vector3(p.x, 0, p.z))
	add_child(u)
	units.append(u)
	u.visible = pid == 0 or not fog_enabled or fog[idx(cell_of(u.position))] == 2
	return u

func spawn_trained(b, kind: String) -> void:
	var toward: Vector3 = b.rally if b.has_rally else b.position + Vector3(0, 0, 10)
	var pos: Vector3 = approach_point(b, toward)
	var u = spawn_unit(b.owner_id, kind, pos)
	stats[b.owner_id]["trained"] += 1
	if b.has_rally:
		var r = resource_at(b.rally, 2.0)
		if r and u.is_citizen():
			u.order_gather(r)
		else:
			u.order_move(b.rally + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)))
	if b.owner_id == 0 and hud:
		hud.refresh_selection()

func pop_used(pid: int) -> int:
	var n := 0
	for u in units:
		if u.owner_id == pid:
			n += 1
	return n

func _recount_pop(pid: int) -> void:
	var cap := 0
	for b in buildings:
		if b.owner_id == pid and b.built and not b.dead:
			cap += int(b.def.get("pop", 0))
	players[pid].pop_cap = min(cap, Defs.POP_LIMIT)

## Queue a unit; returns "" or the reason it can't.
func train(b, kind: String) -> String:
	var p = players[b.owner_id]
	var d: Dictionary = Defs.UNITS[kind]
	if not b.can_train(kind):
		return "Esta construção não treina essa unidade"
	if p.epoch < int(d["epoch"]):
		return "%s requer a %s" % [d["name"], Defs.EPOCHS[int(d["epoch"]) - 1]["name"]]
	if b.queue.size() >= 5:
		return "A fila está cheia"
	if not p.pay(d["cost"]):
		return "Recursos insuficientes (%s) para produzir: %s" % [Defs.missing_text(p.res, d["cost"]), d["name"]]
	b.queue.append(kind)
	return ""

func cancel_train(b) -> void:
	if b.queue.is_empty():
		return
	var k: String = b.queue.pop_back()
	players[b.owner_id].refund(Defs.UNITS[k]["cost"])
	if b.queue.is_empty():
		b.train_time = 0.0

# ------------------------------------------------------------------ eras
func advance_epoch(pid: int) -> String:
	var p = players[pid]
	if p.epoch >= Defs.EPOCHS.size():
		return "Você já está na última era"
	for b in buildings:
		if b.owner_id == pid and b.researching:
			return "O avanço para a próxima era já está em andamento"
	var cc = null
	for b in buildings:
		if b.owner_id == pid and b.kind == "city_center" and b.built:
			cc = b
			break
	if cc == null:
		return "Você precisa de um Centro da Cidade"
	var e: Dictionary = Defs.EPOCHS[p.epoch]
	if not p.pay(e["cost"]):
		return "Recursos insuficientes (%s) para avançar de era" % Defs.missing_text(p.res, e["cost"])
	cc.researching = true
	cc.research_time = float(e["time"])
	if pid == 0:
		emit_signal("notify", "Avanço para a %s (Era %d) iniciado" % [e["name"], p.epoch + 1], Color(1, 1, 0.7))
	return ""

func epoch_progress(pid: int) -> float:
	for b in buildings:
		if b.owner_id == pid and b.researching:
			var t: float = Defs.EPOCHS[players[pid].epoch]["time"]
			return 1.0 - b.research_time / t
	return -1.0

func finish_epoch(pid: int) -> void:
	var p = players[pid]
	var old := hp_mult(pid, "spearman")
	p.epoch += 1
	var ratio := hp_mult(pid, "spearman") / old
	for u in units:
		if u.owner_id == pid and u.is_military():
			u.max_hp *= ratio
			u.hp *= ratio
	var name: String = Defs.EPOCHS[p.epoch - 1]["name"]
	if pid == 0:
		emit_signal("notify", "Você alcançou a %s (Era %d)" % [name, p.epoch], Color(1, 1, 0.6))
	else:
		emit_signal("notify", "%s alcançou a %s" % [p.name, name], p.color.lightened(0.3))
	_check_crowns()

# ------------------------------------------------------------------ economy & combat numbers
func gather_mult(pid: int, res_type: String) -> float:
	var p = players[pid]
	var m: float = 1.0 + Defs.EPOCH_GATHER_BONUS * (p.epoch - 1)
	if crown_holder.get("economic", -1) == pid:
		m *= 1.0 + Defs.CROWN_ECONOMIC_BONUS
	if p.is_ai:
		m *= Defs.DIFFICULTY[p.difficulty]["gather"]
	if res_type == "food" and is_winter():
		m *= Defs.WINTER_FOOD
	return m

func build_mult(pid: int) -> float:
	return 1.0 + (Defs.CROWN_IMPERIAL_BONUS if crown_holder.get("imperial", -1) == pid else 0.0)

func time_mult(pid: int) -> float:
	return 1.0 / build_mult(pid)

func hp_mult(pid: int, kind: String) -> float:
	if kind == "citizen":
		return 1.0
	return 1.0 + Defs.EPOCH_MILITARY_BONUS * (players[pid].epoch - 1)

func damage(att, tgt) -> float:
	var base := float(att.def["atk"])
	if att.is_unit() and att.is_military():
		base *= 1.0 + Defs.EPOCH_MILITARY_BONUS * (players[att.owner_id].epoch - 1)
	if crown_holder.get("military", -1) == att.owner_id:
		base *= 1.0 + Defs.CROWN_MILITARY_BONUS
	var tcls: String = "building" if tgt.is_building() else tgt.cls()
	var mult: float = att.def.get("bonus", {}).get(tcls, 1.0)
	var armor := float(tgt.def.get("armor", 0))
	if tgt.is_building() and att.is_unit() and att.kind != "catapult" and att.kind != "swordsman":
		armor *= 1.5
	return max(1.0, base * mult - armor)

func deposit(pid: int, res_type: String, amt: float) -> void:
	if amt <= 0.0 or res_type == "":
		return
	var p = players[pid]
	p.res[res_type] = p.res.get(res_type, 0.0) + amt
	p.gathered += amt
	if p.gathered >= Defs.CROWN_ECONOMIC_GATHERED and not crown_holder.has("economic"):
		_check_crowns()

func shoot(src, tgt, dmg: float, kind: String) -> void:
	var m := MeshInstance3D.new()
	if kind == "stone":
		m.mesh = Meshes.sphere(0.32, 6)
		m.material_override = Meshes.mat(Color(0.42, 0.40, 0.37))
	else:
		m.mesh = Meshes.box(Vector3(0.05, 0.05, 1.0))
		m.material_override = Meshes.mat(Color(0.30, 0.22, 0.12))
	var h := 1.4
	if src is Building:
		h = 6.2 if src.kind == "tower" else 4.0
	elif src.kind == "catapult":
		h = 2.6
	var from: Vector3 = src.position + Vector3(0, h, 0)
	m.position = from
	add_child(m)
	m.visible = src.visible
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dist: float = from.distance_to(tgt.position)
	var speed: float = 17.0 if kind == "stone" else 30.0
	projectiles.append({"node": m, "target": tgt, "dmg": dmg, "src": src, "kind": kind, "from": from,
		"t": 0.0, "dur": max(0.15, dist / speed), "arc": dist * (0.32 if kind == "stone" else 0.10),
		"dest": tgt.position, "owner": src.owner_id})

func _tick_projectiles(delta: float) -> void:
	var keep: Array = []
	for pr in projectiles:
		var t = pr["target"]
		if is_instance_valid(t) and not t.dead:
			pr["dest"] = t.position
		var node: MeshInstance3D = pr["node"]
		pr["t"] += delta
		var f: float = pr["t"] / pr["dur"]
		if f >= 1.0:
			var src = pr["src"] if is_instance_valid(pr["src"]) else null
			if pr["kind"] == "stone":
				for e in units + buildings:
					if e.owner_id != pr["owner"] and not e.dead and e.edge_distance(pr["dest"]) <= 2.0:
						var dm: float = pr["dmg"] if e == t else pr["dmg"] * 0.5
						e.take_damage(dm if e.is_building() else min(dm, 14.0), src)
				if node.visible:
					Fx.puff(self, pr["dest"] + Vector3(0, 0.4, 0), "dust", 1.3)
			elif is_instance_valid(t) and not t.dead:
				t.take_damage(pr["dmg"], src)
			node.queue_free()
		else:
			var dest: Vector3 = pr["dest"] + Vector3(0, 1.0, 0)
			var np: Vector3 = (pr["from"] as Vector3).lerp(dest, f) + Vector3(0, sin(f * PI) * pr["arc"], 0)
			if np.distance_squared_to(node.position) > 0.0001:
				node.look_at_from_position(node.position, np, Vector3.UP)
			node.position = np
			keep.append(pr)
	projectiles = keep

# ------------------------------------------------------------------ queries
func nearest_enemy(pid: int, pos: Vector3, rng_m: float, units_only: bool):
	var best = null
	var bd := rng_m
	for u in units:
		if u.owner_id != pid and not u.dead and players[u.owner_id].alive:
			var d: float = u.edge_distance(pos)
			if d <= bd:
				bd = d
				best = u
	if best != null or units_only:
		return best
	for b in buildings:
		if b.owner_id != pid and not b.dead and players[b.owner_id].alive:
			var d: float = b.edge_distance(pos)
			if d <= bd:
				bd = d
				best = b
	return best

func nearest_dropsite(pid: int, pos: Vector3):
	var best = null
	var bd := 1e9
	for b in buildings:
		if b.owner_id == pid and b.built and not b.dead and b.def.get("dropsite", false):
			var d: float = b.edge_distance(pos)
			if d < bd:
				bd = d
				best = b
	return best

func nearest_resource(kind: String, pos: Vector3, max_d: float, pid := -1):
	var best = null
	var bd := max_d
	if kind == "farm":
		for b in buildings:
			if b.kind == "farm" and b.owner_id == pid and b.built and b.workers.size() < 3:
				var d: float = b.position.distance_to(pos)
				if d < bd:
					bd = d
					best = b
		return best
	for r in resources:
		if r.kind == kind and not r.dead:
			var d: float = r.position.distance_to(pos)
			if d < bd:
				bd = d
				best = r
	return best

func nearest_resource_of_type(res_type: String, pos: Vector3, max_d: float):
	var best = null
	var bd := max_d
	for r in resources:
		if r.res_type == res_type and not r.dead:
			var d: float = r.position.distance_to(pos)
			if d < bd:
				bd = d
				best = r
	return best

func nearest_unfinished(pid: int, pos: Vector3, max_d: float):
	var best = null
	var bd := max_d
	for b in buildings:
		if b.owner_id == pid and not b.built and not b.dead:
			var d: float = b.position.distance_to(pos)
			if d < bd:
				bd = d
				best = b
	return best

func resource_at(p: Vector3, r: float):
	for n in resources:
		if not n.dead and n.position.distance_to(Vector3(p.x, 0, p.z)) <= r:
			return n
	return null

# ------------------------------------------------------------------ events
func on_damaged(e, attacker) -> void:
	if e.is_unit():
		e.on_attacked(attacker)
	if attacker == null or not is_instance_valid(attacker):
		return
	if e.owner_id >= 0 and players[e.owner_id].ai:
		players[e.owner_id].ai.on_attacked(e, attacker)
	if e.owner_id == 0 and attacker.owner_id != 0 and time - attack_msg_t > 20.0:
		attack_msg_t = time
		last_alert = e.position
		emit_signal("notify", "Você está sob ataque!", Color(1, 0.4, 0.3))
		if hud:
			hud.ping(e.position)

func on_entity_died(e, attacker) -> void:
	selected.erase(e)
	if e.owner_id >= 0 and stats.has(e.owner_id):
		stats[e.owner_id]["lost" if e.is_unit() else "razed"] += 1
	if e.is_unit():
		units.erase(e)
		if attacker != null and is_instance_valid(attacker) and attacker.owner_id >= 0 and attacker.owner_id != e.owner_id:
			players[attacker.owner_id].kills += 1
			if players[attacker.owner_id].kills >= Defs.CROWN_MILITARY_KILLS:
				_check_crowns()
	elif e.is_building():
		buildings.erase(e)
		if not e.def.get("walkable", false):
			for c in e.cells:
				_occupy(c, -1)
		_recount_pop(e.owner_id)
		if e.kind == "city_center":
			_update_territories()
		_spawn_ruin(e.position, e.radius)
	if hud:
		hud.refresh_selection()
	_check_elimination()

func on_resource_depleted(r) -> void:
	resources.erase(r)
	selected.erase(r)
	_occupy(r.cell, -1)

func on_building_finished(b) -> void:
	stats[b.owner_id]["built"] += 1
	_recount_pop(b.owner_id)
	if b.kind == "city_center":
		_update_territories()
	if b.owner_id == 0:
		emit_signal("notify", "Construção concluída: %s" % b.def["name"], Color(0.8, 1, 0.8))
		if hud:
			hud.refresh_selection()

func _spawn_ruin(p: Vector3, r: float) -> void:
	var bake := Meshes.Bake.new()
	bake.add(Meshes.cyl(r * 0.95, r * 1.05, 0.12, 12), Color(0.20, 0.16, 0.12), Vector3(0, 0.06, 0), Vector3.ZERO, 0.0, 0.0)
	for i in 9:
		var a := TAU * i / 9.0 + randf()
		var rr := randf_range(0.2, 0.85) * r
		bake.add(Meshes.box(Vector3(randf_range(0.4, 1.1), randf_range(0.25, 0.8), randf_range(0.4, 1.0))),
			[Color(0.42, 0.40, 0.37), Color(0.30, 0.21, 0.13), Color(0.16, 0.13, 0.11)][i % 3],
			Vector3(cos(a) * rr, 0.25, sin(a) * rr), Vector3(randf() * 30, randf() * 180, randf() * 25))
	var m := MeshInstance3D.new()
	m.mesh = bake.mesh()
	m.material_override = Meshes.world_mat()
	m.position = p
	add_child(m)
	if fog[idx(cell_of(p))] == 2:
		Fx.puff(self, p + Vector3(0, 1.0, 0), "dust", r * 0.9)
		m.add_child(Fx.smoke(Vector3(0, 0.5, 0), 1.4))
	var tw := m.create_tween()
	tw.tween_interval(26.0)
	tw.tween_property(m, "position:y", -1.0, 4.0)
	tw.tween_callback(m.queue_free)

func change_owner(b, new_owner: int) -> void:
	var old: int = b.owner_id
	b.owner_id = new_owner
	b.queue.clear()
	b.train_time = 0.0
	b.researching = false
	b.loyalty = 100.0
	b.workers.clear()
	b.model.queue_free()
	b.model = Meshes.building_model(b.kind, Defs.TEAM_COLORS[new_owner])
	b.add_child(b.model)
	b._update_model()
	b.sel_ring.material_override.albedo_color = Color(0.2, 1.0, 0.3) if new_owner == 0 else Color(1.0, 0.25, 0.2)
	selected.erase(b)
	b.set_selected(false)
	_recount_pop(old)
	_recount_pop(new_owner)
	var who: String = players[new_owner].name
	emit_signal("notify", "%s capturou: %s" % [who, b.def["name"]], players[new_owner].color.lightened(0.3))
	if b.kind == "city_center":
		_update_territories()
	_check_elimination()

func _tick_capture(dt: float) -> void:
	for b in buildings:
		if b.dead or not b.built or not b.def.get("capturable", false):
			continue
		var counts := {}
		var defenders := 0
		for u in units:
			if u.dead:
				continue
			if u.position.distance_to(b.position) > Defs.CAPTURE_RADIUS + b.radius:
				continue
			if u.owner_id == b.owner_id:
				defenders += 1
			elif u.cls() == "infantry" or u.cls() == "cavalry":
				counts[u.owner_id] = counts.get(u.owner_id, 0) + 1
		if counts.is_empty() or defenders > 0:
			b.loyalty = min(100.0, b.loyalty + Defs.LOYALTY_REGEN * dt)
			b.last_loyalty_msg = int(ceil(b.loyalty / 10.0)) * 10
			continue
		var top := -1
		var tn := 0
		for k in counts:
			if counts[k] > tn:
				tn = counts[k]
				top = k
		b.capture_by = top
		b.loyalty -= min(Defs.CAPTURE_MAX_RATE, Defs.CAPTURE_RATE * tn) * dt
		if b.owner_id == 0:
			var step := int(floor(b.loyalty / 10.0)) * 10
			if step < b.last_loyalty_msg and step >= 0:
				b.last_loyalty_msg = step
				emit_signal("notify", "O inimigo está capturando: %s — a lealdade caiu para %d%%" % [b.def["name"], step], Color(1, 0.5, 0.4))
				if hud:
					hud.ping(b.position)
		if b.loyalty <= 0.0:
			change_owner(b, top)

# ------------------------------------------------------------------ crowns, victory
func _check_crowns() -> void:
	var checks := [["military", "Coroa Militar"], ["economic", "Coroa Econômica"], ["imperial", "Coroa Imperial"]]
	for c in checks:
		if crown_holder.has(c[0]):
			continue
		for p in players:
			if not p.alive:
				continue
			var got := false
			match c[0]:
				"military": got = p.kills >= Defs.CROWN_MILITARY_KILLS
				"economic": got = p.gathered >= Defs.CROWN_ECONOMIC_GATHERED
				"imperial": got = p.epoch >= Defs.CROWN_IMPERIAL_EPOCH
			if got:
				crown_holder[c[0]] = p.id
				p.crowns[c[0]] = true
				var who: String = p.name
				emit_signal("notify", "%s conquistou a %s! (%s)" % [who, c[1], Defs.CROWN_DESC[c[0]]], Color(1, 0.85, 0.3))
				break

func _check_elimination() -> void:
	if over and not config.get("sim", false):
		return
	for p in players:
		if not p.alive:
			continue
		var has_cc := false
		var has_cit := false
		for b in buildings:
			if b.owner_id == p.id and b.kind == "city_center" and not b.dead:
				has_cc = true
				break
		if not has_cc:
			for u in units:
				if u.owner_id == p.id and u.is_citizen() and not u.dead:
					has_cit = true
					break
		if not has_cc and not has_cit:
			p.alive = false
			if p.id != 0:
				emit_signal("notify", "%s foi eliminado" % p.name, p.color.lightened(0.3))
				for e in units + buildings:
					if e.owner_id == p.id and not e.dead:
						e.die(null)
	if not players[0].alive:
		over = true
		emit_signal("ended", false)
		return
	var others := 0
	for p in players:
		if p.id != 0 and p.alive:
			others += 1
	if others == 0:
		over = true
		emit_signal("ended", true)

# ------------------------------------------------------------------ seasons
func month_index() -> int:
	return (Defs.START_MONTH + int(time / Defs.MONTH_SECONDS)) % 12

func year() -> int:
	return 1 + int((Defs.START_MONTH + int(time / Defs.MONTH_SECONDS)) / 12)

func is_winter() -> bool:
	return Defs.WINTER_MONTHS.has(month_index())

func season_speed() -> float:
	return Defs.WINTER_SPEED if is_winter() else 1.0

# ------------------------------------------------------------------ fog of war
func _update_fog() -> void:
	for i in fog.size():
		if fog[i] == 2:
			fog[i] = 1
	if not fog_enabled:
		fog.fill(2)
	else:
		for e in units + buildings:
			if e.owner_id != 0 or e.dead:
				continue
			var sight: float = e.def.get("sight", 10)
			var r := int(ceil(sight / Defs.CELL))
			var c := cell_of(e.position)
			var r2 := (sight / Defs.CELL) * (sight / Defs.CELL)
			for dx in range(-r, r + 1):
				for dy in range(-r, r + 1):
					if dx * dx + dy * dy > r2:
						continue
					var n := Vector2i(c.x + dx, c.y + dy)
					if in_grid(n):
						fog[idx(n)] = 2
	var bytes := PackedByteArray()
	bytes.resize(fog.size())
	for i in fog.size():
		bytes[i] = 255 if fog[i] == 2 else (110 if fog[i] == 1 else 0)
	fog_img.set_data(Defs.GRID, Defs.GRID, false, Image.FORMAT_L8, bytes)
	fog_tex.update(fog_img)
	for u in units:
		if u.owner_id != 0:
			u.visible = fog[idx(cell_of(u.position))] == 2
	for b in buildings:
		if b.owner_id != 0:
			var f := fog[idx(cell_of(b.position))]
			if f == 2:
				b.seen = true
			b.visible = b.seen or f == 2
	for r in resources:
		var f2 := fog[idx(r.cell)]
		r.visible = f2 >= 1

func is_visible_to_player(e) -> bool:
	if e.owner_id == 0:
		return true
	return fog[idx(cell_of(e.position))] == 2

# ------------------------------------------------------------------ main loop
func _separate() -> void:
	var buckets := {}
	for u in units:
		var k := Vector2i(int(u.position.x / 3.0), int(u.position.z / 3.0))
		if not buckets.has(k):
			buckets[k] = []
		buckets[k].append(u)
	for u in units:
		if u.dead:
			continue
		var k := Vector2i(int(u.position.x / 3.0), int(u.position.z / 3.0))
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var list = buckets.get(k + Vector2i(dx, dy))
				if list == null:
					continue
				for o in list:
					if o == u or o.dead:
						continue
					var d: Vector3 = u.position - o.position
					d.y = 0
					var min_d: float = (u.radius + o.radius) * 0.85
					var l := d.length()
					if l < min_d:
						if l < 0.001:
							d = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
							l = d.length()
						var push := d / l * (min_d - l) * 0.25
						var np: Vector3 = u.position + push
						if is_free(cell_of(np)) or not is_free(cell_of(u.position)):
							u.position = np

func _process(delta: float) -> void:
	if over and not config.get("keep_running", false):
		return
	time += delta
	for u in units.duplicate():
		if not u.dead:
			u.tick(delta)
	for b in buildings.duplicate():
		if not b.dead:
			b.tick(delta)
	_tick_projectiles(delta)
	_separate()
	fog_t -= delta
	if fog_t <= 0.0:
		fog_t = 0.25
		_update_fog()
	cap_t -= delta
	if cap_t <= 0.0:
		cap_t = 0.5
		_tick_capture(0.5)
	ai_t -= delta
	if ai_t <= 0.0:
		ai_t = 0.5
		for p in players:
			if p.ai and p.alive:
				p.ai.acc += 0.5
				if p.ai.acc >= float(p.ai.diff["think"]):
					var step: float = p.ai.acc
					p.ai.acc = 0.0
					p.ai.tick(step)
	var target := 1.0 if is_winter() else 0.0
	if snow != target:
		snow = move_toward(snow, target, delta * 0.15)
		terrain_mat.set_shader_parameter("snow", snow)
		Meshes.set_snow(snow)
		# winter light is paler and colder
		sun.light_color = Color(1.0, 0.95, 0.84).lerp(Color(0.86, 0.90, 1.0), snow)
		sun.light_energy = lerp(0.95, 0.80, snow)
		env.ambient_light_color = Color(0.66, 0.72, 0.86).lerp(Color(0.78, 0.82, 0.92), snow)
	if snow_fx:
		snow_fx.emitting = snow > 0.4

func _exit_tree() -> void:
	# break the player <-> computer-player reference cycle so both are freed
	for p in players:
		if p.ai:
			p.ai.p = null
			p.ai.game = null
		p.ai = null
