class_name Controls
extends Node
## Mouse + keyboard (Linux) and touch (Android) controls: select, command, place buildings, move the camera.

var game
var hud
var placing := ""
var ghost: MeshInstance3D
var ghost_mat: StandardMaterial3D
var ghost_tl := Vector2i.ZERO
var dragging := false
var drag_start := Vector2.ZERO
var drag_now := Vector2.ZERO
var box_active := false
var box_mode := false           # touch: one-finger drag draws a selection box
var touches := {}
var touch_start := Vector2.ZERO
var touch_moved := false
var touch_t0 := 0.0
var touch_ignore := false
var pinch_d := 0.0
var pinch_mid := Vector2.ZERO
var last_click_t := -10.0
var last_click_ent = null
var groups := {}
var rotating := false
var markers: Array = []
var attack_mode := false       # next click on the ground is an attack-move order

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

# ---------------------------------------------------------------- input
func _unhandled_input(event: InputEvent) -> void:
	if game == null or game.over:
		return
	if event is InputEventScreenTouch:
		_touch(event)
		return
	if event is InputEventScreenDrag:
		_touch_drag(event)
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton:
		_mouse_button(event)
	elif event is InputEventMouseMotion:
		_mouse_motion(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event)

func _mouse_button(e: InputEventMouseButton) -> void:
	match e.button_index:
		MOUSE_BUTTON_LEFT:
			if e.pressed:
				if placing != "":
					_try_place(e.position, e.shift_pressed)
					return
				if attack_mode:
					attack_mode = false
					command_at(e.position, true)
					return
				dragging = true
				box_active = false
				drag_start = e.position
				drag_now = e.position
			elif dragging:
				dragging = false
				if box_active:
					box_active = false
					_box_select(Rect2(drag_start, e.position - drag_start).abs(), e.shift_pressed)
				else:
					_click_select(e.position, e.shift_pressed or e.ctrl_pressed)
				hud.queue_overlay()
		MOUSE_BUTTON_RIGHT:
			if e.pressed:
				if placing != "":
					cancel_placement()
				elif attack_mode:
					attack_mode = false
					hud.message("Ordem de ataque cancelada", Color(0.9, 0.9, 0.9))
				else:
					command_at(e.position, e.ctrl_pressed)
		MOUSE_BUTTON_MIDDLE:
			rotating = e.pressed
		MOUSE_BUTTON_WHEEL_UP:
			if e.pressed:
				game.cam.zoom_by(0.9)
		MOUSE_BUTTON_WHEEL_DOWN:
			if e.pressed:
				game.cam.zoom_by(1.1)

func _mouse_motion(e: InputEventMouseMotion) -> void:
	if rotating:
		game.cam.rotate_by(-e.relative.x * 0.008)
	if dragging:
		drag_now = e.position
		if drag_start.distance_to(drag_now) > 8.0:
			box_active = true
		hud.queue_overlay()
	if placing != "":
		_move_ghost(e.position)

func _key(e: InputEventKey) -> void:
	var k := e.keycode
	if k >= KEY_0 and k <= KEY_9:
		var n := k - KEY_0
		if e.ctrl_pressed:
			groups[n] = game.selected.filter(func(x): return x.owner_id == 0 and x.is_unit())
			hud.message("Grupo %d definido" % n, Color(0.8, 0.9, 1))
		else:
			var g: Array = groups.get(n, []).filter(func(x): return is_instance_valid(x) and not x.dead)
			if not g.is_empty():
				if _now() - last_click_t < 0.4 and game.selected == g:
					game.cam.look_at_point(g[0].position)
				select(g)
				last_click_t = _now()
		return
	match k:
		KEY_ESCAPE:
			if placing != "":
				cancel_placement()
			elif attack_mode:
				attack_mode = false
			elif not game.selected.is_empty():
				select([])
			else:
				hud.toggle_menu()
		KEY_F10:
			hud.toggle_menu()
		KEY_H:
			select_home()
		KEY_G:
			begin_attack_move()
		KEY_M:
			select_army()
		KEY_PERIOD:
			select_idle_citizen()
		KEY_DELETE:
			for x in game.selected.duplicate():
				if x.owner_id == 0 and not x.is_resource():
					x.die(null)
		KEY_SPACE:
			if game.last_alert != Vector3.ZERO:
				game.cam.look_at_point(game.last_alert)
		KEY_S:
			if e.ctrl_pressed or e.alt_pressed:
				return
		KEY_PAUSE, KEY_P:
			hud.toggle_pause()

