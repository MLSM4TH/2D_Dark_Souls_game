extends Area2D

@export var gold_amount: int = 1

@onready var sprite = $AnimatedSprite2D

var player: Node2D = null


func _ready():
	player = get_tree().get_first_node_in_group("player")

	sprite.play("coin_animation")
	sprite.speed_scale = 1.0


func _process(_delta):
	if player == null:
		return

	if global_position.distance_to(player.global_position) <= 28:
		collect()


func collect():
	var world = get_tree().current_scene

	if world.has_method("add_gold"):
		world.add_gold(gold_amount)

	queue_free()
