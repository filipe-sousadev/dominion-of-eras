class_name Meshes
extends RefCounted
## Builds every model out of simple shapes (original low-poly art).
## Each model is merged into one mesh with per-vertex colours, so a building or a tree is a single
## draw, and all of them share two materials: one for the world (darkens under the fog of war, gets
## snow in winter, foliage sways) and one for people and machines.

const WORLD_SHADER := """
shader_type spatial;
render_mode world_vertex_coords, diffuse_lambert, specular_disabled;
uniform sampler2D fog_tex : filter_linear;
uniform float map_size = 160.0;
uniform float snow = 0.0;
uniform float snow_amt = 1.0;
uniform float use_fog = 1.0;
varying vec3 wpos;
varying float up;
void vertex() {
	float sway = 1.0 - COLOR.a;
	if (sway > 0.001) {
		float w = sin(TIME * 1.4 + VERTEX.x * 0.45 + VERTEX.z * 0.35) + 0.5 * sin(TIME * 2.3 + VERTEX.z * 0.8);
		VERTEX.x += w * 0.028 * sway * VERTEX.y;
		VERTEX.z += w * 0.018 * sway * VERTEX.y;
	}
	wpos = VERTEX;
	up = NORMAL.y;
}
void fragment() {
	vec3 col = COLOR.rgb;
	col = mix(col, vec3(0.70, 0.72, 0.78), snow * snow_amt * 0.9 * smoothstep(0.30, 0.75, up));
	float f = texture(fog_tex, wpos.xz / map_size).r;
	float explored = clamp(f * 2.2, 0.0, 1.0);
	float visible = clamp(f * 2.0 - 1.0, 0.0, 1.0);
	float lum = dot(col, vec3(0.3, 0.5, 0.2));
	col = mix(mix(vec3(lum), col, 0.55) * 0.5, col, visible) * explored;
	ALBEDO = mix(COLOR.rgb, col, use_fog);
	ROUGHNESS = 0.92;
}
"""

static var _mats := {}
static var _cache := {}
static var _world_mat: ShaderMaterial
static var _unit_mat: ShaderMaterial
static var _shader: Shader

# ---------------------------------------------------------------- materials
static func _shared(snow_amt: float, use_fog: float) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = WORLD_SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("snow_amt", snow_amt)
	m.set_shader_parameter("use_fog", use_fog)
	m.set_shader_parameter("map_size", Defs.MAP_SIZE)
	return m

## Material of buildings, trees, rocks and decoration.
static func world_mat() -> ShaderMaterial:
	if _world_mat == null:
		_world_mat = _shared(1.0, 1.0)
	return _world_mat

## Material of people, animals that move and machines (no snow, no fog dimming).
static func unit_mat() -> ShaderMaterial:
	if _unit_mat == null:
		_unit_mat = _shared(0.0, 0.0)
	return _unit_mat

static func set_world(fog_tex: Texture2D) -> void:
	world_mat().set_shader_parameter("fog_tex", fog_tex)
	unit_mat().set_shader_parameter("fog_tex", fog_tex)

static func set_snow(v: float) -> void:
	world_mat().set_shader_parameter("snow", v)

static func clear() -> void:
	_mats.clear()
	_cache.clear()
	_world_mat = null
	_unit_mat = null
	_shader = null

static func mat(c: Color, alpha := false) -> StandardMaterial3D:
	var key := c.to_html() + ("a" if alpha else "")
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m

# ---------------------------------------------------------------- primitive shapes
static func box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b

static func cyl(r_top: float, r_bot: float, h: float, seg := 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c

static func sphere(r: float, seg := 10) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = max(3, seg / 2)
	return s

static func prism(s: Vector3) -> PrismMesh:
	var p := PrismMesh.new()
	p.size = s
	return p

static func capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 8
	c.rings = 2
	return c

# ---------------------------------------------------------------- merging parts into one mesh
class Bake:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()

	## Adds a shape. `sway` (0-1) makes it move in the wind; `shade` darkens its lower part a little.
	func add(mesh: Mesh, col: Color, pos: Vector3, rot_deg := Vector3.ZERO, sway := 0.0, shade := 0.22, scl := Vector3.ONE) -> void:
		var arr := mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var ind: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var rot_b := Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z)))
		var b := rot_b * Basis.from_scale(scl)
		var base := v.size()
		var lo := 1e9
		var hi := -1e9
		var out := PackedVector3Array()
		out.resize(verts.size())
		for i in verts.size():
			var w: Vector3 = b * verts[i] + pos
			out[i] = w
			lo = min(lo, w.y)
			hi = max(hi, w.y)
		var span: float = max(hi - lo, 0.001)
		for i in verts.size():
			v.append(out[i])
			n.append((rot_b * norms[i]).normalized())
			var k: float = 1.0 - shade * (1.0 - (out[i].y - lo) / span)
			c.append(Color(col.r * k, col.g * k, col.b * k, 1.0 - sway))
		if ind.is_empty():
			for i in verts.size():
				idx.append(base + i)
		else:
			for i in ind:
				idx.append(base + i)

	func mesh() -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m

