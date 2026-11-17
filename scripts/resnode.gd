class_name ResNode
extends Entity
## A tree, berry bush, cattle, stone or gold deposit.

var amount := 100.0
var res_type := "wood"
var cell := Vector2i.ZERO

func is_resource() -> bool:
	return true

func setup(g, k: String, p: Vector3, rng: RandomNumberGenerator) -> void:
	game = g
	kind = k
	res_type = Defs.NODE_RES[k]
	amount = Defs.NODE_AMOUNT[k]
	max_hp = amount
	hp = amount
	position = p
	radius = 1.0
	model = Meshes.resource_model(k, rng)
	model.rotation.y = rng.randf() * TAU
	add_child(model)
	make_ring(Color(0.95, 0.85, 0.2))

func display_name() -> String:
	match kind:
		"tree": return "Árvore"
		"berries": return "Arbusto de Frutas"
		"cattle": return "Gado Selvagem"
		"stone": return "Jazida de Pedra"
		"gold": return "Jazida de Ouro"
	return kind.capitalize()

## Takes up to `want` from the deposit and returns how much was taken.
func take(want: float) -> float:
	var got: float = min(want, amount)
	amount -= got
	hp = amount
	if amount <= 0.0 and not dead:
		dead = true
		game.on_resource_depleted(self)
		queue_free()
	return got
