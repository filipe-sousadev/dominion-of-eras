extends Node
## Entry point: main menu, starting matches, and the --screenshot / --self-test options.

var game: Game
var hud: Hud
var controls: Controls
var menu: CanvasLayer
var opp_opt: OptionButton
var diff_opt: OptionButton
var last_cfg := {"opponents": 1, "difficulty": "Normal", "seed": 1234}
var shot_path := ""
var test_path := ""

## Android "back": opens or closes the pause menu during a match, leaves the game from the main menu.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if game != null and hud != null:
			hud.toggle_menu()
		else:
			get_tree().quit()

func _ready() -> void:
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	for i in args.size():
		if args[i] == "--screenshot" and i + 1 < args.size():
			shot_path = _abs(args[i + 1])
		elif args[i].begins_with("--screenshot="):
			shot_path = _abs(args[i].split("=", true, 1)[1])
		elif args[i] == "--self-test" and i + 1 < args.size():
			test_path = _abs(args[i + 1])
		elif args[i].begins_with("--self-test="):
			test_path = _abs(args[i].split("=", true, 1)[1])
	if shot_path != "" or test_path != "":
		# never steal focus from the person, keep drawing while unfocused
		get_window().set_flag(Window.FLAG_NO_FOCUS, true)
		OS.low_processor_usage_mode = false
	var sim_i := args.find("--sim")
	if sim_i >= 0 and sim_i + 1 < args.size():
		var sd := "Hard"
		var di := args.find("--diff")
		if di >= 0 and di + 1 < args.size():
			sd = args[di + 1]
		var dl: Array = []
		var dli := args.find("--diffs")
		if dli >= 0 and dli + 1 < args.size():
			dl = Array(args[dli + 1].split(","))
		var seed_i := args.find("--seed")
		start_game({"opponents": 3, "difficulty": sd, "seed": int(args[seed_i + 1]) if seed_i >= 0 else 99,
			"keep_running": true, "sim": true, "diffs": dl})
		_run_sim(float(args[sim_i + 1]))
		return
	if shot_path != "" and args.has("--menu"):
		show_menu()
		_run_menu_shot()
	elif shot_path != "":
		start_game({"opponents": 1, "difficulty": "Normal", "seed": 1234})
		if args.has("--showcase"):
			_run_showcase(args)
		else:
			_run_screenshot()
	elif test_path != "":
		start_game({"opponents": 1, "difficulty": "Normal", "seed": 1234})
		_run_self_test()
	else:
		show_menu()

func _abs(p: String) -> String:
	if p.is_absolute_path():
		return p
	var cwd := OS.get_environment("PWD")
	if cwd == "":
		cwd = ProjectSettings.globalize_path("res://")
	return cwd.path_join(p)

# ---------------------------------------------------------------- menu
var res_opt: OptionButton
var diff_desc: Label
var menu_theme: Theme

