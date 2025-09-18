@tool
extends Node2D
## Infinite horizontal repetition for a TileMap, gap-safe and Godot 4 friendly.

@export var chunk_path: NodePath = ^"Chunk"   # your TileMap child
@export var duplicates: int = 3
@export var follow_node: NodePath             # Camera2D or Player
@export var trigger_factor := 1.5

var _chunks: Array[TileMap] = []
var _step_px := 0.0
var _left_px_local := 0.0
var _last_used_rect: Rect2i

func _ready() -> void:
	_build()
	set_process(true) # used both for editor repaint polling and runtime recycling

func _build() -> void:
	var src := get_node_or_null(chunk_path) as TileMap
	if src == null:
		return

	# clear old dups (keep src)
	for c in get_children():
		if c != src and c is TileMap:
			c.queue_free()
	await get_tree().process_frame

	var used := src.get_used_rect()  # cell coords
	_last_used_rect = used
	if used.size.x <= 0:
		_chunks.clear()
		_step_px = 0.0
		return

	var cell_w := src.tile_set.tile_size.x
	_step_px = float(used.size.x * cell_w) * src.scale.x
	_left_px_local = src.map_to_local(used.position).x

	_chunks = [src]
	_position_chunk(src, 0)

	for i in range(1, duplicates):
		var dup := src.duplicate(DUPLICATE_USE_INSTANTIATION | DUPLICATE_SIGNALS) as TileMap
		add_child(dup)
		dup.position = src.position
		_position_chunk(dup, i)
		_chunks.append(dup)

func _position_chunk(tilemap: TileMap, index: int) -> void:
	var base_left_world := global_position.x + _left_px_local
	var desired_left_world := base_left_world + _step_px * index
	var new_x := desired_left_world - _left_px_local
	tilemap.position.x = snapped(new_x, 1.0)

func _process(_dt: float) -> void:
	# --- Editor: auto-rebuild if you repainted the chunk ---
	if Engine.is_editor_hint():
		var src := get_node_or_null(chunk_path) as TileMap
		if src:
			var used := src.get_used_rect()
			if used != _last_used_rect:
				_build()
		return

	# --- Game: recycle chunks around follow node ---
	if _chunks.is_empty() or _step_px <= 0.0:
		return
	var f := get_node_or_null(follow_node) as Node2D
	if f == null:
		return
	var fx := f.global_position.x
	for c in _chunks:
		var cx_left := c.global_position.x + _left_px_local
		while fx - cx_left > _step_px * trigger_factor:
			c.position.x += _step_px * duplicates
			cx_left += _step_px * duplicates
		while cx_left - fx > _step_px * trigger_factor:
			c.position.x -= _step_px * duplicates
			cx_left -= _step_px * duplicates
