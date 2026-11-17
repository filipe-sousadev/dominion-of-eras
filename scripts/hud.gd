class_name Hud
extends CanvasLayer
## On-screen information and buttons: resource bar, rivals list, messages, command grid with icons,
## selection panel, hover help, minimap, pause menu and end-of-match summary.

signal request_restart
signal request_menu

const BAR_H := 44.0
const BOTTOM_H := 178.0

var game
var controls
var theme_res: Theme
var top_bar: Panel
var era_label: Label
var era_bar: Bar
var date_label: Label
var crown_box: HBoxContainer
var speed_btn: Button
var pause_btn: Button
var msg_box: VBoxContainer
var players_panel: Panel
var player_rows: Array = []
var bottom: Panel
var grid: GridContainer
var cmd_buttons: Array = []
var cmd_actions: Array = []
var cmd_icons: Array = []
var cmd_costs: Array = []
var box_btn: Button
var idle_btn: Button
var idle_badge: Label
var army_btn: Button
var portrait: Icons.View
var name_label: Label
var owner_label: Label
var hp_bar: Bar
var hp_label: Label
var stats_label: Label
var status_label: Label
var prog_bar: Bar
var queue_box: HBoxContainer
var multi_box: HFlowContainer
var res_labels := {}
var pop_label: Label
var terr_label: Label
var tip_panel: PanelContainer
var tip_text: RichTextLabel
var tip_for := -1
var minimap
var overlay
var menu_panel: Panel
var help_panel: Panel
var end_panel: Panel
var end_label: Label
var end_stats: RichTextLabel
var alert_rect: ColorRect
var alert_t := 0.0
var info_t := 0.0
var overlay_dirty := true
var pings: Array = []
var speeds := [1.0, 1.5, 2.0, 3.0]
var speed_i := 0
var il := 0.0                  # left / right margins that keep the HUD clear of a phone's notch and round corners
var ir := 0.0
var tip_t := 0.0

const PANEL_BG := Color(0.085, 0.10, 0.13, 0.96)
const PANEL_BG2 := Color(0.13, 0.15, 0.19, 0.96)
const PANEL_EDGE := Color(0.70, 0.56, 0.30)
const TEXT := Color(0.95, 0.93, 0.87)
const TEXT_DIM := Color(0.66, 0.68, 0.70)
const RES_COLORS := {"food": Color(1.0, 0.62, 0.50), "wood": Color(0.80, 0.66, 0.44),
	"stone": Color(0.84, 0.85, 0.88), "gold": Color(1.0, 0.84, 0.30), "tech": Color(0.66, 0.82, 1.0)}

func setup(g, c) -> void:
	game = g
	controls = c
	process_mode = Node.PROCESS_MODE_ALWAYS
	_safe_margins()
	_make_theme()
	alert_rect = ColorRect.new()
	alert_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	alert_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alert_rect.color = Color(1, 0.1, 0.05, 0.0)
	alert_rect.material = _vignette()
	add_child(alert_rect)
	_build_top()
	_build_players()
	_build_bottom()
	_build_tip()
	overlay = Overlay.new()
	overlay.hud = self
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	move_child(overlay, 0)
	_build_menu()
	_build_help()
	_build_end()
	game.notify.connect(message)
	game.ended.connect(show_end)
	refresh_selection()

func _safe_margins() -> void:
	if not OS.has_feature("mobile"):
		return
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or safe.size.x <= 0:
		return
	var k: float = get_viewport().get_visible_rect().size.x / float(win.x)
	il = clamp(safe.position.x * k, 0.0, 90.0)
	ir = clamp((win.x - safe.end.x) * k, 0.0, 90.0)

# ---------------------------------------------------------------- look
func _box(bg: Color, edge: Color, border := 2, radius := 5) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	return s

func _vignette() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec2 d = abs(UV - vec2(0.5)) * 2.0;\n\tfloat v = smoothstep(0.72, 1.0, max(d.x, d.y));\n\tCOLOR = vec4(COLOR.rgb, COLOR.a * v);\n}\n"
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

func _make_theme() -> void:
	theme_res = Theme.new()
	var pb := _box(PANEL_BG, PANEL_EDGE, 2, 6)
	pb.shadow_color = Color(0, 0, 0, 0.45)
	pb.shadow_size = 6
	theme_res.set_stylebox("panel", "Panel", pb)
	theme_res.set_stylebox("panel", "PanelContainer", pb)
	var bn := _box(Color(0.20, 0.23, 0.29), Color(0.42, 0.38, 0.30), 1, 5)
	bn.border_width_bottom = 3
	bn.border_color = Color(0.10, 0.11, 0.14)
	bn.set_content_margin_all(4)
	var bh: StyleBoxFlat = bn.duplicate()
	bh.bg_color = Color(0.29, 0.33, 0.42)
	bh.border_color = PANEL_EDGE
	var bp: StyleBoxFlat = bn.duplicate()
	bp.bg_color = Color(0.44, 0.35, 0.18)
	bp.border_width_bottom = 1
	bp.border_width_top = 3
	bp.border_color = Color(0.20, 0.15, 0.08)
	var bd: StyleBoxFlat = bn.duplicate()
	bd.bg_color = Color(0.13, 0.14, 0.17)
	theme_res.set_stylebox("normal", "Button", bn)
	theme_res.set_stylebox("hover", "Button", bh)
	theme_res.set_stylebox("pressed", "Button", bp)
	theme_res.set_stylebox("disabled", "Button", bd)
	theme_res.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme_res.set_color("font_color", "Button", TEXT)
	theme_res.set_color("font_hover_color", "Button", Color(1, 0.97, 0.85))
	theme_res.set_color("font_disabled_color", "Button", Color(0.5, 0.5, 0.5))
	theme_res.set_font_size("font_size", "Button", 13)
	theme_res.set_font_size("font_size", "Label", 13)
	theme_res.set_color("font_color", "Label", TEXT)
	theme_res.set_color("default_color", "RichTextLabel", TEXT)
	theme_res.set_font_size("normal_font_size", "RichTextLabel", 13)
	theme_res.set_font_size("bold_font_size", "RichTextLabel", 14)
	var fill := _box(Color(0.25, 0.80, 0.30), Color(0, 0, 0, 0), 0, 3)
	var back := _box(Color(0.05, 0.05, 0.06), Color(0.02, 0.02, 0.02), 1, 3)
	theme_res.set_stylebox("fill", "ProgressBar", fill)
	theme_res.set_stylebox("background", "ProgressBar", back)
	var tp := _box(Color(0.06, 0.07, 0.09, 0.97), PANEL_EDGE, 1, 4)
	tp.set_content_margin_all(6)
	theme_res.set_stylebox("panel", "TooltipPanel", tp)
	theme_res.set_color("font_color", "TooltipLabel", TEXT)

func _panel(parent: Node) -> Panel:
	var p := Panel.new()
	p.theme = theme_res
	parent.add_child(p)
	return p