func _style(bg: Color, edge: Color, border := 2, radius := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(8)
	s.anti_aliasing = true
	return s

func _make_menu_theme() -> void:
	menu_theme = Theme.new()
	var gold := Color(0.70, 0.56, 0.30)
	var bn := _style(Color(0.17, 0.20, 0.26), Color(0.09, 0.10, 0.13), 1)
	bn.border_width_bottom = 4
	var bh: StyleBoxFlat = bn.duplicate()
	bh.bg_color = Color(0.27, 0.31, 0.40)
	bh.border_color = gold
	var bp: StyleBoxFlat = bn.duplicate()
	bp.bg_color = Color(0.44, 0.35, 0.18)
	bp.border_width_bottom = 1
	bp.border_width_top = 4
	for t in ["Button", "OptionButton"]:
		menu_theme.set_stylebox("normal", t, bn)
		menu_theme.set_stylebox("hover", t, bh)
		menu_theme.set_stylebox("pressed", t, bp)
		menu_theme.set_stylebox("focus", t, StyleBoxEmpty.new())
		menu_theme.set_color("font_color", t, Color(0.95, 0.93, 0.87))
		menu_theme.set_color("font_hover_color", t, Color(1, 0.95, 0.75))
	menu_theme.set_stylebox("panel", "PopupMenu", _style(Color(0.10, 0.12, 0.16), gold, 1))
	menu_theme.set_stylebox("hover", "PopupMenu", _style(Color(0.30, 0.34, 0.44), gold, 0, 3))
	menu_theme.set_font_size("font_size", "PopupMenu", 17)
	menu_theme.set_color("font_color", "Label", Color(0.95, 0.93, 0.87))

func show_menu() -> void:
	_clear_game()
	Engine.time_scale = 1.0
	if menu:
		menu.visible = true
		return
	_make_menu_theme()
	menu = CanvasLayer.new()
	add_child(menu)
	var bg := MenuBackdrop.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)
	var panel := Panel.new()
	var ps := _style(Color(0.07, 0.085, 0.11, 0.90), Color(0.70, 0.56, 0.30), 2, 10)
	ps.shadow_color = Color(0, 0, 0, 0.5)
	ps.shadow_size = 18
	panel.add_theme_stylebox_override("panel", ps)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -250
	panel.offset_right = 250
	panel.offset_top = -312
	panel.offset_bottom = 312
	menu.add_child(panel)
	var box := VBoxContainer.new()
	box.theme = menu_theme
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 40
	box.offset_right = -40
	box.offset_top = 26
	box.offset_bottom = -20
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "DOMINION OF ERAS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.48))
	title.add_theme_color_override("font_outline_color", Color(0.22, 0.13, 0.04))
	title.add_theme_constant_override("outline_size", 8)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Colete · Expanda · Avance · Conquiste"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.80, 0.82, 0.80))
	box.add_child(sub)
	box.add_child(_spacer(10))
	opp_opt = _option(box, "Rivais", ["1", "2", "3"], 1)
	var labels: Array = []
	for k in Defs.DIFFICULTY_ORDER:
		labels.append(Defs.DIFFICULTY[k]["label"])
	diff_opt = _option(box, "Dificuldade", labels, 1)
	diff_desc = Label.new()
	diff_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	diff_desc.custom_minimum_size = Vector2(420, 44)
	diff_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_desc.add_theme_font_size_override("font_size", 13)
	diff_desc.add_theme_color_override("font_color", Color(0.72, 0.84, 0.95))
	box.add_child(diff_desc)
	diff_opt.item_selected.connect(_on_diff)
	_on_diff(1)
	res_opt = _option(box, "Recursos iniciais", Defs.START_RES_LEVELS.keys(), 0)
	box.add_child(_spacer(6))
	_menu_button(box, "Jogar Escaramuça", _on_play)
	_menu_button(box, "Sair", func(): get_tree().quit())
	var help := Label.new()
	help.text = "Clique esquerdo seleciona, clique direito ordena · WASD ou bordas movem a câmera, roda aproxima, Q/E giram\nToque: toque para selecionar e ordenar, arraste para mover, pinça para aproximar"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_font_size_override("font_size", 11)
	help.add_theme_color_override("font_color", Color(0.62, 0.65, 0.66))
	box.add_child(help)

func _on_diff(i: int) -> void:
	diff_desc.text = Defs.DIFFICULTY[Defs.DIFFICULTY_ORDER[i]]["desc"]

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _option(parent: Node, text: String, items: Array, sel: int) -> OptionButton:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(200, 0)
	l.add_theme_font_size_override("font_size", 17)
	row.add_child(l)
	var o := OptionButton.new()
	for it in items:
		o.add_item(it)
	o.select(sel)
	o.custom_minimum_size = Vector2(220, 44)
	o.add_theme_font_size_override("font_size", 17)
	row.add_child(o)
	return o

