extends CharacterBody2D

@onready var anim = $AnimatedSprite2D
@onready var health_bar = $EnemyHealthBar

@export var speed: float = 80.0
@export var wander_speed: float = 40.0
@export var berserk_speed: float = 120.0

@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 0.5
@export var berserk_attack_cooldown: float = 0.25

@export var attack_range: float = 14.0
@export var stop_range: float = 14.0
@export var detection_range: float = 250.0

@export var max_health: float = 30.0
@export var berserk_health_percent: float = 0.35

var health: float = 30.0
var player: Node2D = null

var can_attack = true
var hide_health_task_id = 0

var is_chasing = false
var is_berserk = false
var has_detected_player = false

var wander_direction = Vector2.ZERO
var wander_timer = 0.0

var sliding_wall = false
var wall_slide_direction = Vector2.ZERO

var base_speed = 80.0
var base_attack_damage = 10.0
var base_max_health = 30.0

var damage_label_scene = preload("res://scenes/damage_number.tscn")

func _ready():
	add_to_group("enemy")

	player = get_tree().get_first_node_in_group("player")
	health = max_health

	health_bar.play("enemy_health_bar")
	health_bar.pause()
	health_bar.frame = 0
	health_bar.visible = false
	
	base_speed = speed
	base_attack_damage = attack_damage
	base_max_health = max_health

	pick_new_wander_direction()
	anim.play("skeleton_walking_south")


func _physics_process(delta):
	if player == null:
		return

	var distance = global_position.distance_to(player.global_position)

	if distance <= detection_range:
		has_detected_player = true

	is_chasing = has_detected_player

	if is_chasing:
		chase_player(distance)
	else:
		wander(delta)

	move_and_slide()

	if is_chasing:
		handle_wall_slide()
	elif hit_wall_collision():
		pick_new_wander_direction()

	if can_attack and is_touching_player():
		attack_player()


func chase_player(distance):
	var current_speed = get_current_speed()

	if distance <= stop_range:
		velocity = Vector2.ZERO
		play_idle_animation()
		return

	if sliding_wall:
		velocity = wall_slide_direction * current_speed
		play_walk_animation(wall_slide_direction)
		return

	var direction = global_position.direction_to(player.global_position)
	velocity = direction * current_speed
	play_walk_animation(direction)


func handle_wall_slide():
	var wall_collision = get_first_wall_collision()

	if wall_collision == null:
		sliding_wall = false
		return

	var normal = wall_collision.get_normal()
	var to_player = global_position.direction_to(player.global_position)

	var tangent_a = Vector2(-normal.y, normal.x).normalized()
	var tangent_b = Vector2(normal.y, -normal.x).normalized()

	if tangent_a.dot(to_player) > tangent_b.dot(to_player):
		wall_slide_direction = tangent_a
	else:
		wall_slide_direction = tangent_b

	sliding_wall = true


func get_first_wall_collision():
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var body = collision.get_collider()

		if body != null and not body.is_in_group("player"):
			return collision

	return null


func hit_wall_collision():
	return get_first_wall_collision() != null


func wander(delta):
	wander_timer -= delta

	if wander_timer <= 0:
		pick_new_wander_direction()

	if wander_direction == Vector2.ZERO:
		velocity = Vector2.ZERO
		play_idle_animation()
		return

	velocity = wander_direction * wander_speed
	play_walk_animation(wander_direction)


func pick_new_wander_direction():
	var directions = [
		Vector2.RIGHT,
		Vector2.LEFT,
		Vector2.UP,
		Vector2.DOWN,
		Vector2.ZERO,
		Vector2.ZERO
	]

	wander_direction = directions.pick_random()

	if wander_direction == Vector2.ZERO:
		wander_timer = randf_range(0.8, 1.5)
	else:
		wander_timer = randf_range(1.0, 2.5)


func get_current_speed():
	if is_berserk:
		return berserk_speed

	return speed


func is_touching_player():
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var body = collision.get_collider()

		if body != null and body.is_in_group("player"):
			return true

	return false


func attack_player():
	can_attack = false

	if player.has_method("take_damage"):
		player.take_damage(attack_damage)

	var cooldown = attack_cooldown

	if is_berserk:
		cooldown = berserk_attack_cooldown

	await get_tree().create_timer(cooldown).timeout
	can_attack = true


func take_damage(amount):
	health -= amount
	health = clamp(health, 0, max_health)

	update_health_bar()
	show_health_bar_temporarily()
	check_berserk_mode()
	
	flash_damage()

	if health <= 0:
		die()


func check_berserk_mode():
	var health_percent = health / max_health

	if health_percent <= berserk_health_percent:
		is_berserk = true


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

	if world.has_method("add_enemy_kill"):
		world.add_enemy_kill()

	set_physics_process(false)
	velocity = Vector2.ZERO

	var tween = create_tween()
	tween.parallel().tween_property(anim, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(anim, "scale", Vector2(0.6, 0.6), 0.4)

	await tween.finished

	queue_free()


func play_idle_animation():
	if anim.animation == "skeleton_walking_sideways":
		anim.play("skeleton_walking_sideways")
	elif anim.animation == "skeleton_walking_north":
		anim.play("skeleton_walking_north")
	else:
		anim.play("skeleton_walking_south")

	anim.frame = 0
	anim.pause()


func play_walk_animation(direction: Vector2):
	anim.play()

	if abs(direction.x) > abs(direction.y):
		anim.play("skeleton_walking_sideways")
		anim.flip_h = direction.x < 0
	elif direction.y > 0:
		anim.play("skeleton_walking_south")
		anim.flip_h = false
	else:
		anim.play("skeleton_walking_north")
		anim.flip_h = false


func apply_level_scaling(level):
	var health_percent = health / max_health

	var level_bonus = max(level - 1, 0)

	speed = base_speed + min(level_bonus * 2.0, 30.0)
	attack_damage = base_attack_damage + level_bonus * 0.5
	max_health = base_max_health + level_bonus * 3.0

	health = max_health * health_percent
	update_health_bar()


func show_damage_number(amount, is_critical):
	var damage_label = damage_label_scene.instantiate()
	get_tree().current_scene.add_child(damage_label)

	damage_label.global_position = global_position + Vector2(0, -80)
	
	if is_critical:
		damage_label.setup(str(int(amount)) + "!", true)
	else:
		damage_label.setup(str(int(amount)), false)
		
		
func flash_damage():
	anim.modulate = Color(1, 0, 0, 1)

	await get_tree().create_timer(0.1).timeout

	if is_instance_valid(anim):
		anim.modulate = Color(1, 1, 1, 1)