func _label(parent: Node, text: String, pos: Vector2, size := 13, col := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.theme = theme_res
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _button(parent: Node, text: String, size: Vector2, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.size = size
	b.theme = theme_res
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _icon_button(parent: Node, icon: String, size: Vector2, tip: String, cb: Callable) -> Button:
	var b := _button(parent, "", size, cb)
	b.tooltip_text = tip
	var ic := Icons.View.new(icon, min(size.x, size.y) - 12.0)
	ic.position = (size - ic.size) * 0.5 - Vector2(0, 1)
	ic.team = Defs.TEAM_COLORS[0]
	b.add_child(ic)
	return b

# ---------------------------------------------------------------- top bar
func _chip(parent: Node, icon: String, tip: String, col: Color, width := 84.0) -> Label:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, 32)
	c.tooltip_text = tip
	c.theme = theme_res
	parent.add_child(c)
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", _box(Color(0.04, 0.05, 0.07, 0.85), Color(0.30, 0.28, 0.24), 1, 4))
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(bg)
	var ic := Icons.View.new(icon, 24)
	ic.position = Vector2(5, 4)
	ic.team = Defs.TEAM_COLORS[0]
	c.add_child(ic)
	var l := _label(c, "0", Vector2(32, 5), 15, col)
	l.size = Vector2(width - 38, 22)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l

func _build_top() -> void:
	top_bar = _panel(self)
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = -4
	top_bar.offset_right = 4
	top_bar.offset_top = -4
	top_bar.offset_bottom = BAR_H
	var left := HBoxContainer.new()
	left.position = Vector2(12 + il, 8)
	left.add_theme_constant_override("separation", 5)
	top_bar.add_child(left)
	for k in Defs.RES:
		res_labels[k] = _chip(left, k, Defs.RES_NAMES[k], RES_COLORS[k])
	pop_label = _chip(left, "pop", "População (construa Casas para aumentar o limite)", Color(0.92, 0.93, 0.98), 92)
	terr_label = _chip(left, "territory", "Territórios sob seu controle", Color(0.78, 0.88, 1.0), 76)
	var right := HBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -12 - ir
	right.offset_top = 8
	right.add_theme_constant_override("separation", 8)
	right.alignment = BoxContainer.ALIGNMENT_END
	top_bar.add_child(right)
	crown_box = HBoxContainer.new()
	crown_box.add_theme_constant_override("separation", 2)
	right.add_child(crown_box)
	var era := Control.new()
	era.custom_minimum_size = Vector2(176, 32)
	right.add_child(era)
	era_label = _label(era, "", Vector2(0, 1), 15, Color(1.0, 0.88, 0.55))
	era_label.size = Vector2(176, 22)
	era_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	era_bar = Bar.new()
	era_bar.position = Vector2(8, 25)
	era_bar.size = Vector2(160, 6)
	era_bar.fill = Color(1.0, 0.8, 0.3)
	era_bar.visible = false
	era.add_child(era_bar)
	var dt := Control.new()
	dt.custom_minimum_size = Vector2(190, 32)
	right.add_child(dt)
	date_label = _label(dt, "", Vector2(0, 5), 14)
	date_label.size = Vector2(190, 22)
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_btn = _button(right, "1x", Vector2(46, 30), _cycle_speed)
	speed_btn.tooltip_text = "Velocidade do jogo"
	pause_btn = _button(right, "Pausa", Vector2(66, 30), toggle_pause)
	pause_btn.tooltip_text = "Pausar (P)"
	var mb := _button(right, "Menu", Vector2(66, 30), toggle_menu)
	mb.tooltip_text = "Menu (Esc ou F10)"
	msg_box = VBoxContainer.new()
	msg_box.position = Vector2(14 + il, BAR_H + 10)
	msg_box.add_theme_constant_override("separation", 1)
	msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(msg_box)

func _cycle_speed() -> void:
	speed_i = (speed_i + 1) % speeds.size()
	Engine.time_scale = speeds[speed_i]
	speed_btn.text = ("%sx" % str(speeds[speed_i])).replace(".0x", "x")

# ---------------------------------------------------------------- rivals list
func _build_players() -> void:
	var n: int = game.players.size()
	players_panel = _panel(self)
	players_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	players_panel.offset_left = -232 - ir
	players_panel.offset_right = -8 - ir
	players_panel.offset_top = BAR_H + 8
	players_panel.offset_bottom = BAR_H + 8 + 30 + n * 22
	players_panel.add_theme_stylebox_override("panel", _box(Color(0.06, 0.07, 0.09, 0.78), Color(0.45, 0.38, 0.24), 1, 5))
	_label(players_panel, "Jogador", Vector2(26, 5), 11, TEXT_DIM)
	_label(players_panel, "Era", Vector2(112, 5), 11, TEXT_DIM)
	_label(players_panel, "Terr.", Vector2(142, 5), 11, TEXT_DIM)
	_label(players_panel, "Pontos", Vector2(178, 5), 11, TEXT_DIM)
	for i in n:
		var p = game.players[i]
		var y := 24.0 + i * 22.0
		var sw := ColorRect.new()
		sw.color = p.color
		sw.position = Vector2(9, y + 4)
		sw.size = Vector2(11, 11)
		sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		players_panel.add_child(sw)
		var row := {"name": _label(players_panel, p.name, Vector2(26, y), 13, p.color.lightened(0.45)),
			"era": _label(players_panel, "1", Vector2(116, y), 13), "terr": _label(players_panel, "1", Vector2(150, y), 13),
			"score": _label(players_panel, "0", Vector2(178, y), 13)}
		player_rows.append(row)

## A rough score: what a player has built up and destroyed.
func score_of(p) -> int:
	var s: float = p.gathered * 0.1 + p.kills * 15.0 + (p.epoch - 1) * 250.0 + game.territories_of(p.id) * 150.0
	s += game.pop_used(p.id) * 10.0
	return int(s)

# ---------------------------------------------------------------- bottom bar
func _build_bottom() -> void:
	bottom = _panel(self)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = -4
	bottom.offset_right = 4
	bottom.offset_bottom = 4
	bottom.offset_top = -BOTTOM_H
	# quick buttons
	var quick := VBoxContainer.new()
	quick.position = Vector2(12 + il, 10)
	quick.add_theme_constant_override("separation", 4)
	bottom.add_child(quick)
	idle_btn = _icon_button(quick, "idle", Vector2(52, 38), "Próximo cidadão ocioso (.)", func(): controls.select_idle_citizen())
	idle_badge = _label(idle_btn, "", Vector2(30, 0), 12, Color(1, 0.9, 0.4))
	idle_badge.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	idle_badge.add_theme_constant_override("outline_size", 4)
	army_btn = _icon_button(quick, "army", Vector2(52, 38), "Selecionar todo o exército (M)", func(): controls.select_army())
	_icon_button(quick, "city_center", Vector2(52, 38), "Ir para o Centro da Cidade (H)", func(): controls.select_home())
	box_btn = _icon_button(quick, "box", Vector2(52, 38), "Toque: arrastar com um dedo desenha a caixa de seleção", _toggle_box)
	box_btn.toggle_mode = true
	# command grid
	grid = GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(72 + il, 10)
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	bottom.add_child(grid)
	for i in 12:
		var b := _button(grid, "", Vector2(74, 52), _on_cmd.bind(i))
		b.mouse_entered.connect(_show_tip.bind(i))
		b.mouse_exited.connect(_hide_tip.bind(i))
		var ic := Icons.View.new("", 32)
		ic.position = Vector2(21, 2)
		ic.team = Defs.TEAM_COLORS[0]
		b.add_child(ic)
		var cl := _label(b, "", Vector2(0, 33), 11)
		cl.size = Vector2(74, 16)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cl.clip_text = true
		cmd_buttons.append(b)
		cmd_icons.append(ic)
		cmd_costs.append(cl)
		cmd_actions.append({})
	# selection info
	var info := Control.new()
	info.anchor_right = 1.0
	info.offset_left = 392 + il
	info.offset_right = -198 - ir
	info.offset_top = 10
	info.offset_bottom = 10 + 160
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(info)
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", _box(PANEL_BG2, Color(0.36, 0.33, 0.27), 1, 5))
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(frame)
	var pf := Panel.new()
	pf.add_theme_stylebox_override("panel", _box(Color(0.05, 0.06, 0.08), PANEL_EDGE.darkened(0.2), 2, 5))
	pf.position = Vector2(10, 10)
	pf.size = Vector2(78, 78)
	pf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(pf)
	portrait = Icons.View.new("", 62)
	portrait.position = Vector2(8, 8)
	pf.add_child(portrait)
	name_label = _label(info, "", Vector2(100, 5), 18, Color(1.0, 0.92, 0.70))
	owner_label = _label(info, "", Vector2(100, 8), 13, TEXT_DIM)
	hp_bar = Bar.new()
	hp_bar.position = Vector2(100, 32)
	hp_bar.size = Vector2(260, 15)
	info.add_child(hp_bar)
	hp_label = _label(info, "", Vector2(100, 31), 11)
	hp_label.size = Vector2(260, 16)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hp_label.add_theme_constant_override("outline_size", 3)
	stats_label = _label(info, "", Vector2(100, 53), 12, Color(0.86, 0.88, 0.92))
	status_label = _label(info, "", Vector2(100, 73), 13)
	status_label.anchor_right = 1.0
	status_label.offset_right = -10
	status_label.offset_bottom = 73 + 80
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prog_bar = Bar.new()
	prog_bar.position = Vector2(10, 96)
	prog_bar.size = Vector2(78, 9)
	prog_bar.fill = Color(0.38, 0.62, 1.0)
	info.add_child(prog_bar)
	queue_box = HBoxContainer.new()
	queue_box.position = Vector2(10, 112)
	queue_box.add_theme_constant_override("separation", 3)
	queue_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(queue_box)
	multi_box = HFlowContainer.new()
	multi_box.position = Vector2(100, 58)
	multi_box.anchor_right = 1.0
	multi_box.offset_right = -10
	multi_box.add_theme_constant_override("h_separation", 5)
	multi_box.add_theme_constant_override("v_separation", 5)
	multi_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(multi_box)
	# minimap
	var mf := Panel.new()
	mf.add_theme_stylebox_override("panel", _box(Color(0, 0, 0), PANEL_EDGE, 2, 3))
	mf.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mf.offset_left = -190 - ir
	mf.offset_right = -10 - ir
	mf.offset_top = 8
	mf.offset_bottom = 172
	mf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(mf)
	minimap = Minimap.new()
	minimap.hud = self
	minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -187 - ir
	minimap.offset_right = -13 - ir
	minimap.offset_top = 11
	minimap.offset_bottom = 169
	bottom.add_child(minimap)
	minimap.build()

func _build_tip() -> void:
	tip_panel = PanelContainer.new()
	tip_panel.theme = theme_res
	var sb := _box(Color(0.05, 0.06, 0.08, 0.97), PANEL_EDGE, 1, 5)
	sb.set_content_margin_all(9)
	tip_panel.add_theme_stylebox_override("panel", sb)
	tip_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	tip_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tip_panel.offset_left = 72 + il
	tip_panel.offset_bottom = -BOTTOM_H - 8
	tip_panel.offset_top = -BOTTOM_H - 8
	tip_panel.custom_minimum_size = Vector2(320, 0)
	tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_text = RichTextLabel.new()
	tip_text.bbcode_enabled = true
	tip_text.fit_content = true
	tip_text.scroll_active = false
	tip_text.custom_minimum_size = Vector2(300, 0)
	tip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_panel.add_child(tip_text)
	tip_panel.visible = false
	add_child(tip_panel)

func _center_panel(w: float, h: float) -> Panel:
	var p := _panel(self)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.offset_left = -w * 0.5
	p.offset_right = w * 0.5
	p.offset_top = -h * 0.5
	p.offset_bottom = h * 0.5
	return p

func _title(parent: Node, text: String, w: float, y := 14.0, size := 22) -> Label:
	var t := _label(parent, text, Vector2(0, y), size, Color(1.0, 0.88, 0.55))
	t.size = Vector2(w, 32)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return t

func _build_menu() -> void:
	menu_panel = _center_panel(280, 356)
	_title(menu_panel, "Jogo Pausado", 280)
	var v := VBoxContainer.new()
	v.position = Vector2(30, 60)
	v.add_theme_constant_override("separation", 10)
	menu_panel.add_child(v)
	_button(v, "Voltar ao Jogo", Vector2(220, 46), toggle_menu)
	_button(v, "Como Jogar", Vector2(220, 46), func(): help_panel.visible = true)
	_button(v, "Reiniciar", Vector2(220, 46), _on_restart)
	_button(v, "Menu Principal", Vector2(220, 46), _on_menu)
	_button(v, "Sair", Vector2(220, 46), func(): get_tree().quit())
	menu_panel.visible = false

const HELP_TEXT := """[b][color=#ffe08c]Objetivo[/color][/b]
Elimine todos os rivais: um jogador cai quando fica sem Centro da Cidade e sem cidadãos.

[b][color=#ffe08c]Economia[/color][/b]
Cidadãos coletam [color=#ff9e80]Comida[/color], [color=#cca870]Madeira[/color], [color=#d6d9e0]Pedra[/color] e [color=#ffd64d]Ouro[/color] e levam ao Centro da Cidade ou a um Armazém. Estudiosos na Universidade geram [color=#a8d1ff]Tecnologia[/color], usada para avançar de era.

[b][color=#ffe08c]Territórios[/color][/b]
Cada Centro da Cidade domina um território; só é possível construir dentro dos seus. Infantaria e cavalaria perto de um Centro ou Universidade inimigos sem defensores reduzem a lealdade até capturá-los.

[b][color=#ffe08c]Combate[/color][/b]
Lanceiro vence cavalaria · Cavaleiro vence arqueiros e cerco · Arqueiro vence infantaria · Catapulta derruba construções.

[b][color=#ffe08c]Controles[/color][/b]
Clique esquerdo seleciona (arraste para caixa, duplo clique = todos do tipo) · Clique direito ordena
WASD / setas / bordas movem a câmera · roda do mouse aproxima · Q/E giram
G = atacar ao mover (ou Ctrl + clique direito) · M = todo o exército · H = Centro da Cidade
. = cidadão ocioso · Ctrl+0-9 cria grupo, 0-9 seleciona · Del remove · Espaço = último alerta · P pausa
Toque: toque para selecionar e ordenar, arraste para mover a câmera, pinça para aproximar."""

func _build_help() -> void:
	help_panel = _center_panel(660, 520)
	_title(help_panel, "Como Jogar", 660)
	var t := RichTextLabel.new()
	t.theme = theme_res
	t.bbcode_enabled = true
	t.text = HELP_TEXT
	t.position = Vector2(26, 56)
	t.size = Vector2(608, 396)
	help_panel.add_child(t)
	var b := _button(help_panel, "Fechar", Vector2(160, 42), func(): help_panel.visible = false)
	b.position = Vector2(250, 464)
	help_panel.visible = false

func _build_end() -> void:
	end_panel = _center_panel(620, 360)
	end_label = _title(end_panel, "", 620, 16, 34)
	end_label.size.y = 48
	end_stats = RichTextLabel.new()
	end_stats.theme = theme_res
	end_stats.bbcode_enabled = true
	end_stats.position = Vector2(24, 78)
	end_stats.size = Vector2(572, 200)
	end_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_panel.add_child(end_stats)
	var h := HBoxContainer.new()
	h.position = Vector2(150, 296)
	h.add_theme_constant_override("separation", 20)
	end_panel.add_child(h)
	_button(h, "Jogar Novamente", Vector2(150, 46), _on_restart)
	_button(h, "Menu Principal", Vector2(150, 46), _on_menu)
	end_panel.visible = false

func _on_restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	emit_signal("request_restart")

func _on_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	emit_signal("request_menu")

# ---------------------------------------------------------------- api
func blocks(pos: Vector2) -> bool:
	for c in [top_bar, bottom, menu_panel, end_panel, help_panel, players_panel]:
		if c.visible and c.get_global_rect().has_point(pos):
			return true
	return false

func menu_open() -> bool:
	return menu_panel.visible or end_panel.visible

func toggle_menu() -> void:
	if end_panel.visible:
		return
	if help_panel.visible:
		help_panel.visible = false
		return
	menu_panel.visible = not menu_panel.visible
	get_tree().paused = menu_panel.visible

func toggle_pause() -> void:
	if menu_panel.visible or end_panel.visible:
		return
	get_tree().paused = not get_tree().paused
	pause_btn.text = "Retomar" if get_tree().paused else "Pausa"
	message("Jogo pausado" if get_tree().paused else "Jogo retomado", Color(0.9, 0.9, 0.9))

func show_end(won: bool) -> void:
	end_label.text = "Vitória!" if won else "Você foi derrotado"
	end_label.add_theme_color_override("font_color", Color(1, 0.85, 0.35) if won else Color(1, 0.45, 0.4))
	var secs := int(game.time)
	var t := "[center][color=#a8adb3]Tempo de jogo %d:%02d  ·  Dificuldade %s[/color][/center]\n" % [secs / 60, secs % 60,
		Defs.DIFFICULTY[game.config.get("difficulty", "Normal")]["label"]]
	t += "[table=7][cell][color=#a8adb3]Jogador[/color][/cell][cell][color=#a8adb3]  Pontos[/color][/cell][cell][color=#a8adb3]  Era[/color][/cell][cell][color=#a8adb3]  Abates[/color][/cell][cell][color=#a8adb3]  Perdas[/color][/cell][cell][color=#a8adb3]  Treinados[/color][/cell][cell][color=#a8adb3]  Coletado[/color][/cell]"
	for p in game.players:
		var st: Dictionary = game.stats[p.id]
		t += "[cell][color=#%s]%s[/color]%s[/cell][cell]  %d[/cell][cell]  %d[/cell][cell]  %d[/cell][cell]  %d[/cell][cell]  %d[/cell][cell]  %d[/cell]" % [
			p.color.lightened(0.4).to_html(false), p.name, "" if p.alive else " ✝", score_of(p), p.epoch, p.kills, st["lost"], st["trained"], int(p.gathered)]
	t += "[/table]"
	end_stats.text = t
	end_panel.visible = true
	Engine.time_scale = 1.0

func message(text: String, color := Color.WHITE) -> void:
	var l := Label.new()
	l.text = text
	l.theme = theme_res
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg_box.add_child(l)
	while msg_box.get_child_count() > 6:
		var old := msg_box.get_child(0)
		msg_box.remove_child(old)
		old.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(8.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)

func ping(p: Vector3) -> void:
	pings.append({"pos": p, "t": 3.0})
	alert_t = 1.6

func queue_overlay() -> void:
	overlay_dirty = true

func _toggle_box() -> void:
	controls.box_mode = box_btn.button_pressed

# ---------------------------------------------------------------- commands
func _set_cmd(i: int, icon: String, label: String, action: Dictionary, enabled := true) -> void:
	var b: Button = cmd_buttons[i]
	b.disabled = false
	b.modulate = Color.WHITE if enabled else Color(1, 1, 1, 0.45)
	cmd_icons[i].set_kind(icon)
	cmd_costs[i].text = label
	cmd_actions[i] = action

func refresh_selection() -> void:
	if grid == null:
		return
	for i in 12:
		cmd_buttons[i].disabled = true
		cmd_buttons[i].modulate = Color(1, 1, 1, 0.22)
		cmd_icons[i].set_kind("")
		cmd_costs[i].text = ""
		cmd_actions[i] = {}
	var sel: Array = game.selected.filter(func(x): return is_instance_valid(x) and not x.dead)
	var own_units: Array = sel.filter(func(x): return x.owner_id == 0 and x.is_unit())
	var p = game.players[0]
	if own_units.any(func(x): return x.is_citizen()):
		var i := 0
		for k in Defs.BUILD_MENU:
			var d: Dictionary = Defs.BUILDINGS[k]
			var ok: bool = p.epoch >= int(d["epoch"])
			_set_cmd(i, k, Defs.cost_text(d["cost"]) if ok else "Era %d" % int(d["epoch"]),
				{"type": "build", "kind": k, "cost": d["cost"], "locked": not ok}, ok)
			i += 1
		_set_cmd(11, "stop", "Parar", {"type": "stop"})
	elif not own_units.is_empty():
		_set_cmd(0, "attack", "Atacar", {"type": "amove"})
		_set_cmd(1, "stop", "Parar", {"type": "stop"})
		_set_cmd(3, "delete", "Dispensar", {"type": "delete"})
	elif sel.size() == 1 and sel[0].owner_id == 0 and sel[0].is_building():
		var b = sel[0]
		var i := 0
		if b.built:
			for u in b.trains():
				var d: Dictionary = Defs.UNITS[u]
				var ok: bool = p.epoch >= int(d["epoch"])
				_set_cmd(i, u, Defs.cost_text(d["cost"]) if ok else "Era %d" % int(d["epoch"]),
					{"type": "train", "kind": u, "cost": d["cost"], "locked": not ok}, ok)
				i += 1
			if b.kind == "city_center" and p.epoch < Defs.EPOCHS.size():
				var e: Dictionary = Defs.EPOCHS[p.epoch]
				_set_cmd(4, "epoch", "Próxima Era", {"type": "epoch", "cost": e["cost"]})
			if not b.queue.is_empty():
				_set_cmd(8, "cancel", "Cancelar", {"type": "cancel"})
		_set_cmd(11, "delete", "Demolir", {"type": "delete"})
	if tip_for >= 0:
		_show_tip(tip_for)
	_update_afford()
	if overlay:
		overlay_dirty = true

func _update_afford() -> void:
	var p = game.players[0]
	for i in 12:
		var a: Dictionary = cmd_actions[i]
		if a.has("cost") and not a.get("locked", false):
			var ok: bool = Defs.can_afford(p.res, a["cost"])
			cmd_costs[i].add_theme_color_override("font_color", TEXT if ok else Color(1.0, 0.42, 0.36))
			cmd_icons[i].modulate = Color.WHITE if ok else Color(0.62, 0.62, 0.62)
		else:
			cmd_costs[i].add_theme_color_override("font_color", TEXT_DIM if a.get("locked", false) else TEXT)
			cmd_icons[i].modulate = Color.WHITE

func _cost_bb(cost: Dictionary) -> String:
	var p = game.players[0]
	var parts: Array = []
	for k in Defs.RES:
		if cost.has(k):
			var ok: bool = p.res[k] >= cost[k]
			parts.append("[color=#%s]%d %s[/color]" % [RES_COLORS[k].to_html(false) if ok else "ff5a4d", int(cost[k]), Defs.RES_NAMES[k]])
	return "   ".join(parts)

func _unit_bb(k: String) -> String:
	var d: Dictionary = Defs.UNITS[k]
	var s := "[color=#c4c9d1]Vida %d · Ataque %d · Alcance %s · Velocidade %d · Armadura %d[/color]" % [int(d["hp"]), int(d["atk"]),
		"corpo a corpo" if float(d["range"]) < 3.0 else str(int(d["range"])), int(d["speed"]), int(d["armor"])]
	var bon: Array = []
	for c in d.get("bonus", {}):
		bon.append("%s ×%s" % [Defs.CLASS_NAMES[c], str(d["bonus"][c])])
	if not bon.is_empty():
		s += "\n[color=#9fe08a]Bônus contra: %s[/color]" % ", ".join(bon)
	return s

func _show_tip(i: int) -> void:
	tip_for = i
	var a: Dictionary = cmd_actions[i]
	if a.is_empty():
		tip_panel.visible = false
		return
	var t := ""
	match a["type"]:
		"build":
			var d: Dictionary = Defs.BUILDINGS[a["kind"]]
			t = "[b][color=#ffe08c]Construir %s[/color][/b]\n%s\n%s\n[color=#c4c9d1]Vida %d · Tempo %ds[/color]" % [d["name"], _cost_bb(d["cost"]), Defs.DESC[a["kind"]], int(d["hp"]), int(d["time"])]
			if a.get("locked", false):
				t += "\n[color=#ff8a70]Requer a %s[/color]" % Defs.EPOCHS[int(d["epoch"]) - 1]["name"]
		"train":
			var u: Dictionary = Defs.UNITS[a["kind"]]
			t = "[b][color=#ffe08c]Treinar %s[/color][/b]\n%s\n%s\n%s\n[color=#c4c9d1]Tempo %ds[/color]" % [u["name"], _cost_bb(u["cost"]), Defs.DESC[a["kind"]], _unit_bb(a["kind"]), int(u["time"])]
			if a.get("locked", false):
				t += "\n[color=#ff8a70]Requer a %s[/color]" % Defs.EPOCHS[int(u["epoch"]) - 1]["name"]
		"epoch":
			var e: Dictionary = Defs.EPOCHS[game.players[0].epoch]
			t = "[b][color=#ffe08c]Avançar para a %s[/color][/b]\n%s\nSoldados +10%% de vida e ataque, coleta +5%%.\n[color=#c4c9d1]Tempo %ds[/color]" % [e["name"], _cost_bb(e["cost"]), int(e["time"])]
		"stop":
			t = "[b][color=#ffe08c]Parar[/color][/b]\nInterrompe o que os selecionados estão fazendo."
		"amove":
			t = "[b][color=#ffe08c]Atacar ao mover (G)[/color][/b]\nClique em um ponto: os soldados vão até lá atacando todo inimigo no caminho. Também: Ctrl + clique direito."
		"delete":
			t = "[b][color=#ffe08c]Remover (Del)[/color][/b]\nRemove os selecionados do jogo."
		"cancel":
			t = "[b][color=#ffe08c]Cancelar[/color][/b]\nCancela a última unidade da fila e devolve os recursos."
	tip_text.text = t
	tip_t = 4.0
	tip_panel.visible = true
	tip_panel.reset_size()

func _hide_tip(i: int) -> void:
	if tip_for == i:
		tip_for = -1
		tip_panel.visible = false

func _on_cmd(i: int) -> void:
	var a: Dictionary = cmd_actions[i]
	if a.is_empty():
		return
	match a["type"]:
		"build":
			controls.start_placement(a["kind"])
		"stop":
			for x in game.selected:
				if x.owner_id == 0 and x.is_unit():
					x.stop()
		"amove":
			controls.begin_attack_move()
		"delete":
			for x in game.selected.duplicate():
				if x.owner_id == 0 and not x.is_resource():
					x.die(null)
		"train":
			var b = game.selected[0]
			var n: int = 5 if Input.is_key_pressed(KEY_SHIFT) else 1
			for k in n:
				var err: String = game.train(b, a["kind"])
				if err != "":
					message(err, Color(1, 0.6, 0.5))
					break
			refresh_selection()
		"epoch":
			var err2: String = game.advance_epoch(0)
			if err2 != "":
				message(err2, Color(1, 0.6, 0.5))
		"cancel":
			game.cancel_train(game.selected[0])
			refresh_selection()

# ---------------------------------------------------------------- per frame
func _process(delta: float) -> void:
	if game == null:
		return
	overlay.queue_redraw()
	# on a touch screen nothing "leaves" a button, so the help closes by itself
	if tip_panel.visible and DisplayServer.is_touchscreen_available():
		tip_t -= delta
		if tip_t <= 0.0:
			tip_for = -1
			tip_panel.visible = false
	info_t -= delta
	for pg in pings:
		pg["t"] -= delta
	pings = pings.filter(func(pg): return pg["t"] > 0.0)
	if alert_t > 0.0:
		alert_t = max(0.0, alert_t - delta)
		alert_rect.color.a = 0.5 * abs(sin(alert_t * 6.0)) * min(1.0, alert_t)
	if info_t > 0.0:
		return
	info_t = 0.2
	var p = game.players[0]
	era_label.text = "%s · Era %d" % [Defs.EPOCHS[p.epoch - 1]["name"], p.epoch]
	var ep: float = game.epoch_progress(0)
	era_bar.visible = ep >= 0.0
	era_bar.value = ep * 100.0
	var secs := int(game.time)
	date_label.text = "%s, Ano %d  ·  %d:%02d" % [Defs.MONTHS[game.month_index()], game.year(), secs / 60, secs % 60]
	date_label.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0) if game.is_winter() else TEXT)
	_update_crowns()
	var used: int = game.pop_used(0)
	pop_label.text = "%d/%d" % [used, p.pop_cap]
	pop_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4) if used >= p.pop_cap else Color(0.92, 0.93, 0.98))
	terr_label.text = "%d/%d" % [game.territories_of(0), game.seeds.size()]
	for k in Defs.RES:
		res_labels[k].text = str(int(p.res[k]))
	var idle := 0
	var army := 0
	for u in game.units:
		if u.owner_id == 0 and not u.dead:
			if u.is_citizen():
				if u.state == "idle":
					idle += 1
			else:
				army += 1
	idle_badge.text = str(idle) if idle > 0 else ""
	idle_btn.modulate = Color.WHITE if idle > 0 else Color(1, 1, 1, 0.5)
	army_btn.modulate = Color.WHITE if army > 0 else Color(1, 1, 1, 0.5)
	for i in player_rows.size():
		var pl = game.players[i]
		var row: Dictionary = player_rows[i]
		row["era"].text = str(pl.epoch)
		row["terr"].text = str(game.territories_of(pl.id))
		row["score"].text = str(score_of(pl))
		if not pl.alive:
			for k in row:
				row[k].modulate = Color(1, 1, 1, 0.35)
			row["score"].text = "fora"
	_update_afford()
	_update_info()
	minimap.queue_redraw()

