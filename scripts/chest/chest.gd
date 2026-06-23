extends Area2D

@onready var sprite = $AnimatedSprite2D
@onready var interaction_label = $InteractionLabel

@export var interact_distance: float = 45.0
@export var mimic_chance: float = 0.25
@export var chest_score_reward: int = 150
@export var chest_exp_reward: int = 40

@export var min_coins: int = 5
@export var max_coins: int = 12
@export var potion_chance: float = 0.25

var mimic_scene = preload("res://scenes/mimic.tscn")

var player: Node2D = null
var opened = false

var coin_scene = preload("res://scenes/coin.tscn")
var potion_scene = preload("res://scenes/health_potion.tscn")


func _ready():
	player = get_tree().get_first_node_in_group("player")

	interaction_label.visible = false
	interaction_label.text = "Press E"
	interaction_label.position = Vector2(-35, -40)

	sprite.play("chest_open")
	sprite.pause()
	sprite.frame = 0


func _process(_delta):
	if opened or player == null:
		return

	var distance = global_position.distance_to(player.global_position)

	if distance <= interact_distance:
		interaction_label.visible = true

		if Input.is_action_just_pressed("interact"):
			open_chest()
	else:
		interaction_label.visible = false


func open_chest():
	print("Chest opened")

	opened = true
	interaction_label.visible = false

	var world = get_tree().current_scene

	if world.has_method("add_chest_opened"):
		world.add_chest_opened()

	if randf() <= mimic_chance:
		spawn_mimic()
	else:
		give_reward()


func give_reward():
	var world = get_tree().current_scene

	if world.has_method("add_score"):
		world.add_score(chest_score_reward)

	if world.has_method("add_exp"):
		world.add_exp(chest_exp_reward)

	drop_coins()

	if randf() <= potion_chance:
		drop_health_potion()

	sprite.play("chest_open")

	await sprite.animation_finished

	if world.has_method("respawn_chest_after_delay"):
		world.respawn_chest_after_delay()

	queue_free()


func spawn_mimic():
	visible = false

	await get_tree().create_timer(0.15).timeout

	var mimic = mimic_scene.instantiate()
	get_tree().current_scene.add_child(mimic)
	mimic.global_position = global_position

	var world = get_tree().current_scene

	if world.has_method("add_mimic_spawned"):
		world.add_mimic_spawned()
	

	if world.has_method("respawn_chest_after_delay"):
		world.respawn_chest_after_delay()

	queue_free()
	

func drop_coins():
	var coin_count = randi_range(min_coins, max_coins)

	for i in range(coin_count):
		var coin = coin_scene.instantiate()
		get_tree().current_scene.add_child(coin)

		var random_offset = Vector2(
			randf_range(-20, 20),
			randf_range(-20, 20)
		)

		coin.global_position = global_position + random_offset


func drop_health_potion():
	var potion = potion_scene.instantiate()
	get_tree().current_scene.add_child(potion)

	potion.global_position = global_position + Vector2(25, -10)
