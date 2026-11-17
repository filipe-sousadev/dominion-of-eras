class_name Icons
extends RefCounted
## Every picture in the interface, drawn with simple shapes (no image files).
## paint() draws the icon named `kind` inside rectangle `r` of any CanvasItem.

const C_SKIN := Color(0.90, 0.72, 0.55)
const C_WOOD := Color(0.58, 0.39, 0.20)
const C_DARK := Color(0.16, 0.13, 0.11)
const C_STONE := Color(0.72, 0.72, 0.74)
const C_METAL := Color(0.82, 0.85, 0.90)
const C_GOLD := Color(1.0, 0.80, 0.22)
const C_ROOF := Color(0.72, 0.33, 0.22)
const C_THATCH := Color(0.86, 0.70, 0.38)
const C_WALL := Color(0.90, 0.85, 0.72)
const C_LEAF := Color(0.36, 0.66, 0.26)

static func _p(r: Rect2, x: float, y: float) -> Vector2:
	return r.position + Vector2(x, y) * r.size

static func _rect(ci: CanvasItem, r: Rect2, x: float, y: float, w: float, h: float, c: Color) -> void:
	ci.draw_rect(Rect2(_p(r, x, y), Vector2(w, h) * r.size), c)

static func _poly(ci: CanvasItem, r: Rect2, pts: Array, c: Color) -> void:
	var out := PackedVector2Array()
	for i in range(0, pts.size(), 2):
		out.append(_p(r, pts[i], pts[i + 1]))
	ci.draw_colored_polygon(out, c)

static func _circ(ci: CanvasItem, r: Rect2, x: float, y: float, rad: float, c: Color) -> void:
	ci.draw_circle(_p(r, x, y), rad * r.size.x, c)

static func _line(ci: CanvasItem, r: Rect2, x1: float, y1: float, x2: float, y2: float, c: Color, w := 0.07) -> void:
	ci.draw_line(_p(r, x1, y1), _p(r, x2, y2), c, max(1.0, w * r.size.x), true)

static func _arc(ci: CanvasItem, r: Rect2, x: float, y: float, rad: float, a0: float, a1: float, c: Color, w := 0.07) -> void:
	ci.draw_arc(_p(r, x, y), rad * r.size.x, a0, a1, 16, c, max(1.0, w * r.size.x), true)

static func _person(ci: CanvasItem, r: Rect2, body: Color, x := 0.5) -> void:
	_poly(ci, r, [x - 0.2, 0.92, x - 0.17, 0.5, x - 0.08, 0.42, x + 0.08, 0.42, x + 0.17, 0.5, x + 0.2, 0.92], body)
	_circ(ci, r, x, 0.27, 0.13, C_SKIN)