func _menu_button(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(420, 54)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	parent.add_child(b)

func _on_play() -> void:
	var cfg := {"opponents": opp_opt.selected + 1, "difficulty": Defs.DIFFICULTY_ORDER[diff_opt.selected],
		"resources": Defs.START_RES_LEVELS.values()[res_opt.selected], "seed": randi()}
	start_game(cfg)

## Painted landscape behind the main menu: sky, sun, hills and a little settlement.
class MenuBackdrop extends Control:
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _hill(base: float, amp: float, freq: float, phase: float, c: Color) -> void:
		var pts := PackedVector2Array()
		pts.append(Vector2(0, size.y))
		var n := 48
		for i in n + 1:
			var x := size.x * i / float(n)
			var y := size.y * base - sin(i * freq + phase) * amp * size.y - sin(i * freq * 2.3 + phase * 1.7) * amp * 0.4 * size.y
			pts.append(Vector2(x, y))
		pts.append(Vector2(size.x, size.y))
		draw_colored_polygon(pts, c)

	func _draw() -> void:
		var bands := 120
		for i in bands:
			var f := i / float(bands - 1)
			var c := Color(0.08, 0.13, 0.27).lerp(Color(0.93, 0.58, 0.34), pow(f, 1.7))
			draw_rect(Rect2(0, size.y * 0.72 * i / bands, size.x, size.y * 0.72 / bands + 1.0), c)
		var sun := Vector2(size.x * 0.72, size.y * 0.50)
		for i in 6:
			draw_circle(sun, size.y * (0.22 - i * 0.03), Color(1.0, 0.86, 0.55, 0.07 + i * 0.03))
		draw_circle(sun, size.y * 0.055, Color(1.0, 0.95, 0.78))
		for i in 5:
			var cx := fmod(size.x * (0.15 + i * 0.23) + t * (5.0 + i * 1.5), size.x + 400.0) - 200.0
			var cy := size.y * (0.12 + 0.07 * (i % 3))
			for k in 9:
				draw_circle(Vector2(cx + k * 22.0, cy + sin(k * 1.9 + i) * 7.0), 20.0 + 9.0 * sin(k * 0.4 + 0.3), Color(1, 0.90, 0.84, 0.05))
		_hill(0.62, 0.05, 0.21, 0.4, Color(0.30, 0.34, 0.42))
		_hill(0.70, 0.045, 0.33, 2.1, Color(0.20, 0.30, 0.28))
		_hill(0.80, 0.035, 0.27, 4.0, Color(0.14, 0.26, 0.16))
		_hill(0.92, 0.03, 0.4, 1.0, Color(0.08, 0.16, 0.10))
		# settlement silhouettes on the near hill
		var base := Vector2(size.x * 0.14, size.y * 0.80)
		for i in 4:
			var p := base + Vector2(i * 52.0, -sin(i * 1.3) * 10.0)
			Icons.paint(self, ["house", "city_center", "tower", "house"][i], Rect2(p, Vector2(46, 46) * (1.4 if i == 1 else 1.0)), Color(0.9, 0.3, 0.2))
		for i in 7:
			Icons.paint(self, "tree", Rect2(Vector2(size.x * (0.56 + i * 0.06), size.y * (0.80 + 0.02 * (i % 3))), Vector2(50, 50)))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.05, 0.35))

# ---------------------------------------------------------------- matches
func _clear_game() -> void:
	get_tree().paused = false
	if hud:
		hud.queue_free()
		hud = null
	if game:
		game.queue_free()
		game = null
	controls = null

func start_game(cfg: Dictionary) -> void:
	_clear_game()
	last_cfg = cfg
	if menu:
		menu.visible = false
	game = Game.new()
	add_child(game)
	game.setup(cfg)
	controls = Controls.new()
	controls.game = game
	game.add_child(controls)
	game.controls = controls
	hud = Hud.new()
	add_child(hud)
	controls.hud = hud
	game.hud = hud
	hud.setup(game, controls)
	hud.request_restart.connect(func(): start_game(last_cfg))
	hud.request_menu.connect(show_menu)
	hud.message("Bem-vindo! Colete recursos, domine territórios e derrote seus rivais.", Color(1, 0.95, 0.7))

# ---------------------------------------------------------------- --screenshot
func _run_screenshot() -> void:
	# give the citizens work so the picture shows the game being played
	await get_tree().process_frame
	var cits: Array = game.units.filter(func(u): return u.owner_id == 0)
	for i in cits.size():
		var u = cits[i]
		var n = game.nearest_resource_of_type(["food", "wood", "food", "gold", "wood", "stone"][i % 6], u.position, 40.0)
		if n:
			u.order_gather(n)
	controls.select(cits.slice(0, 2))
	for f in 120:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(shot_path.get_base_dir())
	var err := img.save_png(shot_path)
	print("screenshot saved: ", shot_path, " err=", err)
	get_tree().quit(0 if err == OK else 1)

func _save_shot() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(shot_path.get_base_dir())
	var err := img.save_png(shot_path)
	print("screenshot saved: ", shot_path, " err=", err)
	get_tree().quit(0 if err == OK else 1)

func _run_menu_shot() -> void:
	for f in 30:
		await get_tree().process_frame
	_save_shot()

