# mushroom.gd (attach to Mushroom.tscn root)
extends CharacterBody2D

@export var max_hp: float = 12.0
@export var move_speed: float = 0.0      # 0 = stationary; set >0 to waddle
@export var contact_damage: float = 0.0  # for later if you want touch damage
@export var gold_reward: int = 3

var hp: float

func _ready() -> void:
	hp = max_hp
	add_to_group("enemies", true)   # make sure player can find us
	# Set Physics Layer in the Inspector to your enemy layer (e.g., Layer 3)

func _physics_process(delta: float) -> void:
	# Optional: slow leftward shuffle
	if move_speed > 0.0:
		velocity.x = -move_speed
		move_and_slide()

func apply_hit(dmg: float, _is_crit: bool = false) -> void:
        hp -= max(0.0, dmg)
        _hit_flash()
        if hp <= 0.0:
                _die()


func _hit_flash() -> void:
	# quick white flash on the visible sprite node
	var node := get_node_or_null("Sprite") as CanvasItem
	if node == null:
		node = get_node_or_null("AnimatedSprite2D") as CanvasItem
	if node != null:
		node.modulate = Color(2, 2, 2, 1)
		await get_tree().process_frame
		await get_tree().create_timer(0.06).timeout
		node.modulate = Color(1, 1, 1, 1)

func _die() -> void:
	# reward player (adjust to your Economy API)
	if "add_gold" in Economy:
		Economy.add_gold(gold_reward)
	queue_free()
