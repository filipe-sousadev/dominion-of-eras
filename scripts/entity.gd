class_name Entity
extends Node3D
## Base of every thing on the map: units, buildings and resources.

var game  # Game
var kind := ""
var owner_id := -1          # -1 = nature
var hp := 1.0
var max_hp := 1.0
var radius := 0.5
var dead := false
var selected := false
var sel_ring: MeshInstance3D
var model: Node3D
var seen := false           # has the human player ever seen it

func is_unit() -> bool:
	return false

func is_building() -> bool:
	return false

func is_resource() -> bool:
	return false

func display_name() -> String:
	return kind.capitalize()

func pos2() -> Vector2:
	return Vector2(position.x, position.z)

## Distance from a point to this entity's edge (on the ground plane).
func edge_distance(p: Vector3) -> float:
	return max(0.0, Vector2(p.x - position.x, p.z - position.z).length() - radius)

func set_selected(v: bool) -> void:
	selected = v
	if sel_ring:
		sel_ring.visible = v

func make_ring(c: Color) -> void:
	sel_ring = Meshes.ring(radius + 0.3, c)
	sel_ring.visible = false
	add_child(sel_ring)

func take_damage(amount: float, attacker) -> void:
	if dead:
		return
	hp -= amount
	if game:
		game.on_damaged(self, attacker)
	if hp <= 0.0:
		hp = 0.0
		die(attacker)

func die(_attacker) -> void:
	if dead:
		return
	dead = true
	if game:
		game.on_entity_died(self, _attacker)
	queue_free()

func tick(_delta: float) -> void:
	pass
