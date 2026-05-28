extends CharacterBody2D

@onready var anim = $AnimatedSprite2D

@export var speed = 40
@export var attack_damage = 10.0
@export var attack_cooldown = 1.0
@export var attack_range = 4.0

var player: Node2D = null
var can_attack = true


func _ready():
	player = get_tree().get_first_node_in_group("player")
	anim.play("skeleton_walking_south")


func _physics_process(_delta):
	if player == null:
		return

	var direction = global_position.direction_to(player.global_position)
	var distance = global_position.distance_to(player.global_position)

	velocity = direction * speed
	play_walk_animation(direction)
	move_and_slide()

	if distance <= attack_range and can_attack:
		attack_player()


func attack_player():
	can_attack = false

	if player.has_method("take_damage"):
		player.take_damage(attack_damage)
		print("Skeleton damaged player")

	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true


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
