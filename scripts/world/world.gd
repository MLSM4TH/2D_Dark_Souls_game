extends Node2D

@onready var tilemap = $TileMapLayer
@onready var torches = $Torches
@onready var player = $player
@onready var score_label = $CanvasLayer/GameplayHUD/ScoreLabel
@onready var ambient_drips = $water_drip_cave

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

@onready var death_screen = $CanvasLayer/DeathScreen
@onready var you_died_label = $CanvasLayer/DeathScreen/YouDiedLabel

@onready var save_button = $CanvasLayer/PauseMenu/MainPausePage/VBoxContainer/SaveButton
@onready var save_notification = $CanvasLayer/GameplayHUD/SaveNotification

@onready var playtime_label = $CanvasLayer/GameplayHUD/PlayTimeLabel
@onready var level_label = $CanvasLayer/GameplayHUD/LevelLabel
@onready var exp_label = $CanvasLayer/GameplayHUD/ExpLabel

@onready var achievement_popup = $CanvasLayer/AchievementPopup
@onready var achievement_label = $CanvasLayer/AchievementPopup/AchievementLabel

@onready var main_menu_vbox = $CanvasLayer/PauseMenu/MainPausePage/VBoxContainer

@onready var statistics_button = $CanvasLayer/PauseMenu/MainPausePage/VBoxContainer/StatisticsButton
@onready var statistics_container = $CanvasLayer/PauseMenu/MainPausePage/VBoxContainer/StatisticsBox
@onready var statistics_label = $CanvasLayer/PauseMenu/MainPausePage/VBoxContainer/StatisticsBox/StatisticsLabel
@onready var achievements_label = $CanvasLayer/PauseMenu/MainPausePage/VBoxContainer/StatisticsBox/AchievementsLabel
@onready var stats_back_button = $CanvasLayer/PauseMenu/MainPausePage/VBoxContainer/StatisticsBox/StatsBackButton
@onready var level_up_label = $CanvasLayer/LevelUpLabel

@onready var gold_label = $CanvasLayer/GameplayHUD/GoldLabel
@onready var gold_icon = $CanvasLayer/GameplayHUD/GoldIcon

@onready var shop_menu = $CanvasLayer/ShopMenu
@onready var shop_title_label = $CanvasLayer/ShopMenu/VBoxContainer/TitleLabel
@onready var health_upgrade_button = $CanvasLayer/ShopMenu/VBoxContainer/HealthUpgradeButton
@onready var damage_upgrade_button = $CanvasLayer/ShopMenu/VBoxContainer/DamageUpgradeButton
@onready var stamina_upgrade_button = $CanvasLayer/ShopMenu/VBoxContainer/StaminaUpgradeButton
@onready var full_heal_button = $CanvasLayer/ShopMenu/VBoxContainer/PotionButton
@onready var shop_close_button = $CanvasLayer/ShopMenu/VBoxContainer/BackButton

var goblin_shop_scene = preload("res://scenes/goblin_shop.tscn")

var shop_room_position = Vector2i(68, 82)
var shop_room_size = Vector2i(18, 12)

var health_upgrade_cost = 50
var damage_upgrade_cost = 75
var stamina_upgrade_cost = 50
var full_heal_cost = 30

var health_upgrades_bought = 0
var damage_upgrades_bought = 0
var stamina_upgrades_bought = 0

var gold = 0
var highest_score = 0

var normal_menu_position = Vector2.ZERO

var unlocked_achievements = {}

var player_level = 1
var player_exp = 0
var exp_to_next_level = 100

var player_is_dead = false
var is_paused = false

var score = 0
var enemies_killed = 0
var total_playtime = 0.0

var autosave_interval = 60.0
var autosave_timer = 0.0

var save_path = "user://save_game.cfg"

var WALL_NORMAL_SOURCE = 0
var WALL_DECAYED_SOURCE = 1
var FLOOR_SOURCE = 2
var TILE_COORDS = Vector2i(0, 0)

var torch_scene = preload("res://scenes/torches.tscn")
var skeleton_scene = preload("res://scenes/skeleton_enemy.tscn")

var map_width = 160
var map_height = 100

var floor_cells = {}

var corridor_width = 9
var torch_amount = 45
var min_torch_distance = 12

var boss_room_position = Vector2i.ZERO
var boss_room_size = Vector2i(30, 22)

