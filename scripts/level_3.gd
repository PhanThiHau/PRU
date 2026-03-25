extends "res://scripts/base_level.gd"

## Level 3: Cao nguyên (highlands)
## Địa hình đồi dốc, nhiều vị trí bắn tỉa và xe tăng chốt giữ.

var airplane_scene = preload("res://scenes/objects/enemy_airplane.tscn")
var tank_ally_scene = preload("res://scenes/objects/tank_t-54.tscn")
var tank_enemy_scene = preload("res://scenes/objects/tank_m-48.tscn")
var prop_scene = preload("res://scenes/objects/destructible_prop.tscn")
var powerup_scene = preload("res://scenes/objects/powerup.tscn")
var building_boss_scene = preload("res://scenes/objects/boss_building.tscn")
var ally_roaming_scene = preload("res://scenes/objects/ally_roaming.tscn")
var enemy_soldier_scene = preload("res://scenes/Enemy/Enemy.tscn")

const LEVEL_W: float = 4200.0
const GROUND_Y: float = 650.0

const TERRAIN_TOP = [
	Vector2(0, 650),
	Vector2(500, 610),
	Vector2(900, 690),
	Vector2(1400, 620),
	Vector2(1800, 700),
	Vector2(2300, 640),
	Vector2(2800, 710),
	Vector2(3300, 630),
	Vector2(3800, 680),
	Vector2(4200, 650),
]

var _wind_time: float = 0.0

func setup_level():
	level_name = "MÀN 3: CAO NGUYÊN LỬA"


func _ready():
	super._ready()
	_setup_level_bgm("res://assets/audio/backgroundSound.mp3", -10.0)
	
	# base_level.gd spawned a `player`. Let's see if a manual one exists.
	var all_players = get_tree().get_nodes_in_group("player")
	var manual_player = null
	for p in all_players:
		if p != player:
			manual_player = p
			break
	
	if manual_player:
		if is_instance_valid(player):
			player.queue_free()
		player = manual_player
		if not player.player_died.is_connected(_on_player_died):
			player.player_died.connect(_on_player_died)
	
	if player and "topdown_mode" in player:
		player.topdown_mode = true
		
	# Bật topdown_mode cho tất cả xe tăng và kẻ địch được đặt thủ công trên bản đồ
	for node in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("allies"):
		if "topdown_mode" in node:
			node.topdown_mode = true
			
	# Spawn 3 nhom dong minh (5 linh moi nhom)
	_spawn_allies()
	_spawn_enemies()
			
	queue_redraw()

var victory_triggered: bool = false

func _process(delta):
	_wind_time += delta
	queue_redraw()
	
	if not victory_triggered and player and is_instance_valid(player):
		if player.global_position.x >= 8900.0:
			victory_triggered = true
			var vz = preload("res://scenes/objects/VictoryZone.tscn").instantiate()
			add_child(vz)
			vz._trigger_victory()

func _spawn_allies():
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	var p_pos = Vector2(400, 400)
	if players.size() > 0:
		p_pos = players[0].global_position
		
	var points = [
		p_pos + Vector2(200, 0),
		p_pos + Vector2(1200, 100),
		p_pos + Vector2(2400, -100),
		p_pos + Vector2(3600, 50),
		p_pos + Vector2(4800, -50)
	]
	for pt in points:
		for i in range(10):
			var ally = ally_roaming_scene.instantiate()
			ally.global_position = pt + Vector2(randf_range(-60, 60), randf_range(-60, 60))
			if "topdown_mode" in ally:
				ally.topdown_mode = true
			add_child(ally)

func _spawn_enemies():
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	var p_pos = Vector2(400, 400)
	if players.size() > 0:
		p_pos = players[0].global_position
		
	var points = [
		p_pos + Vector2(1000, 0),
		p_pos + Vector2(1800, 200),
		p_pos + Vector2(3200, -200),
		p_pos + Vector2(4400, 150),
		p_pos + Vector2(5600, -150)
	]
	for pt in points:
		for i in range(20):
			var enemy = enemy_soldier_scene.instantiate()
			enemy.global_position = pt + Vector2(randf_range(-60, 60), randf_range(-60, 60))
			if "topdown_mode" in enemy:
				enemy.topdown_mode = true
			add_child(enemy)

func _spawn_tank_ally(pos: Vector2):
	var tank = tank_ally_scene.instantiate()
	tank.global_position = pos
	if "topdown_mode" in tank:
		tank.topdown_mode = true
	add_child(tank)

func _spawn_tank_enemy(pos: Vector2):
	var tank = tank_enemy_scene.instantiate()
	tank.global_position = pos
	if "topdown_mode" in tank:
		tank.topdown_mode = true
	add_child(tank)

