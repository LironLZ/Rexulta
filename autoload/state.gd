extends Node

# -------- Run layer (resets on Ascend) --------
var gold := 0.0
var xp := 0.0
var level := 1
var chosen_weapon := ""   # weapon id (see Economy.weapons)
var chosen_class := ""    # set at Lv10 each run
var fish := 0
var ore := 0
var mode := "arena"       # "arena" | "fishing" | "mining"

# -------- Unlocks (UI gating) --------
signal unlocks_changed
var fishing_unlocked := false
var mining_unlocked := false
var ascend_unlocked := false

# -------- Meta (persists across runs) --------
var lifetime_xp := 0.0
var run_xp := 0.0
var sigils := 0
var class_marks := {"warrior":0, "archer":0, "mage":0, "rogue":0, "fighter":0}
var class_mastery := {
	"warrior": {"dmg_mult": 1.0},
	"archer":  {"dmg_mult": 1.0},
	"mage":    {"dmg_mult": 1.0},
	"rogue":   {"dmg_mult": 1.0},
	"fighter": {"dmg_mult": 1.0}
}

# -------- Character sheet (run-layer) --------
signal ability_points_changed(remaining: int)
signal skill_points_changed(remaining: int)
signal attribute_changed(key: String, total_value: int)
signal skill_changed(skill_id: String, rank: int)

var ability_points: int = 0
var skill_points: int = 0

const ABILITY_POINTS_PER_LEVEL := 5
const SKILL_POINTS_START_LEVEL := 10
const SKILL_POINTS_PER_LEVEL   := 1

# NOTE: We keep internal keys the same, only the user-facing names change
var attributes := {
	"attack":  {"name":"Attack",       "base": 0, "alloc": 0, "max_alloc": 200, "desc": "Increases damage."},
	"dex":     {"name":"Dexterity",    "base": 0, "alloc": 0, "max_alloc": 200, "desc": "Affects crit & speed."},
	"defense": {"name":"Defence",      "base": 0, "alloc": 0, "max_alloc": 200, "desc": "Reduces damage taken."},
	"magic":   {"name":"Intelligence", "base": 0, "alloc": 0, "max_alloc": 200, "desc": "Boosts magic power."},
}

const ATTACK_DAMAGE_PER_POINT := 0.10
const BASE_CRIT_CHANCE := 0.05
const CRIT_PER_DEX := 0.001

func get_attr_total(key: String) -> int:
	var a = attributes.get(key)
	return 0 if a == null else int(a.base + a.alloc)

func can_alloc_attr(key: String, delta: int) -> bool:
	var a = attributes.get(key)
	if a == null: return false
	if delta > 0:
		return ability_points >= delta and a.alloc + delta <= a.max_alloc
	else:
		return a.alloc + delta >= 0

func add_attr_alloc(key: String, delta: int) -> bool:
	if delta == 0: return true
	if not can_alloc_attr(key, delta): return false
	attributes[key].alloc += delta
	ability_points -= delta
	ability_points_changed.emit(ability_points)
	attribute_changed.emit(key, get_attr_total(key))
	save()
	return true

func refund_attr_alloc(key: String, amount: int = 1) -> bool:
	var a = attributes.get(key)
	if a == null or amount <= 0: return false
	var take = min(amount, a.alloc)
	if take <= 0: return false
	a.alloc -= take
	ability_points += take
	ability_points_changed.emit(ability_points)
	attribute_changed.emit(key, get_attr_total(key))
	save()
	return true

# -------- Skills (example tree) --------
var player_class := "Warrior"
var skills := {
	"power_strike": {"name":"Power Strike", "max": 5, "rank": 0, "desc":"+% melee damage",         "requires":[]},
	"iron_skin":    {"name":"Iron Skin",    "max": 5, "rank": 0, "desc":"-% damage taken",          "requires":[{"id":"power_strike","rank":2}]},
	"battle_cry":   {"name":"Battle Cry",   "max": 3, "rank": 0, "desc":"+party atk (active buff)", "requires":[{"id":"iron_skin","rank":3}]},
}

func _meets_skill_reqs(skill_id: String) -> bool:
	var s = skills.get(skill_id)
	if s == null: return false
	for req in s.requires:
		var have = skills.get(req.id, null)
		if have == null or have.rank < int(req.rank):
			return false
	return true

func can_raise_skill(skill_id: String) -> bool:
	var s = skills.get(skill_id)
	if s == null: return false
	if s.rank >= s.max: return false
	if skill_points <= 0: return false
	return _meets_skill_reqs(skill_id)

func raise_skill(skill_id: String) -> bool:
	if not can_raise_skill(skill_id): return false
	skills[skill_id].rank += 1
	skill_points -= 1
	skill_changed.emit(skill_id, skills[skill_id].rank)
	skill_points_changed.emit(skill_points)
	save()
	return true

func refund_skill(skill_id: String, ranks: int = 1) -> bool:
	var s = skills.get(skill_id)
	if s == null or ranks <= 0: return false
	var take = min(ranks, s.rank)
	if take <= 0: return false
	s.rank -= take
	skill_points += take
	skill_changed.emit(skill_id, s.rank)
	skill_points_changed.emit(skill_points)
	save()
	return true

# -------- Save / offline --------
var _save_path := "user://save.json"
var last_save_unix := 0

signal level_up(new_level)
signal class_ready()
signal mode_changed(new_mode)

func _ready():
	load_save()
	_backfill_points_from_level()
	_maybe_emit_class_ready()