func _update_crowns() -> void:
	if crown_box.get_child_count() == game.crown_holder.size():
		return
	for c in crown_box.get_children():
		c.queue_free()
	for k in ["military", "economic", "imperial"]:
		if game.crown_holder.has(k):
			var pl = game.players[game.crown_holder[k]]
			var ic := Icons.View.new("crown", 26)
			ic.team = pl.color.lightened(0.25)
			ic.mouse_filter = Control.MOUSE_FILTER_STOP
			ic.tooltip_text = "%s: %s (%s)" % [Defs.CROWN_NAMES[k], pl.name, Defs.CROWN_DESC[k]]
			ic.theme = theme_res
			crown_box.add_child(ic)

func _tile(icon: String, text: String, team: Color, size := 30.0) -> Control:
	var c := Panel.new()
	c.add_theme_stylebox_override("panel", _box(Color(0.05, 0.06, 0.08), Color(0.36, 0.33, 0.27), 1, 4))
	c.custom_minimum_size = Vector2(size + 6, size + 6)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := Icons.View.new(icon, size)
	ic.position = Vector2(3, 3)
	ic.team = team
	c.add_child(ic)
	if text != "":
		var l := _label(c, text, Vector2(0, size - 12), 12, Color(1, 0.95, 0.7))
		l.size = Vector2(size + 3, 16)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		l.add_theme_constant_override("outline_size", 4)
	return c