func _process(delta: float) -> void:
	if game == null:
		return
	var cam: CameraRig = game.cam
	var speed: float = cam.dist * 0.9 * delta
	var mv := Vector2.ZERO
	if not hud.menu_open():
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			mv.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			mv.x += 1
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			mv.y += 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			mv.y -= 1
		if Input.is_key_pressed(KEY_Q):
			cam.rotate_by(delta * 1.5)
		if Input.is_key_pressed(KEY_E):
			cam.rotate_by(-delta * 1.5)
		# edge scrolling (desktop, focused window only)
		if not DisplayServer.is_touchscreen_available() and get_window().has_focus():
			var mp := get_viewport().get_mouse_position()
			var vs := get_viewport().get_visible_rect().size
			if Rect2(Vector2.ZERO, vs).has_point(mp):
				if mp.x < 4:
					mv.x -= 1
				elif mp.x > vs.x - 5:
					mv.x += 1
				if mp.y < 4:
					mv.y += 1
				elif mp.y > vs.y - 5:
					mv.y -= 1
	if mv != Vector2.ZERO:
		cam.move_by(mv.normalized() * speed)
	# fade command markers
	var keep: Array = []
	for m in markers:
		m["t"] -= delta
		if m["t"] <= 0.0:
			m["node"].queue_free()
		else:
			m["node"].scale = Vector3.ONE * (0.6 + m["t"])
			keep.append(m)
	markers = keep

# ---------------------------------------------------------------- touch
func _touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		touches[e.index] = e.position
		if touches.size() == 1:
			touch_start = e.position
			touch_moved = false
			touch_t0 = _now()
			touch_ignore = hud.blocks(e.position)
			drag_start = e.position
			drag_now = e.position
		elif touches.size() == 2:
			var ps: Array = touches.values()
			pinch_d = ps[0].distance_to(ps[1])
			pinch_mid = (ps[0] + ps[1]) * 0.5
			touch_moved = true
			box_active = false
	else:
		var was_single := touches.size() == 1
		touches.erase(e.index)
		if was_single and not touch_ignore:
			if box_active:
				box_active = false
				_box_select(Rect2(drag_start, e.position - drag_start).abs(), false)
				hud.queue_overlay()
			elif not touch_moved:
				if _now() - touch_t0 > 0.6:
					if placing != "":
						cancel_placement()
					else:
						select([])
				else:
					_tap(e.position)
		if touches.is_empty():
			touch_ignore = false

func _touch_drag(e: InputEventScreenDrag) -> void:
	if not touches.has(e.index):
		return
	var prev: Vector2 = touches[e.index]
	touches[e.index] = e.position
	if touch_ignore:
		return
	if touches.size() == 1:
		if e.position.distance_to(touch_start) > 14.0:
			touch_moved = true
		if not touch_moved:
			return
		if box_mode and placing == "":
			box_active = true
			drag_now = e.position
			hud.queue_overlay()
		else:
			game.cam.drag_pan(prev, e.position)
			if placing != "":
				_move_ghost(get_viewport().get_visible_rect().size * Vector2(0.5, 0.4))
	elif touches.size() == 2:
		var ps: Array = touches.values()
		var d: float = ps[0].distance_to(ps[1])
		var mid: Vector2 = (ps[0] + ps[1]) * 0.5
		if d > 10.0 and pinch_d > 10.0:
			game.cam.zoom_by(pinch_d / d)
		game.cam.drag_pan(pinch_mid, mid)
		pinch_d = d
		pinch_mid = mid

func _tap(pos: Vector2) -> void:
	if placing != "":
		_move_ghost(pos)
		_try_place(pos, false)
		return
	if attack_mode:
		attack_mode = false
		command_at(pos, true)
		return
	var ent = pick(pos)
	var mine: Array = game.selected.filter(func(x): return x.owner_id == 0 and not x.is_resource())
	if ent != null and ent.owner_id == 0:
		var own_targetable: bool = ent.is_building() and not mine.is_empty() and mine.any(func(x): return x.is_unit() and x.is_citizen()) \
			and (not ent.built or ent.hp < ent.max_hp or ent.kind in ["university", "farm"] or ent.def.get("dropsite", false)) \
			and not game.selected.has(ent)
		if own_targetable:
			command_at(pos)
		else:
			_click_select(pos, false)
		return
	if not mine.is_empty():
		command_at(pos)
	else:
		_click_select(pos, false)

# ---------------------------------------------------------------- selecting
func pick(screen: Vector2):
	var cam: Camera3D = game.cam.cam
	var best = null
	var best_score := 1e9
	for list in [game.units, game.buildings, game.resources]:
		for e in list:
			if e.dead or not e.visible:
				continue
			var h := 0.8 if e.is_unit() else (1.5 if e.is_building() else 0.8)
			var wp: Vector3 = e.position + Vector3(0, h, 0)
			if cam.is_position_behind(wp):
				continue
			var sp := cam.unproject_position(wp)
			var right: Vector3 = cam.global_transform.basis.x
			var rp := cam.unproject_position(wp + right * e.radius)
			var r_px: float = max(sp.distance_to(rp) * 1.15, 14.0 if e.is_unit() else 10.0)
			var d := sp.distance_to(screen)
			if d <= r_px:
				var score := d / r_px + (0.0 if e.is_unit() else 0.6)
				if score < best_score:
					best_score = score
					best = e
	return best