static func paint(ci: CanvasItem, kind: String, r: Rect2, team := Color(0.25, 0.45, 1.0)) -> void:
	match kind:
		# ------------------------------------------------ resources
		"food":
			_circ(ci, r, 0.42, 0.58, 0.27, Color(0.86, 0.20, 0.18))
			_circ(ci, r, 0.60, 0.60, 0.24, Color(0.92, 0.28, 0.22))
			_circ(ci, r, 0.38, 0.50, 0.07, Color(1, 0.6, 0.55))
			_line(ci, r, 0.5, 0.38, 0.56, 0.2, C_WOOD, 0.06)
			_poly(ci, r, [0.56, 0.22, 0.80, 0.12, 0.72, 0.32], C_LEAF)
		"wood":
			_poly(ci, r, [0.10, 0.62, 0.62, 0.22, 0.82, 0.40, 0.30, 0.82], C_WOOD)
			_circ(ci, r, 0.72, 0.31, 0.14, Color(0.84, 0.66, 0.40))
			_circ(ci, r, 0.72, 0.31, 0.06, C_WOOD)
			_poly(ci, r, [0.22, 0.86, 0.74, 0.50, 0.90, 0.66, 0.40, 0.98], C_WOOD.darkened(0.2))
			_circ(ci, r, 0.82, 0.58, 0.11, Color(0.78, 0.60, 0.36))
		"stone":
			_poly(ci, r, [0.08, 0.85, 0.18, 0.45, 0.42, 0.30, 0.62, 0.50, 0.60, 0.85], C_STONE.darkened(0.15))
			_poly(ci, r, [0.42, 0.88, 0.50, 0.50, 0.72, 0.38, 0.92, 0.58, 0.90, 0.88], C_STONE)
			_poly(ci, r, [0.50, 0.50, 0.72, 0.38, 0.74, 0.56, 0.58, 0.62], Color(0.9, 0.9, 0.92))
		"gold":
			_poly(ci, r, [0.10, 0.86, 0.22, 0.56, 0.58, 0.56, 0.70, 0.86], C_GOLD.darkened(0.15))
			_poly(ci, r, [0.36, 0.60, 0.46, 0.32, 0.80, 0.32, 0.92, 0.60], C_GOLD)
			_poly(ci, r, [0.46, 0.32, 0.80, 0.32, 0.76, 0.40, 0.50, 0.40], Color(1, 0.95, 0.6))
			_poly(ci, r, [0.22, 0.56, 0.58, 0.56, 0.54, 0.64, 0.26, 0.64], Color(1, 0.9, 0.5))
		"tech":
			_poly(ci, r, [0.08, 0.28, 0.48, 0.36, 0.48, 0.88, 0.08, 0.78], Color(0.86, 0.90, 1.0))
			_poly(ci, r, [0.92, 0.28, 0.52, 0.36, 0.52, 0.88, 0.92, 0.78], Color(0.70, 0.80, 1.0))
			for y in [0.46, 0.58, 0.70]:
				_line(ci, r, 0.16, y - 0.04, 0.40, y, Color(0.3, 0.4, 0.7), 0.035)
				_line(ci, r, 0.84, y - 0.04, 0.60, y, Color(0.3, 0.4, 0.7), 0.035)
			_poly(ci, r, [0.50, 0.04, 0.56, 0.18, 0.70, 0.18, 0.59, 0.27, 0.63, 0.40, 0.50, 0.32, 0.37, 0.40, 0.41, 0.27, 0.30, 0.18, 0.44, 0.18], C_GOLD)
		"pop":
			_person(ci, r, Color(0.80, 0.84, 0.92), 0.36)
			_person(ci, r, Color(0.95, 0.96, 1.0), 0.64)
		"territory":
			_line(ci, r, 0.26, 0.10, 0.26, 0.94, C_WOOD.lightened(0.2), 0.08)
			_poly(ci, r, [0.30, 0.12, 0.88, 0.24, 0.62, 0.38, 0.88, 0.54, 0.30, 0.56], team.lightened(0.15))
		# ------------------------------------------------ units
		"citizen":
			_person(ci, r, team)
			_line(ci, r, 0.70, 0.86, 0.80, 0.36, C_WOOD, 0.06)
			_rect(ci, r, 0.68, 0.28, 0.24, 0.13, C_METAL)
		"spearman":
			_person(ci, r, team, 0.44)
			_line(ci, r, 0.76, 0.94, 0.76, 0.12, C_WOOD, 0.05)
			_poly(ci, r, [0.76, 0.02, 0.83, 0.20, 0.69, 0.20], C_METAL)
			_circ(ci, r, 0.32, 0.66, 0.17, team.darkened(0.3))
			_circ(ci, r, 0.32, 0.66, 0.06, C_METAL)
		"swordsman":
			_person(ci, r, team, 0.42)
			_poly(ci, r, [0.28, 0.20, 0.42, 0.10, 0.56, 0.20, 0.56, 0.26, 0.28, 0.26], C_METAL)
			_line(ci, r, 0.74, 0.74, 0.86, 0.14, C_METAL, 0.08)
			_line(ci, r, 0.64, 0.66, 0.84, 0.70, C_WOOD, 0.06)
		"archer":
			_person(ci, r, team, 0.38)
			_arc(ci, r, 0.60, 0.52, 0.34, -1.2, 1.2, C_WOOD, 0.07)
			_line(ci, r, 0.72, 0.20, 0.72, 0.84, Color(0.9, 0.9, 0.85), 0.03)
			_line(ci, r, 0.48, 0.52, 0.98, 0.52, C_WOOD.lightened(0.3), 0.04)
		"cavalry":
			_poly(ci, r, [0.12, 0.62, 0.26, 0.42, 0.62, 0.40, 0.70, 0.16, 0.90, 0.10, 0.96, 0.34, 0.82, 0.38, 0.80, 0.62, 0.72, 0.94, 0.62, 0.94, 0.62, 0.68, 0.34, 0.68, 0.30, 0.94, 0.20, 0.94, 0.20, 0.68], Color(0.55, 0.36, 0.20))
			_poly(ci, r, [0.34, 0.44, 0.36, 0.22, 0.52, 0.18, 0.56, 0.44], team)
			_circ(ci, r, 0.45, 0.12, 0.09, C_SKIN)
		"catapult":
			_line(ci, r, 0.10, 0.74, 0.90, 0.74, C_WOOD, 0.10)
			_circ(ci, r, 0.26, 0.82, 0.13, C_WOOD.darkened(0.3))
			_circ(ci, r, 0.74, 0.82, 0.13, C_WOOD.darkened(0.3))
			_line(ci, r, 0.56, 0.72, 0.56, 0.36, C_WOOD.darkened(0.15), 0.08)
			_line(ci, r, 0.78, 0.66, 0.20, 0.22, C_WOOD.lightened(0.15), 0.07)
			_circ(ci, r, 0.20, 0.20, 0.11, C_STONE)
		# ------------------------------------------------ buildings
		"city_center":
			_rect(ci, r, 0.14, 0.56, 0.72, 0.36, C_WALL)
			_poly(ci, r, [0.06, 0.58, 0.50, 0.24, 0.94, 0.58], C_THATCH)
			_rect(ci, r, 0.42, 0.66, 0.16, 0.26, C_DARK)
			_line(ci, r, 0.50, 0.26, 0.50, 0.02, C_WOOD, 0.05)
			_poly(ci, r, [0.52, 0.02, 0.84, 0.09, 0.52, 0.17], team.lightened(0.1))
		"house":
			_rect(ci, r, 0.20, 0.50, 0.60, 0.40, C_WALL)
			_poly(ci, r, [0.10, 0.52, 0.50, 0.14, 0.90, 0.52], C_THATCH)
			_rect(ci, r, 0.30, 0.62, 0.15, 0.28, C_WOOD.darkened(0.2))
			_rect(ci, r, 0.56, 0.60, 0.14, 0.14, C_DARK)
		"farm":
			_rect(ci, r, 0.08, 0.30, 0.84, 0.60, Color(0.46, 0.33, 0.18))
			for i in 4:
				_rect(ci, r, 0.12, 0.36 + i * 0.135, 0.76, 0.07, Color(0.92, 0.80, 0.30))
			_poly(ci, r, [0.70, 0.30, 0.78, 0.06, 0.86, 0.30], Color(0.95, 0.85, 0.35))
			_line(ci, r, 0.78, 0.30, 0.78, 0.12, Color(0.75, 0.62, 0.2), 0.03)
		"storehouse":
			_rect(ci, r, 0.14, 0.34, 0.72, 0.56, C_WOOD)
			_rect(ci, r, 0.14, 0.34, 0.72, 0.08, C_WOOD.darkened(0.3))
			_rect(ci, r, 0.14, 0.82, 0.72, 0.08, C_WOOD.darkened(0.3))
			_line(ci, r, 0.16, 0.42, 0.84, 0.82, C_WOOD.darkened(0.3), 0.07)
			_line(ci, r, 0.84, 0.42, 0.16, 0.82, C_WOOD.darkened(0.3), 0.07)
		"barracks":
			_poly(ci, r, [0.50, 0.08, 0.86, 0.20, 0.82, 0.62, 0.50, 0.92, 0.18, 0.62, 0.14, 0.20], team)
			_poly(ci, r, [0.50, 0.08, 0.86, 0.20, 0.82, 0.62, 0.50, 0.92], team.darkened(0.25))
			_line(ci, r, 0.50, 0.24, 0.50, 0.74, C_METAL, 0.09)
			_line(ci, r, 0.36, 0.36, 0.64, 0.36, C_GOLD, 0.07)
		"archery":
			_circ(ci, r, 0.5, 0.5, 0.42, Color(0.95, 0.93, 0.85))
			_circ(ci, r, 0.5, 0.5, 0.30, team)
			_circ(ci, r, 0.5, 0.5, 0.18, Color(0.95, 0.93, 0.85))
			_circ(ci, r, 0.5, 0.5, 0.08, Color(0.9, 0.2, 0.15))
			_line(ci, r, 0.52, 0.48, 0.94, 0.08, C_WOOD, 0.05)
		"stable":
			_arc(ci, r, 0.5, 0.46, 0.30, PI * 0.82, PI * 2.18, C_METAL, 0.16)
			_circ(ci, r, 0.25, 0.70, 0.07, C_METAL)
			_circ(ci, r, 0.75, 0.70, 0.07, C_METAL)
			for a in [3.4, 4.2, 5.2, 6.0]:
				_circ(ci, r, 0.5 + cos(a) * 0.30, 0.46 + sin(a) * 0.30, 0.035, C_DARK)
		"workshop":
			for i in 8:
				var a := TAU * i / 8.0
				_line(ci, r, 0.5 + cos(a) * 0.24, 0.5 + sin(a) * 0.24, 0.5 + cos(a) * 0.44, 0.5 + sin(a) * 0.44, C_STONE, 0.14)
			_circ(ci, r, 0.5, 0.5, 0.32, C_STONE)
			_circ(ci, r, 0.5, 0.5, 0.13, C_DARK)
		"university":
			_poly(ci, r, [0.06, 0.36, 0.50, 0.10, 0.94, 0.36], C_ROOF)
			_rect(ci, r, 0.10, 0.36, 0.80, 0.08, Color(0.95, 0.94, 0.90))
			for x in [0.16, 0.36, 0.56, 0.76]:
				_rect(ci, r, x, 0.44, 0.09, 0.38, Color(0.95, 0.94, 0.90))
			_rect(ci, r, 0.06, 0.82, 0.88, 0.09, C_STONE)
		"tower":
			_poly(ci, r, [0.30, 0.94, 0.34, 0.34, 0.66, 0.34, 0.70, 0.94], C_STONE)
			_rect(ci, r, 0.24, 0.22, 0.52, 0.14, C_STONE.darkened(0.12))
			for x in [0.24, 0.44, 0.64]:
				_rect(ci, r, x, 0.10, 0.12, 0.13, C_STONE.darkened(0.12))
			_rect(ci, r, 0.45, 0.50, 0.10, 0.18, C_DARK)
			_poly(ci, r, [0.50, 0.10, 0.50, -0.02, 0.76, 0.04], team.lightened(0.1))
		# ------------------------------------------------ actions
		"stop":
			_circ(ci, r, 0.5, 0.5, 0.40, Color(0.85, 0.22, 0.18))
			_rect(ci, r, 0.30, 0.30, 0.40, 0.40, Color(1, 0.95, 0.9))
		"delete":
			_circ(ci, r, 0.5, 0.42, 0.30, Color(0.92, 0.90, 0.84))
			_rect(ci, r, 0.36, 0.60, 0.28, 0.22, Color(0.92, 0.90, 0.84))
			_circ(ci, r, 0.39, 0.42, 0.08, C_DARK)
			_circ(ci, r, 0.61, 0.42, 0.08, C_DARK)
			for x in [0.44, 0.56]:
				_line(ci, r, x, 0.66, x, 0.82, C_DARK, 0.03)
		"cancel":
			_line(ci, r, 0.22, 0.22, 0.78, 0.78, Color(0.95, 0.3, 0.25), 0.14)
			_line(ci, r, 0.78, 0.22, 0.22, 0.78, Color(0.95, 0.3, 0.25), 0.14)
		"epoch":
			_poly(ci, r, [0.50, 0.06, 0.88, 0.48, 0.64, 0.48, 0.64, 0.92, 0.36, 0.92, 0.36, 0.48, 0.12, 0.48], C_GOLD)
			_poly(ci, r, [0.50, 0.06, 0.88, 0.48, 0.64, 0.48, 0.64, 0.92, 0.50, 0.92], C_GOLD.darkened(0.18))
		"attack":
			_line(ci, r, 0.18, 0.84, 0.80, 0.14, C_METAL, 0.09)
			_line(ci, r, 0.82, 0.84, 0.20, 0.14, C_METAL, 0.09)
			_line(ci, r, 0.12, 0.66, 0.34, 0.90, C_GOLD, 0.07)
			_line(ci, r, 0.88, 0.66, 0.66, 0.90, C_GOLD, 0.07)
		"army":
			_poly(ci, r, [0.50, 0.08, 0.86, 0.20, 0.82, 0.62, 0.50, 0.92, 0.18, 0.62, 0.14, 0.20], C_METAL)
			_poly(ci, r, [0.50, 0.18, 0.76, 0.27, 0.73, 0.58, 0.50, 0.80, 0.27, 0.58, 0.24, 0.27], team)
		"idle":
			_person(ci, r, Color(0.80, 0.82, 0.88), 0.40)
			_line(ci, r, 0.62, 0.12, 0.84, 0.12, Color(1, 1, 1), 0.05)
			_line(ci, r, 0.84, 0.12, 0.62, 0.36, Color(1, 1, 1), 0.05)
			_line(ci, r, 0.62, 0.36, 0.84, 0.36, Color(1, 1, 1), 0.05)
		"box":
			for i in 4:
				var f := i / 4.0 + 0.04
				_line(ci, r, 0.12 + f * 0.76, 0.16, 0.12 + f * 0.76 + 0.10, 0.16, Color(0.5, 1, 0.6), 0.05)
				_line(ci, r, 0.12 + f * 0.76, 0.84, 0.12 + f * 0.76 + 0.10, 0.84, Color(0.5, 1, 0.6), 0.05)
				_line(ci, r, 0.12, 0.16 + f * 0.68, 0.12, 0.16 + f * 0.68 + 0.10, Color(0.5, 1, 0.6), 0.05)
				_line(ci, r, 0.88, 0.16 + f * 0.68, 0.88, 0.16 + f * 0.68 + 0.10, Color(0.5, 1, 0.6), 0.05)
		"crown":
			_poly(ci, r, [0.10, 0.80, 0.10, 0.30, 0.30, 0.52, 0.50, 0.18, 0.70, 0.52, 0.90, 0.30, 0.90, 0.80], team)
			_rect(ci, r, 0.10, 0.72, 0.80, 0.12, team.darkened(0.25))
		# ------------------------------------------------ nature
		"tree":
			_rect(ci, r, 0.44, 0.60, 0.12, 0.34, C_WOOD)
			_circ(ci, r, 0.5, 0.40, 0.30, C_LEAF.darkened(0.15))
			_circ(ci, r, 0.60, 0.30, 0.18, C_LEAF)
		"berries":
			_circ(ci, r, 0.5, 0.56, 0.38, C_LEAF.darkened(0.2))
			for q in [[0.36, 0.44], [0.60, 0.40], [0.50, 0.66], [0.70, 0.64], [0.30, 0.68]]:
				_circ(ci, r, q[0], q[1], 0.07, Color(0.9, 0.15, 0.25))
		"cattle":
			_poly(ci, r, [0.14, 0.36, 0.70, 0.36, 0.74, 0.22, 0.92, 0.26, 0.92, 0.48, 0.78, 0.52, 0.76, 0.90, 0.66, 0.90, 0.64, 0.64, 0.30, 0.64, 0.28, 0.90, 0.18, 0.90], Color(0.74, 0.46, 0.30))
			_circ(ci, r, 0.44, 0.48, 0.09, Color(0.93, 0.88, 0.80))
		_:
			_circ(ci, r, 0.5, 0.5, 0.3, Color(0.6, 0.6, 0.6))


## A control that shows one icon.
class View extends Control:
	var kind := ""
	var team := Color(0.25, 0.45, 1.0)
	var dim := false

	func _init(k := "", size_px := 32.0) -> void:
		kind = k
		custom_minimum_size = Vector2(size_px, size_px)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_kind(k: String) -> void:
		if k != kind:
			kind = k
			queue_redraw()

	func _draw() -> void:
		if kind == "" or size.x < 2.0 or size.y < 2.0:
			return
		Icons.paint(self, kind, Rect2(Vector2.ZERO, size), team)
