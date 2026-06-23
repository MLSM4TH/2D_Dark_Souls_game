extends Node2D

@onready var label = $Label

var lifetime = 0.8

func setup(text_value, is_critical):
	label.position = Vector2.ZERO
	label.pivot_offset = label.size / 2

	if is_critical:
		label.text = "CRIT!\n" + text_value
		label.modulate = Color(1, 0.1, 0.1, 1)
		label.scale = Vector2(1.2, 1.2)
	else:
		label.text = text_value
		label.modulate = Color(1, 1, 1, 1)
		label.scale = Vector2(1.0, 1.0)

func _ready():
	await get_tree().create_timer(0.35).timeout

	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.45)

	await tween.finished
	queue_free()