var skeleton_amount = 20
var min_enemy_spawn_distance = 10

var total_damage_dealt = 0
var total_damage_taken = 0
var critical_hits = 0

var kill_streak = 0
var best_kill_streak = 0
var kill_streak_timer = 0.0
var kill_streak_time_limit = 5.0

var chest_scene = preload("res://scenes/chest.tscn")
var chest_amount = 10
var min_chest_spawn_distance = 8

var chests_opened = 0
var mimics_spawned = 0
var mimics_killed = 0

func _ready():
	randomize()

	generate_dungeon()
	spawn_torches()
	spawn_player_randomly()
	spawn_skeletons_randomly()
	spawn_chests_randomly()
	spawn_goblin_shop()

	ambient_drips.volume_db = -18
	ambient_drips.play()

	setup_ui()
	connect_buttons()

	score_label.text = "Score: 0"

	if get_tree().has_meta("death_respawn"):
		get_tree().remove_meta("death_respawn")

		player.health = player.max_health
		player.stamina = player.max_stamina
		player.update_health_bar()
		player.update_stamina_bar()

		score = 0
		enemies_killed = 0
		total_playtime = 0.0
		player_level = 1
		player_exp = 0
		exp_to_next_level = 100

		score_label.text = "Score: 0"
		update_progression_ui()
		update_playtime_label()
	else:
		load_game()


func _process(delta):
	if player_is_dead:
		return

	if get_tree().paused:
		return

	total_playtime += delta
	autosave_timer += delta

	update_playtime_label()
	
	check_achievements()
	if autosave_timer >= autosave_interval:
		autosave_timer = 0.0
		save_game()
		show_save_notification("Autosaved")
		
	if kill_streak > 0:
		kill_streak_timer -= delta

	if kill_streak_timer <= 0:
		kill_streak = 0


func setup_ui():
	pause_menu.visible = false
	main_pause_page.visible = true
	settings_page.visible = false

	death_screen.visible = false
	death_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	you_died_label.process_mode = Node.PROCESS_MODE_ALWAYS
	you_died_label.text = "YOU DIED"
	you_died_label.modulate = Color(1, 0, 0, 0)
	you_died_label.scale = Vector2(0.8, 0.8)

	save_notification.visible = false
	save_notification.modulate.a = 0.0
	
	level_label.position = Vector2(20, 40)
	exp_label.position = Vector2(20, 55)

	playtime_label.position = Vector2(570, 15)
	playtime_label.size = Vector2(160, 30)
	playtime_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	achievement_popup.visible = false
	achievement_popup.modulate.a = 0.0

	level_up_label.visible = false
	level_up_label.text = "LEVEL UP!"
	level_up_label.modulate = Color(1, 1, 0, 0)
	level_up_label.scale = Vector2(0.8, 0.8)
	
	normal_menu_position = main_menu_vbox.position
	statistics_container.visible = false
	
	statistics_container.visible = false
	statistics_label.text = ""
	achievements_label.text = ""
	stats_back_button.text = "Back"
	
	score_label.visible = true
	score_label.text = "Score: " + str(score)
	score_label.position = Vector2(1075, 15)
	score_label.size = Vector2(180, 30)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.z_index = 100
	
	gold_icon.visible = true
	gold_label.visible = true
	gold_icon.position = Vector2(1180, 50)
	gold_icon.scale = Vector2(0.75, 0.75)
	gold_label.position = Vector2(1200, 40)
	gold_label.size = Vector2(120, 30)
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	gold_label.text = str(gold)
	gold_label.z_index = 100
	gold_icon.z_index = 100
	
	shop_menu.visible = false
	shop_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	shop_title_label.text = "Goblin Shop"
	shop_menu.position = Vector2(430, 160)
	shop_menu.size = Vector2(420, 360)

	health_upgrade_button.text = "+10 Health - " + str(health_upgrade_cost) + " Gold"
	damage_upgrade_button.text = "+2 Damage - " + str(damage_upgrade_cost) + " Gold"
	stamina_upgrade_button.text = "+10 Stamina - " + str(stamina_upgrade_cost) + " Gold"
	full_heal_button.text = "Full Heal - " + str(full_heal_cost) + " Gold"
	shop_close_button.text = "Close"
	
	


