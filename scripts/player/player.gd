extends CharacterBody2D

var walk_speed = 200
var run_speed = 400

var dodge_speed = 700
var dodge_duration = 0.2
var dodge_direction = Vector2.ZERO

var max_health = 100.0
var health = 100.0

var max_stamina = 100.0
var stamina = 100.0
var stamina_regen = 18.0

var sprint_stamina_cost = 8.0
var dodge_stamina_cost = 18.0
var attack_stamina_cost = 12.0

var attack_damage_active = false
var attack_commit_time = 0.75
var attack_cancel_frame = 1

var last_direction = "south"

var is_attacking = false
var is_dodging = false
var is_invincible = false
var is_parrying = false
var can_cancel_attack = false

@onready var anim = $AnimatedSprite2D
@onready var stamina_bar = $"../CanvasLayer/StaminaBar"
@onready var health_bar = $"../CanvasLayer/HealthBar"

@onready var footstep_sound = $footstep_rock
@onready var slash_sound = $sword_slash
@onready var dodge_sound = $dodge
@onready var parry_sound = $"sword_parry"


func _ready():
	add_to_group("player")

	anim.play("idle_south")

	stamina_bar.play("stamina_bar_depletion_animation")
	stamina_bar.pause()

	health_bar.play("health_bar_depletion_animation")
	health_bar.pause()

	footstep_sound.volume_db = -12
	slash_sound.volume_db = -6
	dodge_sound.volume_db = -8
	parry_sound.volume_db = -8

	update_stamina_bar()
	update_health_bar()


func _physics_process(delta):
	var direction = Vector2.ZERO

	if Input.is_action_pressed("move_right"):
		direction.x += 1
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_down"):
		direction.y += 1
	if Input.is_action_pressed("move_up"):
		direction.y -= 1

	direction = direction.normalized()

	var is_trying_to_sprint = Input.is_action_pressed("run") and direction != Vector2.ZERO

	if not is_attacking and not is_dodging and not is_trying_to_sprint:
		stamina += stamina_regen * delta
		stamina = clamp(stamina, 0, max_stamina)
		update_stamina_bar()

	if is_parrying and direction != Vector2.ZERO:
		stop_parry()

	if is_attacking and can_cancel_attack and direction != Vector2.ZERO:
		cancel_attack()

	if is_dodging:
		velocity = dodge_direction * dodge_speed
		move_and_slide()
		return

	if Input.is_action_pressed("parry") and direction == Vector2.ZERO and not is_attacking:
		start_parry()
		velocity = Vector2.ZERO
		move_and_slide()
		stop_footsteps()
		return
	else:
		if is_parrying:
			stop_parry()

	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		stop_footsteps()
		return

	if Input.is_action_just_pressed("dodge") and stamina >= dodge_stamina_cost:
		start_dodge(direction)
		return

	if Input.is_action_just_pressed("attack") and stamina >= attack_stamina_cost:
		attack()
		return

	var current_speed = walk_speed
	var is_sprinting = is_trying_to_sprint and stamina > 0

	if is_sprinting:
		current_speed = run_speed
		stamina -= sprint_stamina_cost * delta
		stamina = clamp(stamina, 0, max_stamina)
		update_stamina_bar()

	velocity = direction * current_speed
	move_and_slide()

	handle_animation(direction, is_sprinting)
	handle_footsteps(direction, is_sprinting)


func take_damage(amount):
	if is_invincible:
		return

	health -= amount
	health = clamp(health, 0, max_health)
	update_health_bar()

	if health <= 0:
		die()


func die():
	print("Player died")
	velocity = Vector2.ZERO
	set_physics_process(false)


func update_health_bar():
	var health_percent = health / max_health
	var frame_count = health_bar.sprite_frames.get_frame_count("health_bar_depletion_animation")
	var frame_index = round((1.0 - health_percent) * (frame_count - 1))
	health_bar.frame = clamp(frame_index, 0, frame_count - 1)


func update_stamina_bar():
	var stamina_percent = stamina / max_stamina
	var frame_count = stamina_bar.sprite_frames.get_frame_count("stamina_bar_depletion_animation")
	var frame_index = round((1.0 - stamina_percent) * (frame_count - 1))
	stamina_bar.frame = clamp(frame_index, 0, frame_count - 1)


