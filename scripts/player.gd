class_name PlayerData
extends RefCounted

var id := 0
var name := ""
var color := Color.WHITE
var is_ai := false
var res := {}
var epoch := 1
var pop_cap := 0
var kills := 0
var gathered := 0.0
var crowns := {}             # "military" / "economic" / "imperial" -> true
var alive := true
var ai = null
var difficulty := "Normal"
var start_pos := Vector3.ZERO

func _init(i: int, ai_player: bool) -> void:
	id = i
	is_ai = ai_player
	name = Defs.TEAM_NAMES[i]
	color = Defs.TEAM_COLORS[i]
	res = Defs.START_RES.duplicate()
	for k in res:
		res[k] = float(res[k])

func pay(cost: Dictionary) -> bool:
	if not Defs.can_afford(res, cost):
		return false
	for k in cost:
		res[k] -= cost[k]
	return true

func refund(cost: Dictionary) -> void:
	for k in cost:
		res[k] += cost[k]
