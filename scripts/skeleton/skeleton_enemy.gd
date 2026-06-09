extends CharacterBody2D

@onready var anim = $AnimatedSprite2D
@onready var health_bar = $EnemyHealthBar

@export var speed = 40
@export var attack_damage = 10.0
@export var attack_cooldown = 1.0
@export var attack_range = 14.0
@export var stop_range = 14.0

@export var max_health = 30.0

var health = 30.0
var player: Node2D = null
var can_attack = true
var hide_health_task_id = 0


func _ready():
	add_to_group("enemy")

	player = get_tree().get_first_node_in_group("player")

	health = max_health

	health_bar.play("enemy_health_bar")
	health_bar.pause()
	health_bar.frame = 0
	health_bar.visible = false

	anim.play("skeleton_walking_south")


func _physics_process(_delta):
	if player == null:
		return

	var direction = global_position.direction_to(player.global_position)
	var distance = global_position.distance_to(player.global_position)

	if distance > stop_range:
		velocity = direction * speed
		play_walk_animation(direction)
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	if distance <= attack_range and can_attack:
		attack_player()


func attack_player():
	can_attack = false

	if player.has_method("take_damage"):
		player.take_damage(attack_damage)

	await get_tree().create_timer(attack_cooldown).timeout

	can_attack = true


func take_damage(amount):
	health -= amount
	health = clamp(health, 0, max_health)

	update_health_bar()
	show_health_bar_temporarily()

	if health <= 0:
		die()


func update_health_bar():
	var health_percent = health / max_health
	var frame_count = health_bar.sprite_frames.get_frame_count("enemy_health_bar")
	var frame_index = round((1.0 - health_percent) * (frame_count - 1))

	health_bar.frame = clamp(frame_index, 0, frame_count - 1)


func show_health_bar_temporarily():
	hide_health_task_id += 1
	var current_task = hide_health_task_id

	health_bar.visible = true

	await get_tree().create_timer(4.0).timeout

	if current_task == hide_health_task_id:
		health_bar.visible = false


func die():
	var world = get_tree().current_scene

	if world.has_method("add_score"):
		world.add_score(100)

	queue_free()


func play_walk_animation(direction: Vector2):
	if abs(direction.x) > abs(direction.y):
		anim.play("skeleton_walking_sideways")
		anim.flip_h = direction.x < 0
	elif direction.y > 0:
		anim.play("skeleton_walking_south")
		anim.flip_h = false
	else:
		anim.play("skeleton_walking_north")
		anim.flip_h = false
