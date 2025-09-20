extends CharacterBody2D

@export var move_speed: float = 180.0
@export var autorun: bool = true                    # ignored while ENGAGE is active
@export var gravity_multiplier: float = 1.0

# Ground alignment
@export var ground_mask: int = 1        # Physics layer for ground
@export var snap_probe_up: float = 200  # Ray starts this far above the player

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") as float

# combat cadence (reuse your Economy cadence)
var _fire_accum := 0.0

# run → engage state
enum { RUN, ENGAGE }
var _state := RUN
var _target: Node2D = null

func _ready() -> void:
	# Help the body stick to floors (useful for pixel art platforms)
	floor_snap_length = 6.0
	# One-time precise placement so feet sit on the ground line
	_snap_to_ground()

func _physics_process(delta: float) -> void:
	# --- horizontal movement ---
	if _state == RUN and autorun:
		velocity.x = move_speed
	else:
		velocity.x = 0.0  # stop while ENGAGE or autorun off

	# --- gravity / floor stick ---
	if not is_on_floor():
		velocity.y += gravity * gravity_multiplier * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

	# --- proactively stop if we WOULD hit an enemy this step (prevents ghosting) ---
	if _state == RUN and autorun and _would_hit_enemy_this_frame(delta):
		velocity.x = 0.0

	move_and_slide()

	# --- start engage if we actually touched an enemy (slide collision) ---
	if _state == RUN:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			var enemy := _enemy_root_from(col.get_collider())
			if enemy != null:
				_start_engage(enemy)
				break

	# --- melee-only cadence while ENGAGE ---
	if _state == ENGAGE and is_instance_valid(_target):
		_fire_accum += delta
		var sps = max(0.001, Economy.shots_per_second())
		if _fire_accum >= (1.0 / sps):
			_fire_accum = 0.0
			_melee_strike(_target)
	else:
		_fire_accum = 0.0

func _would_hit_enemy_this_frame(delta: float) -> bool:
	# Use the body's own shape to test a tiny advance this frame.
	var step = min(move_speed * delta, 4.0)
	if step <= 0.0:
		return false
	var motion := Vector2(step, 0)
	if test_move(global_transform, motion):
		# Narrow to enemies via a short ray on the enemy layer (Layer 3 => bit 1<<(3-1)=1<<2)
		var from := global_position
		var to := from + Vector2(step + 10.0, 0)
		var params := PhysicsRayQueryParameters2D.create(from, to)
		params.collision_mask = 1 << 2
		var hit := get_viewport().get_world_2d().direct_space_state.intersect_ray(params)
		return hit.size() > 0
	return false

func _enemy_root_from(obj: Object) -> Node2D:
	var n := obj as Node
	while n:
		if n.is_in_group("enemies"):
			return n as Node2D
		n = n.get_parent()
	return null

func _start_engage(enemy: Node2D) -> void:
	_state = ENGAGE
	_target = enemy
	# one-shot connect to resume when the enemy leaves
	_target.tree_exited.connect(_on_target_exited, Object.CONNECT_ONE_SHOT)

func _on_target_exited() -> void:
	if _state == ENGAGE:
		_end_engage()

func _end_engage() -> void:
	_state = RUN
	_target = null
	_fire_accum = 0.0

func _melee_strike(enemy: Node2D) -> void:
	# Your original DPS cadence, but only at melee range
	var shots = max(0.001, Economy.shots_per_second())
	var dmg = max(1.0, Economy.dps() / shots)
	if enemy.has_method("apply_hit"):
		enemy.call("apply_hit", dmg)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_fullscreen"):
		Display.toggle_fullscreen()
		return

	# existing behavior
	if e.is_action_pressed("ui_accept") and _state == RUN:
		autorun = !autorun


# ---------- Ground snap helpers ----------

func _bottom_margin_world() -> float:
	# distance from player origin to the bottom of the collider (in world px)
	var cs := $CollisionShape2D as CollisionShape2D
	if cs == null or cs.shape == null:
		return 8.0
	var half_h := 8.0
	if cs.shape is RectangleShape2D:
		half_h = (cs.shape as RectangleShape2D).size.y * 0.5
	elif cs.shape is CapsuleShape2D:
		var cap := cs.shape as CapsuleShape2D
		half_h = cap.height * 0.5 + cap.radius
	elif cs.shape is CircleShape2D:
		half_h = (cs.shape as CircleShape2D).radius
	var scale_y = abs(cs.get_global_transform().get_scale().y)
	var half_h_world = half_h * scale_y
	var offset_world := cs.get_global_position().y - global_position.y
	return offset_world + half_h_world

func _snap_to_ground() -> void:
	var from := global_position - Vector2(0, snap_probe_up)
	var to := from + Vector2(0, 4000)
	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.collision_mask = ground_mask
	var hit := get_viewport().get_world_2d().direct_space_state.intersect_ray(params)
	if hit and hit.has("position"):
		global_position.y = (hit.position as Vector2).y - _bottom_margin_world()
