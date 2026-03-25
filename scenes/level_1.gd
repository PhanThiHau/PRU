extends Node2D

## Level 1: Rừng Điện Biên
## Uses TileMap created in editor, player/enemy/airplane placed in editor

var hud_scene = preload("res://scenes/ui/hud.tscn")
var ally_roaming_scene = preload("res://scenes/objects/ally_roaming.tscn")
var enemy_soldier_scene = preload("res://scenes/Enemy/Enemy.tscn")
var hud: CanvasLayer
var player: Node2D
var rest_area_triggered: bool = false
var can_interact_ally: bool = false
var ally_interacted: bool = false
var ally_label: Label = null

func _setup_level_bgm(path: String = "res://assets/audio/game_background_music1.mp3", volume_db: float = -10.0):
	var bgm = get_node_or_null("BGM")
	if bgm == null:
		bgm = AudioStreamPlayer.new()
		bgm.name = "BGM"
		add_child(bgm)

	var loaded_stream = load(path)
	if loaded_stream:
		if loaded_stream is AudioStreamMP3:
			(loaded_stream as AudioStreamMP3).loop = true
		elif loaded_stream is AudioStreamOggVorbis:
			(loaded_stream as AudioStreamOggVorbis).loop = true
		elif loaded_stream is AudioStreamWAV:
			(loaded_stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		bgm.stream = loaded_stream

	bgm.volume_db = volume_db
	if not bgm.playing:
		bgm.play()

func _ready():
	# Nhạc nền nhỏ
	_setup_level_bgm("res://assets/audio/backgroundSound.mp3", -8.0)

	# Find the player (placed in editor)
	player = _find_node_by_type("CharacterBody2D", "player")
	if not player:
		# Try to find by group after a frame
		await get_tree().process_frame
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
	
	# Instance HUD
	hud = hud_scene.instantiate()
	add_child(hud)
	
	# Connect player signals
	if player:
		if player.has_signal("player_died"):
			player.player_died.connect(_on_player_died)
	
	# Show level name
	hud.show_message("RỪNG ĐIỆN BIÊN", 3.0)
	
	# Setup ally interaction at end of map
	_setup_ally()
	
	# Configure enemies and airplanes patrol ranges
	_setup_enemies()
	
	# Spawn allies and enemies
	_spawn_allies()
	_spawn_enemies()

func _spawn_allies():
	if not player:
		return
	var base_pos = player.global_position
	var points = [Vector2(200, -80), Vector2(2200, -80), Vector2(4200, -80)]
	for pt_offset in points:
		var spawn_pos = base_pos + pt_offset
		for i in range(10):
			var ally = ally_roaming_scene.instantiate()
			ally.global_position = spawn_pos + Vector2(randf_range(-60, 60), randf_range(-20, 20))
			add_child(ally)

func _spawn_enemies():
	if not player:
		return
	var base_pos = player.global_position
	var points = [Vector2(1000, -80), Vector2(3000, -80), Vector2(5000, -80)]
	for pt_offset in points:
		var spawn_pos = base_pos + pt_offset
		for i in range(20):
			var enemy = enemy_soldier_scene.instantiate()
			enemy.global_position = spawn_pos + Vector2(randf_range(-60, 60), randf_range(-20, 20))
			add_child(enemy)

func _process(delta):
	if can_interact_ally and not ally_interacted:
		if Input.is_physical_key_pressed(KEY_E):
			_on_ally_interacted()

func _find_node_by_name_substring(sub: String, parent: Node) -> Node:
	if sub.to_lower() in parent.name.to_lower():
		return parent
	for child in parent.get_children():
		var found = _find_node_by_name_substring(sub, child)
		if found: return found
	return null

func _find_node_by_type(type_name: String, group_name: String) -> Node:
	# Search through direct children and their children
	for child in get_children():
		if child.is_in_group(group_name):
			return child
		for grandchild in child.get_children():
			if grandchild.is_in_group(group_name):
				return grandchild
	return null

func _setup_enemies():
	# Configure airplane patrol ranges based on their positions
	for child in get_children():
		if child.has_method("take_damage") and child.is_in_group("enemies"):
			if child is Node2D and "patrol_min_x" in child:
				# It's an airplane - set patrol range around its position
				child.patrol_min_x = child.global_position.x - 300
				child.patrol_max_x = child.global_position.x + 300
				child.patrol_y = child.global_position.y

func _setup_ally():
	var ally = _find_node_by_name_substring("DongMinh", self)
	if not ally:
		# Fallback if taking too long or not exactly matches
		_create_rest_area()
		return
		
	var area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1 # Player layer
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 120.0
	col.shape = shape
	area.add_child(col)
	
	ally.add_child(area)
	
	ally_label = Label.new()
	ally_label.text = "[E] Trò chuyện"
	ally_label.visible = false
	ally_label.position = Vector2(-40, -60)
	ally.add_child(ally_label)
	
	area.body_entered.connect(func(body):
		if body.is_in_group("player") and not ally_interacted:
			ally_label.visible = true
			can_interact_ally = true
	)
	
	area.body_exited.connect(func(body):
		if body.is_in_group("player"):
			if ally_label: ally_label.visible = false
			can_interact_ally = false
	)

func _on_ally_interacted():
	ally_interacted = true
	can_interact_ally = false
	if ally_label:
		ally_label.visible = false
		
	# Dialogue from Ally
	hud.show_message("Đồng minh: Đồng chí làm tốt lắm, hãy nghỉ ngơi", 3.0)
	await get_tree().create_timer(3.0).timeout
	
	# Show "Mission Accomplished" and "Rest"
	_show_mission_accomplished()

func _show_mission_accomplished():
	# Create overlay
	var overlay = CanvasLayer.new()
	overlay.layer = 100
	add_child(overlay)
	
	var panel = ColorRect.new()
	panel.color = Color(0, 0, 0, 0.85)
	panel.anchors_preset = Control.PRESET_FULL_RECT
	overlay.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.anchors_preset = Control.PRESET_CENTER
	vbox.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vbox.grow_vertical = Control.GROW_DIRECTION_BOTH
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(vbox)
	
	var title = Label.new()
	title.text = "ĐÃ HOÀN THÀNH NHIỆM VỤ"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)
	
	var subtitle = Label.new()
	subtitle.text = "HÃY NGHỈ NGƠI"
	subtitle.add_theme_font_size_override("font_size", 30)
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)
	
	await get_tree().create_timer(4.0).timeout
	GameManager.complete_level()

func _create_rest_area():
	# Removed old rest area logic. If fallback happens we just print for now.
	print("Ally not found for level completion.")

func _on_player_died():
	# Single life - show score and return to menu
	_show_game_over_screen()

func _show_game_over_screen():
	# Pause the game and freeze screen
	get_tree().paused = true
	
	# Create a full-screen game over overlay
	var overlay = CanvasLayer.new()
	overlay.layer = 100
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)
	
	var control = Control.new()
	overlay.add_child(control)
	
	var vp_size = get_viewport_rect().size
	control.size = vp_size
	
	var panel = ColorRect.new()
	panel.color = Color(0.1, 0.0, 0.0, 0.85)
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
	title.text = "ĐỒNG CHÍ ĐÃ RẤT CỐ GẮNG"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 40)
	vbox.add_child(btn_hbox)
	
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

func _complete_level():
	hud.show_message("HOÀN THÀNH NHIỆM VỤ!", 3.0)
	await get_tree().create_timer(3.0).timeout
	GameManager.complete_level()
