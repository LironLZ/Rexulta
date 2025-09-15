extends Node

# --- simple built-in weapon data (we'll move to JSON later)
var weapons := {
	"bow":  {"base_dps": 5.0, "fire_interval": 0.6, "tag": "bow"},
	"wand": {"base_dps": 5.0, "fire_interval": 0.7, "tag": "wand"}
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

func current_weapon() -> Dictionary:
	var id = State.chosen_weapon
	if id == "" or not weapons.has(id):
		return weapons["bow"]
	return weapons[id]

func dps() -> float:
	var w := current_weapon()
	var base := float(w.base_dps) + add_dmg
	return max(base * dmg_mult * class_mastery_mult() * prestige_mult_damage(), 0.1)

func shots_per_second() -> float:
	var w := current_weapon()
	return 1.0 / (float(w.fire_interval) * fire_interval_mult)
