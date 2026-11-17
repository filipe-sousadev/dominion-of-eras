class_name Defs
extends RefCounted
## All the numbers that shape how the game plays. Mirrors MECHANICS.md / mechanics.json.

const MAP_SIZE := 160.0          # metres, square map
const CELL := 2.0                # path-finding cell size (metres)
const GRID := 80                 # MAP_SIZE / CELL
const SPEED_SCALE := 0.3         # panel speed value -> metres per second
const MONTH_SECONDS := 54.0      # one calendar month of game time
const START_MONTH := 5           # June (0 = January)
const MONTHS := ["Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho", "Julho",
	"Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"]
const WINTER_MONTHS := [11, 0, 1]
const WINTER_SPEED := 0.909      # 11 -> 10 speed points in February (reference/picture-143.jpg)
const WINTER_FOOD := 0.75

const RES := ["food", "wood", "stone", "gold", "tech"]
const RES_SHORT := {"food": "C", "wood": "M", "stone": "P", "gold": "O", "tech": "T"}
const RES_NAMES := {"food": "Comida", "wood": "Madeira", "stone": "Pedra", "gold": "Ouro", "tech": "Tecnologia"}
const START_RES_LEVELS := {"Baixo": 1.0, "Padrão": 2.0, "Alto": 5.0}
const START_RES := {"food": 200, "wood": 200, "stone": 100, "gold": 100, "tech": 100}
const START_CITIZENS := 6
const POP_LIMIT := 200
const CARRY := 10.0
const BUILD_RATE := 1.0          # build seconds removed per second per builder
const UNIVERSITY_WORKERS := 5

const GATHER := {"berries": 0.8, "cattle": 1.0, "farm": 0.6, "tree": 0.7, "stone": 0.5,
	"gold": 0.5, "university": 0.4}
const NODE_RES := {"berries": "food", "cattle": "food", "farm": "food", "tree": "wood",
	"stone": "stone", "gold": "gold", "university": "tech"}
const NODE_AMOUNT := {"berries": 200, "cattle": 150, "tree": 100, "stone": 400, "gold": 400}

const EPOCHS := [
	{"name": "Idade da Pedra", "cost": {}, "time": 0},
	{"name": "Idade do Cobre", "cost": {"food": 300, "gold": 100, "tech": 150}, "time": 40},
	{"name": "Idade do Bronze", "cost": {"food": 500, "gold": 250, "tech": 300}, "time": 60},
	{"name": "Idade do Ferro", "cost": {"food": 800, "gold": 400, "tech": 500}, "time": 80},
	{"name": "Era Clássica", "cost": {"food": 1200, "gold": 600, "tech": 800}, "time": 100},
]
const EPOCH_MILITARY_BONUS := 0.10   # +10 % hit points and attack per era above the first
const EPOCH_GATHER_BONUS := 0.05     # +5 % gathering per era above the first

const UNITS := {
	"citizen": {"name": "Cidadão", "hp": 30, "atk": 5, "range": 1.2, "rate": 1.5, "speed": 11,
		"sight": 10, "armor": 0, "cls": "civil", "cost": {"food": 50}, "time": 12, "epoch": 1,
		"bonus": {}},
	"spearman": {"name": "Lanceiro", "hp": 60, "atk": 6, "range": 1.4, "rate": 1.5, "speed": 11,
		"sight": 12, "armor": 1, "cls": "infantry", "cost": {"food": 30, "wood": 20}, "time": 15,
		"epoch": 1, "bonus": {"cavalry": 3.0}},
	"swordsman": {"name": "Espadachim", "hp": 80, "atk": 9, "range": 1.2, "rate": 1.5, "speed": 10,
		"sight": 12, "armor": 2, "cls": "infantry", "cost": {"food": 40, "gold": 30}, "time": 18,
		"epoch": 1, "bonus": {"infantry": 1.5, "building": 1.5}},
	"archer": {"name": "Arqueiro", "hp": 45, "atk": 7, "range": 12.0, "rate": 2.0, "speed": 11,
		"sight": 14, "armor": 0, "cls": "ranged", "cost": {"wood": 30, "gold": 30}, "time": 16,
		"epoch": 1, "bonus": {"infantry": 1.5}},
	"cavalry": {"name": "Cavaleiro", "hp": 110, "atk": 10, "range": 1.5, "rate": 1.7, "speed": 16,
		"sight": 14, "armor": 2, "cls": "cavalry", "cost": {"food": 60, "gold": 50}, "time": 22,
		"epoch": 2, "bonus": {"ranged": 2.0, "siege": 2.0}},
	"catapult": {"name": "Catapulta", "hp": 120, "atk": 10, "range": 16.0, "rate": 4.0, "speed": 7,
		"sight": 14, "armor": 3, "cls": "siege", "cost": {"wood": 100, "gold": 80}, "time": 30,
		"epoch": 3, "bonus": {"building": 4.0}, "splash": 2.0},
}

