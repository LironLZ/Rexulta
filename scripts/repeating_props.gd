@tool
extends Node2D
# res://scripts/repeating_props.gd

## Put your decorative nodes under a child called "Chunk".
## This script tiles that chunk horizontally and recycles as the camera moves.

@export var chunk_path: NodePath = ^"Chunk"
@export var chunk_width_px: int = 520      # width of one chunk in pixels
@export var duplicates: int = 5             # total chunks visible (>=2)
@export var follow_node: NodePath           # optional; camera auto-detected if empty
@export var trigger_factor: float = 1.5     # recycle when cam passes 1.5 chunks
@export_group("Scale Variations")
@export var min_scale := 1       
@export var max_scale := 2.5        
@export var reroll_scale_on_recycle := true
var _chunks: Array[Node2D] = []
var _cam: Camera2D

func _ready() -> void:
	_build_if_needed()
	set_process(true)

func _build_if_needed() -> void:
	_clear_dupes()

	var base := get_node_or_null(chunk_path) as Node2D
	if base == null:
		push_warning("RepeatingProps: missing 'Chunk' node")
		return

	_cam = get_viewport().get_camera_2d()

	_chunks.resize(duplicates)
	_chunks[0] = base
	_apply_scale_variations(base)
	for i in range(1, duplicates):
		# Godot 4: use Node.DuplicateFlags.*
		var dupe := base.duplicate(Node.DuplicateFlags.DUPLICATE_SCRIPTS) as Node2D
		# (If your version complains, just do: var dupe := base.duplicate() as Node2D)
		add_child(dupe)
		dupe.position = base.position + Vector2(chunk_width_px * i, 0)
		_apply_scale_variations(dupe) 
		_chunks[i] = dupe

func _clear_dupes() -> void:
	for c in get_children():
		if c is Node2D and c.name.begins_with("Chunk") and c != get_node_or_null(chunk_path):
			c.queue_free()
	_chunks.clear()

func _process(_dt: float) -> void:
	if _chunks.is_empty():
		return
	if _cam == null:
		_cam = get_viewport().get_camera_2d()
		if _cam == null:
			return

	# Pixel-perfect Y; only recycle on X
	for c in _chunks:
		c.position.y = round(c.position.y)

	var slice_w := float(chunk_width_px)
	var cam_x := _cam.global_position.x
	var left := _leftmost()
	var right := _rightmost()

	while cam_x - left.global_position.x > slice_w * trigger_factor:
		left.global_position.x = right.global_position.x + slice_w
		if reroll_scale_on_recycle:
			_apply_scale_variations(left) 
		_sort_chunks()
		left = _leftmost()
		right = _rightmost()

func _leftmost() -> Node2D:
	var n := _chunks[0]
	for c in _chunks:
		if c.global_position.x < n.global_position.x:
			n = c
	return n

func _rightmost() -> Node2D:
	var n := _chunks[0]
	for c in _chunks:
		if c.global_position.x > n.global_position.x:
			n = c
	return n

func _sort_chunks() -> void:
	_chunks.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	
func _apply_scale_variations(chunk: Node2D) -> void:
	# Disabled if no range
	if max_scale <= 0.0 or min_scale <= 0.0:
		return
	if abs(max_scale - min_scale) < 0.0001:
		return
	for child in chunk.get_children():
		if child is Node2D and child.name == "Tree":   # only scale the Tree wrapper
			var s := randf_range(min_scale, max_scale)
			(child as Node2D).scale = Vector2(s, s)    # uniform scale
