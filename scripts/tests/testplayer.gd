extends CharacterBody2D

var walk_speed = 200
var run_speed = 400

var dodge_speed = 700
var dodge_duration = 0.2
var dodge_direction = Vector2.ZERO

var last_direction = "south"

var is_dodging = false
var is_parrying = false
var is_attacking = false
var is_invincible = false

@onready var anim = $AnimatedSprite2D


func _ready():
	anim.play("idle_south")


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

	if is_dodging:
		velocity = dodge_direction * dodge_speed
		move_and_slide()
		return

	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_parrying and direction != Vector2.ZERO:
		stop_parry()

	if Input.is_action_pressed("parry") and direction == Vector2.ZERO:
		start_parry()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if Input.is_action_just_pressed("dodge"):
		start_dodge(direction)
		return

	if Input.is_action_just_pressed("attack"):
		attack()
		return

	var current_speed = walk_speed
	var is_sprinting = Input.is_action_pressed("run") and direction != Vector2.ZERO

	if is_sprinting:
		current_speed = run_speed

	velocity = direction * current_speed
	move_and_slide()

	handle_animation(direction, is_sprinting)


func attack():
	is_attacking = true

	if last_direction == "sideways":
		anim.play("attack_sideways")
	elif last_direction == "south":
		anim.play("attack_south")
	elif last_direction == "north":
		anim.play("attack_north")

	await anim.animation_finished

	is_attacking = false
	play_idle_animation()


func start_dodge(direction):
	if direction == Vector2.ZERO:
		return

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


func start_parry():
	if is_parrying:
		return

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

			if direction.x > 0:
				anim.flip_h = false
			else:
				anim.flip_h = true

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