func connect_buttons():
	resume_button.pressed.connect(_on_resume_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)

	fullscreen_button.pressed.connect(_on_fullscreen_button_pressed)
	borderless_button.pressed.connect(_on_borderless_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)

	save_button.pressed.connect(_on_save_button_pressed)
	
	statistics_button.pressed.connect(_on_statistics_button_pressed)
	stats_back_button.pressed.connect(_on_stats_back_button_pressed)
	
	health_upgrade_button.pressed.connect(_on_health_upgrade_pressed)
	damage_upgrade_button.pressed.connect(_on_damage_upgrade_pressed)
	stamina_upgrade_button.pressed.connect(_on_stamina_upgrade_pressed)
	full_heal_button.pressed.connect(_on_full_heal_pressed)
	shop_close_button.pressed.connect(_on_shop_close_pressed)

func generate_dungeon():
	tilemap.clear()
	clear_old_torches()
	floor_cells.clear()

	carve_room(Vector2i(5, 5), Vector2i(32, 22))

	carve_room(Vector2i(48, 5), Vector2i(36, 24))
	carve_room(Vector2i(98, 8), Vector2i(38, 24))

	carve_room(Vector2i(8, 42), Vector2i(38, 24))
	carve_room(Vector2i(58, 42), Vector2i(38, 24))
	carve_room(Vector2i(108, 42), Vector2i(38, 24))

	carve_room(Vector2i(20, 75), Vector2i(38, 20))
	carve_room(Vector2i(75, 75), Vector2i(38, 20))

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

	create_void_with_wall_border(Vector2i(15, 13), Vector2i(12, 6))
	create_void_with_wall_border(Vector2i(60, 14), Vector2i(14, 6))
	create_void_with_wall_border(Vector2i(112, 17), Vector2i(14, 6))

	create_void_with_wall_border(Vector2i(20, 50), Vector2i(14, 7))
	create_void_with_wall_border(Vector2i(70, 50), Vector2i(14, 7))
	create_void_with_wall_border(Vector2i(120, 50), Vector2i(14, 7))

	create_void_with_wall_border(Vector2i(32, 82), Vector2i(14, 6))
	create_void_with_wall_border(Vector2i(88, 82), Vector2i(14, 6))

	create_random_boss_room()

	for cell in floor_cells.keys():
		place_floor(cell)

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

	var boss_center = boss_room_position + Vector2i(
		int(boss_room_size.x / 2),
		int(boss_room_size.y / 2)
	)

	carve_corridor(Vector2i(82, 54), boss_center)

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


func spawn_player_randomly():
	var random_floor = get_random_floor_position()
	player.global_position = tilemap.to_global(tilemap.map_to_local(random_floor))


func spawn_skeletons_randomly():
	for i in range(skeleton_amount):
		var skeleton = skeleton_scene.instantiate()
		add_child(skeleton)

		var random_floor = get_random_floor_far_from_player()
		skeleton.global_position = tilemap.to_global(tilemap.map_to_local(random_floor))
		skeleton.global_position.y -= 6

		if skeleton.has_method("apply_level_scaling"):
			skeleton.apply_level_scaling(player_level)


func get_random_floor_position():
	var floor_positions = floor_cells.keys()
	return floor_positions.pick_random()


func get_random_floor_far_from_player():
	var floor_positions = floor_cells.keys()
	var player_tile = tilemap.local_to_map(tilemap.to_local(player.global_position))

	for i in range(100):
		var random_floor = floor_positions.pick_random()

		if is_inside_shop_room(random_floor):
			continue

		if random_floor.distance_to(player_tile) < min_enemy_spawn_distance:
			continue

		if not has_open_space_around(random_floor):
			continue

		return random_floor

	return floor_positions.pick_random()
	
	


func add_score(amount):
	score += amount

	if score > highest_score:
		highest_score = score

	score_label.text = "Score: " + str(score)

func add_enemy_kill():
	enemies_killed += 1
	add_exp(25)

	kill_streak += 1
	kill_streak_timer = kill_streak_time_limit

	if kill_streak > best_kill_streak:
		best_kill_streak = kill_streak

	if kill_streak >= 3:
		add_score(50)

	check_achievements()


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
	get_tree().paused = false
	is_paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _on_quit_button_pressed():
	get_tree().quit()