func select(list: Array) -> void:
	for x in game.selected:
		if is_instance_valid(x):
			x.set_selected(false)
	game.selected = list.filter(func(x): return is_instance_valid(x) and not x.dead)
	for x in game.selected:
		x.set_selected(true)
	hud.refresh_selection()

func _click_select(pos: Vector2, add: bool) -> void:
	var ent = pick(pos)
	if ent == null:
		if not add:
			select([])
		return
	# double click/tap: all of that kind on screen
	if ent == last_click_ent and _now() - last_click_t < 0.35 and ent.owner_id == 0 and ent.is_unit():
		var vs := get_viewport().get_visible_rect()
		var same: Array = []
		for u in game.units:
			if u.owner_id == 0 and u.kind == ent.kind and vs.has_point(game.cam.cam.unproject_position(u.position)):
				same.append(u)
		select(same)
		return
	last_click_ent = ent
	last_click_t = _now()
	if add and ent.owner_id == 0 and ent.is_unit():
		var l: Array = game.selected.duplicate()
		if l.has(ent):
			l.erase(ent)
		else:
			l.append(ent)
		select(l.filter(func(x): return x.owner_id == 0 and x.is_unit()))
	else:
		select([ent])

func _box_select(r: Rect2, add: bool) -> void:
	var cam: Camera3D = game.cam.cam
	var out: Array = game.selected.duplicate() if add else []
	for u in game.units:
		if u.owner_id != 0 or u.dead:
			continue
		var wp: Vector3 = u.position + Vector3(0, 0.7, 0)
		if cam.is_position_behind(wp):
			continue
		if r.has_point(cam.unproject_position(wp)) and not out.has(u):
			out.append(u)
	select(out.filter(func(x): return x.owner_id == 0 and x.is_unit()))

func select_home() -> void:
	for b in game.buildings:
		if b.owner_id == 0 and b.kind == "city_center":
			select([b])
			game.cam.look_at_point(b.position)
			return

func select_idle_citizen() -> void:
	var idle: Array = game.units.filter(func(u): return u.owner_id == 0 and u.is_citizen() and u.state == "idle")
	if idle.is_empty():
		hud.message("Nenhum cidadão ocioso", Color(0.9, 0.9, 0.9))
		return
	var i := 0
	if game.selected.size() == 1 and idle.has(game.selected[0]):
		i = (idle.find(game.selected[0]) + 1) % idle.size()
	select([idle[i]])
	game.cam.look_at_point(idle[i].position)

# ---------------------------------------------------------------- commands
func command_at(screen: Vector2, attack_move := false) -> void:
	var ent = pick(screen)
	var g = game.cam.ground_at(screen)
	if g == null:
		return
	issue_command(ent, g, attack_move)

## The next click sends the selected soldiers to a point, fighting on the way.
func begin_attack_move() -> void:
	if not game.selected.any(func(x): return x.owner_id == 0 and x.is_unit() and x.is_military()):
		hud.message("Selecione soldados primeiro", Color(0.9, 0.9, 0.9))
		return
	cancel_placement()
	attack_mode = true
	hud.message("Atacar ao mover: clique no destino (clique direito cancela)", Color(1, 0.8, 0.6))

func select_army() -> void:
	var army: Array = game.units.filter(func(u): return u.owner_id == 0 and not u.dead and u.is_military())
	if army.is_empty():
		hud.message("Você ainda não tem soldados", Color(0.9, 0.9, 0.9))
		return
	select(army)

