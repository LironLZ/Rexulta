# res://actors/Enemy.gd
extends StaticBody2D  # <— was Node2D

@export var hp_max: float = 30.0
@export var gold_drop_base: float = 15.0

@onready var spr: Sprite2D = $Sprite2D
@onready var hp: float = hp_max

const FT_SCENE: PackedScene = preload("res://ui/FloatingText2D.tscn")

func _ready() -> void:
	add_to_group("enemies")
	# ensure no inherited tint
	modulate = Color.WHITE
	self_modulate = Color.WHITE
	if is_instance_valid(spr):
		spr.modulate = Color.WHITE
		spr.self_modulate = Color.WHITE


func apply_hit(dmg: float) -> void:
	hp -= dmg
	_spawn_damage_text(dmg)
	_flash_hurt()
	if hp <= 0.0:
		_die()

func _spawn_damage_text(amount: float, is_crit: bool = false) -> void:
	var ft := FT_SCENE.instantiate()
	ft.position = global_position + Vector2(0, -12)
	ft.z_index = 100
	get_parent().add_child(ft)
	ft.show_value(amount, is_crit)

func _flash_hurt() -> void:
	if not is_instance_valid(spr):
		return
	var tw := create_tween()
	tw.tween_property(spr, "modulate", Color(1, 0.6, 0.6), 0.05)
	tw.tween_property(spr, "modulate", Color(1, 1, 1), 0.12)

func _die() -> void:
	State.gold += gold_drop_base
	State.add_xp(1.0)
	queue_free()
	
