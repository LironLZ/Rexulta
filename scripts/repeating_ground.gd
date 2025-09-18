@tool
extends Node2D
## Repeats a base StaticBody2D collider horizontally to match a TileMap's repeated chunks.

@export var tilemap_path: NodePath = ^"../RepeatingTerrain/Chunk"  # your terrain TileMap
@export var base_body_path: NodePath = ^"Base"                     # child StaticBody2D (original)
@export var duplicates: int = 3
@export var follow_node: NodePath                                   # Camera2D or Player
@export var trigger_factor := 1.5

var _step_px := 0.0
var _left_px_local := 0.0
var _bodies: Array[StaticBody2D] = []
var _last_used_rect: Rect2i

func _ready() -> void:
	_build()
	set_process(true)

func _build() -> void:
	var tm := get_node_or_null(tilemap_path) as TileMap
	var base := get_node_or_null(base_body_path) as StaticBody2D
	if tm == null or base == null:
		return

	# remove old duplicates
	for c in get_children():
		if c != base and c is StaticBody2D:
			c.queue_free()
	await get_tree().process_frame

	var used := tm.get_used_rect()
	_last_used_rect = used
	if used.size.x <= 0:
		return

	var cell_w := tm.tile_set.tile_size.x
	_step_px = float(used.size.x * cell_w) * tm.scale.x
	_left_px_local = tm.map_to_local(used.position).x

	_bodies = [base]
	_position_body(base, 0)

	for i in range(1, duplicates):
		var dup := base.duplicate(DUPLICATE_USE_INSTANTIATION | DUPLICATE_SIGNALS) as StaticBody2D
		add_child(dup)
		dup.owner = get_tree().edited_scene_root
		# keep same y; x gets placed below
		dup.position.y = base.position.y
		_bodies.append(dup)
		_position_body(dup, i)

func _position_body(b: StaticBody2D, index: int) -> void:
	# align left edges to the TileMap's used-area grid
	var base_left_world := global_position.x + _left_px_local
	var desired_left_world := base_left_world + _step_px * index
	var new_x := desired_left_world - _left_px_local
	b.position.x = snapped(new_x, 1.0)

func _process(_dt: float) -> void:
	if Engine.is_editor_hint():
		var tm := get_node_or_null(tilemap_path) as TileMap
		if tm and tm.get_used_rect() != _last_used_rect:
			_build()
		return

	if _bodies.is_empty() or _step_px <= 0.0:
		return
	var f := get_node_or_null(follow_node) as Node2D
	if f == null: return

	var fx := f.global_position.x
	for b in _bodies:
		var bx_left := b.global_position.x + _left_px_local
		while fx - bx_left > _step_px * trigger_factor:
			b.position.x += _step_px * duplicates
			bx_left += _step_px * duplicates
		while bx_left - fx > _step_px * trigger_factor:
			b.position.x -= _step_px * duplicates
			bx_left -= _step_px * duplicates