## Gives the selection an order: the target entity (or null) and a ground point.
func issue_command(ent, ground: Vector3, attack_move := false) -> void:
	var us: Array = game.selected.filter(func(x): return x.owner_id == 0 and x.is_unit() and not x.dead)
	var bs: Array = game.selected.filter(func(x): return x.owner_id == 0 and x.is_building() and not x.dead)
	if us.is_empty():
		for b in bs:
			b.rally = ent.position if ent != null and ent.is_resource() else ground
			b.has_rally = true
		if not bs.is_empty():
			_marker(ground, Color(0.3, 0.6, 1.0))
		return
	if ent != null and ent.owner_id >= 0 and ent.owner_id != 0:
		for u in us:
			u.order_attack(ent)
		_marker(ent.position, Color(1, 0.2, 0.2))
		return
	if ent != null and ent.is_resource():
		for u in us:
			if u.is_citizen():
				u.order_gather(ent)
			else:
				u.order_move(ent.position)
		_marker(ent.position, Color(1, 0.9, 0.3))
		return
	if ent != null and ent.owner_id == 0 and ent.is_building():
		var b = ent
		for u in us:
			if not u.is_citizen():
				u.order_move(b.position + Vector3(randf_range(-4, 4), 0, b.radius + 2.0))
			elif not b.built or b.hp < b.max_hp:
				u.order_build(b)
			elif b.kind == "university" and b.workers.size() < Defs.UNIVERSITY_WORKERS:
				b.workers.append(u)
				u.order_work(b)
			elif b.kind == "farm" and b.workers.size() < 3:
				b.workers.append(u)
				u.order_gather(b)
			elif b.def.get("dropsite", false) and u.carry_amt > 0.0:
				u.order_return()
			else:
				u.order_move(b.position + Vector3(randf_range(-3, 3), 0, b.radius + 2.0))
		_marker(b.position, Color(0.3, 1, 0.4))
		return
	# move in a loose formation
	var n := us.size()
	var cols := int(ceil(sqrt(n)))
	var i := 0
	for u in us:
		var off := Vector3((i % cols - (cols - 1) * 0.5) * 1.7, 0, (i / cols - (cols - 1) * 0.5) * 1.7)
		if attack_move:
			u.order_attack_move(ground + (off if n > 1 else Vector3.ZERO))
		else:
			u.order_move(ground + (off if n > 1 else Vector3.ZERO))
		i += 1
	_marker(ground, Color(1, 0.35, 0.25) if attack_move else Color(0.3, 1, 0.4))

func _marker(p: Vector3, c: Color) -> void:
	var m := Meshes.ring(0.9, c)
	m.position = Vector3(p.x, 0.1, p.z)
	game.add_child(m)
	markers.append({"node": m, "t": 0.6})

# ---------------------------------------------------------------- placing buildings
func start_placement(kind: String) -> void:
	var p = game.players[0]
	var d: Dictionary = Defs.BUILDINGS[kind]
	if p.epoch < int(d["epoch"]):
		hud.message("%s requer a %s" % [d["name"], Defs.EPOCHS[int(d["epoch"]) - 1]["name"]], Color(1, 0.7, 0.5))
		return
	if not Defs.can_afford(p.res, d["cost"]):
		hud.message("Recursos insuficientes (%s) para construir: %s" % [Defs.missing_text(p.res, d["cost"]), d["name"]], Color(1, 0.7, 0.5))
		return
	cancel_placement()
	placing = kind
	var s: float = d["size"] * Defs.CELL
	ghost = MeshInstance3D.new()
	ghost.mesh = Meshes.building_mesh(kind, Defs.TEAM_COLORS[0])
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost_mat = StandardMaterial3D.new()
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_mat.albedo_color = Color(0.2, 1, 0.3, 0.45)
	ghost.material_override = ghost_mat
	game.add_child(ghost)
	var vs := get_viewport().get_visible_rect().size
	_move_ghost(get_viewport().get_mouse_position() if not DisplayServer.is_touchscreen_available() else vs * Vector2(0.5, 0.4))
	hud.message("Posicione: %s (%s). %s" % [d["name"], Defs.cost_text(d["cost"]),
		"Toque no chão para posicionar; segure para cancelar." if DisplayServer.is_touchscreen_available() else "Clique esquerdo posiciona; clique direito cancela."], Color(0.85, 0.9, 1))

func cancel_placement() -> void:
	placing = ""
	if ghost:
		ghost.queue_free()
		ghost = null

func _move_ghost(screen: Vector2) -> void:
	if ghost == null:
		return
	var g = game.cam.ground_at(screen)
	if g == null:
		return
	ghost_tl = game.snap_cells(placing, g)
	ghost.position = game.footprint_center(placing, ghost_tl) + Vector3(0, 0.05, 0)
	var ok: bool = game.placement_error(0, placing, ghost_tl) == ""
	ghost_mat.albedo_color = Color(0.2, 1, 0.3, 0.45) if ok else Color(1, 0.2, 0.2, 0.45)

func _try_place(screen: Vector2, keep: bool) -> void:
	_move_ghost(screen)
	var builders: Array = game.selected.filter(func(x): return x.owner_id == 0 and x.is_unit() and x.is_citizen())
	var err: String = game.order_construct(0, placing, ghost_tl, builders)
	if err != "":
		hud.message(err, Color(1, 0.6, 0.5))
		return
	if not keep or not Defs.can_afford(game.players[0].res, Defs.BUILDINGS[placing]["cost"]):
		cancel_placement()
	hud.refresh_selection()