# ================= Leveling =================
func xp_to_level(n):
	return int(floor(30.0 * pow(n, 2.2)))

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
		_on_level_gained(level)
		emit_signal("level_up", level)
		need = xp_to_level(level)

func _on_level_gained(new_level: int) -> void:
	ability_points += ABILITY_POINTS_PER_LEVEL
	if new_level >= SKILL_POINTS_START_LEVEL:
		skill_points += SKILL_POINTS_PER_LEVEL
	ability_points_changed.emit(ability_points)
	skill_points_changed.emit(skill_points)

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

# ================= Modes =================
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
	if chosen_class != "":
		var gained := int(floor(pow(max(0.0, run_xp / 30_000.0), 0.5)))
		class_marks[chosen_class] += max(gained, 0)
		class_mastery[chosen_class].dmg_mult = 1.0 + 0.03 * float(class_marks[chosen_class])

	gold = 0
	fish = 0
	ore = 0
	xp = 0
	run_xp = 0
	level = 1
	ability_points = 0
	skill_points = 0
	for k in attributes.keys():
		attributes[k].alloc = 0
	for id in skills.keys():
		skills[id].rank = 0

	chosen_weapon = ""
	chosen_class = ""
	mode = "arena"
	save()

# ================= Meta =================
func _maybe_gain_sigil():
	var target := int(floor(pow(max(0.0, lifetime_xp / 50_000.0), 0.5)))
	if target > sigils:
		sigils = target

# ================= Save / Load / Offline =================
func save():
	var data = {
		"gold": gold, "xp": xp, "level": level,
		"fish": fish, "ore": ore, "mode": mode,
		"fishing_unlocked": fishing_unlocked,
		"mining_unlocked": mining_unlocked,
		"ascend_unlocked": ascend_unlocked,
		"lifetime_xp": lifetime_xp, "run_xp": run_xp, "sigils": sigils,
		"class_marks": class_marks, "class_mastery": class_mastery,
		"chosen_weapon": chosen_weapon, "chosen_class": chosen_class,
		"ability_points": ability_points,
		"skill_points": skill_points,
		"attributes": attributes,
		"skills": skills,
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

	gold = float(data.get("gold", 0))
	xp = float(data.get("xp", 0))
	level = int(data.get("level", 1))
	fish = int(data.get("fish", 0))
	ore = int(data.get("ore", 0))
	mode = String(data.get("mode", "arena"))

	fishing_unlocked = bool(data.get("fishing_unlocked", false))
	mining_unlocked  = bool(data.get("mining_unlocked", false))
	ascend_unlocked  = bool(data.get("ascend_unlocked", false))

	lifetime_xp = float(data.get("lifetime_xp", 0))
	run_xp = float(data.get("run_xp", 0))
	sigils = int(data.get("sigils", 0))
	class_marks = data.get("class_marks", class_marks)
	class_mastery = data.get("class_mastery", class_mastery)
	chosen_weapon = String(data.get("chosen_weapon", ""))
	chosen_class  = String(data.get("chosen_class", ""))
	last_save_unix = int(data.get("last_save_unix", 0))

	ability_points = int(data.get("ability_points", 0))
	skill_points   = int(data.get("skill_points", 0))

	var saved_attrs = data.get("attributes", null)
	if typeof(saved_attrs) == TYPE_DICTIONARY:
		for k in attributes.keys():
			if saved_attrs.has(k):
				var sa = saved_attrs[k]
				attributes[k].base  = int(sa.get("base", attributes[k].base))
				attributes[k].alloc = int(sa.get("alloc", attributes[k].alloc))
				attributes[k].max_alloc = int(sa.get("max_alloc", attributes[k].max_alloc))

	var saved_skills = data.get("skills", null)
	if typeof(saved_skills) == TYPE_DICTIONARY:
		for id in skills.keys():
			if saved_skills.has(id):
				var ss = saved_skills[id]
				skills[id].rank = int(ss.get("rank", skills[id].rank))

	# Offline catch-up (cap 6h)
	var dt = max(0, Time.get_unix_time_from_system() - last_save_unix)
	var capped = min(dt, 6 * 3600)
	if capped > 0:
		match mode:
			"arena":   gold += 0.5 * float(capped)
			"fishing": fish += int(floor(0.2 * float(capped)))
			"mining":  ore  += int(floor(0.2 * float(capped)))

	var allowed := ["arena", "fishing", "mining"]
	if not allowed.has(mode):
		mode = "arena"

# ----- retro AP for existing saves -----
func _backfill_points_from_level() -> void:
	var expected = ABILITY_POINTS_PER_LEVEL * max(0, level - 1)
	if ability_points < expected:
		ability_points = expected
		ability_points_changed.emit(ability_points)


# +10% damage per Attack (rounded up). Optional weapon bonus folds in here
func get_attack_scaled_range(base_min: int, base_max: int, attack_bonus: int = 0) -> Vector2i:
	var atk = max(0, get_attr_total("attack") + attack_bonus)
	var mult := 1.0 + ATTACK_DAMAGE_PER_POINT * float(atk)
	var safe_min = max(0, base_min)
	var safe_max = max(safe_min, base_max)
	var new_min := int(ceil(float(safe_min) * mult))
	var new_max := int(ceil(float(safe_max) * mult))
	return Vector2i(new_min, new_max)

func get_crit_chance(extra_accuracy: float = 0.0) -> float:
	var dex_total = float(get_attr_total("dex")) + max(0.0, extra_accuracy)
	return clampf(BASE_CRIT_CHANCE + CRIT_PER_DEX * dex_total, 0.0, 0.999)