func _fill_box(box: Container, sig: String, build: Callable) -> void:
	## Rebuilds the row of tiles only when what it shows has changed.
	if box.get_meta("sig", "") == sig:
		return
	box.set_meta("sig", sig)
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	build.call()

func _update_info() -> void:
	var sel: Array = game.selected.filter(func(x): return is_instance_valid(x) and not x.dead)
	if sel.size() != game.selected.size():
		game.selected = sel
		refresh_selection()
	prog_bar.visible = false
	owner_label.text = ""
	if sel.is_empty():
		portrait.set_kind("")
		name_label.text = ""
		hp_bar.visible = false
		hp_label.text = ""
		stats_label.text = ""
		_fill_box(queue_box, "", func(): pass)
		_fill_box(multi_box, "", func(): pass)
		status_label.text = "Selecione cidadãos para coletar e construir, ou soldados para lutar." if not DisplayServer.is_touchscreen_available() \
			else "Toque no seu povo para selecionar; depois toque onde devem ir ou trabalhar."
		return
	hp_bar.visible = true
	if sel.size() > 1:
		var counts := {}
		var kinds := {}
		var hp := 0.0
		var mhp := 0.0
		for x in sel:
			counts[x.kind] = counts.get(x.kind, 0) + 1
			kinds[x.kind] = x
			hp += x.hp
			mhp += x.max_hp
		portrait.team = game.players[max(sel[0].owner_id, 0)].color
		portrait.set_kind("army" if sel.any(func(x): return x.is_unit() and x.is_military()) else "pop")
		name_label.text = "%d selecionados" % sel.size()
		hp_bar.fill = Color(0.25, 0.80, 0.30)
		hp_bar.max_value = mhp
		hp_bar.value = hp
		hp_label.text = "%d/%d" % [int(hp), int(mhp)]
		stats_label.text = ""
		status_label.text = ""
		var sig := ""
		for k in counts:
			sig += "%s%d," % [k, counts[k]]
		_fill_box(queue_box, "", func(): pass)
		_fill_box(multi_box, sig, func():
			for k in counts:
				multi_box.add_child(_tile(k, str(counts[k]), game.players[max(kinds[k].owner_id, 0)].color, 40.0)))
		return
	_fill_box(multi_box, "", func(): pass)
	var e = sel[0]
	portrait.team = game.players[e.owner_id].color if e.owner_id >= 0 else Color(0.5, 0.5, 0.5)
	portrait.set_kind(e.kind)
	portrait.queue_redraw()
	name_label.text = e.display_name()
	if e.owner_id > 0:
		owner_label.text = "(%s)" % game.players[e.owner_id].name
		owner_label.position.x = 100 + name_label.get_minimum_size().x + 8
		owner_label.add_theme_color_override("font_color", game.players[e.owner_id].color.lightened(0.4))
	hp_bar.max_value = e.max_hp
	hp_bar.value = e.hp
	var f: float = e.hp / max(e.max_hp, 1.0)
	hp_bar.fill = Color(0.25, 0.80, 0.30) if f > 0.5 else (Color(0.95, 0.78, 0.2) if f > 0.25 else Color(0.92, 0.28, 0.22))
	hp_label.text = "%d/%d" % [int(e.hp), int(e.max_hp)]
	if e.is_resource():
		hp_bar.visible = false
		hp_label.text = ""
		stats_label.text = "%s restante: %d" % [Defs.RES_NAMES[e.res_type], int(e.amount)]
		status_label.text = "Cidadãos coletam aqui."
		_fill_box(queue_box, "", func(): pass)
		return
	if e.is_unit():
		var atk: float = float(e.def["atk"]) * (1.0 + (Defs.EPOCH_MILITARY_BONUS * (game.players[e.owner_id].epoch - 1) if e.is_military() else 0.0))
		stats_label.text = "Ataque %d  ·  Alcance %s  ·  Velocidade %d  ·  Armadura %d" % [int(round(atk)), "corpo a corpo" if e.atk_range() < 3.0 else str(int(e.atk_range())), int(e.def["speed"]), int(e.def["armor"])]
		var st := ""
		match e.state:
			"idle": st = "Ocioso"
			"move": st = "Avançando em formação de ataque" if e.amove else "Em movimento"
			"attack": st = "Atacando"
			"gather": st = "Coletando %s" % Defs.RES_NAMES[e.carry_type] if e.carry_type != "" else "Coletando"
			"return": st = "Levando %d de %s para o depósito" % [int(e.carry_amt), Defs.RES_NAMES.get(e.carry_type, "")]
			"build": st = "Construindo"
			"work": st = "Estudando na Universidade (gera Tecnologia)"
		if e.is_citizen() and e.carry_amt > 0.0 and e.state != "return":
			st += "  (%d/%d)" % [int(e.carry_amt), int(Defs.CARRY)]
		var bon: Array = []
		for c in e.def.get("bonus", {}):
			bon.append(Defs.CLASS_NAMES[c])
		if not bon.is_empty():
			st += "\nForte contra: " + ", ".join(bon)
		status_label.text = st
		_fill_box(queue_box, "", func(): pass)
		return
	# building
	var b = e
	var stat := "Armadura %d" % int(b.def.get("armor", 0))
	if b.def.has("atk"):
		stat += "  ·  Ataque %d  ·  Alcance %d" % [int(b.def["atk"]), int(b.def["range"])]
	if b.def.has("pop"):
		stat += "  ·  População +%d" % int(b.def["pop"])
	stats_label.text = stat
	var lines: Array = []
	var qsig := ""
	if not b.built:
		lines.append("Em construção (%d%%)" % int(b.build_done / float(b.def["time"]) * 100.0))
		prog_bar.visible = true
		prog_bar.value = b.build_done / float(b.def["time"]) * 100.0
	else:
		if not b.queue.is_empty():
			qsig = ",".join(b.queue)
			lines.append("Treinando: %s" % Defs.UNITS[b.queue[0]]["name"])
			prog_bar.visible = true
			prog_bar.value = b.train_time / b.current_train_total() * 100.0
			if b.queue[0] != "citizen" and game.pop_used(b.owner_id) >= game.players[b.owner_id].pop_cap:
				lines.append("Limite de população atingido: construa Casas")
		if b.researching:
			var ep: float = game.epoch_progress(b.owner_id)
			lines.append("Avançando para a %s" % Defs.EPOCHS[game.players[b.owner_id].epoch]["name"])
			prog_bar.visible = true
			prog_bar.value = ep * 100.0
		if b.kind == "university":
			lines.append("Estudiosos: %d/%d (geram Tecnologia)" % [b.workers.size(), Defs.UNIVERSITY_WORKERS])
		if b.kind == "farm":
			lines.append("Fazendeiros: %d/3" % b.workers.size())
		if b.loyalty < 100.0:
			lines.append("Lealdade: %d%%" % int(b.loyalty))
		if b.kind == "city_center" and b.owner_id >= 0:
			lines.append("Território: %s" % game.territory_name(game.territory_at(b.position)))
		if lines.is_empty():
			lines.append(Defs.DESC.get(b.kind, ""))
	status_label.text = "\n".join(lines)
	var team: Color = game.players[b.owner_id].color
	_fill_box(queue_box, qsig if b.owner_id == 0 else "", func():
		for q in b.queue:
			queue_box.add_child(_tile(q, "", team, 28.0)))