func show_death_screen():
	if player_is_dead:
		return

	player_is_dead = true

	death_screen.visible = true
	death_screen.show()
	you_died_label.show()

	you_died_label.text = "YOU DIED"
	you_died_label.modulate = Color(1, 0, 0, 0)
	you_died_label.scale = Vector2(0.8, 0.8)

	var tween = create_tween()

	tween.parallel().tween_property(you_died_label, "modulate:a", 1.0, 1.0)
	tween.parallel().tween_property(you_died_label, "scale", Vector2(1.3, 1.3), 1.0)

	await tween.finished
	await get_tree().create_timer(1.0).timeout

	var fade_out = create_tween()

	fade_out.parallel().tween_property(you_died_label, "modulate:a", 0.0, 0.8)
	fade_out.parallel().tween_property(you_died_label, "scale", Vector2(1.6, 1.6), 0.8)

	await fade_out.finished
	
	get_tree().set_meta("death_respawn", true)
	get_tree().reload_current_scene()


func save_game():
	var config = ConfigFile.new()

	config.set_value("player", "health", player.health)
	config.set_value("player", "stamina", player.stamina)

	config.set_value("game", "score", score)
	config.set_value("game", "enemies_killed", enemies_killed)
	config.set_value("game", "playtime", total_playtime)
	
	config.set_value("progression", "level", player_level)
	config.set_value("progression", "exp", player_exp)
	config.set_value("progression", "exp_to_next_level", exp_to_next_level)
	
	config.set_value("progression", "level", player_level)
	config.set_value("progression", "exp", player_exp)
	config.set_value("progression", "exp_to_next_level", exp_to_next_level)
	config.set_value("game", "playtime", total_playtime)
	
	config.set_value("game", "highest_score", highest_score)
	
	config.set_value("combat", "damage_dealt", total_damage_dealt)
	config.set_value("combat", "damage_taken", total_damage_taken)
	config.set_value("combat", "critical_hits", critical_hits)
		
	config.set_value("chests", "chests_opened", chests_opened)
	config.set_value("chests", "mimics_spawned", mimics_spawned)
	config.set_value("chests", "mimics_killed", mimics_killed)
	
	config.set_value("shop", "health_upgrade_cost", health_upgrade_cost)
	config.set_value("shop", "damage_upgrade_cost", damage_upgrade_cost)
	config.set_value("shop", "stamina_upgrade_cost", stamina_upgrade_cost)

	config.set_value("shop", "health_upgrades_bought", health_upgrades_bought)
	config.set_value("shop", "damage_upgrades_bought", damage_upgrades_bought)
	config.set_value("shop", "stamina_upgrades_bought", stamina_upgrades_bought)

	config.set_value("player_stats", "max_health", player.max_health)
	config.set_value("player_stats", "max_stamina", player.max_stamina)
	config.set_value("player_stats", "attack_damage", player.player_attack_damage)
		
	for achievement_name in unlocked_achievements.keys():
		config.set_value("achievements", achievement_name, true)
		
	config.set_value("loot", "gold", gold)

	config.set_value(
		"settings",
		"fullscreen",
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	)

	config.set_value(
		"settings",
		"borderless",
		DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS)
	)

	config.set_value(
		"save",
		"last_save",
		Time.get_datetime_string_from_system()
	)

	var error = config.save(save_path)

	if error == OK:
		print("Game saved")
	else:
		print("Save failed: ", error)