func handle_footsteps(direction, is_sprinting):
	if direction == Vector2.ZERO:
		stop_footsteps()
		return

	if not footstep_sound.playing:
		if is_sprinting:
			footstep_sound.pitch_scale = randf_range(1.05, 1.15)
		else:
			footstep_sound.pitch_scale = randf_range(0.95, 1.05)

		footstep_sound.play()


func stop_footsteps():
	if footstep_sound.playing:
		footstep_sound.stop()


func start_dodge(direction):
	if direction == Vector2.ZERO:
		return

	stop_footsteps()

	stamina -= dodge_stamina_cost
	stamina = clamp(stamina, 0, max_stamina)
	update_stamina_bar()

	dodge_sound.pitch_scale = randf_range(0.95, 1.05)
	dodge_sound.play()

	is_dodging = true
	is_invincible = true
	dodge_direction = direction.normalized()

	if last_direction == "sideways":
		anim.play("running_sideways")
	elif last_direction == "south":
		anim.play("running_south")
	elif last_direction == "north":
		anim.play("running_north")

	anim.speed_scale = 2.0

	await get_tree().create_timer(dodge_duration).timeout

	is_dodging = false
	is_invincible = false
	anim.speed_scale = 1.0

	play_idle_animation()


func attack():
	stop_footsteps()

	stamina -= attack_stamina_cost
	stamina = clamp(stamina, 0, max_stamina)
	update_stamina_bar()

	slash_sound.pitch_scale = randf_range(0.95, 1.08)
	slash_sound.play()

	is_attacking = true
	can_cancel_attack = false
	attack_damage_active = false

	var attack_animation = ""

	if last_direction == "sideways":
		attack_animation = "attack_sideways"
	elif last_direction == "south":
		attack_animation = "attack_south"
	elif last_direction == "north":
		attack_animation = "attack_north"

	anim.play(attack_animation)

	while anim.frame < attack_cancel_frame and is_attacking:
		await get_tree().process_frame

	can_cancel_attack = true

	var frame_count = anim.sprite_frames.get_frame_count(attack_animation)
	var animation_fps = anim.sprite_frames.get_animation_speed(attack_animation)
	var animation_length = frame_count / animation_fps
	var damage_time = animation_length * attack_commit_time

	await get_tree().create_timer(damage_time).timeout

	if is_attacking:
		attack_damage_active = true

	await anim.animation_finished

	is_attacking = false
	can_cancel_attack = false
	attack_damage_active = false

	play_idle_animation()


func cancel_attack():
	is_attacking = false
	can_cancel_attack = false
	attack_damage_active = false
	play_idle_animation()


func start_parry():
	if is_parrying:
		return

	stop_footsteps()

	parry_sound.pitch_scale = randf_range(0.95, 1.05)
	parry_sound.play()

	is_parrying = true
	is_invincible = true

	if last_direction == "sideways":
		anim.play("attack_sideways")
		anim.pause()
		anim.frame = 3
	elif last_direction == "south":
		anim.play("attack_south")
		anim.pause()
		anim.frame = 2
	elif last_direction == "north":
		anim.play("attack_north")
		anim.pause()
		anim.frame = 2


func stop_parry():
	is_parrying = false
	is_invincible = false
	anim.play()
	play_idle_animation()


func handle_animation(direction, is_sprinting):
	if direction != Vector2.ZERO:
		if abs(direction.x) > abs(direction.y):
			last_direction = "sideways"
			anim.flip_h = direction.x < 0

			if is_sprinting:
				anim.play("running_sideways")
			else:
				anim.play("walk_sideways")

		elif direction.y > 0:
			last_direction = "south"
			anim.flip_h = false

			if is_sprinting:
				anim.play("running_south")
			else:
				anim.play("walk_south")

		elif direction.y < 0:
			last_direction = "north"
			anim.flip_h = false

			if is_sprinting:
				anim.play("running_north")
			else:
				anim.play("walk_north")

		anim.speed_scale = 1.0
	else:
		play_idle_animation()


func play_idle_animation():
	anim.speed_scale = 1.0

	if last_direction == "sideways":
		anim.play("idle_sideways")
	elif last_direction == "south":
		anim.play("idle_south")
	elif last_direction == "north":
		anim.play("idle_north")
