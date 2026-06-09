extends Node2D

@onready var tilemap = $TileMapLayer
@onready var torches = $Torches
@onready var player = $player
@onready var score_label = $CanvasLayer/ScoreLabel
@onready var skeleton_enemy = $SkeletonEnemy

@onready var pause_menu = $CanvasLayer/PauseMenu
@onready var main_pause_page = $CanvasLayer/PauseMenu/MainPausePage
@onready var settings_page = $CanvasLayer/PauseMenu/SettingsPage

@onready var resume_button = $CanvasLayer/PauseMenu/MainPausePage/VBoxContainer/ResumeButton
@onready var settings_button = $CanvasLayer/PauseMenu/MainPausePage/VBoxContainer/SettingsButton
@onready var main_menu_button = $CanvasLayer/PauseMenu/MainPausePage/VBoxContainer/MainMenuButton
@onready var quit_button = $CanvasLayer/PauseMenu/MainPausePage/VBoxContainer/QuitButton

@onready var fullscreen_button = $CanvasLayer/PauseMenu/SettingsPage/VBoxContainer/FullscreenButton
@onready var borderless_button = $CanvasLayer/PauseMenu/SettingsPage/VBoxContainer/BorderlessButton
@onready var back_button = $CanvasLayer/PauseMenu/SettingsPage/VBoxContainer/BackButton

var is_paused = false

var score = 0

var WALL_NORMAL_SOURCE = 0
var WALL_DECAYED_SOURCE = 1
var FLOOR_SOURCE = 2
var TILE_COORDS = Vector2i(0, 0)

var torch_scene = preload("res://scenes/torches.tscn")

var map_width = 160
var map_height = 100

var floor_cells = {}

var corridor_width = 9
var torch_amount = 45
var min_torch_distance = 12

var boss_room_position = Vector2i.ZERO
var boss_room_size = Vector2i(30, 22)

@onready var ambient_drips = $water_drip_cave

func _ready():
	randomize()
	generate_dungeon()
	spawn_torches()
	spawn_player_on_floor(Vector2i(10, 10))
	ambient_drips.volume_db = -18
	ambient_drips.play()
	place_skeleton_on_floor(Vector2i(12, 10))
	
	pause_menu.visible = false
	main_pause_page.visible = true
	settings_page.visible = false

	resume_button.pressed.connect(_on_resume_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

	fullscreen_button.pressed.connect(_on_fullscreen_button_pressed)
	borderless_button.pressed.connect(_on_borderless_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	
	score_label.text = "Score: 0"


func generate_dungeon():
	tilemap.clear()
	clear_old_torches()
	floor_cells.clear()

	# Main starting area
	carve_room(Vector2i(5, 5), Vector2i(32, 22))

	# Main dungeon rooms
	carve_room(Vector2i(48, 5), Vector2i(36, 24))
	carve_room(Vector2i(98, 8), Vector2i(38, 24))

	carve_room(Vector2i(8, 42), Vector2i(38, 24))
	carve_room(Vector2i(58, 42), Vector2i(38, 24))
	carve_room(Vector2i(108, 42), Vector2i(38, 24))

	carve_room(Vector2i(20, 75), Vector2i(38, 20))
	carve_room(Vector2i(75, 75), Vector2i(38, 20))

	# Wide corridors connecting main rooms
	carve_corridor(Vector2i(30, 16), Vector2i(55, 16))
	carve_corridor(Vector2i(78, 17), Vector2i(105, 20))

	carve_corridor(Vector2i(25, 25), Vector2i(25, 48))
	carve_corridor(Vector2i(68, 27), Vector2i(68, 48))
	carve_corridor(Vector2i(120, 30), Vector2i(120, 48))

	carve_corridor(Vector2i(42, 54), Vector2i(65, 54))
	carve_corridor(Vector2i(92, 54), Vector2i(115, 54))

	carve_corridor(Vector2i(38, 62), Vector2i(38, 80))
	carve_corridor(Vector2i(82, 64), Vector2i(82, 80))

	carve_corridor(Vector2i(50, 85), Vector2i(78, 85))

	# Large black voids inside rooms
	create_void_with_wall_border(Vector2i(15, 13), Vector2i(12, 6))
	create_void_with_wall_border(Vector2i(60, 14), Vector2i(14, 6))
	create_void_with_wall_border(Vector2i(112, 17), Vector2i(14, 6))

	create_void_with_wall_border(Vector2i(20, 50), Vector2i(14, 7))
	create_void_with_wall_border(Vector2i(70, 50), Vector2i(14, 7))
	create_void_with_wall_border(Vector2i(120, 50), Vector2i(14, 7))

	create_void_with_wall_border(Vector2i(32, 82), Vector2i(14, 6))
	create_void_with_wall_border(Vector2i(88, 82), Vector2i(14, 6))

	# Random boss room
	create_random_boss_room()

	# Place floors
	for cell in floor_cells.keys():
		place_floor(cell)

	# Create walls around all floor areas
	create_walls_around_floor()


func carve_room(start_pos, size):
	for x in range(start_pos.x, start_pos.x + size.x):
		for y in range(start_pos.y, start_pos.y + size.y):
			add_floor(Vector2i(x, y))


func carve_corridor(start_pos, end_pos):
	var half_width = int(corridor_width / 2)

	if start_pos.x != end_pos.x:
		var min_x = min(start_pos.x, end_pos.x)
		var max_x = max(start_pos.x, end_pos.x)

		for x in range(min_x, max_x + 1):
			for y in range(start_pos.y - half_width, start_pos.y + half_width + 1):
				add_floor(Vector2i(x, y))

	if start_pos.y != end_pos.y:
		var min_y = min(start_pos.y, end_pos.y)
		var max_y = max(start_pos.y, end_pos.y)

		for y in range(min_y, max_y + 1):
			for x in range(start_pos.x - half_width, start_pos.x + half_width + 1):
				add_floor(Vector2i(x, y))


func create_void_with_wall_border(start_pos, size):
	for x in range(start_pos.x, start_pos.x + size.x):
		for y in range(start_pos.y, start_pos.y + size.y):
			var pos = Vector2i(x, y)

			var is_border = (
				x == start_pos.x
				or y == start_pos.y
				or x == start_pos.x + size.x - 1
				or y == start_pos.y + size.y - 1
			)

			floor_cells.erase(pos)

			if is_border:
				place_random_wall(pos)
			else:
				tilemap.erase_cell(pos)


func create_random_boss_room():
	var possible_positions = [
		Vector2i(118, 8),
		Vector2i(118, 68),
		Vector2i(15, 68),
		Vector2i(62, 10),
		Vector2i(95, 72)
	]

	boss_room_position = possible_positions.pick_random()

	carve_room(boss_room_position, boss_room_size)

	# Boss room entrance corridor always connects to main dungeon
	var boss_center = boss_room_position + Vector2i(int(boss_room_size.x / 2), int(boss_room_size.y / 2))
	carve_corridor(Vector2i(82, 54), boss_center)

	# Big black arena hazard/object in the boss room
	create_void_with_wall_border(
		boss_room_position + Vector2i(9, 7),
		Vector2i(12, 6)
	)


func add_floor(pos):
	if pos.x > 1 and pos.y > 1 and pos.x < map_width - 1 and pos.y < map_height - 1:
		floor_cells[pos] = true


func create_walls_around_floor():
	var directions = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1),
		Vector2i(1, 1),
		Vector2i(-1, -1),
		Vector2i(1, -1),
		Vector2i(-1, 1)
	]

	for cell in floor_cells.keys():
		for direction in directions:
			var wall_pos = cell + direction

			if not floor_cells.has(wall_pos):
				place_random_wall(wall_pos)