static func _inst(mesh: Mesh, material: Material, name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	if name != "":
		mi.name = name
	return mi

const SKIN := Color(0.86, 0.66, 0.50)
const HAIR := Color(0.25, 0.17, 0.10)
const WOOD := Color(0.50, 0.34, 0.19)
const DARKWOOD := Color(0.33, 0.22, 0.12)
const THATCH := Color(0.74, 0.60, 0.33)
const STONE := Color(0.64, 0.62, 0.58)
const PLASTER := Color(0.86, 0.80, 0.67)
const METAL := Color(0.74, 0.76, 0.80)
const TILE := Color(0.66, 0.30, 0.20)
const DIRT := Color(0.42, 0.33, 0.20)
const LEATHER := Color(0.42, 0.28, 0.16)
const CLOTH := Color(0.36, 0.30, 0.24)

# ---------------------------------------------------------------- units
## A limb that swings from its top: returns the pivot node.
static func _limb(parent: Node3D, bake: Bake, pivot: Vector3, name: String) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pivot
	n.add_child(_inst(bake.mesh(), unit_mat()))
	parent.add_child(n)
	return n

static func _unit_meshes(kind: String, team: Color) -> Dictionary:
	var key := "u:%s:%s" % [kind, team.to_html()]
	if _cache.has(key):
		return _cache[key]
	var out := {}
	var body := Bake.new()
	var dark := team.darkened(0.35)
	match kind:
		"cavalry":
			var horse := Color(0.45, 0.29, 0.16)
			body.add(box(Vector3(0.62, 0.62, 1.6)), horse, Vector3(0, 1.05, 0))
			body.add(box(Vector3(0.34, 0.75, 0.38)), horse, Vector3(0, 1.55, 0.85), Vector3(-35, 0, 0))
			body.add(box(Vector3(0.28, 0.3, 0.55)), horse.darkened(0.1), Vector3(0, 1.88, 1.2), Vector3(15, 0, 0))
			body.add(box(Vector3(0.08, 0.5, 0.5)), Color(0.15, 0.10, 0.06), Vector3(0, 1.75, 0.62), Vector3(-35, 0, 0), 0.0, 0.0)
			body.add(box(Vector3(0.1, 0.6, 0.1)), Color(0.15, 0.10, 0.06), Vector3(0, 0.95, -0.88), Vector3(25, 0, 0))
			body.add(box(Vector3(0.68, 0.12, 0.7)), team, Vector3(0, 1.4, -0.05))
			body.add(box(Vector3(0.44, 0.55, 0.3)), team, Vector3(0, 1.78, -0.05))
			body.add(box(Vector3(0.48, 0.3, 0.34)), METAL.darkened(0.15), Vector3(0, 1.95, -0.05))
			body.add(sphere(0.17, 8), SKIN, Vector3(0, 2.27, -0.02))
			body.add(sphere(0.19, 8), METAL, Vector3(0, 2.33, -0.04), Vector3.ZERO, 0.0, 0.1, Vector3(1, 0.75, 1))
			body.add(box(Vector3(0.14, 0.5, 0.16)), LEATHER, Vector3(-0.36, 1.35, 0.0))
			body.add(box(Vector3(0.14, 0.5, 0.16)), LEATHER, Vector3(0.36, 1.35, 0.0))
			body.add(cyl(0.3, 0.3, 0.06, 10), dark, Vector3(-0.38, 1.75, 0.1), Vector3(0, 0, 90))
			out["body"] = body.mesh()
			var leg := Bake.new()
			leg.add(box(Vector3(0.15, 0.75, 0.15)), horse.darkened(0.12), Vector3(0, -0.37, 0))
			leg.add(box(Vector3(0.17, 0.12, 0.17)), Color(0.12, 0.09, 0.07), Vector3(0, -0.72, 0))
			out["leg"] = leg.mesh()
			var arm := Bake.new()
			arm.add(box(Vector3(0.11, 0.45, 0.11)), SKIN, Vector3(0, -0.2, 0))
			arm.add(cyl(0.03, 0.03, 2.4, 5), WOOD, Vector3(0, -0.4, 0.5), Vector3(90, 0, 0))
			arm.add(cyl(0.0, 0.07, 0.3, 5), METAL, Vector3(0, -0.4, 1.8), Vector3(90, 0, 0))
			out["arm_r"] = arm.mesh()
		"catapult":
			body.add(box(Vector3(1.3, 0.22, 2.3)), WOOD, Vector3(0, 0.55, 0))
			body.add(box(Vector3(0.16, 0.16, 2.5)), DARKWOOD, Vector3(-0.62, 0.72, 0))
			body.add(box(Vector3(0.16, 0.16, 2.5)), DARKWOOD, Vector3(0.62, 0.72, 0))
			for x in [-0.55, 0.55]:
				body.add(box(Vector3(0.14, 1.3, 0.14)), DARKWOOD, Vector3(x, 1.2, 0.35), Vector3(-12, 0, 0))
				body.add(box(Vector3(0.12, 1.2, 0.12)), DARKWOOD, Vector3(x, 1.1, 0.75), Vector3(30, 0, 0))
			body.add(box(Vector3(1.3, 0.14, 0.14)), DARKWOOD, Vector3(0, 1.8, 0.45))
			body.add(box(Vector3(0.7, 0.34, 0.5)), team, Vector3(0, 0.84, -0.85))
			for x in [-0.78, 0.78]:
				for z in [-0.75, 0.75]:
					body.add(cyl(0.38, 0.38, 0.12, 12), DARKWOOD, Vector3(x, 0.38, z), Vector3(0, 0, 90))
					body.add(cyl(0.1, 0.1, 0.16, 6), METAL.darkened(0.3), Vector3(x, 0.38, z), Vector3(0, 0, 90))
			out["body"] = body.mesh()
			var arm2 := Bake.new()
			arm2.add(box(Vector3(0.14, 0.14, 2.3)), WOOD, Vector3(0, 0, -0.95))
			arm2.add(cyl(0.3, 0.18, 0.2, 8), DARKWOOD, Vector3(0, 0.08, -2.0))
			arm2.add(sphere(0.2, 6), STONE.darkened(0.2), Vector3(0, 0.22, -2.0))
			out["arm"] = arm2.mesh()
		_:
			# a person: tunic in the team colour
			var tunic := team
			body.add(box(Vector3(0.44, 0.52, 0.27)), tunic, Vector3(0, 0.84, 0))
			body.add(box(Vector3(0.46, 0.14, 0.29)), tunic.darkened(0.2), Vector3(0, 0.56, 0))
			body.add(box(Vector3(0.48, 0.07, 0.31)), LEATHER, Vector3(0, 0.68, 0))
			body.add(sphere(0.175, 8), SKIN, Vector3(0, 1.3, 0))
			match kind:
				"citizen":
					body.add(sphere(0.185, 8), HAIR, Vector3(0, 1.36, -0.03), Vector3.ZERO, 0.0, 0.1, Vector3(1, 0.7, 1))
					body.add(box(Vector3(0.3, 0.32, 0.14)), LEATHER, Vector3(0, 0.9, -0.2))
				"spearman":
					body.add(sphere(0.2, 8), LEATHER, Vector3(0, 1.36, -0.01), Vector3.ZERO, 0.0, 0.1, Vector3(1, 0.72, 1))
					body.add(box(Vector3(0.46, 0.3, 0.29)), LEATHER.lightened(0.1), Vector3(0, 0.95, 0))
				"swordsman":
					body.add(sphere(0.205, 8), METAL, Vector3(0, 1.36, -0.01), Vector3.ZERO, 0.0, 0.1, Vector3(1, 0.78, 1))
					body.add(box(Vector3(0.05, 0.16, 0.3)), team.lightened(0.15), Vector3(0, 1.55, -0.02))
					body.add(box(Vector3(0.48, 0.36, 0.31)), METAL.darkened(0.12), Vector3(0, 0.93, 0))
					body.add(box(Vector3(0.6, 0.1, 0.3)), METAL.darkened(0.05), Vector3(0, 1.1, 0))
				"archer":
					body.add(sphere(0.2, 8), Color(0.24, 0.36, 0.2), Vector3(0, 1.35, -0.03), Vector3.ZERO, 0.0, 0.1, Vector3(1, 0.8, 1.05))
					body.add(cyl(0.08, 0.08, 0.5, 6), LEATHER, Vector3(0.12, 0.98, -0.2), Vector3(0, 0, -20))
					for i in 3:
						body.add(cyl(0.012, 0.012, 0.22, 4), Color(0.9, 0.9, 0.85), Vector3(0.2 + i * 0.03, 1.28, -0.2 + i * 0.02), Vector3(0, 0, -20))
			out["body"] = body.mesh()
			var leg2 := Bake.new()
			leg2.add(box(Vector3(0.17, 0.42, 0.19)), CLOTH, Vector3(0, -0.2, 0))
			leg2.add(box(Vector3(0.18, 0.14, 0.26)), LEATHER.darkened(0.25), Vector3(0, -0.45, 0.03))
			out["leg"] = leg2.mesh()
			var al := Bake.new()
			al.add(box(Vector3(0.12, 0.2, 0.13)), tunic.darkened(0.1), Vector3(0, -0.08, 0))
			al.add(box(Vector3(0.1, 0.3, 0.11)), SKIN, Vector3(0, -0.32, 0))
			var ar := Bake.new()
			ar.add(box(Vector3(0.12, 0.2, 0.13)), tunic.darkened(0.1), Vector3(0, -0.08, 0))
			ar.add(box(Vector3(0.1, 0.3, 0.11)), SKIN, Vector3(0, -0.32, 0))
			match kind:
				"citizen":
					ar.add(cyl(0.025, 0.025, 0.8, 5), WOOD, Vector3(0, -0.45, 0.22), Vector3(90, 0, 0))
					ar.add(box(Vector3(0.05, 0.22, 0.14)), METAL.darkened(0.2), Vector3(0, -0.42, 0.58))
				"spearman":
					ar.add(cyl(0.028, 0.028, 2.3, 5), WOOD, Vector3(0, -0.45, 0.35), Vector3(72, 0, 0))
					ar.add(cyl(0.0, 0.06, 0.3, 5), METAL, Vector3(0, -0.05, 1.58), Vector3(72, 0, 0))
					al.add(cyl(0.32, 0.32, 0.06, 12), dark, Vector3(-0.09, -0.3, 0.05), Vector3(0, 0, 90))
					al.add(cyl(0.09, 0.09, 0.09, 8), METAL, Vector3(-0.1, -0.3, 0.05), Vector3(0, 0, 90))
				"swordsman":
					ar.add(box(Vector3(0.05, 0.08, 0.85)), METAL.lightened(0.1), Vector3(0, -0.45, 0.5))
					ar.add(box(Vector3(0.22, 0.05, 0.06)), DARKWOOD, Vector3(0, -0.45, 0.08))
					al.add(box(Vector3(0.07, 0.72, 0.52)), team, Vector3(-0.09, -0.26, 0.05))
					al.add(box(Vector3(0.08, 0.6, 0.1)), METAL, Vector3(-0.1, -0.26, 0.05))
				"archer":
					al.add(cyl(0.02, 0.02, 1.15, 5), WOOD, Vector3(0, -0.45, 0.14))
					al.add(cyl(0.006, 0.006, 1.1, 3), Color(0.9, 0.9, 0.85), Vector3(0, -0.45, 0.05))
			out["arm_l"] = al.mesh()
			out["arm_r"] = ar.mesh()
	_cache[key] = out
	return out

static func unit_model(kind: String, team: Color) -> Node3D:
	var n := Node3D.new()
	var m := _unit_meshes(kind, team)
	n.add_child(_inst(m["body"], unit_mat(), "body"))
	var legs_a: Array = []
	var legs_b: Array = []
	match kind:
		"cavalry":
			var i := 0
			for pos in [Vector3(-0.22, 0.8, 0.6), Vector3(0.22, 0.8, -0.6), Vector3(0.22, 0.8, 0.6), Vector3(-0.22, 0.8, -0.6)]:
				var l := Node3D.new()
				l.position = pos
				l.add_child(_inst(m["leg"], unit_mat()))
				n.add_child(l)
				if i < 2:
					legs_a.append(l)
				else:
					legs_b.append(l)
				i += 1
			var arm := Node3D.new()
			arm.position = Vector3(0.3, 2.0, 0.0)
			arm.add_child(_inst(m["arm_r"], unit_mat()))
			n.add_child(arm)
			n.set_meta("arm_r", arm)
			n.set_meta("stride", 0.55)
		"catapult":
			var a := Node3D.new()
			a.position = Vector3(0, 1.75, 0.45)
			a.rotation.x = deg_to_rad(-25)
			a.add_child(_inst(m["arm"], unit_mat()))
			n.add_child(a)
			n.set_meta("sling", a)
		_:
			for sx in [-1.0, 1.0]:
				var l2 := Node3D.new()
				l2.position = Vector3(0.11 * sx, 0.52, 0)
				l2.add_child(_inst(m["leg"], unit_mat()))
				n.add_child(l2)
				if sx < 0:
					legs_a.append(l2)
				else:
					legs_b.append(l2)
			var al := Node3D.new()
			al.position = Vector3(-0.29, 1.08, 0)
			al.add_child(_inst(m["arm_l"], unit_mat()))
			n.add_child(al)
			var ar := Node3D.new()
			ar.position = Vector3(0.29, 1.08, 0)
			ar.add_child(_inst(m["arm_r"], unit_mat()))
			n.add_child(ar)
			n.set_meta("arm_l", al)
			n.set_meta("arm_r", ar)
			n.set_meta("stride", 0.7)
			if kind == "archer":
				al.rotation.x = deg_to_rad(-70)
	n.set_meta("legs_a", legs_a)
	n.set_meta("legs_b", legs_b)
	return n

# ---------------------------------------------------------------- buildings
static func _windows(b: Bake, xs: Array, y: float, z: float, c := Color(0.16, 0.13, 0.10)) -> void:
	for x in xs:
		b.add(box(Vector3(0.42, 0.5, 0.06)), c, Vector3(x, y, z), Vector3.ZERO, 0.0, 0.0)
		b.add(box(Vector3(0.52, 0.07, 0.08)), DARKWOOD, Vector3(x, y - 0.29, z))

static func _banner(b: Bake, team: Color, pos: Vector3, h := 2.4) -> void:
	b.add(cyl(0.05, 0.06, h, 5), DARKWOOD, pos + Vector3(0, h * 0.5, 0))
	b.add(box(Vector3(0.9, 0.55, 0.05)), team, pos + Vector3(0.5, h - 0.33, 0), Vector3.ZERO, 0.6, 0.0)
	b.add(sphere(0.09, 6), Color(0.95, 0.8, 0.3), pos + Vector3(0, h + 0.05, 0))

static func building_mesh(kind: String, team: Color) -> ArrayMesh:
	var key := "b:%s:%s" % [kind, team.to_html()]
	if _cache.has(key):
		return _cache[key]
	var b := Bake.new()
	var s: float = float(Defs.BUILDINGS[kind]["size"]) * Defs.CELL
	if kind != "farm":
		b.add(cyl(s * 0.56, s * 0.62, 0.08, 14), DIRT, Vector3(0, 0.04, 0), Vector3.ZERO, 0.0, 0.0)
	match kind:
		"city_center":
			b.add(cyl(3.3, 3.5, 0.5, 18), STONE.darkened(0.12), Vector3(0, 0.25, 0))
			b.add(cyl(2.9, 3.0, 2.3, 18), PLASTER, Vector3(0, 1.6, 0))
			b.add(cyl(3.05, 3.05, 0.22, 18), DARKWOOD, Vector3(0, 2.75, 0))
			b.add(cyl(1.5, 3.7, 1.7, 18), THATCH, Vector3(0, 3.6, 0), Vector3.ZERO, 0.0, 0.3)
			b.add(cyl(1.25, 1.35, 1.0, 14), PLASTER.darkened(0.06), Vector3(0, 4.9, 0))
			b.add(cyl(0.12, 1.75, 1.5, 14), THATCH.darkened(0.08), Vector3(0, 6.1, 0), Vector3.ZERO, 0.0, 0.3)
			for i in 12:
				var a := TAU * i / 12.0
				b.add(box(Vector3(0.22, 2.5, 0.22)), DARKWOOD, Vector3(cos(a) * 2.98, 1.6, sin(a) * 2.98), Vector3(0, -rad_to_deg(a), 0))
				if i % 3 != 0:
					b.add(box(Vector3(0.08, 0.55, 0.42)), Color(0.16, 0.13, 0.10), Vector3(cos(a + 0.26) * 2.97, 1.9, sin(a + 0.26) * 2.97), Vector3(0, -rad_to_deg(a + 0.26), 0), 0.0, 0.0)
			# doorway facing +z, with a porch
			b.add(box(Vector3(1.3, 1.9, 0.5)), Color(0.14, 0.10, 0.07), Vector3(0, 1.3, 2.85), Vector3.ZERO, 0.0, 0.0)
			b.add(prism(Vector3(2.2, 0.8, 1.6)), THATCH.darkened(0.12), Vector3(0, 2.85, 3.3))
			for x in [-0.95, 0.95]:
				b.add(box(Vector3(0.2, 2.2, 0.2)), DARKWOOD, Vector3(x, 1.35, 3.9))
			b.add(box(Vector3(1.9, 0.14, 1.4)), STONE, Vector3(0, 0.3, 3.5))
			# palisade
			for i in 26:
				var a2 := TAU * i / 26.0 + 0.12
				if abs(angle_difference(a2, PI * 0.5)) < 0.5:
					continue
				b.add(cyl(0.0, 0.16, 1.5 + 0.2 * (i % 3), 5), DARKWOOD.lightened(0.05 * (i % 2)), Vector3(cos(a2) * 3.85, 0.75, sin(a2) * 3.85))
			_banner(b, team, Vector3(0, 6.6, 0), 2.2)
			_banner(b, team, Vector3(-1.4, 0.3, 3.9), 3.0)
			b.add(cyl(0.75, 0.85, 1.5, 8), STONE.darkened(0.1), Vector3(2.6, 0.75, -2.5))
			b.add(cyl(0.0, 1.0, 1.0, 8), THATCH, Vector3(2.6, 2.0, -2.5))
			b.add(box(Vector3(0.8, 0.6, 0.8)), WOOD, Vector3(-2.9, 0.38, 2.6), Vector3(0, 20, 0))
			b.add(cyl(0.3, 0.3, 0.7, 8), WOOD.lightened(0.1), Vector3(-2.2, 0.43, 3.2))
		"house":
			b.add(box(Vector3(3.0, 0.3, 3.0)), STONE.darkened(0.1), Vector3(0, 0.15, 0))
			b.add(box(Vector3(2.8, 1.7, 2.8)), PLASTER, Vector3(0, 1.1, 0))
			for x in [-1.4, 1.4]:
				for z in [-1.4, 1.4]:
					b.add(box(Vector3(0.18, 1.8, 0.18)), DARKWOOD, Vector3(x, 1.1, z))
			b.add(box(Vector3(2.9, 0.16, 0.12)), DARKWOOD, Vector3(0, 1.95, 1.4))
			b.add(prism(Vector3(3.4, 1.5, 3.3)), THATCH, Vector3(0, 2.7, 0), Vector3.ZERO, 0.0, 0.3)
			b.add(box(Vector3(0.7, 1.15, 0.08)), DARKWOOD, Vector3(-0.5, 0.85, 1.42))
			_windows(b, [0.7], 1.25, 1.42)
			b.add(box(Vector3(0.45, 1.3, 0.45)), STONE.darkened(0.2), Vector3(0.9, 3.0, -0.6))
			b.add(box(Vector3(3.44, 0.12, 0.3)), team, Vector3(0, 2.02, 1.62))
		"farm":
			b.add(box(Vector3(5.8, 0.1, 5.8)), Color(0.40, 0.29, 0.16), Vector3(0, 0.05, 0), Vector3.ZERO, 0.0, 0.0)
			for i in 7:
				b.add(box(Vector3(5.3, 0.16, 0.28)), Color(0.33, 0.23, 0.12), Vector3(0, 0.14, -2.4 + i * 0.8), Vector3.ZERO, 0.0, 0.0)
				for j in 9:
					b.add(cyl(0.0, 0.16, 0.6, 4), Color(0.86, 0.76, 0.30).darkened(0.08 * ((i + j) % 3)), Vector3(-2.4 + j * 0.6, 0.5, -2.4 + i * 0.8), Vector3.ZERO, 0.8, 0.3)
			for x in [-2.9, 2.9]:
				for z in [-2.9, 0.0, 2.9]:
					b.add(box(Vector3(0.14, 0.8, 0.14)), DARKWOOD, Vector3(x, 0.4, z))
			for z in [-2.9, 2.9]:
				b.add(box(Vector3(5.8, 0.08, 0.08)), WOOD, Vector3(0, 0.6, z))
			b.add(cyl(0.05, 0.05, 1.6, 5), DARKWOOD, Vector3(2.9, 0.8, 2.9))
			b.add(box(Vector3(0.6, 0.4, 0.05)), team, Vector3(3.2, 1.38, 2.9), Vector3.ZERO, 0.6, 0.0)
			b.add(cyl(0.05, 0.05, 1.5, 5), WOOD, Vector3(-1.6, 0.75, 0.4))
			b.add(box(Vector3(0.9, 0.08, 0.08)), WOOD, Vector3(-1.6, 1.15, 0.4))
			b.add(sphere(0.2, 6), THATCH, Vector3(-1.6, 1.55, 0.4))
			b.add(box(Vector3(0.5, 0.5, 0.2)), team.darkened(0.2), Vector3(-1.6, 1.1, 0.4))
		"storehouse":
			b.add(box(Vector3(3.5, 0.3, 2.9)), STONE.darkened(0.15), Vector3(0, 0.15, 0))
			b.add(box(Vector3(3.3, 1.7, 2.7)), WOOD, Vector3(0, 1.1, 0))
			for x in [-1.1, 0.0, 1.1]:
				b.add(box(Vector3(0.1, 1.7, 2.74)), DARKWOOD, Vector3(x * 1.5, 1.1, 0))
			b.add(prism(Vector3(3.8, 1.1, 3.2)), DARKWOOD.lightened(0.08), Vector3(0, 2.5, 0), Vector3.ZERO, 0.0, 0.3)
			b.add(box(Vector3(1.3, 1.3, 0.08)), Color(0.14, 0.10, 0.07), Vector3(0, 0.95, 1.37), Vector3.ZERO, 0.0, 0.0)
			for x in [-1.3, 1.35]:
				b.add(cyl(0.3, 0.3, 0.65, 8), WOOD.lightened(0.12), Vector3(x, 0.4, 1.75))
			b.add(box(Vector3(0.6, 0.5, 0.6)), WOOD.lightened(0.05), Vector3(1.2, 0.33, -1.75), Vector3(0, 15, 0))
			b.add(cyl(0.12, 0.12, 1.4, 6), WOOD, Vector3(-1.3, 0.2, -1.8), Vector3(0, 0, 90))
			b.add(cyl(0.12, 0.12, 1.4, 6), WOOD.darkened(0.1), Vector3(-1.3, 0.4, -1.75), Vector3(0, 0, 90))
			b.add(box(Vector3(3.84, 0.14, 0.3)), team, Vector3(0, 1.98, 1.5))
		"barracks":
			b.add(box(Vector3(5.5, 0.35, 4.5)), STONE.darkened(0.15), Vector3(0, 0.17, 0))
			b.add(box(Vector3(5.2, 2.2, 4.2)), STONE, Vector3(0, 1.4, 0))
			b.add(prism(Vector3(5.7, 1.6, 4.7)), TILE, Vector3(0, 3.3, 0), Vector3.ZERO, 0.0, 0.3)
			b.add(box(Vector3(1.3, 1.7, 0.1)), DARKWOOD, Vector3(0, 1.2, 2.12))
			b.add(box(Vector3(1.5, 0.2, 0.2)), STONE.darkened(0.25), Vector3(0, 2.15, 2.15))
			_windows(b, [-1.7, 1.7], 1.6, 2.12)
			for x in [-2.6, 2.6]:
				b.add(box(Vector3(0.5, 2.9, 0.5)), STONE.darkened(0.1), Vector3(x, 1.45, 2.1))
				b.add(box(Vector3(0.62, 0.2, 0.62)), STONE.darkened(0.2), Vector3(x, 2.95, 2.1))
			_banner(b, team, Vector3(-2.6, 3.0, 2.1), 1.9)
			_banner(b, team, Vector3(2.6, 3.0, 2.1), 1.9)
			# weapon rack and training dummy
			b.add(box(Vector3(1.4, 0.08, 0.08)), WOOD, Vector3(-1.6, 0.9, 2.75))
			for i in 4:
				b.add(cyl(0.02, 0.02, 1.5, 4), WOOD.lightened(0.1), Vector3(-2.15 + i * 0.36, 0.75, 2.72), Vector3(-8, 0, 0))
			b.add(cyl(0.06, 0.06, 1.3, 5), WOOD, Vector3(1.8, 0.65, 2.9))
			b.add(box(Vector3(0.5, 0.5, 0.25)), THATCH, Vector3(1.8, 1.05, 2.9))
			b.add(sphere(0.16, 6), THATCH.lightened(0.1), Vector3(1.8, 1.48, 2.9))
			b.add(box(Vector3(5.74, 0.14, 0.3)), team, Vector3(0, 2.58, 2.25))
		"archery":
			b.add(box(Vector3(5.4, 0.22, 4.6)), WOOD.darkened(0.1), Vector3(0, 0.11, 0))
			b.add(box(Vector3(2.4, 2.0, 4.2)), WOOD, Vector3(1.4, 1.2, 0))
			b.add(prism(Vector3(5.7, 1.3, 4.8)), THATCH, Vector3(0, 3.0, 0), Vector3.ZERO, 0.0, 0.3)
			for x in [-2.5, 0.1]:
				for z in [-2.1, 2.1]:
					b.add(box(Vector3(0.22, 2.3, 0.22)), DARKWOOD, Vector3(x, 1.25, z))
			b.add(box(Vector3(5.4, 0.16, 0.16)), DARKWOOD, Vector3(0, 2.3, 2.1))
			for z in [-1.2, 0.0, 1.2]:
				b.add(cyl(0.48, 0.48, 0.14, 12), Color(0.92, 0.88, 0.74), Vector3(-2.2, 1.1, z), Vector3(0, 0, 90))
				b.add(cyl(0.3, 0.3, 0.16, 12), team, Vector3(-2.2, 1.1, z), Vector3(0, 0, 90), 0.0, 0.0)
				b.add(cyl(0.12, 0.12, 0.18, 8), Color(0.95, 0.85, 0.3), Vector3(-2.2, 1.1, z), Vector3(0, 0, 90), 0.0, 0.0)
				b.add(box(Vector3(0.1, 1.1, 0.1)), DARKWOOD, Vector3(-2.3, 0.55, z))
			b.add(box(Vector3(0.9, 1.5, 0.08)), DARKWOOD, Vector3(1.4, 0.95, 2.12))
			b.add(cyl(0.22, 0.22, 0.7, 8), LEATHER, Vector3(2.4, 0.55, 2.5))
			for i in 4:
				b.add(cyl(0.012, 0.012, 0.5, 4), Color(0.9, 0.9, 0.85), Vector3(2.32 + i * 0.05, 1.0, 2.5 + (i % 2) * 0.06))
			b.add(box(Vector3(5.74, 0.14, 0.3)), team, Vector3(0, 2.38, 2.38))
		"stable":
			b.add(box(Vector3(5.6, 0.25, 4.5)), DIRT.lightened(0.1), Vector3(0, 0.12, 0))
			b.add(box(Vector3(5.4, 1.9, 2.6)), WOOD, Vector3(0, 1.15, -0.8))
			b.add(prism(Vector3(5.9, 1.4, 3.3)), THATCH.darkened(0.12), Vector3(0, 2.8, -0.8), Vector3.ZERO, 0.0, 0.3)
			for x in [-1.8, 0.0, 1.8]:
				b.add(box(Vector3(1.2, 1.4, 0.08)), Color(0.14, 0.10, 0.07), Vector3(x, 0.95, 0.52), Vector3.ZERO, 0.0, 0.0)
				b.add(box(Vector3(1.2, 0.6, 0.1)), DARKWOOD, Vector3(x, 0.55, 0.55))
			# paddock fence
			for x in [-2.7, -0.9, 0.9, 2.7]:
				b.add(box(Vector3(0.14, 1.0, 0.14)), DARKWOOD, Vector3(x, 0.6, 2.15))
			for y in [0.55, 0.95]:
				b.add(box(Vector3(5.5, 0.08, 0.08)), WOOD.lightened(0.08), Vector3(0, y, 2.15))
			for z in [0.9, 1.6]:
				for x in [-2.7, 2.7]:
					b.add(box(Vector3(0.08, 0.08, 1.4)), WOOD.lightened(0.08), Vector3(x, 0.75, 1.45))
			b.add(box(Vector3(0.9, 0.5, 0.7)), THATCH.lightened(0.05), Vector3(-1.9, 0.5, 1.4))
			b.add(box(Vector3(1.0, 0.3, 0.4)), WOOD.darkened(0.15), Vector3(1.6, 0.4, 1.5))
			b.add(box(Vector3(5.94, 0.14, 0.3)), team, Vector3(0, 2.18, 0.85))
		"workshop":
			b.add(box(Vector3(5.4, 0.3, 4.6)), STONE.darkened(0.2), Vector3(0, 0.15, 0))
			b.add(box(Vector3(3.6, 2.4, 4.2)), WOOD, Vector3(-0.8, 1.5, 0))
			b.add(prism(Vector3(4.1, 1.3, 4.7)), STONE.darkened(0.3), Vector3(-0.8, 3.35, 0), Vector3.ZERO, 0.0, 0.3)
			b.add(box(Vector3(1.6, 1.9, 0.08)), Color(0.14, 0.10, 0.07), Vector3(-0.8, 1.25, 2.12), Vector3.ZERO, 0.0, 0.0)
			b.add(box(Vector3(0.55, 2.2, 0.55)), STONE.darkened(0.25), Vector3(-2.0, 3.6, -1.2))
			# crane
			b.add(box(Vector3(0.26, 4.6, 0.26)), DARKWOOD, Vector3(2.1, 2.3, -0.6))
			b.add(box(Vector3(0.2, 0.2, 2.8)), DARKWOOD, Vector3(2.1, 4.5, 0.5))
			b.add(box(Vector3(0.14, 1.8, 0.14)), DARKWOOD, Vector3(2.1, 3.7, 0.1), Vector3(40, 0, 0))
			b.add(cyl(0.015, 0.015, 2.2, 3), Color(0.8, 0.75, 0.6), Vector3(2.1, 3.4, 1.7))
			b.add(box(Vector3(0.5, 0.5, 0.5)), STONE, Vector3(2.1, 2.1, 1.7))
			# timber pile and a wheel
			for i in 3:
				b.add(cyl(0.14, 0.14, 2.0, 6), WOOD.lightened(0.06 * i), Vector3(1.9, 0.44 + (i % 2) * 0.26, -1.9 + i * 0.2), Vector3(0, 0, 90))
			b.add(cyl(0.5, 0.5, 0.12, 12), DARKWOOD, Vector3(1.2, 0.8, 2.1), Vector3(80, 0, 0))
			b.add(box(Vector3(4.14, 0.14, 0.3)), team, Vector3(-0.8, 2.72, 2.3))
		"university":
			b.add(box(Vector3(5.6, 0.3, 5.4)), STONE.darkened(0.08), Vector3(0, 0.15, 0))
			b.add(box(Vector3(5.2, 0.25, 5.0)), STONE, Vector3(0, 0.42, 0))
			b.add(box(Vector3(4.2, 2.7, 3.4)), Color(0.93, 0.91, 0.86), Vector3(0, 1.9, -0.4))
			for x in [-2.1, -1.05, 0.0, 1.05, 2.1]:
				b.add(cyl(0.19, 0.22, 2.7, 8), Color(0.96, 0.95, 0.91), Vector3(x, 1.9, 2.0))
				b.add(box(Vector3(0.5, 0.14, 0.5)), STONE, Vector3(x, 3.3, 2.0))
			b.add(box(Vector3(5.0, 0.35, 4.9)), Color(0.90, 0.88, 0.82), Vector3(0, 3.5, 0.2))
			b.add(prism(Vector3(5.0, 1.1, 0.3)), Color(0.93, 0.91, 0.86), Vector3(0, 4.2, 2.45))
			b.add(prism(Vector3(5.2, 1.15, 5.1)), TILE.lightened(0.05), Vector3(0, 4.22, 0.1), Vector3.ZERO, 0.0, 0.3)
			b.add(box(Vector3(1.1, 1.9, 0.08)), DARKWOOD, Vector3(0, 1.5, 1.32))
			b.add(cyl(0.45, 0.45, 0.1, 12), team, Vector3(0, 4.2, 2.62), Vector3(90, 0, 0), 0.0, 0.0)
			b.add(box(Vector3(2.4, 0.12, 0.4)), STONE.lightened(0.05), Vector3(0, 0.6, 2.75))
		"tower":
			b.add(cyl(1.25, 1.4, 0.5, 10), STONE.darkened(0.2), Vector3(0, 0.25, 0))
			b.add(cyl(0.9, 1.15, 5.2, 10), STONE, Vector3(0, 3.0, 0))
			b.add(cyl(1.3, 1.0, 0.5, 10), STONE.darkened(0.1), Vector3(0, 5.8, 0))
			for i in 8:
				var a3 := TAU * i / 8.0
				b.add(box(Vector3(0.42, 0.5, 0.3)), STONE.darkened(0.05), Vector3(cos(a3) * 1.15, 6.3, sin(a3) * 1.15), Vector3(0, 90 - rad_to_deg(a3), 0))
			b.add(cyl(0.0, 1.05, 1.5, 10), TILE, Vector3(0, 7.2, 0))
			b.add(box(Vector3(0.5, 1.1, 0.1)), DARKWOOD, Vector3(0, 1.0, 1.1))
			for y in [2.6, 4.2]:
				b.add(box(Vector3(0.16, 0.5, 0.1)), Color(0.12, 0.10, 0.08), Vector3(0, y, 0.98), Vector3.ZERO, 0.0, 0.0)
			b.add(box(Vector3(0.75, 0.45, 0.05)), team, Vector3(0.45, 8.3, 0), Vector3.ZERO, 0.6, 0.0)
			b.add(cyl(0.04, 0.04, 1.0, 4), DARKWOOD, Vector3(0, 8.2, 0))
	var mesh := b.mesh()
	_cache[key] = mesh
	return mesh

static func building_model(kind: String, team: Color) -> Node3D:
	var n := Node3D.new()
	n.add_child(_inst(building_mesh(kind, team), world_mat()))
	return n

# ---------------------------------------------------------------- resources
static func _resource_mesh(kind: String, variant: int) -> ArrayMesh:
	var key := "r:%s:%d" % [kind, variant]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var b := Bake.new()
	match kind:
		"tree":
			if variant % 3 == 0:
				# pine: stacked cones
				var h := rng.randf_range(4.6, 6.6)
				var g := Color(0.12, 0.30, 0.15).lightened(rng.randf() * 0.08)
				b.add(cyl(0.14, 0.24, 1.6, 6), DARKWOOD, Vector3(0, 0.8, 0))
				for i in 4:
					var f := float(i) / 4.0
					b.add(cyl(0.0, 1.55 * (1.0 - f * 0.62), h * 0.42, 8), g.lightened(f * 0.12), Vector3(0, 1.3 + h * (0.2 + f * 0.62) * 0.75, 0), Vector3(0, i * 30, 0), 0.5 + f * 0.5, 0.35)
			elif variant % 3 == 1:
				# broadleaf
				var g2 := Color(0.22, 0.44, 0.15).lightened(rng.randf() * 0.1)
				b.add(cyl(0.2, 0.32, 2.4, 6), WOOD.darkened(0.25), Vector3(0, 1.2, 0))
				b.add(cyl(0.08, 0.12, 1.2, 5), WOOD.darkened(0.25), Vector3(0.45, 2.3, 0.1), Vector3(0, 0, -45))
				b.add(sphere(1.55, 8), g2, Vector3(0, 3.4, 0), Vector3.ZERO, 0.6, 0.35, Vector3(1, 0.85, 1))
				b.add(sphere(1.1, 8), g2.lightened(0.08), Vector3(0.85, 3.9, 0.35), Vector3.ZERO, 0.8, 0.3)
				b.add(sphere(1.0, 8), g2.darkened(0.08), Vector3(-0.8, 3.1, -0.45), Vector3.ZERO, 0.7, 0.3)
				b.add(sphere(0.85, 8), g2.lightened(0.14), Vector3(-0.1, 4.4, -0.2), Vector3.ZERO, 0.9, 0.25)
			else:
				# tall slim tree with a pale trunk
				var g3 := Color(0.36, 0.52, 0.18).lightened(rng.randf() * 0.1)
				b.add(cyl(0.11, 0.17, 3.4, 6), Color(0.80, 0.78, 0.70), Vector3(0, 1.7, 0))
				b.add(sphere(1.0, 8), g3, Vector3(0, 3.7, 0), Vector3.ZERO, 0.7, 0.3, Vector3(1, 1.5, 1))
				b.add(sphere(0.7, 8), g3.lightened(0.1), Vector3(0.4, 4.6, 0.2), Vector3.ZERO, 0.9, 0.3, Vector3(1, 1.3, 1))
		"berries":
			b.add(sphere(0.95, 8), Color(0.20, 0.40, 0.15), Vector3(0, 0.55, 0), Vector3.ZERO, 0.3, 0.4, Vector3(1.1, 0.8, 1.1))
			b.add(sphere(0.6, 8), Color(0.24, 0.46, 0.17), Vector3(0.5, 0.75, 0.3), Vector3.ZERO, 0.4, 0.3)
			b.add(sphere(0.55, 8), Color(0.18, 0.37, 0.14), Vector3(-0.5, 0.6, -0.35), Vector3.ZERO, 0.4, 0.3)
			for i in 12:
				var a := TAU * i / 12.0 + rng.randf() * 0.4
				var rr := rng.randf_range(0.55, 0.95)
				b.add(sphere(0.11, 5), Color(0.86, 0.10, 0.22), Vector3(cos(a) * rr, 0.55 + rng.randf() * 0.55, sin(a) * rr), Vector3.ZERO, 0.0, 0.0)
		"cattle":
			var hide: Color = [Color(0.72, 0.42, 0.28), Color(0.86, 0.82, 0.76), Color(0.36, 0.25, 0.18)][variant % 3]
			b.add(box(Vector3(0.72, 0.72, 1.45)), hide, Vector3(0, 0.9, 0))
			b.add(box(Vector3(0.4, 0.46, 0.55)), hide.lightened(0.12), Vector3(0, 1.05, 0.9))
			b.add(box(Vector3(0.3, 0.22, 0.2)), Color(0.9, 0.75, 0.7), Vector3(0, 0.95, 1.2))
			for x in [-0.25, 0.25]:
				b.add(cyl(0.0, 0.05, 0.3, 4), Color(0.93, 0.9, 0.82), Vector3(x, 1.4, 0.85), Vector3(0, 0, -30 if x > 0 else 30))
				for z in [-0.5, 0.5]:
					b.add(box(Vector3(0.14, 0.58, 0.14)), hide.darkened(0.2), Vector3(x * 0.9, 0.29, z))
			b.add(box(Vector3(0.06, 0.5, 0.06)), hide.darkened(0.3), Vector3(0, 0.85, -0.78), Vector3(20, 0, 0))
			b.add(box(Vector3(0.74, 0.35, 0.5)), hide.darkened(0.25), Vector3(0, 1.0, -0.2))
		"stone":
			for i in 6:
				var r := rng.randf_range(0.45, 0.95)
				b.add(sphere(r, 5), Color(0.66, 0.66, 0.64).darkened(rng.randf() * 0.2), Vector3(rng.randf_range(-0.7, 0.7), r * 0.45, rng.randf_range(-0.7, 0.7)),
					Vector3(rng.randf() * 40, rng.randf() * 180, 0), 0.0, 0.35, Vector3(1, rng.randf_range(0.6, 0.9), rng.randf_range(0.8, 1.1)))
		"gold":
			for i in 5:
				var r2 := rng.randf_range(0.4, 0.8)
				b.add(sphere(r2, 5), Color(0.50, 0.46, 0.42).darkened(rng.randf() * 0.15), Vector3(rng.randf_range(-0.65, 0.65), r2 * 0.45, rng.randf_range(-0.65, 0.65)),
					Vector3(rng.randf() * 40, rng.randf() * 180, 0), 0.0, 0.35, Vector3(1, 0.75, 1))
			for i in 8:
				b.add(box(Vector3(0.3, 0.26, 0.3)), Color(1.0, 0.80, 0.16).darkened(rng.randf() * 0.12),
					Vector3(rng.randf_range(-0.75, 0.75), rng.randf_range(0.35, 0.75), rng.randf_range(-0.75, 0.75)), Vector3(rng.randf() * 50, rng.randf() * 90, 25), 0.0, 0.1)
	var mesh := b.mesh()
	_cache[key] = mesh
	return mesh

static func resource_model(kind: String, rng: RandomNumberGenerator) -> Node3D:
	var n := Node3D.new()
	var mi := _inst(_resource_mesh(kind, rng.randi() % 9), world_mat())
	var s := rng.randf_range(0.88, 1.12)
	mi.scale = Vector3(s, rng.randf_range(0.9, 1.15) * s, s) if kind == "tree" else Vector3.ONE
	n.add_child(mi)
	return n

# ---------------------------------------------------------------- ground decoration
## Small things scattered on the ground. kind: tuft | flower | pebble | bush
static func decor_mesh(kind: String) -> ArrayMesh:
	var key := "d:" + kind
	if _cache.has(key):
		return _cache[key]
	var b := Bake.new()
	match kind:
		"tuft":
			for i in 5:
				var a := TAU * i / 5.0
				b.add(cyl(0.0, 0.07, 0.5 + 0.12 * (i % 2), 3), Color(0.30, 0.46, 0.16).lightened(0.06 * (i % 3)), Vector3(cos(a) * 0.14, 0.26, sin(a) * 0.14), Vector3(cos(a) * 16, 0, -sin(a) * 16), 1.0, 0.45)
		"flower":
			for i in 3:
				var a2 := TAU * i / 3.0
				b.add(cyl(0.012, 0.012, 0.36, 3), Color(0.25, 0.45, 0.16), Vector3(cos(a2) * 0.16, 0.18, sin(a2) * 0.16), Vector3.ZERO, 1.0, 0.0)
				b.add(sphere(0.07, 4), Color(1, 1, 1), Vector3(cos(a2) * 0.16, 0.4, sin(a2) * 0.16), Vector3.ZERO, 1.0, 0.0)
		"pebble":
			b.add(sphere(0.22, 5), Color(0.60, 0.59, 0.56), Vector3(0, 0.07, 0), Vector3.ZERO, 0.0, 0.3, Vector3(1.2, 0.55, 0.9))
			b.add(sphere(0.13, 5), Color(0.52, 0.51, 0.49), Vector3(0.25, 0.05, 0.12), Vector3.ZERO, 0.0, 0.3, Vector3(1, 0.6, 1))
		"bush":
			b.add(sphere(0.5, 6), Color(0.21, 0.38, 0.14), Vector3(0, 0.3, 0), Vector3.ZERO, 0.4, 0.4, Vector3(1.2, 0.75, 1.1))
			b.add(sphere(0.34, 6), Color(0.26, 0.44, 0.16), Vector3(0.35, 0.36, 0.15), Vector3.ZERO, 0.5, 0.3)
	var mesh := b.mesh()
	_cache[key] = mesh
	return mesh

static func ring(radius: float, c: Color) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = radius - 0.1
	t.outer_radius = radius
	t.rings = 28
	t.ring_segments = 4
	var mi := MeshInstance3D.new()
	mi.mesh = t
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.position.y = 0.08
	mi.scale.y = 0.3
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
