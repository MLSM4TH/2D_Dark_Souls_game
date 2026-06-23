extends Area2D

@export var pickup_delay: float = 0.8

@onready var sprite = $Sprite2D

var player: Node2D = null
var can_pickup = false


func _ready():
	player = get_tree().get_first_node_in_group("player")

	if sprite != null:
		sprite.visible = true

	await get_tree().create_timer(pickup_delay).timeout
	can_pickup = true


func _process(_delta):
	if player == null or not can_pickup:
		return

	if global_position.distance_to(player.global_position) <= 28:
		collect()


func collect():
	player.health = player.max_health

	if player.has_method("update_health_bar"):
		player.update_health_bar()

	queue_free()
