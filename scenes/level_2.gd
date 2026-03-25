extends Node2D

var bg_music: AudioStreamPlayer
var hud_scene = preload("res://scenes/ui/hud.tscn")
var ally_roaming_scene = preload("res://scenes/objects/ally_roaming.tscn")
var enemy_soldier_scene = preload("res://scenes/Enemy/Enemy.tscn")
var hud: CanvasLayer

func _ready():
	_setup_audio()
	hud = hud_scene.instantiate()
	add_child(hud)
	hud.show_message("ĐỒNG BẰNG MIỀN NAM", 3.0)
	
	# Spawn allies and enemies
	_spawn_allies()
	_spawn_enemies()

func _setup_audio():
	bg_music = AudioStreamPlayer.new()
	bg_music.stream = load("res://assets/audio/backgroundSound.mp3") # Keep using backgroundSound.mp3 for now
	bg_music.volume_db = -4.0
	bg_music.process_mode = Node.PROCESS_MODE_ALWAYS
	bg_music.finished.connect(func(): bg_music.play()) # LOOP MUSIC
	add_child(bg_music)
	bg_music.play()

var t54_connected: bool = false
var m48_connected: bool = false
var game_over: bool = false

func _process(delta):
	if game_over: return
	
	if not t54_connected:
		var t54s = get_tree().get_nodes_in_group("t54_tank")
		if t54s.size() > 0:
			t54s[0].tank_destroyed.connect(_on_t54_destroyed)
			t54_connected = true
			
	if not m48_connected:
		var m48s = get_tree().get_nodes_in_group("m48_tank")
		if m48s.size() > 0:
			m48s[0].tank_destroyed.connect(_on_m48_destroyed)
			m48_connected = true
			
	# Connect to player death dynamically
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var p = players[0]
		if not p.is_connected("player_died", _on_player_died):
			p.player_died.connect(_on_player_died)

func _on_player_died():
	if game_over: return
	game_over = true
	_show_end_screen("ĐỒNG CHÍ ĐÃ RẤT CỐ GẮNG", false)

func _on_t54_destroyed():
	if game_over: return
	game_over = true
	_show_end_screen("XE TĂNG ĐỒNG MINH ĐÃ BỊ PHÁ HỦY!", false)

func _on_m48_destroyed():
	if game_over: return
	game_over = true
	_show_end_screen("TIẾN VỀ SÀI GÒN", true)

func _show_end_screen(msg: String, is_win: bool):
	get_tree().paused = true
	
	var overlay = CanvasLayer.new()
	overlay.layer = 100
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	
	var control = Control.new()
	overlay.add_child(control)
	
	var vp_size = get_viewport_rect().size
	control.size = vp_size
	
	var panel = ColorRect.new()
	if is_win:
		panel.color = Color(0.0, 0.2, 0.0, 0.85) # Green overlay for win
	else:
		panel.color = Color(0.1, 0.0, 0.0, 0.85) # Red overlay for lose
	panel.size = vp_size
	control.add_child(panel)
	
	var center = CenterContainer.new()
	center.size = vp_size
	control.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)
	
	var title = Label.new()
	title.text = msg
	title.add_theme_font_size_override("font_size", 48)
	if is_win:
		title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
	else:
		title.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 40)
	vbox.add_child(btn_hbox)
	
	if not is_win:
		var btn_retry = Button.new()
		btn_retry.text = " CHƠI LẠI "
		btn_retry.add_theme_font_size_override("font_size", 28)
		btn_retry.pressed.connect(func(): 
			get_tree().paused = false
			get_tree().reload_current_scene()
		)
		btn_hbox.add_child(btn_retry)
		
		var btn_menu = Button.new()
		btn_menu.text = " MÀN HÌNH CHÍNH "
		btn_menu.add_theme_font_size_override("font_size", 28)
		btn_menu.pressed.connect(func(): 
			get_tree().paused = false
			GameManager.go_to_menu()
		)
		btn_hbox.add_child(btn_menu)
	else:
		var btn_next = Button.new()
		btn_next.text = " TIẾP TỤC (MÀN 3) "
		btn_next.add_theme_font_size_override("font_size", 28)
		btn_next.pressed.connect(func(): 
			get_tree().paused = false
			GameManager.current_level = 1
			GameManager.complete_level()
		)
		btn_hbox.add_child(btn_next)

func _spawn_allies():
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	var base_pos = Vector2(400, 400)
	if players.size() > 0:
		base_pos = players[0].global_position
	
	var points = [Vector2(200, -80), Vector2(1800, -80), Vector2(3400, -80)]
	for pt_offset in points:
		var spawn_pos = base_pos + pt_offset
		for i in range(10):
			var ally = ally_roaming_scene.instantiate()
			ally.global_position = spawn_pos + Vector2(randf_range(-60, 60), randf_range(-20, 20))
			add_child(ally)

func _spawn_enemies():
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	var base_pos = Vector2(1000, 400)
	if players.size() > 0:
		base_pos = players[0].global_position
		
	var points = [Vector2(1000, -80), Vector2(2600, -80), Vector2(4200, -80)]
	for pt_offset in points:
		var spawn_pos = base_pos + pt_offset
		for i in range(20):
			var enemy = enemy_soldier_scene.instantiate()
			enemy.global_position = spawn_pos + Vector2(randf_range(-60, 60), randf_range(-20, 20))
			add_child(enemy)