func _spawn_airplane(pos: Vector2, mn: float, mx: float):
	var ap = airplane_scene.instantiate()
	ap.global_position = pos
	ap.patrol_min_x = mn
	ap.patrol_max_x = mx
	add_child(ap)

func _spawn_prop(pos: Vector2, ptype: int):
	var p = prop_scene.instantiate()
	p.prop_type = ptype
	p.global_position = pos
	add_child(p)

func _spawn_powerup(pos: Vector2, ptype: int):
	var p = powerup_scene.instantiate()
	p.power_type = ptype
	p.global_position = pos
	add_child(p)

func _on_boss_defeated():
	complete_level()

func _ground_y(x: float) -> float:
	if x <= TERRAIN_TOP[0].x:
		return TERRAIN_TOP[0].y
	for i in range(TERRAIN_TOP.size() - 1):
		var a = TERRAIN_TOP[i]
		var b = TERRAIN_TOP[i + 1]
		if x <= b.x:
			var t = (x - a.x) / max(b.x - a.x, 1.0)
			return lerp(a.y, b.y, t)
	return TERRAIN_TOP[TERRAIN_TOP.size() - 1].y

func _draw():
	pass

func _draw_sky():
	draw_rect(Rect2(-1000, -800, 6000, 1600), Color(0.32, 0.50, 0.62))
	draw_rect(Rect2(-1000, -200, 6000, 500), Color(0.42, 0.62, 0.72, 0.8))
	for i in range(10):
		var x = -400 + i * 600
		var y = 80 + float((i * 37) % 90)
		_draw_cloud(Vector2(x, y))

func _draw_far_mountains():
	var c = Color(0.12, 0.18, 0.12, 0.7)
	for i in range(12):
		var x = -300 + i * 520
		var h = 280.0 + float((i * 41) % 120)
		_tri(Vector2(x, GROUND_Y + 20), Vector2(x + 260, h), Vector2(x + 520, GROUND_Y + 20), c)

func _draw_near_ridges():
	var c = Color(0.10, 0.16, 0.08, 0.85)
	for i in range(14):
		var x = -260 + i * 480
		var h = 340.0 + float((i * 29) % 90)
		_tri(Vector2(x, GROUND_Y + 40), Vector2(x + 240, h), Vector2(x + 480, GROUND_Y + 40), c)

func _draw_ground():
	var poly = PackedVector2Array()
	for p in TERRAIN_TOP:
		poly.append(p)
	poly.append(Vector2(LEVEL_W, 900))
	poly.append(Vector2(0, 900))
	draw_colored_polygon(poly, Color(0.20, 0.14, 0.08))
	draw_polyline(PackedVector2Array(TERRAIN_TOP), Color(0.28, 0.42, 0.16), 8.0)

func _draw_fog():
	for i in range(5):
		var y = 520 + i * 22
		var x = -200 + float(i) * 180
		var w = 1400 + sin(_wind_time + float(i)) * 80
		draw_rect(Rect2(x, y, w, 16), Color(0.7, 0.78, 0.74, 0.08))

func _draw_props():
	# Hàng rào và đá
	for x in [500, 1200, 1900, 2600, 3300, 3900]:
		_draw_rock(Vector2(float(x), randf_range(400, 700)))
	for x in [800, 1600, 2400, 3200, 4000]:
		_draw_post(Vector2(float(x), randf_range(400, 700)))

func _draw_cloud(pos: Vector2):
	draw_circle(pos, 32, Color(1, 1, 1, 0.35))
	draw_circle(pos + Vector2(24, 6), 24, Color(1, 1, 1, 0.30))
	draw_circle(pos + Vector2(-24, -6), 22, Color(1, 1, 1, 0.28))

func _draw_rock(pos: Vector2):
	draw_rect(Rect2(pos.x - 18, pos.y - 8, 36, 12), Color(0.22, 0.20, 0.18))
	draw_rect(Rect2(pos.x - 10, pos.y - 16, 20, 10), Color(0.26, 0.24, 0.22))

func _draw_post(pos: Vector2):
	draw_rect(Rect2(pos.x - 4, pos.y - 30, 8, 30), Color(0.20, 0.16, 0.10))
	draw_line(Vector2(pos.x - 18, pos.y - 20), Vector2(pos.x + 18, pos.y - 16), Color(0.35, 0.12, 0.10), 3.0)

func _tri(p1: Vector2, p2: Vector2, p3: Vector2, c: Color):
	draw_colored_polygon(PackedVector2Array([p1, p2, p3]), c)
