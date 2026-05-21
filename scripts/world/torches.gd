extends Node2D

@onready var anim = $AnimatedSprite2D
@onready var light = $PointLight2D
@onready var fire_sound = $torch

func _ready():

	anim.play("torch_animation")

	setup_light()

	fire_sound.volume_db = -16
	fire_sound.pitch_scale = randf_range(0.95, 1.05)
	fire_sound.play()


func setup_light():

	var gradient = Gradient.new()

	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))

	var texture = GradientTexture2D.new()

	texture.gradient = gradient
	texture.width = 256
	texture.height = 256

	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)

	light.texture = texture

	light.color = Color.html("#FFB347")

	light.energy = 0.65

	light.texture_scale = 3.0

	light.blend_mode = Light2D.BLEND_MODE_ADD

	light.enabled = true