# size is in path cells (CELL metres each)
const BUILDINGS := {
	"city_center": {"name": "Centro da Cidade", "hp": 1500, "cost": {"wood": 300, "stone": 200},
		"size": 4, "time": 60, "pop": 10, "trains": ["citizen"], "dropsite": true, "sight": 18,
		"atk": 4, "range": 14.0, "rate": 2.0, "epoch": 1, "capturable": true, "armor": 5},
	"house": {"name": "Casa", "hp": 300, "cost": {"wood": 50}, "size": 2, "time": 20, "pop": 10,
		"sight": 8, "epoch": 1, "armor": 3},
	"farm": {"name": "Fazenda", "hp": 200, "cost": {"wood": 60}, "size": 3, "time": 15, "sight": 6,
		"epoch": 1, "walkable": true, "armor": 0},
	"storehouse": {"name": "Armazém", "hp": 400, "cost": {"wood": 80}, "size": 2, "time": 20,
		"dropsite": true, "sight": 8, "epoch": 1, "armor": 3},
	"barracks": {"name": "Quartel", "hp": 800, "cost": {"wood": 150}, "size": 3, "time": 35,
		"trains": ["spearman", "swordsman"], "sight": 10, "epoch": 1, "armor": 4},
	"archery": {"name": "Arquearia", "hp": 700, "cost": {"wood": 150}, "size": 3, "time": 35,
		"trains": ["archer"], "sight": 10, "epoch": 1, "armor": 4},
	"stable": {"name": "Estábulo", "hp": 800, "cost": {"wood": 175, "gold": 50}, "size": 3,
		"time": 40, "trains": ["cavalry"], "sight": 10, "epoch": 2, "armor": 4},
	"workshop": {"name": "Oficina de Cerco", "hp": 800, "cost": {"wood": 200, "stone": 100},
		"size": 3, "time": 45, "trains": ["catapult"], "sight": 10, "epoch": 3, "armor": 4},
	"university": {"name": "Universidade", "hp": 900, "cost": {"wood": 150, "stone": 100},
		"size": 3, "time": 45, "sight": 10, "epoch": 1, "capturable": true, "armor": 4},
	"tower": {"name": "Torre", "hp": 600, "cost": {"wood": 75, "stone": 100}, "size": 1,
		"time": 30, "sight": 18, "atk": 8, "range": 16.0, "rate": 2.0, "epoch": 1, "armor": 5},
}
const BUILD_MENU := ["house", "farm", "storehouse", "barracks", "archery", "stable", "workshop",
	"university", "tower", "city_center"]

# Capture of City Centers and Universities by enemy foot and horse soldiers
const CAPTURE_RADIUS := 10.0
const CAPTURE_RATE := 2.0        # loyalty % lost per second per capturing unit
const CAPTURE_MAX_RATE := 8.0
const LOYALTY_REGEN := 1.0       # % per second when nobody captures

# Crowns
const CROWN_MILITARY_KILLS := 25
const CROWN_ECONOMIC_GATHERED := 3000
const CROWN_IMPERIAL_EPOCH := 3
const CROWN_MILITARY_BONUS := 0.10
const CROWN_ECONOMIC_BONUS := 0.10
const CROWN_IMPERIAL_BONUS := 0.15

const TEAM_COLORS := [Color(0.15, 0.32, 0.95), Color(0.88, 0.14, 0.10), Color(0.95, 0.80, 0.10),
	Color(0.55, 0.20, 0.80)]
const TEAM_NAMES := ["Você", "Aldric", "Morwen", "Tobias"]

const TERRITORY_NAMES := ["Vale das Cinzas", "Charneca Rubra", "Colinas do Falcão", "Lagoa Sombria",
	"Riacho de Pedra", "Campos do Oeste", "Prado das Flores", "Mata de Ferro", "Águas Cinzentas",
	"Campo dos Espinhos", "Bosque do Carvalho", "Várzea Clara", "Marca do Pousio", "Monte Alto",
	"Vale da Névoa", "Olmeiral"]

