extends CharacterBody2D

@export var move_speed: float = 180.0
@export var autorun: bool = true
@export var gravity_multiplier: float = 1.0

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") as float
var _fire_accum := 0.0

func _physics_process(delta: float) -> void:
	# --- constant right movement (toggle with autorun) ---
	velocity.x = (move_speed if autorun else 0.0)

	# --- gravity / floor stick ---
	if not is_on_floor():
		velocity.y += gravity * gravity_multiplier * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

	move_and_slide()

	# --- auto-fire on cadence ---
	_fire_accum += delta
	var sps := Economy.shots_per_second()
	if sps > 0.0 and _fire_accum >= (1.0 / sps):
		_fire_accum = 0.0
		_auto_fire()

func _unhandled_input(e: InputEvent) -> void:
	# Optional: toggle autorun with Space/Enter (ui_accept)
	if e.is_action_pressed("ui_accept"):
		autorun = !autorun

func _auto_fire() -> void:
	var e = _nearest_enemy()
	if e == null: 
		return
	var shots = max(0.001, Economy.shots_per_second())
	var dmg = Economy.dps() / shots
	e.apply_hit(dmg)

func _nearest_enemy():
	var best = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group("enemies"):
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best