func load_game():
	var config = ConfigFile.new()
	var error = config.load(save_path)

	if error != OK:
		print("No save file found")
		return

	score = config.get_value("game", "score", 0)
	score_label.text = "Score: " + str(score)

	enemies_killed = config.get_value("game", "enemies_killed", 0)
	total_playtime = config.get_value("game", "playtime", 0.0)

	player.health = config.get_value("player", "health", player.max_health)
	player.stamina = config.get_value("player", "stamina", player.max_stamina)
	
	player_level = config.get_value("progression", "level", 1)
	player_exp = config.get_value("progression", "exp", 0)
	exp_to_next_level = config.get_value("progression", "exp_to_next_level", 100)
	
	player_level = config.get_value("progression", "level", 1)
	player_exp = config.get_value("progression", "exp", 0)
	exp_to_next_level = config.get_value("progression", "exp_to_next_level", 100)
	total_playtime = config.get_value("game", "playtime", 0.0)
	
	highest_score = config.get_value("game", "highest_score", 0)
	
	total_damage_dealt = config.get_value("combat", "damage_dealt", 0)
	total_damage_taken = config.get_value("combat", "damage_taken", 0)
	critical_hits = config.get_value("combat", "critical_hits", 0)
	
	chests_opened = config.get_value("chests", "chests_opened", 0)
	mimics_spawned = config.get_value("chests", "mimics_spawned", 0)
	mimics_killed = config.get_value("chests", "mimics_killed", 0)
	
	unlocked_achievements.clear()
	
	gold = config.get_value("loot", "gold", 0)
	gold_label.text = str(gold)
	
	health_upgrade_cost = config.get_value("shop", "health_upgrade_cost", 50)
	damage_upgrade_cost = config.get_value("shop", "damage_upgrade_cost", 75)
	stamina_upgrade_cost = config.get_value("shop", "stamina_upgrade_cost", 50)

	health_upgrades_bought = config.get_value("shop", "health_upgrades_bought", 0)
	damage_upgrades_bought = config.get_value("shop", "damage_upgrades_bought", 0)
	stamina_upgrades_bought = config.get_value("shop", "stamina_upgrades_bought", 0)

	player.max_health = config.get_value("player_stats", "max_health", player.max_health)
	player.max_stamina = config.get_value("player_stats", "max_stamina", player.max_stamina)
	player.player_attack_damage = config.get_value("player_stats", "attack_damage", player.player_attack_damage)

	var achievement_names = [
		"First Blood",
		"Hunter",
		"Executioner",
		"Level Up",
		"Experienced",
		"Survivor"
	]

	for achievement_name in achievement_names:
		var unlocked = config.get_value("achievements", achievement_name, false)
		if unlocked:
			unlocked_achievements[achievement_name] = true

	update_progression_ui()
	update_playtime_label()

	player.update_health_bar()
	player.update_stamina_bar()

	var fullscreen = config.get_value("settings", "fullscreen", false)

	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	var borderless = config.get_value("settings", "borderless", false)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, borderless)

	var last_save = config.get_value("save", "last_save", "No save date")
	print("Game loaded")
	print("Last save: ", last_save)


func _on_save_button_pressed():
	save_game()
	show_save_notification("Game Saved")


func show_save_notification(message):
	save_notification.text = message
	save_notification.visible = true
	save_notification.modulate.a = 1.0

	var tween = create_tween()
	tween.tween_property(save_notification, "modulate:a", 0.0, 2.0)

	await tween.finished

	save_notification.visible = false
	
	
func add_exp(amount):
	player_exp += amount

	while player_exp >= exp_to_next_level:
		player_exp -= exp_to_next_level
		level_up()

	update_progression_ui()


func level_up():
	player_level += 1
	exp_to_next_level = int(exp_to_next_level * 1.35)

	player.max_health += 5
	player.health = player.max_health

	player.max_stamina += 5
	player.stamina = player.max_stamina

	player.stamina_regen += 1.0

	if player_level % 2 == 0:
		player.player_attack_damage += 1.0

	player.update_health_bar()
	player.update_stamina_bar()


	scale_existing_enemies()
	check_achievements()
	show_level_up_popup()
	show_save_notification("Level Up!")


func update_progression_ui():
	level_label.text = "LV " + str(player_level)
	exp_label.text = "EXP: " + str(player_exp) + " / " + str(exp_to_next_level)
	

func show_level_up_popup():
	level_up_label.visible = true
	level_up_label.modulate.a = 0.0
	level_up_label.scale = Vector2(0.8, 0.8)

	var tween = create_tween()
	tween.parallel().tween_property(level_up_label, "modulate:a", 1.0, 0.4)
	tween.parallel().tween_property(level_up_label, "scale", Vector2(1.3, 1.3), 0.4)

	await tween.finished
	await get_tree().create_timer(1.0).timeout

	var fade = create_tween()
	fade.parallel().tween_property(level_up_label, "modulate:a", 0.0, 0.6)
	fade.parallel().tween_property(level_up_label, "scale", Vector2(1.6, 1.6), 0.6)

	await fade.finished
	level_up_label.visible = false


func get_playtime_text():
	var seconds = int(total_playtime)
	var minutes = int(seconds / 60)
	var hours = int(minutes / 60)

	seconds = seconds % 60
	minutes = minutes % 60

	return "%02d:%02d:%02d" % [hours, minutes, seconds]