## Computer players. Keys are internal; "label" is what the player reads.
##  gather: gathering multiplier · first_attack: seconds before the first wave · wave: soldiers in it
##  wave_step / wave_max: growth per wave · wave_every: seconds between waves · citizens: worker target
##  think: seconds between decisions · bases: City Centers it wants · expand_at: when it starts expanding
##  The flags switch tactics on: counter (answers your army mix), regroup (gathers before marching),
##  retreat (pulls back from lost fights), focus (picks targets by class and health), flee (workers run
##  from raids), pick_weak (attacks the weakest rival), harass (cavalry raids on workers),
##  towers (towers per town).
const DIFFICULTY_ORDER := ["Easy", "Normal", "Hard", "Brutal", "Insane"]
const DIFFICULTY := {
	"Easy": {"label": "Fácil", "gather": 0.75, "first_attack": 660.0, "wave": 5, "wave_step": 2,
		"wave_max": 14, "wave_every": 210.0, "citizens": 16, "think": 2.0, "bases": 1, "expand_at": 900.0,
		"mil_scale": 0.7, "counter": false, "regroup": false, "retreat": false, "focus": false,
		"flee": false, "pick_weak": false, "harass": false, "towers": 0,
		"desc": "Rival lento e desatento. Ideal para aprender."},
	"Normal": {"label": "Normal", "gather": 1.0, "first_attack": 420.0, "wave": 9, "wave_step": 3,
		"wave_max": 28, "wave_every": 160.0, "citizens": 24, "think": 1.0, "bases": 2, "expand_at": 360.0,
		"mil_scale": 1.0, "counter": true, "regroup": true, "retreat": false, "focus": false,
		"flee": true, "pick_weak": false, "harass": false, "towers": 1,
		"desc": "Joga de forma equilibrada: reúne o exército e responde às suas tropas."},
	"Hard": {"label": "Difícil", "gather": 1.1, "first_attack": 330.0, "wave": 12, "wave_step": 4,
		"wave_max": 36, "wave_every": 135.0, "citizens": 30, "think": 1.0, "bases": 3, "expand_at": 270.0,
		"mil_scale": 1.25, "counter": true, "regroup": true, "retreat": true, "focus": true,
		"flee": true, "pick_weak": true, "harass": false, "towers": 2,
		"desc": "Recua de lutas perdidas, concentra o ataque e mira no rival mais fraco."},
	"Brutal": {"label": "Brutal", "gather": 1.25, "first_attack": 260.0, "wave": 14, "wave_step": 5,
		"wave_max": 46, "wave_every": 110.0, "citizens": 36, "think": 0.5, "bases": 4, "expand_at": 210.0,
		"mil_scale": 1.5, "counter": true, "regroup": true, "retreat": true, "focus": true,
		"flee": true, "pick_weak": true, "harass": true, "towers": 3,
		"desc": "Economia acelerada, expansão rápida e cavalaria caçando seus cidadãos."},
	"Insane": {"label": "Insano", "gather": 1.5, "first_attack": 200.0, "wave": 16, "wave_step": 6,
		"wave_max": 60, "wave_every": 90.0, "citizens": 44, "think": 0.5, "bases": 5, "expand_at": 150.0,
		"mil_scale": 1.9, "counter": true, "regroup": true, "retreat": true, "focus": true,
		"flee": true, "pick_weak": true, "harass": true, "towers": 4,
		"desc": "Sem piedade: ataca cedo, em massa e sem parar. Só para veteranos."},
}

## One-line descriptions shown in the tooltips.
const DESC := {
	"citizen": "Coleta recursos, constrói e conserta.",
	"spearman": "Infantaria barata. Forte contra cavalaria.",
	"swordsman": "Infantaria pesada. Forte contra infantaria e construções.",
	"archer": "Ataca de longe. Forte contra infantaria, fraco contra cavalaria.",
	"cavalry": "Rápido. Forte contra arqueiros e armas de cerco.",
	"catapult": "Arma de cerco. Destrói construções; dano em área.",
	"city_center": "Treina cidadãos, recebe recursos e domina o território.",
	"house": "Aumenta o limite de população em 10.",
	"farm": "Comida infinita para até 3 fazendeiros.",
	"storehouse": "Ponto de entrega de recursos.",
	"barracks": "Treina lanceiros e espadachins.",
	"archery": "Treina arqueiros.",
	"stable": "Treina cavaleiros.",
	"workshop": "Constrói catapultas.",
	"university": "Até 5 estudiosos geram Tecnologia.",
	"tower": "Dispara flechas nos inimigos próximos.",
}
const CLASS_NAMES := {"civil": "civis", "infantry": "infantaria", "ranged": "arqueiros",
	"cavalry": "cavalaria", "siege": "cerco", "building": "construções"}
const CROWN_NAMES := {"military": "Coroa Militar", "economic": "Coroa Econômica", "imperial": "Coroa Imperial"}
const CROWN_DESC := {"military": "+10% de ataque", "economic": "+10% de coleta",
	"imperial": "+15% de velocidade de construção e treino"}

static func can_afford(res: Dictionary, cost: Dictionary) -> bool:
	for k in cost:
		if res.get(k, 0.0) < cost[k]:
			return false
	return true

static func cost_text(cost: Dictionary) -> String:
	var parts := []
	for k in RES:
		if cost.has(k):
			parts.append("%d%s" % [int(cost[k]), RES_SHORT[k]])
	return " ".join(parts)

static func missing_text(res: Dictionary, cost: Dictionary) -> String:
	var parts := []
	for k in RES:
		if cost.has(k) and res.get(k, 0.0) < cost[k]:
			parts.append(RES_NAMES[k])
	return ", ".join(parts)