## Developer picture: every building and unit side by side (add --winter, --fight or --close).
func _run_showcase(args: Array) -> void:
	await get_tree().process_frame
	game.fog_enabled = false
	var p = game.players[0]
	p.epoch = 3
	var c: Vector3 = p.start_pos
	var i := 0
	for k in ["house", "farm", "storehouse", "barracks", "archery", "stable", "workshop", "university", "tower"]:
		var pos := c + Vector3(-22 + (i % 5) * 10.5, 0, -14 - (i / 5) * 10.0)
		var tl: Vector2i = game.snap_cells(k, pos)
		for x in range(-1, 5):
			for y in range(-1, 5):
				var cell := tl + Vector2i(x, y)
				for r in game.resources.duplicate():
					if r.cell == cell:
						r.take(9999.0)
		if game.placement_error(0, k, tl) == "":
			var b = game.place_building(0, k, tl, i != 8)
			if i == 8:
				b.add_build(12.0)
		i += 1
	i = 0
	for k in ["citizen", "spearman", "swordsman", "archer", "cavalry", "catapult"]:
		for j in 3:
			var u = game.spawn_unit(0, k, c + Vector3(-12 + i * 4.2, 0, 9 + j * 2.2))
			u.rotation.y = 0.5
			if j == 0:
				u.order_move(u.position + Vector3(30, 0, 3))
		i += 1
	if args.has("--fight"):
		for j in 8:
			var e = game.spawn_unit(1, ["spearman", "archer", "cavalry", "swordsman"][j % 4], c + Vector3(-10 + j * 3.0, 0, 20))
			e.order_attack_move(c)
		for b in game.buildings:
			if b.kind == "house":
				b.hp = b.max_hp * 0.3
	if args.has("--winter"):
		game.time = Defs.MONTH_SECONDS * 6.2
		game.snow = 0.99
	controls.select(game.buildings.filter(func(b): return b.kind == "barracks"))
	if not game.buildings.filter(func(b): return b.kind == "barracks").is_empty():
		hud._on_cmd(0)
		hud._on_cmd(1)
		hud._on_cmd(1)
		hud._show_tip(1)
	game.cam.look_at_point(c + Vector3(0, 0, -6 if not args.has("--close") else 8))
	game.cam.zoom_by(0.8 if not args.has("--close") else 0.42)
	var li := args.find("--look")
	if li >= 0:
		var xz: PackedStringArray = args[li + 1].split(",")
		game.cam.look_at_point(c + Vector3(float(xz[0]), 0, float(xz[1])))
		game.cam.zoom_by(float(xz[2]) if xz.size() > 2 else 1.0)
	p.kills = 30
	game._check_crowns()
	for f in 150:
		await get_tree().process_frame
	_save_shot()

# ---------------------------------------------------------------- --sim (developer check of the computer players)
func _run_sim(secs: float) -> void:
	Engine.time_scale = 8.0
	var t := 0.0
	while t < secs:
		await _wait(60.0)
		t += 60.0
		for p in game.players:
			var kinds := {}
			for b in game.buildings:
				if b.owner_id == p.id:
					kinds[b.kind] = kinds.get(b.kind, 0) + 1
			var mil := 0
			for u in game.units:
				if u.owner_id == p.id and u.is_military():
					mil += 1
			print("t=%d %s alive=%s era=%d pop=%d/%d mil=%d terr=%d kills=%d ph=%s w=%d res=%s bld=%s" % [int(game.time), p.name, p.alive, p.epoch,
				game.pop_used(p.id), p.pop_cap, mil, game.territories_of(p.id), p.kills, (p.ai.phase if p.ai else "-"), (p.ai.wave if p.ai else 0), str(p.res.values().map(func(v): return int(v))), str(kinds)])
	get_tree().quit(0)

# ---------------------------------------------------------------- --self-test
func _wait(game_secs: float) -> void:
	await get_tree().create_timer(game_secs, true, false, false).timeout