func update_playtime_label():
	playtime_label.text = get_playtime_text()


func scale_existing_enemies():
	var enemies = get_tree().get_nodes_in_group("enemy")

	for enemy in enemies:
		if enemy.has_method("apply_level_scaling"):
			enemy.apply_level_scaling(player_level)
			
			
func check_achievements():
	if enemies_killed >= 1:
		unlock_achievement("First Blood", "Kill your first enemy")

	if enemies_killed >= 10:
		unlock_achievement("Hunter", "Kill 10 enemies")

	if enemies_killed >= 25:
		unlock_achievement("Executioner", "Kill 25 enemies")

	if player_level >= 2:
		unlock_achievement("Level Up", "Reach level 2")

	if player_level >= 5:
		unlock_achievement("Experienced", "Reach level 5")

	if total_playtime >= 300:
		unlock_achievement("Survivor", "Survive for 5 minutes")


func unlock_achievement(title, description):
	if unlocked_achievements.has(title):
		return

	unlocked_achievements[title] = true
	show_achievement_popup(title, description)


func show_achievement_popup(title, description):
	achievement_label.text = "Achievement Unlocked!\n" + title + "\n" + description

	achievement_popup.visible = true
	achievement_popup.modulate.a = 1.0
	achievement_popup.scale = Vector2(0.8, 0.8)

	var tween = create_tween()
	tween.parallel().tween_property(achievement_popup, "scale", Vector2(1.0, 1.0), 0.4)
	tween.parallel().tween_property(achievement_popup, "modulate:a", 1.0, 0.4)

	await get_tree().create_timer(2.0).timeout

	var fade_out = create_tween()
	fade_out.tween_property(achievement_popup, "modulate:a", 0.0, 1.0)

	await fade_out.finished
	achievement_popup.visible = false
	
func _on_statistics_button_pressed():
	show_statistics_page()


func _on_stats_back_button_pressed():
	hide_statistics_page()


func show_statistics_page():
	resume_button.visible = false
	main_menu_button.visible = false
	statistics_button.visible = false
	settings_button.visible = false
	save_button.visible = false
	quit_button.visible = false

	main_menu_vbox.position = Vector2(0, 10)

	statistics_container.visible = true
	update_statistics_menu()

func hide_statistics_page():
	main_menu_vbox.position = normal_menu_position

	resume_button.visible = true
	main_menu_button.visible = true
	statistics_button.visible = true
	settings_button.visible = true
	save_button.visible = true
	quit_button.visible = true

	statistics_container.visible = false


func update_statistics_menu():
	var unlocked_count = unlocked_achievements.size()
	var total_achievements = 6

	statistics_label.text = (
		"Statistics\n\n"
		+ "Level: " + str(player_level) + "\n"
		+ "EXP: " + str(player_exp) + " / " + str(exp_to_next_level) + "\n"
		+ "Score: " + str(score) + "\n"
		+ "Highest Score: " + str(highest_score) + "\n"
		+ "Enemies Killed: " + str(enemies_killed) + "\n"
		+ "Chests Opened: " + str(chests_opened) + "\n"
		+ "Mimics Found: " + str(mimics_spawned) + "\n"
		+ "Mimics Killed: " + str(mimics_killed) + "\n"
		+ "Damage Dealt: " + str(total_damage_dealt) + "\n"
 		+ "Damage Taken: " + str(total_damage_taken) + "\n"
 		+ "Critical Hits: " + str(critical_hits) + "\n"
		+ "Playtime: " + get_playtime_text() + "\n"
		+ "Achievements: " + str(unlocked_count) + " / " + str(total_achievements)
	)

	update_achievements_menu()



func update_achievements_menu():
	var text = "Achievements\n\n"

	text += get_achievement_line("First Blood", "Kill your first enemy")
	text += get_achievement_line("Hunter", "Kill 10 enemies")
	text += get_achievement_line("Executioner", "Kill 25 enemies")
	text += get_achievement_line("Level Up", "Reach level 2")
	text += get_achievement_line("Experienced", "Reach level 5")
	text += get_achievement_line("Survivor", "Survive for 5 minutes")

	achievements_label.text = text


