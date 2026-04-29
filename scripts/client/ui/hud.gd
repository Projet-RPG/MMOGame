extends CanvasLayer

@onready var bar_hp := $HP/HBoxContainer/BarHP
@onready var label_hp := $HP/HBoxContainer/LabelHP

func _ready() -> void:
	bar_hp.min_value = 0
	bar_hp.max_value = 100
	bar_hp.value = 100

func update_hp(current: int, maximum: int) -> void:
	maximum = max(maximum, 1)
	bar_hp.max_value = maximum
	bar_hp.value = clamp(current, 0, maximum)
	label_hp.text = "HP : %d / %d" % [current, maximum]
