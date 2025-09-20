extends ParallaxBackground

@export var speed_x := 18.0  # px/sec; + = right, - = left

func _ready() -> void:
	# Keep parallax scrolling even when the tree is paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func _process(delta: float) -> void:
	scroll_offset.x += speed_x * delta
