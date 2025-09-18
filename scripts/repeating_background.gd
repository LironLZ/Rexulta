# res://scripts/repeating_background.gd
extends Node2D

## Drop your background texture here in the Inspector
@export var texture: Texture2D
## Vertical placement (tweak until the horizon lines up with your ground)
@export var y: float = 0.0
## Scroll speed to the left (pixels/second). Set to 0 for no auto-scroll.
@export var speed: float = 30.0
## If true, stick the background to the camera horizontally (no auto-scroll).
@export var follow_camera: bool = false

var _tex_w: float
var _sprites: Array[Sprite2D] = []

func _ready() -> void:
	assert(texture != null, "Assign 'texture' on RepeatingBackground.")
	_tex_w = float(texture.get_width())

	# How many copies do we need to cover the screen? +2 as safe buffer.
	var need := int(ceil(get_viewport_rect().size.x / _tex_w)) + 2
	for i in range(need):
		var s := Sprite2D.new()
		s.texture = texture
		s.centered = false        # <- avoids subpixel offsets & gaps
		s.position = Vector2(i * _tex_w, y)
		s.z_index = -100
		add_child(s)
		_sprites.append(s)

func _process(delta: float) -> void:
	if follow_camera:
		_snap_to_camera()
	else:
		# Auto-scroll left
		var dx := -speed * delta
		for s in _sprites:
			s.position.x += dx
		_wrap()

func _wrap() -> void:
	# If a sprite goes fully off the left, move it to the right end.
	# (No gaps because copies overlap by whole texture width.)
	# Sort by x so we know leftmost/rightmost.
	_sprites.sort_custom(func(a, b): return a.position.x < b.position.x)
	var left := _sprites[0]
	var right := _sprites[-1]
	if left.position.x + _tex_w < 0.0:
		left.position.x = right.position.x + _tex_w
		_sprites.remove_at(0)
		_sprites.append(left)

func _snap_to_camera() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	# Align first copy to nearest repeat boundary at/left of camera’s left edge.
	var left_edge := cam.global_position.x - get_viewport_rect().size.x * 0.5
	var base = floor(left_edge / _tex_w) * _tex_w
	for i in range(_sprites.size()):
		_sprites[i].global_position.x = base + i * _tex_w
		_sprites[i].global_position.y = global_position.y + y
