extends CharacterBody2D

@onready var anim = $AnimatedSprite2D
@onready var health_bar = $MimicHealthBar

@export var max_health: float = 60.0
@export var attack_damage: float = 8.0
@export var attack_cooldown: float = 1.8
@export var attack_range: float = 38.0
@export var detection_range: float = 260.0

@export var hop_speed: float = 170.0
@export var hop_duration: float = 0.22
@export var hop_delay: float = 0.45
@export var hop_sprite_height: float = -12.0

var health: float = 60.0
var player: Node2D = null

var can_attack = true
var is_attacking = false
var is_hopping = false
var has_detected_player = false
var hop_direction = Vector2.ZERO
var hop_timer = 0.0

var damage_label_scene = preload("res://scenes/damage_number.tscn")


func _ready():
	add_to_group("enemy")
	add_to_group("mimic")

	player = get_tree().get_first_node_in_group("player")
	health = max_health

	health_bar.position.y = -45

	anim.play("mimic_animation")
	anim.pause()
	anim.frame = 0

	health_bar.play("mimic_health_bar")
	health_bar.pause()
	health_bar.frame = 0
	health_bar.visible = false


func _physics_process(delta):
	if player == null:
		return

	var distance = global_position.distance_to(player.global_position)

	if distance <= detection_range:
		has_detected_player = true

	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_hopping:
		continue_hop(delta)
		return

	if has_detected_player:
		if distance <= attack_range and can_attack:
			attack_player()
		else:
			start_hop()
	else:
		velocity = Vector2.ZERO
		anim.pause()
		anim.frame = 0


func start_hop():
	is_hopping = true
	hop_timer = hop_duration

	hop_direction = global_position.direction_to(player.global_position)
	anim.flip_h = player.global_position.x < global_position.x

	anim.play("mimic_animation")


func continue_hop(delta):
	hop_timer -= delta

	var progress = 1.0 - (hop_timer / hop_duration)

	if progress < 0.5:
		anim.position.y = lerp(0.0, hop_sprite_height, progress * 2.0)
	else:
		anim.position.y = lerp(hop_sprite_height, 0.0, (progress - 0.5) * 2.0)

	velocity = hop_direction * hop_speed
	move_and_slide()

	if get_slide_collision_count() > 0:
		end_hop()
		return

	if hop_timer <= 0:
		end_hop()


func end_hop():
	is_hopping = false
	velocity = Vector2.ZERO
	anim.position.y = 0
	anim.pause()
	anim.frame = 0

	await get_tree().create_timer(hop_delay).timeout


func attack_player():
	can_attack = false
	is_attacking = true
	velocity = Vector2.ZERO

	anim.play("mimic_animation")

	await get_tree().create_timer(0.25).timeout

	if player != null:
		var distance = global_position.distance_to(player.global_position)

		if distance <= attack_range and player.has_method("take_damage"):
			player.take_damage(attack_damage)

	await get_tree().create_timer(0.35).timeout

	is_attacking = false

	await get_tree().create_timer(attack_cooldown).timeout

	can_attack = true


func take_damage(amount):
	health -= amount
	health = clamp(health, 0, max_health)

	flash_damage()
	update_health_bar()
	show_health_bar_temporarily()

	if health <= 0:
		die()


func update_health_bar():
	var health_percent = health / max_health
	var frame_count = health_bar.sprite_frames.get_frame_count("mimic_health_bar")
	var frame_index = round((1.0 - health_percent) * (frame_count - 1))
	health_bar.frame = clamp(frame_index, 0, frame_count - 1)


func show_health_bar_temporarily():
	health_bar.visible = true

	await get_tree().create_timer(4.0).timeout

	if health > 0:
		health_bar.visible = false


func show_damage_number(amount, is_critical):
	var damage_label = damage_label_scene.instantiate()
	get_tree().current_scene.add_child(damage_label)

	damage_label.global_position = global_position + Vector2(0, -75)
	damage_label.setup(str(int(amount)), is_critical)


func flash_damage():
	var original_color = anim.modulate
	anim.modulate = Color(1, 0, 0, 1)

	await get_tree().create_timer(0.1).timeout

	if is_instance_valid(anim):
		anim.modulate = original_color


func die():
	var world = get_tree().current_scene

	if world.has_method("add_score"):
		world.add_score(200)

	if world.has_method("add_enemy_kill"):
		world.add_enemy_kill()

	if world.has_method("add_mimic_killed"):
		world.add_mimic_killed()

	set_physics_process(false)
	velocity = Vector2.ZERO

	var tween = create_tween()
	tween.parallel().tween_property(anim, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(anim, "scale", Vector2(0.6, 0.6), 0.4)

	await tween.finished
	queue_free()
