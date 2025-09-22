extends VBoxContainer

@export var skill_id: String

@onready var name_l:  Label  = $Name
@onready var rank_l:  Label  = $Rank
@onready var spend_b: Button = $Spend

func _ready() -> void:
	if not State.skills.has(skill_id):
		push_error("SkillButton: unknown skill %s" % skill_id)
		queue_free()
		return

	var s = State.skills[skill_id]
	name_l.text = s.name
	spend_b.hint_tooltip = s.desc

	spend_b.pressed.connect(_on_spend)
	State.skill_changed.connect(_on_skill_changed)
	State.skill_points_changed.connect(_on_sp_changed)

	_refresh()

func _on_spend() -> void:
	if State.raise_skill(skill_id):
		_refresh()

func _on_skill_changed(changed: String, _rank: int) -> void:
	if changed == skill_id:
		_refresh()

func _on_sp_changed(_remaining: int) -> void:
	_refresh()

func _refresh() -> void:
	var s = State.skills[skill_id]
	rank_l.text = "Rank %d / %d" % [s.rank, s.max]
	spend_b.disabled = not State.can_raise_skill(skill_id)
	spend_b.text = "MAX" if s.rank >= s.max else "+"
