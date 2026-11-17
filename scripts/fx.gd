class_name Fx
extends RefCounted
## Small particle effects: chimney smoke, fire on damaged buildings, dust and impact puffs.

static var _mat: StandardMaterial3D
static var _quad: QuadMesh

static func _mesh() -> QuadMesh:
	if _quad == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_mat.vertex_color_use_as_albedo = true
		_mat.billboard_keep_scale = true
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 32
		gt.height = 32
		_mat.albedo_texture = gt
		_quad = QuadMesh.new()
		_quad.size = Vector2(1, 1)
		_quad.material = _mat
	return _quad

static func clear() -> void:
	_mat = null
	_quad = null

static func _ramp(a: Color, b: Color, c: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, c)
	g.add_point(0.4, b)
	return g

static func _base(amount: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.mesh = _mesh()
	p.amount = amount
	p.lifetime = life
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var c := Curve.new()
	c.add_point(Vector2(0, 0.45))
	c.add_point(Vector2(1, 1.0))
	p.scale_amount_curve = c
	return p

static func smoke(pos: Vector3, size := 0.9) -> CPUParticles3D:
	var p := _base(12, 3.5)
	p.position = pos
	p.direction = Vector3(0.25, 1, 0.1)
	p.spread = 12.0
	p.gravity = Vector3(0.25, 0.35, 0)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.9
	p.scale_amount_min = size * 0.7
	p.scale_amount_max = size * 1.2
	p.color_ramp = _ramp(Color(0.80, 0.80, 0.80, 0.0), Color(0.74, 0.74, 0.74, 0.62), Color(0.6, 0.6, 0.62, 0.0))
	return p

static func fire(pos: Vector3, size := 1.4) -> CPUParticles3D:
	var p := _base(16, 1.1)
	p.position = pos
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = size * 0.6
	p.direction = Vector3(0, 1, 0)
	p.spread = 20.0
	p.gravity = Vector3(0, 2.5, 0)
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.4
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size * 1.1
	p.color_ramp = _ramp(Color(1.0, 0.85, 0.3, 0.9), Color(1.0, 0.45, 0.1, 0.7), Color(0.2, 0.2, 0.2, 0.0))
	return p

## A one-off burst that frees itself. kind: dust | hit
static func puff(parent: Node, pos: Vector3, kind := "dust", size := 1.0) -> void:
	var p := _base(10 if kind == "dust" else 6, 0.9 if kind == "dust" else 0.35)
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector3(0, 1, 0)
	p.spread = 80.0
	p.gravity = Vector3(0, -1.0, 0)
	p.initial_velocity_min = 1.0 * size
	p.initial_velocity_max = 2.6 * size
	p.scale_amount_min = 0.5 * size
	p.scale_amount_max = 1.1 * size
	if kind == "dust":
		p.color_ramp = _ramp(Color(0.62, 0.55, 0.42, 0.7), Color(0.6, 0.54, 0.44, 0.45), Color(0.6, 0.55, 0.45, 0.0))
	else:
		p.color_ramp = _ramp(Color(1, 0.95, 0.7, 0.9), Color(1, 0.8, 0.4, 0.6), Color(1, 0.7, 0.3, 0.0))
	parent.add_child(p)
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(p.lifetime + 0.3)
	tw.tween_callback(p.queue_free)