func place_floor(pos):
	tilemap.set_cell(pos, FLOOR_SOURCE, TILE_COORDS)


func place_random_wall(pos):
	var source_id = WALL_NORMAL_SOURCE

	if randi_range(0, 7) == 1:
		source_id = WALL_DECAYED_SOURCE

	tilemap.set_cell(pos, source_id, TILE_COORDS)


func spawn_torches():
	var valid_positions = []

	for cell in floor_cells.keys():
		if has_open_space_around(cell):
			valid_positions.append(cell)

	valid_positions.shuffle()

	var placed_torches = []

	for pos in valid_positions:
		if placed_torches.size() >= torch_amount:
			break

		if is_far_from_other_torches(pos, placed_torches):
			spawn_standing_torch(pos)
			placed_torches.append(pos)

	# Extra boss room torches
	spawn_boss_room_torches()


func spawn_boss_room_torches():
	var torch_spots = [
		boss_room_position + Vector2i(5, 5),
		boss_room_position + Vector2i(boss_room_size.x - 6, 5),
		boss_room_position + Vector2i(5, boss_room_size.y - 6),
		boss_room_position + Vector2i(boss_room_size.x - 6, boss_room_size.y - 6)
	]

	for spot in torch_spots:
		if floor_cells.has(spot):
			spawn_standing_torch(spot)


func has_open_space_around(pos):
	for x in range(pos.x - 3, pos.x + 4):
		for y in range(pos.y - 3, pos.y + 4):
			if not floor_cells.has(Vector2i(x, y)):
				return false

	return true


func is_far_from_other_torches(pos, placed_torches):
	for torch_pos in placed_torches:
		if pos.distance_to(torch_pos) < min_torch_distance:
			return false

	return true


func spawn_standing_torch(pos):
	var torch = torch_scene.instantiate()
	torches.add_child(torch)

	torch.global_position = tilemap.to_global(tilemap.map_to_local(pos))
	torch.global_position.y -= 6


func clear_old_torches():
	for child in torches.get_children():
		child.queue_free()


func spawn_player_on_floor(pos):
	player.global_position = tilemap.to_global(tilemap.map_to_local(pos))


func place_skeleton_on_floor(pos: Vector2i):
	skeleton_enemy.global_position = tilemap.to_global(tilemap.map_to_local(pos))
	skeleton_enemy.global_position.y -= 6
	
func add_score(amount):
	score += amount
	score_label.text = "Score: " + str(score)
	
func _input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if is_paused and settings_page.visible:
			show_main_pause_page()
		else:
			toggle_pause()


func toggle_pause():
	is_paused = !is_paused
	get_tree().paused = is_paused
	pause_menu.visible = is_paused

	if is_paused:
		show_main_pause_page()


func show_main_pause_page():
	main_pause_page.visible = true
	settings_page.visible = false


func show_settings_page():
	main_pause_page.visible = false
	settings_page.visible = true

func _on_resume_button_pressed():
	toggle_pause()


func _on_settings_button_pressed():
	show_settings_page()


func _on_back_button_pressed():
	show_main_pause_page()


func _on_fullscreen_button_pressed():
	var mode = DisplayServer.window_get_mode()

	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _on_borderless_button_pressed():
	var borderless = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, !borderless)
	

func _on_main_menu_button_pressed():
	print("Main menu not added yet")


func _on_quit_button_pressed():
	get_tree().quit()
