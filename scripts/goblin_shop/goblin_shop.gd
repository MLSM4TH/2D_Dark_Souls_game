extends Area2D

@onready var interaction_label = $InteractionLabel

@export var interact_distance: float = 55.0

var player: Node2D = null


func _ready():
	player = get_tree().get_first_node_in_group("player")

	interaction_label.visible = false
	interaction_label.text = "Press E to Shop"
	interaction_label.position = Vector2(-50, -45)


func _process(_delta):
	if player == null:
		return

	var distance = global_position.distance_to(player.global_position)

	if distance <= interact_distance:
		interaction_label.visible = true

		if Input.is_action_just_pressed("interact"):
			var world = get_tree().current_scene

			if world.has_method("open_shop"):
				world.open_shop()
	else:
		interaction_label.visible = false
