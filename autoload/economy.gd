extends Node

# --- simple built-in weapon data (we'll move to JSON later)
const DEFAULT_WEAPON := "sword"
var weapons := {
	"sword": {"base_dps": 4.0, "fire_interval": 0.7, "tag": "sword", "melee_min": 1, "melee_max": 4, "attack_bonus": 5},
	"bow":  {"base_dps": 5.0, "fire_interval": 0.6, "tag": "bow",  "melee_min": 1, "melee_max": 3, "attack_bonus": 0},
	"wand": {"base_dps": 5.0, "fire_interval": 0.7, "tag": "wand", "melee_min": 1, "melee_max": 3, "attack_bonus": 0}
}

# --- run-time knobs (reset on ascend)
var add_dmg: float = 0.0
var dmg_mult: float = 1.0
var fire_interval_mult: float = 1.0

func prestige_mult_damage() -> float:
	return 1.0 + 0.12 * float(State.sigils)

func class_mastery_mult() -> float:
	var c = State.chosen_class
	if c == "": 
		return 1.0
	var m = State.class_mastery.get(c, {"dmg_mult": 1.0})
	return float(m.dmg_mult)

func current_weapon_id() -> String:
	var id = State.chosen_weapon
	if id == "" or not weapons.has(id):
		return DEFAULT_WEAPON
	return id

func current_weapon() -> Dictionary:
	return weapons[current_weapon_id()]

func dps() -> float:
	var w := current_weapon()
	var base := float(w.base_dps) + add_dmg
	return max(base * dmg_mult * class_mastery_mult() * prestige_mult_damage(), 0.1)

func shots_per_second() -> float:
	var w := current_weapon()
	return 1.0 / (float(w.fire_interval) * fire_interval_mult)

func weapon_attack_bonus() -> int:
	return int(current_weapon().get("attack_bonus", 0))

func weapon_melee_range() -> Vector2i:
	var w := current_weapon()
	var base_min := int(w.get("melee_min", 1))
	var base_max := int(w.get("melee_max", max(1, base_min)))
	if base_max < base_min:
		base_max = base_min
	return Vector2i(base_min, base_max)
