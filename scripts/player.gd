# player.gd — Godot 4.x
extends CharacterBody2D

@export var move_speed: int = 180
@export var autorun: bool = true
@export var gravity_multiplier: float = 1.0

# Base damage range (inclusive) BEFORE scaling by Attack/DEX
@export var min_damage: int = 1
@export var max_damage: int = 4

# Ground alignment
@export var ground_mask: int = 1
@export var snap_probe_up: float = 200

# Animation names (must match SpriteFrames on $Sprite)
@export var idle_anim  := "idle"     # optional; will fallback if missing
@export var walk_anim  := "walk"     # required
@export var attack_anim := "attack"  # non-looping

@onready var anim: AnimatedSprite2D = $Sprite

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity") as float

# RNG for per-hit rolls
var _rng := RandomNumberGenerator.new()

const BASE_CRIT_CHANCE := 0.05
const CRIT_PER_ACCURACY := 0.001
const CRIT_DAMAGE_MULT := 2.0

# combat cadence
var _fire_accum := 0.0

# run → engage state
enum { RUN, ENGAGE }
var _state := RUN
var _target: Node2D = null

# animation state
var _attacking := false   # true while 'attack' is playing once

# ---- Crit tuning ----
const CRIT_MULT := 2.5  # 2.5x crits, rounded up

func _ready() -> void:
	floor_snap_length = 6.0
	_snap_to_ground()

	_rng.randomize()

	if is_instance_valid(anim) and anim.sprite_frames:
		anim.speed_scale = 1.0
		if anim.sprite_frames.has_animation(walk_anim):
			anim.play(walk_anim)
		elif anim.sprite_frames.has_animation(idle_anim):
			anim.play(idle_anim)
		elif anim.sprite_frames.has_animation("default"):
			anim.play("default")
		anim.animation_finished.connect(_on_anim_finished)

func _physics_process(delta: float) -> void:
	# --- horizontal movement ---
	if _state == RUN and autorun:
		velocity.x = float(move_speed)
	else:
		velocity.x = 0.0

	# --- gravity / floor stick ---
	if not is_on_floor():
		velocity.y += gravity * gravity_multiplier * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0

	# --- proactively stop if we WOULD hit an enemy this step ---
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

	# --- melee cadence while ENGAGE ---
	if _state == ENGAGE and is_instance_valid(_target):
		_fire_accum += delta
		var sps = max(0.001, Economy.shots_per_second())
		if _fire_accum >= (1.0 / sps):
			_fire_accum = 0.0
			_melee_strike(_target)   # also triggers attack anim
	else:
		_fire_accum = 0.0

	_update_animation()

func _update_animation() -> void:
	if not is_instance_valid(anim) or anim.sprite_frames == null:
		return

	# Face target during ENGAGE, else face move direction
	if _state == ENGAGE and is_instance_valid(_target):
		anim.flip_h = (_target.global_position.x < global_position.x)
	elif velocity.x != 0.0:
		anim.flip_h = velocity.x < 0.0

	# While attack is playing, don't override it
	if _attacking and anim.animation == attack_anim and anim.is_playing():
		return

	var moving = (_state == RUN and abs(velocity.x) > 1.0)

	if moving:
		if anim.sprite_frames.has_animation(walk_anim):
			if anim.animation != walk_anim or !anim.is_playing():
				anim.play(walk_anim)
	else:
		var idle_name := idle_anim if anim.sprite_frames.has_animation(idle_anim) \
			else ("default" if anim.sprite_frames.has_animation("default") else walk_anim)
		if anim.animation != idle_name or !anim.is_playing():
			anim.play(idle_name)

func _play_attack() -> void:
	if not is_instance_valid(anim) or anim.sprite_frames == null:
		return
	if anim.sprite_frames.has_animation(attack_anim):
		_attacking = true
		anim.play(attack_anim)  # Loop = Off in SpriteFrames

func _on_anim_finished() -> void:
	if anim.animation == attack_anim:
		_attacking = false

func _would_hit_enemy_this_frame(delta: float) -> bool:
	var step = min(move_speed * delta, 4.0)
	if step <= 0.0:
		return false
	var motion := Vector2(step, 0)
	if test_move(global_transform, motion):
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
	_target.tree_exited.connect(_on_target_exited, Object.CONNECT_ONE_SHOT)
	_play_attack()

func _on_target_exited() -> void:
	if _state == ENGAGE:
		_end_engage()

func _end_engage() -> void:
	_state = RUN
	_target = null
	_fire_accum = 0.0
	_attacking = false

# -------- Damage helpers (Attack + DEX + Crit) --------

func get_current_damage_range() -> Vector2i:
	# Uses base min/max and scales by Attack; DEX bumps min inside State helper
	return State.get_attack_scaled_range(min_damage, max_damage)

func roll_damage() -> int:
		var r := get_current_damage_range()
		var dmg := _rng.randi_range(r.x, r.y)
		# Uncomment for a quick sanity print:
		# print("[DMG] atk=", State.get_attr_total("attack"), " range=", r, " roll=", dmg)
		return dmg


func _melee_strike(enemy: Node2D) -> void:
		if enemy.has_method("apply_hit"):
				var dmg := roll_damage()
				var is_crit := _roll_is_crit()
				if is_crit:
						dmg = max(1, int(round(float(dmg) * CRIT_DAMAGE_MULT)))
				enemy.call("apply_hit", float(dmg), is_crit)
		_play_attack()

func _roll_is_crit() -> bool:
		var accuracy_points := float(State.get_attr_total("dex"))
		var chance := clampf(BASE_CRIT_CHANCE + (CRIT_PER_ACCURACY * accuracy_points), 0.0, 0.999)
		return _rng.randf() < chance


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_fullscreen"):
		Display.toggle_fullscreen()
		return
	if e.is_action_pressed("ui_accept") and _state == RUN:
		autorun = !autorun

# ---------- Ground snap helpers ----------
func _bottom_margin_world() -> float:
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