func get_achievement_line(title, description):
	var checkbox = "[ ]"

	if unlocked_achievements.has(title):
		checkbox = "[X]"

	return checkbox + " " + title + " - " + description + "\n"


func add_damage_dealt(amount):
	total_damage_dealt += int(amount)


func add_damage_taken(amount):
	total_damage_taken += int(amount)


func add_critical_hit():
	critical_hits += 1
	

func spawn_chests_randomly():
	for i in range(chest_amount):
		var chest = chest_scene.instantiate()
		add_child(chest)

		var random_floor = get_random_floor_far_from_player()
		chest.global_position = tilemap.to_global(tilemap.map_to_local(random_floor))
		chest.global_position.y -= 6


func add_chest_opened():
	chests_opened += 1


func add_mimic_spawned():
	mimics_spawned += 1


func add_mimic_killed():
	mimics_killed += 1


func respawn_chest_after_delay():
	await get_tree().create_timer(20.0).timeout

	var chest = chest_scene.instantiate()
	add_child(chest)

	var random_floor = get_random_floor_far_from_player()
	chest.global_position = tilemap.to_global(tilemap.map_to_local(random_floor))
	chest.global_position.y -= 6


func add_gold(amount):
	gold += amount
	gold_label.text = str(gold)


func open_shop():
	is_paused = true
	get_tree().paused = true
	shop_menu.visible = true
	update_shop_buttons()


func close_shop():
	shop_menu.visible = false
	get_tree().paused = false
	is_paused = false


func update_shop_buttons():
	health_upgrade_button.text = "+10 Health - " + str(health_upgrade_cost) + " Gold"
	damage_upgrade_button.text = "+2 Damage - " + str(damage_upgrade_cost) + " Gold"
	stamina_upgrade_button.text = "+10 Stamina - " + str(stamina_upgrade_cost) + " Gold"
	full_heal_button.text = "Full Heal - " + str(full_heal_cost) + " Gold"

	health_upgrade_button.disabled = gold < health_upgrade_cost
	damage_upgrade_button.disabled = gold < damage_upgrade_cost
	stamina_upgrade_button.disabled = gold < stamina_upgrade_cost
	full_heal_button.disabled = gold < full_heal_cost or player.health >= player.max_health


func spend_gold(amount):
	if gold < amount:
		return false

	gold -= amount
	gold_label.text = str(gold)
	return true


func _on_health_upgrade_pressed():
	if not spend_gold(health_upgrade_cost):
		return

	health_upgrades_bought += 1
	player.max_health += 10
	player.health = player.max_health
	player.update_health_bar()

	health_upgrade_cost += 25
	update_shop_buttons()
	save_game()


func _on_damage_upgrade_pressed():
	if not spend_gold(damage_upgrade_cost):
		return

	damage_upgrades_bought += 1
	player.player_attack_damage += 2

	damage_upgrade_cost += 35
	update_shop_buttons()
	save_game()


func _on_stamina_upgrade_pressed():
	if not spend_gold(stamina_upgrade_cost):
		return

	stamina_upgrades_bought += 1
	player.max_stamina += 10
	player.stamina = player.max_stamina
	player.update_stamina_bar()

	stamina_upgrade_cost += 25
	update_shop_buttons()
	save_game()


func _on_full_heal_pressed():
	if not spend_gold(full_heal_cost):
		return

	player.health = player.max_health
	player.update_health_bar()

	update_shop_buttons()
	save_game()


func _on_shop_close_pressed():
	close_shop()


func create_shop_room():
	carve_room(shop_room_position, shop_room_size)

	var center = shop_room_position + Vector2i(
		int(shop_room_size.x / 2),
		int(shop_room_size.y / 2)
	)

	carve_corridor(Vector2i(82, 80), center)


func spawn_goblin_shop():
	var goblin = goblin_shop_scene.instantiate()
	add_child(goblin)

	var center = shop_room_position + Vector2i(
		int(shop_room_size.x / 2),
		int(shop_room_size.y / 2)
	)

	goblin.global_position = tilemap.to_global(tilemap.map_to_local(center))
	goblin.global_position.y -= 6


func is_inside_shop_room(pos: Vector2i):
	return (
		pos.x >= shop_room_position.x
		and pos.x < shop_room_position.x + shop_room_size.x
		and pos.y >= shop_room_position.y
		and pos.y < shop_room_position.y + shop_room_size.y
	)
