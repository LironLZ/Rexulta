extends Node2D
@export var hp: float = 30.0
@export var gold_drop_base: float = 15.0
@onready var spr: Sprite2D = $Sprite2D

func _ready():
	add_to_group("enemies")

func apply_hit(dmg: float) -> void:
	hp -= dmg
	# tiny flash
	var old := spr.modulate
	spr.modulate = Color(1, 0.6, 0.6)
	await get_tree().process_frame
	spr.modulate = old
	if hp <= 0:
		_die()

func _die() -> void:
	State.gold += gold_drop_base
	State.add_xp(1.0)
	queue_free()