func _run_self_test() -> void:
	Engine.time_scale = 4.0
	var steps: Array = []
	for f in 10:
		await get_tree().process_frame
	var p = game.players[0]
	var cits: Array = game.units.filter(func(u): return u.owner_id == 0 and u.is_citizen())
	# move
	var mover = cits[0]
	var start: Vector3 = mover.position
	controls.select([mover])
	controls.issue_command(null, start + Vector3(10, 0, -6))
	await _wait(4.0)
	var moved: float = start.distance_to(mover.position)
	steps.append({"step": "move", "passed": moved > 4.0, "detail": "citizen walked %.1f m after a move order" % moved})
	# act: gather wood and bring it home
	var wood0: float = p.res["wood"]
	var tree = game.nearest_resource_of_type("wood", cits[1].position, 60.0)
	controls.select([cits[1], cits[2]])
	if tree:
		controls.issue_command(tree, tree.position)
	await _wait(40.0)
	var gained: float = p.res["wood"] - wood0
	steps.append({"step": "act", "passed": gained >= 10.0, "detail": "2 citizens gathered and delivered %d wood" % int(gained)})
	# train a citizen at the City Center
	var cc = null
	for b in game.buildings:
		if b.owner_id == 0 and b.kind == "city_center":
			cc = b
	var pop0: int = game.pop_used(0)
	var terr: String = game.train(cc, "citizen") if cc else "no city center"
	await _wait(16.0)
	steps.append({"step": "train", "passed": terr == "" and game.pop_used(0) > pop0, "detail": "population %d -> %d after training a Citizen" % [pop0, game.pop_used(0)]})
	# build a house
	var builders: Array = [cits[3], cits[4]]
	var tl: Vector2i = game.snap_cells("house", cc.position + Vector3(-9, 0, -9))
	var berr: String = ""
	for tries in 20:
		berr = game.order_construct(0, "house", tl, builders)
		if berr == "":
			break
		tl += Vector2i(-1 if tries % 2 == 0 else 0, -1 if tries % 2 == 1 else 0)
	await _wait(25.0)
	var built := false
	for b in game.buildings:
		if b.owner_id == 0 and b.kind == "house" and b.built:
			built = true
	steps.append({"step": "build", "passed": built, "detail": "house built: %s %s" % [str(built), berr]})
	# fight: an enemy spearman walks in, our soldier attacks it
	var foe = game.spawn_unit(1, "spearman", cc.position + Vector3(14, 0, 0))
	var mine = game.spawn_unit(0, "swordsman", cc.position + Vector3(10, 0, 0))
	controls.select([mine])
	controls.issue_command(foe, foe.position)
	await _wait(14.0)
	var foe_dead: bool = not is_instance_valid(foe) or foe.dead or foe.hp < foe.max_hp
	steps.append({"step": "fight", "passed": foe_dead, "detail": "swordsman attacked an enemy spearman (enemy %s)" % ("defeated" if (not is_instance_valid(foe) or foe.dead) else "wounded")})
	# attack-move: a soldier sent past an enemy stops to fight it
	var foe2 = game.spawn_unit(1, "archer", cc.position + Vector3(16, 0, 6))
	var mine2 = game.spawn_unit(0, "cavalry", cc.position + Vector3(4, 0, 6))
	controls.select([mine2])
	controls.issue_command(null, cc.position + Vector3(30, 0, 6), true)
	await _wait(12.0)
	var engaged: bool = not is_instance_valid(foe2) or foe2.dead or foe2.hp < foe2.max_hp
	steps.append({"step": "attack-move", "passed": engaged, "detail": "cavalry on an attack-move order fought the archer in its path: %s" % str(engaged)})
	# computer players: every difficulty level is complete and the rival is making decisions
	var ai_ok: bool = game.players[1].ai != null and game.players[1].ai.t > 0.0
	for k in Defs.DIFFICULTY_ORDER:
		for f2 in ["label", "gather", "first_attack", "wave", "wave_step", "wave_max", "wave_every", "citizens", "think", "bases", "counter", "regroup", "retreat", "focus", "flee", "pick_weak", "harass", "towers", "desc"]:
			if not Defs.DIFFICULTY[k].has(f2):
				ai_ok = false
	steps.append({"step": "rivals", "passed": ai_ok, "detail": "%d difficulty levels defined; rival has been thinking for %d s" % [Defs.DIFFICULTY_ORDER.size(), int(game.players[1].ai.t)]})
	# panel buttons: train from the City Center, advance the era, place and cancel a building
	for k in Defs.RES:
		p.res[k] += 1000.0
	controls.select([cc])
	hud._on_cmd(0)
	hud._on_cmd(4)
	var era_started: bool = game.epoch_progress(0) >= 0.0
	controls.select(game.units.filter(func(u): return u.owner_id == 0 and u.is_citizen()).slice(0, 3))
	hud._on_cmd(3)
	controls._move_ghost(get_viewport().get_visible_rect().size * 0.5)
	controls.cancel_placement()
	controls._tap(get_viewport().get_visible_rect().size * Vector2(0.5, 0.3))
	await _wait(42.0)
	steps.append({"step": "era", "passed": era_started and p.epoch == 2, "detail": "advanced to %s with the Next Era button" % Defs.EPOCHS[p.epoch - 1]["name"]})
	# hud
	await get_tree().process_frame
	var hud_ok: bool = hud.bottom.visible and hud.res_labels["food"].text != "" and hud.pop_label.text.contains("/") \
		and hud.date_label.text != "" and hud.minimap.visible
	steps.append({"step": "hud", "passed": hud_ok, "detail": "population %s, food %s, wood %s, date '%s', minimap shown" % [hud.pop_label.text, hud.res_labels["food"].text, hud.res_labels["wood"].text, hud.date_label.text]})
	var out := {"version": 1, "steps": steps}
	DirAccess.make_dir_recursive_absolute(test_path.get_base_dir())
	var f := FileAccess.open(test_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out, "  "))
		f.close()
	print(JSON.stringify(out))
	Engine.time_scale = 1.0
	get_tree().quit(0)

func _exit_tree() -> void:
	# release the shared materials so nothing is reported as leaked at exit
	_clear_game()
	Meshes.clear()
	Fx.clear()
