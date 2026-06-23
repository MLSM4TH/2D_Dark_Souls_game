extends Control

@onready var background = $Background
@onready var lightning_flash = $LightningFlash
@onready var knight_preview = $KnightPreview

@onready var menu_panel = $MenuPanel
@onready var title_label = $MenuPanel/VBoxContainer/TitleLabel
@onready var continue_button = $MenuPanel/VBoxContainer/ContinueButton
@onready var new_game_button = $MenuPanel/VBoxContainer/NewGameButton
@onready var settings_button = $MenuPanel/VBoxContainer/SettingsButton
@onready var quit_button = $MenuPanel/VBoxContainer/QuitButton

@onready var settings_panel = $SettingsPanel
@onready var fullscreen_button = $SettingsPanel/VBoxContainer/FullscreenButton
@onready var borderless_button = $SettingsPanel/VBoxContainer/BorderlessButton
@onready var back_button = $SettingsPanel/VBoxContainer/BackButton

@onready var rain_layer = $RainLayer

var rain_drops = []
var rain_amount = 70
var rain_speed = 520.0

var save_path = "user://save_game.cfg"
var world_scene_path = "res://scenes/world.tscn"


func _ready():
	setup_ui()
	connect_buttons()
	create_rain()
	update_menu_layout()
	start_lightning_loop()


func setup_ui():
	background.color = Color(0.02, 0.02, 0.04, 1)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	lightning_flash.color = Color(1, 1, 1, 1)
	lightning_flash.modulate.a = 0.0
	lightning_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE

	menu_panel.size = Vector2(360, 320)
	settings_panel.size = Vector2(360, 260)

	title_label.text = "DUNGEON\nOF THE FALLEN"
	continue_button.text = "Continue"
	new_game_button.text = "New Game"
	settings_button.text = "Settings"
	quit_button.text = "Quit"

	fullscreen_button.text = "Fullscreen"
	borderless_button.text = "Borderless"
	back_button.text = "Back"

	knight_preview.scale = Vector2(15, 15)
	knight_preview.z_index = 5
	knight_preview.play("idle_south")

	settings_panel.visible = false

	if not FileAccess.file_exists(save_path):
		continue_button.disabled = true


func update_menu_layout():
	var screen_size = get_viewport_rect().size

	background.position = Vector2.ZERO
	background.size = screen_size

	lightning_flash.position = Vector2.ZERO
	lightning_flash.size = screen_size

	rain_layer.position = Vector2.ZERO

	menu_panel.position = Vector2(80, (screen_size.y / 2) - 160)
	settings_panel.position = Vector2(80, (screen_size.y / 2) - 130)

	knight_preview.position = Vector2(screen_size.x * 0.75, screen_size.y * 0.55)


func connect_buttons():
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	borderless_button.pressed.connect(_on_borderless_pressed)
	back_button.pressed.connect(_on_back_pressed)


func _on_continue_pressed():
	get_tree().change_scene_to_file(world_scene_path)


func _on_new_game_pressed():
	delete_save_file()
	get_tree().change_scene_to_file(world_scene_path)


func _on_settings_pressed():
	menu_panel.visible = false
	settings_panel.visible = true


func _on_back_pressed():
	settings_panel.visible = false
	menu_panel.visible = true


func _on_quit_pressed():
	get_tree().quit()


func _on_fullscreen_pressed():
	var mode = DisplayServer.window_get_mode()

	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		fullscreen_button.text = "Fullscreen"
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		fullscreen_button.text = "Windowed"

	await get_tree().create_timer(0.1).timeout
	update_menu_layout()


func _on_borderless_pressed():
	var borderless = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, not borderless)

	await get_tree().create_timer(0.1).timeout
	update_menu_layout()


func _notification(what):
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		update_menu_layout()


func delete_save_file():
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)


func start_lightning_loop():
	while true:
		await get_tree().create_timer(randf_range(2.5, 8.0)).timeout
		await flash_lightning_sequence()


func flash_lightning_sequence():
	var flash_count = randi_range(1, 3)

	for i in range(flash_count):
		var strength = randf_range(0.25, 0.65)
		var flash_in = randf_range(0.02, 0.06)
		var flash_out = randf_range(0.12, 0.35)

		lightning_flash.modulate.a = 0.0

		var tween = create_tween()
		tween.tween_property(lightning_flash, "modulate:a", strength, flash_in)
		tween.tween_property(lightning_flash, "modulate:a", 0.0, flash_out)

		await tween.finished
		await get_tree().create_timer(randf_range(0.05, 0.22)).timeout


func create_rain():
	var screen_size = get_viewport_rect().size

	for i in range(rain_amount):
		var drop = Line2D.new()
		drop.width = 1.0
		drop.default_color = Color(0.55, 0.65, 0.8, randf_range(0.25, 0.55))

		var length = randf_range(12, 24)
		drop.points = [
			Vector2.ZERO,
			Vector2(-4, length)
		]

		drop.position = Vector2(
			randf_range(0, screen_size.x),
			randf_range(-screen_size.y, screen_size.y)
		)

		rain_layer.add_child(drop)
		rain_drops.append(drop)


func _process(delta):
	update_rain(delta)


func update_rain(delta):
	var screen_size = get_viewport_rect().size

	for drop in rain_drops:
		drop.position.y += rain_speed * delta
		drop.position.x -= 120 * delta

		if drop.position.y > screen_size.y + 40:
			drop.position.y = randf_range(-120, -20)
			drop.position.x = randf_range(0, screen_size.x + 200)
