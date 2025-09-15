extends CharacterBody2D

@export var move_speed := 180.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") as float
var _fire_accum := 0.0

func _physics_process(delta: float) -> void:
	# Horizontal move (A/D or arrows). Set move_speed=0 if you want the player stationary.
	var dir := Input.get_axis("ui_left","ui_right")
	velocity.x = dir * move_speed

	# Stay grounded (no jump). Falls until it hits the ground, then sticks.
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	move_and_slide()

	# Auto-fire
	_fire_accum += delta
	var sps := Economy.shots_per_second()
	if sps > 0.0 and _fire_accum >= (1.0 / sps):
		_fire_accum = 0.0
		_auto_fire()

func _auto_fire() -> void:
	var e = _nearest_enemy()
	if e == null: return
	var dmg = Economy.dps() / max(0.001, Economy.shots_per_second())
	e.apply_hit(dmg)

func _nearest_enemy():
	var best
	var best_d := 1e9
	for e in get_tree().get_nodes_in_group("enemies"):
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best
