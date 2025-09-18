extends Node

# -------- Run layer (resets on Ascend) --------
var gold := 0.0
var xp := 0.0
var level := 1
var chosen_weapon := ""   # "bow" | "wand" (for now)
var chosen_class := ""    # set at Lv10 each run
var fish := 0
var ore := 0
var mode := "arena"       # "arena" | "fishing" | "mining"

# -------- Unlocks (UI gating) --------
signal unlocks_changed
var fishing_unlocked := false
var mining_unlocked := false
var ascend_unlocked := false

# -------- Meta (persists) --------
var lifetime_xp := 0.0
var run_xp := 0.0         # XP earned this run only (for class marks)
var sigils := 0
var class_marks := {"warrior":0, "archer":0, "mage":0, "rogue":0, "fighter":0}
var class_mastery := {
	"warrior": {"dmg_mult": 1.0},
	"archer":  {"dmg_mult": 1.0},
	"mage":    {"dmg_mult": 1.0},
	"rogue":   {"dmg_mult": 1.0},
	"fighter": {"dmg_mult": 1.0}
}

# -------- Save / offline --------
var _save_path := "user://save.json"
var last_save_unix := 0

signal level_up(new_level)
signal class_ready()
signal mode_changed(new_mode)

func _ready():
	load_save()
	_maybe_emit_class_ready()

# ================= Leveling =================
func xp_to_level(n):
	return int(floor(30.0 * pow(n, 2.2)))  # quick to 10

func add_xp(amount):
	xp += amount
	lifetime_xp += amount
	run_xp += amount
	_check_level()
	_maybe_gain_sigil()
	_maybe_emit_class_ready()
	save()

func _check_level():
	var need = xp_to_level(level)
	while xp >= need:
		xp -= need
		level += 1
		emit_signal("level_up", level)
		need = xp_to_level(level)

func _maybe_emit_class_ready():
	if level >= 10 and chosen_class == "":
		emit_signal("class_ready")

# ================= Choices =================
func choose_weapon(id):
	chosen_weapon = id
	save()

func choose_class(id):
	chosen_class = id
	save()

# ================= Unlocks =================
func set_unlocks(fishing: Variant = null, mining: Variant = null, ascend_unl: Variant = null) -> void:
	var changed := false
	if fishing != null and fishing_unlocked != fishing:
		fishing_unlocked = fishing
		changed = true
	if mining != null and mining_unlocked != mining:
		mining_unlocked = mining
		changed = true
	if ascend_unl != null and ascend_unlocked != ascend_unl:
		ascend_unlocked = ascend_unl
		changed = true
	if changed:
		emit_signal("unlocks_changed")
		save()



# ================= Modes (for fishing/mining/arena) =================
func set_mode(new_mode: String) -> void:
	var allowed := ["arena", "fishing", "mining"]
	if not allowed.has(new_mode):
		push_warning("State.set_mode: unknown mode '%s'" % new_mode)
		return
	if mode == new_mode:
		return
	mode = new_mode
	emit_signal("mode_changed", mode)
	save()

# ================= Ascension =================
func ascend():
	# grant per-class marks based on this run's XP
	if chosen_class != "":
		var gained := int(floor(pow(max(0.0, run_xp / 30_000.0), 0.5)))
		class_marks[chosen_class] += max(gained, 0)
		# simple mastery: +3% dmg per mark
		class_mastery[chosen_class].dmg_mult = 1.0 + 0.03 * float(class_marks[chosen_class])

	# reset run layer
	gold = 0
	fish = 0
	ore = 0
	xp = 0
	run_xp = 0
	level = 1
	chosen_weapon = ""
	chosen_class = ""
	mode = "arena"
	save()

# ================= Meta =================
func _maybe_gain_sigil():
	# Sigils scale with lifetime XP (sqrt), +12% dmg each (used in Economy)
	var target := int(floor(pow(max(0.0, lifetime_xp / 50_000.0), 0.5)))
	if target > sigils:
		sigils = target

# ================= Save / Load / Offline =================
func save():
	var data = {
		# run
		"gold": gold, "xp": xp, "level": level,
		"fish": fish, "ore": ore, "mode": mode,
		# unlocks
		"fishing_unlocked": fishing_unlocked,
		"mining_unlocked": mining_unlocked,
		"ascend_unlocked": ascend_unlocked,
		# meta
		"lifetime_xp": lifetime_xp, "run_xp": run_xp, "sigils": sigils,
		"class_marks": class_marks, "class_mastery": class_mastery,
		"chosen_weapon": chosen_weapon, "chosen_class": chosen_class,
		# timestamp
		"last_save_unix": Time.get_unix_time_from_system()
	}
	var f = FileAccess.open(_save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))

func load_save():
	if not FileAccess.file_exists(_save_path):
		return
	var f = FileAccess.open(_save_path, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return

	# run
	gold = float(data.get("gold", 0))
	xp = float(data.get("xp", 0))
	level = int(data.get("level", 1))
	fish = int(data.get("fish", 0))
	ore = int(data.get("ore", 0))
	mode = String(data.get("mode", "arena"))

	# unlocks
	fishing_unlocked = bool(data.get("fishing_unlocked", false))
	mining_unlocked  = bool(data.get("mining_unlocked", false))
	ascend_unlocked  = bool(data.get("ascend_unlocked", false))

	# meta
	lifetime_xp = float(data.get("lifetime_xp", 0))
	run_xp = float(data.get("run_xp", 0))
	sigils = int(data.get("sigils", 0))
	class_marks = data.get("class_marks", class_marks)
	class_mastery = data.get("class_mastery", class_mastery)
	chosen_weapon = String(data.get("chosen_weapon", ""))
	chosen_class  = String(data.get("chosen_class", ""))
	last_save_unix = int(data.get("last_save_unix", 0))

	# Offline catch-up (starter): cap at 6h; simulate based on mode at last save
	var dt = max(0, Time.get_unix_time_from_system() - last_save_unix)
	var capped = min(dt, 6 * 3600)
	if capped > 0:
		match mode:
			"arena":
				gold += 0.5 * float(capped)   # ~0.5 gold/sec placeholder
			"fishing":
				fish += int(floor(0.2 * float(capped)))  # ~1 per 5s
			"mining":
				ore += int(floor(0.2 * float(capped)))   # ~1 per 5s
	# sanitize mode if save had junk
	var allowed := ["arena", "fishing", "mining"]
	if not allowed.has(mode):
		mode = "arena"