# ==================================================================== bars
class Bar extends Control:
	var value := 0.0:
		set(v):
			value = v
			queue_redraw()
	var max_value := 100.0
	var fill := Color(0.25, 0.80, 0.30):
		set(v):
			fill = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var f: float = clamp(value / max(max_value, 0.001), 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.03, 0.04))
		draw_rect(Rect2(Vector2(1, 1), Vector2((size.x - 2) * f, size.y - 2)), fill)
		draw_rect(Rect2(Vector2(1, 1), Vector2((size.x - 2) * f, (size.y - 2) * 0.42)), fill.lightened(0.28))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.9), false, 1.0)


# ==================================================================== minimap
class Minimap extends Control:
	var hud
	var img: Image
	var tex: ImageTexture
	var terr := PackedInt32Array()
	var border := PackedByteArray()
	var img_t := 0.0
	var dragging := false

	func build() -> void:
		var g = hud.game
		terr.resize(Defs.GRID * Defs.GRID)
		border.resize(Defs.GRID * Defs.GRID)
		for y in Defs.GRID:
			for x in Defs.GRID:
				terr[y * Defs.GRID + x] = g.territory_at(g.cell_center(Vector2i(x, y)))
		for y in Defs.GRID:
			for x in Defs.GRID:
				var i := y * Defs.GRID + x
				var b := 0
				if x + 1 < Defs.GRID and terr[i + 1] != terr[i]:
					b = 1
				if y + 1 < Defs.GRID and terr[i + Defs.GRID] != terr[i]:
					b = 1
				border[i] = b
		img = Image.create(Defs.GRID, Defs.GRID, false, Image.FORMAT_RGB8)
		tex = ImageTexture.create_from_image(img)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _refresh_image() -> void:
		var g = hud.game
		for y in Defs.GRID:
			for x in Defs.GRID:
				var i := y * Defs.GRID + x
				var f: int = g.fog[i]
				if f == 0:
					img.set_pixel(x, y, Color(0, 0, 0))
					continue
				var o: int = g.terr_owner[terr[i]]
				var c := Color(0.27, 0.44, 0.17).lerp(Color(0.85, 0.85, 0.9), g.snow)
				if o >= 0:
					c = c.lerp(g.players[o].color, 0.28)
				if border[i] == 1:
					c = g.players[o].color if o >= 0 else Color(0.35, 0.35, 0.45)
				if f == 1:
					c = c.darkened(0.45)
				img.set_pixel(x, y, c)
		tex.update(img)

	func _to_map(p: Vector3) -> Vector2:
		return Vector2(p.x, p.z) / Defs.MAP_SIZE * size

	func _draw() -> void:
		var g = hud.game
		img_t -= 0.2
		if img_t <= 0.0:
			img_t = 0.6
			_refresh_image()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0))
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
		for r in g.resources:
			if r.visible and r.kind != "tree":
				draw_rect(Rect2(_to_map(r.position) - Vector2(1, 1), Vector2(2, 2)),
					Color(1, 0.85, 0.2) if r.kind == "gold" else (Color(0.8, 0.8, 0.8) if r.kind == "stone" else Color(0.9, 0.4, 0.3)))
		for b in g.buildings:
			if b.visible:
				var s: float = max(3.0, b.size_m / Defs.MAP_SIZE * size.x)
				draw_rect(Rect2(_to_map(b.position) - Vector2(s, s) * 0.5, Vector2(s, s)), g.players[b.owner_id].color.lightened(0.15))
		for u in g.units:
			if u.visible:
				draw_rect(Rect2(_to_map(u.position) - Vector2(1.5, 1.5), Vector2(3, 3)), g.players[u.owner_id].color.lightened(0.3))
		# camera view
		var cam: CameraRig = g.cam
		var vs := get_viewport().get_visible_rect().size
		var pts := PackedVector2Array()
		for sp in [Vector2(0, 44), Vector2(vs.x, 44), Vector2(vs.x, vs.y - 178), Vector2(0, vs.y - 178)]:
			var w = cam.ground_at(sp)
			if w != null:
				pts.append(_to_map(w))
		if pts.size() == 4:
			pts.append(pts[0])
			draw_polyline(pts, Color(1, 1, 1, 0.9), 1.0)
		for pg in hud.pings:
			var c := _to_map(pg["pos"])
			draw_arc(c, 4.0 + (3.0 - pg["t"]) * 6.0, 0, TAU, 20, Color(1, 0.3, 0.2), 2.0)
		draw_rect(Rect2(Vector2.ZERO, size), Defs.TEAM_COLORS[0].lerp(Color(0.6, 0.5, 0.3), 0.7), false, 2.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			if event.pressed:
				_jump(event.position)
			accept_event()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var w := Vector3(event.position.x / size.x * Defs.MAP_SIZE, 0, event.position.y / size.y * Defs.MAP_SIZE)
			hud.controls.issue_command(null, w)
			accept_event()
		elif event is InputEventMouseMotion and dragging:
			_jump(event.position)
			accept_event()

	func _jump(p: Vector2) -> void:
		var w := Vector3(p.x / size.x * Defs.MAP_SIZE, 0, p.y / size.y * Defs.MAP_SIZE)
		hud.game.cam.look_at_point(w)


# ==================================================================== overlay
class Overlay extends Control:
	var hud

	func _bar(sp: Vector2, w: float, f: float, c: Color, h := 5.0) -> void:
		var r := Rect2(sp - Vector2(w * 0.5, 0), Vector2(w, h))
		draw_rect(r.grow(1.0), Color(0, 0, 0, 0.75))
		draw_rect(Rect2(r.position, Vector2(w * f, h)), c)
		draw_rect(Rect2(r.position, Vector2(w * f, h * 0.4)), c.lightened(0.35))

	func _draw() -> void:
		var g = hud.game
		if g == null or g.cam == null:
			return
		var cam: Camera3D = g.cam.cam
		var list: Array = []
		for u in g.units:
			if u.visible and (u.selected or u.hp < u.max_hp):
				list.append(u)
		for b in g.buildings:
			if b.visible and (b.selected or b.hp < b.max_hp or not b.built or not b.queue.is_empty()):
				list.append(b)
		for e in g.selected:
			if is_instance_valid(e) and e.is_resource() and e.visible:
				list.append(e)
		for e in list:
			var top: float = 2.3 if e.is_unit() else (8.6 if e.kind in ["city_center", "tower"] else 5.0)
			if e.is_unit() and e.kind == "cavalry":
				top = 3.0
			var wp: Vector3 = e.position + Vector3(0, top, 0)
			if cam.is_position_behind(wp):
				continue
			var sp := cam.unproject_position(wp)
			var w: float = 30.0 if e.is_unit() else 64.0
			var f: float = clamp(e.hp / max(e.max_hp, 1.0), 0.0, 1.0)
			var c := Color(0.25, 0.88, 0.3) if f > 0.5 else (Color(0.95, 0.8, 0.2) if f > 0.25 else Color(0.95, 0.25, 0.2))
			if e.is_resource():
				c = Color(0.95, 0.85, 0.3)
			if e.owner_id > 0:
				c = c.lerp(g.players[e.owner_id].color, 0.35)
			_bar(sp, w, f, c, 4.0 if e.is_unit() else 5.0)
			if e.is_building():
				var y := 8.0
				if e.loyalty < 100.0:
					_bar(sp + Vector2(0, y), w, e.loyalty / 100.0, Color(0.45, 0.65, 1.0), 3.0)
					y += 6.0
				if e.owner_id == 0:
					if not e.built:
						_bar(sp + Vector2(0, y), w, e.build_done / float(e.def["time"]), Color(0.9, 0.9, 0.95), 3.0)
					elif not e.queue.is_empty():
						_bar(sp + Vector2(0, y), w, e.train_time / e.current_train_total(), Color(0.45, 0.75, 1.0), 3.0)
						Icons.paint(self, e.queue[0], Rect2(sp + Vector2(-w * 0.5 - 20, y - 8), Vector2(16, 16)), g.players[0].color)
		var ct = hud.controls
		if ct.box_active:
			var r := Rect2(ct.drag_start, ct.drag_now - ct.drag_start).abs()
			draw_rect(r, Color(0.3, 1, 0.4, 0.10))
			draw_rect(r, Color(0.4, 1, 0.5, 0.95), false, 1.5)
		if ct.attack_mode:
			var mp := get_viewport().get_mouse_position()
			Icons.paint(self, "attack", Rect2(mp + Vector2(12, 12), Vector2(22, 22)))
		# rally flags of selected buildings
		for e in g.selected:
			if is_instance_valid(e) and e.is_building() and e.owner_id == 0 and e.has_rally:
				var rp: Vector3 = e.rally + Vector3(0, 0.1, 0)
				if not cam.is_position_behind(rp):
					var s := cam.unproject_position(rp)
					var from := cam.unproject_position(e.position)
					draw_dashed_line(from, s, Color(1, 1, 1, 0.45), 1.5, 6.0)
					draw_line(s, s + Vector2(0, -22), Color(0.95, 0.95, 0.95), 2.0)
					draw_colored_polygon(PackedVector2Array([s + Vector2(1, -22), s + Vector2(15, -17), s + Vector2(1, -12)]), Defs.TEAM_COLORS[0].lightened(0.2))
