extends CharacterBody2D

## Enemy Airplane - Flies horizontally, drops bombs

signal enemy_died(enemy)
signal crashed(pos: Vector2)

@export var health: float = 15.0
@export var speed: float = 190.0

var direction: float = 1.0
var patrol_min_x: float = 100.0
var patrol_max_x: float = 3900.0
var bomb_timer: float = 2.5
var flash_timer: float = 0.0
var prop_angle: float = 0.0
var smoke_trail: Array = []
var is_falling: bool = false
var fall_velocity: Vector2 = Vector2.ZERO

var bullet_scene = preload("res://scenes/objects/bullet.tscn")

func _ready():
	add_to_group("enemies")
	z_index = 8
	# Layer 2 so player bullets (mask=2) can detect us; mask=0 = fly through terrain
	collision_layer = 2
	collision_mask  = 0

func _physics_process(delta):
	if is_falling:
		_fall_step(delta)
		return
	prop_angle  += delta * 28.0
	flash_timer  = maxf(0.0, flash_timer - delta)
	bomb_timer  -= delta

	# Horizontal patrol
	position.x += direction * speed * delta
	if position.x > patrol_max_x:
		direction = -1.0
	elif position.x < patrol_min_x:
		direction = 1.0

	# Slight sine wave altitude drift
	position.y += sin(Time.get_ticks_msec() / 900.0) * 0.4

	if bomb_timer <= 0.0:
		_drop_bomb()
		bomb_timer = randf_range(2.8, 5.2)

	# Smoke trail
	smoke_trail.append({"pos": global_position + Vector2(0, 10), "life": 0.5})
	for i in range(smoke_trail.size() - 1, -1, -1):
		smoke_trail[i].life -= delta
		if smoke_trail[i].life <= 0.0:
			smoke_trail.remove_at(i)

	queue_redraw()

func _drop_bomb():
	var bomb = Node2D.new()
	bomb.global_position = global_position + Vector2(0, 20)
	bomb.z_index = 9
	
	# Attach a script inline via a custom class
	var script = GDScript.new()
	script.source_code = """
extends Node2D

var vel_x: float = 0.0
var vel_y: float = 0.0
var bomb_damage: float = 3.0
var bomb_lifetime: float = 5.0

func _ready():
	vel_y = 20.0

func _process(delta):
	vel_y += 500.0 * delta
	position.x += vel_x * delta
	position.y += vel_y * delta
	rotation = Vector2(vel_x, vel_y).angle()
	
	# Get ground level from player position
	var ground_y = 700.0
	var players = get_tree().get_nodes_in_group(\"player\")
	if players.size() > 0 and is_instance_valid(players[0]):
		ground_y = players[0].global_position.y + 10.0
	
	if global_position.y >= ground_y:
		_bomb_explode()
		return
	
	bomb_lifetime -= delta
	if bomb_lifetime <= 0:
		queue_free()
	queue_redraw()

func _draw():
	draw_circle(Vector2.ZERO, 6.0, Color(0.15, 0.15, 0.15))
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.4, 0.1))

func _bomb_explode():
	var explosion_scene = load(\"res://scenes/objects/no.tscn\")
	if explosion_scene:
		var exp = explosion_scene.instantiate()
		exp.global_position = global_position
		exp.scale = Vector2(0.5, 0.5)
		get_tree().current_scene.add_child(exp)
		var anim = exp.get_node_or_null(\"AnimatedSprite2D\")
		if anim:
			anim.play(\"explosion\")
			get_tree().create_timer(1.2).timeout.connect(exp.queue_free)
	# Deal damage to nearby units
	for body in get_tree().get_nodes_in_group(\"player\") + get_tree().get_nodes_in_group(\"allies\"):
		if is_instance_valid(body) and global_position.distance_to(body.global_position) < 120.0:
			if body.has_method(\"take_damage\"):
				body.take_damage(int(bomb_damage))
	queue_free()
"""
	script.reload()
	bomb.set_script(script)
	bomb.set("vel_x", direction * 30.0)
	get_tree().current_scene.add_child(bomb)

func take_damage(amount: float):
	health      -= amount
	flash_timer  = 0.14
	if health <= 0.0:
		die()

func die():
	if is_falling:
		return
	GameManager.add_score(800)
	enemy_died.emit(self)
	is_falling = true
	fall_velocity = Vector2(0, 120)
	bomb_timer = 999.0
	# Stop patrol influence
	speed = 0.0
	# Minor shake immediately
	if get_tree().current_scene and get_tree().current_scene.has_method("_start_camera_shake"):
		get_tree().current_scene._start_camera_shake(0.4, 5.0)

func _fall_step(delta: float):
	fall_velocity.y += 520.0 * delta
	global_position += fall_velocity * delta
	rotation += delta * 2.5
	# Crash when hitting ground
	var ground_y = 700.0
	if get_tree().current_scene and get_tree().current_scene.has_method("_ground_y"):
		ground_y = get_tree().current_scene._ground_y(global_position.x) + 10.0
	if global_position.y >= ground_y:
		_crash()

func _crash():
	crashed.emit(global_position)
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)

func _draw():
	# Smoke trail
	for s in smoke_trail:
		var alpha = s.life / 0.5
		draw_circle(to_local(s.pos), 4.0 + (1.0 - alpha) * 6.0, Color(0.5, 0.5, 0.5, alpha * 0.3))

	var c  = Color(0.42, 0.50, 0.38) if flash_timer <= 0.0 else Color(1.0, 0.85, 0.6)
	var gc = Color(0.55, 0.85, 0.98, 0.85)
	var d  = 1 if direction >= 0.0 else -1

	# Wing shadow
	draw_rect(Rect2(-28, -2, 56, 6), Color(0.1, 0.1, 0.1, 0.25))

	# Main wings
	var wing = PackedVector2Array([Vector2(-28,-3),Vector2(-28,3),Vector2(28,3),Vector2(28,-3)])
	draw_colored_polygon(wing, Color(c.r*0.82, c.g*0.82, c.b*0.82))

	# Fuselage
	var body = PackedVector2Array([
		Vector2(-28*d,-5), Vector2(-28*d, 5),
		Vector2( 20*d, 5), Vector2( 30*d, 0),
		Vector2( 20*d,-5)
	])
	draw_colored_polygon(body, c)

	# Tail fin (vertical)
	var vfin = PackedVector2Array([Vector2(-28*d,-5),Vector2(-28*d,-17),Vector2(-18*d,-5)])
	draw_colored_polygon(vfin, Color(c.r*0.88, c.g*0.88, c.b*0.88))

	# Tail horizontal
	var hfin = PackedVector2Array([Vector2(-32*d,-4),Vector2(-32*d,4),Vector2(-19*d,4),Vector2(-19*d,-4)])
	draw_colored_polygon(hfin, Color(c.r*0.9, c.g*0.9, c.b*0.9))

	# Cockpit glass
	draw_circle(Vector2(13*d, -3), 7, gc)

	# Engine housing
	draw_rect(Rect2(18*d - 3, -9, 6, 18), Color(0.55, 0.52, 0.48))

	# Propeller hub
	var ph = Vector2(32*d, 0)
	draw_circle(ph, 4, Color(0.18, 0.18, 0.18))
	# Two spinning blades
	var b1 = Vector2(sin(prop_angle), cos(prop_angle)) * 15
	draw_line(ph + b1, ph - b1, Color(0.2, 0.2, 0.2, 0.55), 3.5)
	var b2 = Vector2(cos(prop_angle), -sin(prop_angle)) * 15
	draw_line(ph + b2, ph - b2, Color(0.2, 0.2, 0.2, 0.45), 3.5)

	# Red star insignia
	draw_circle(Vector2(-6*d, 0), 5.5, Color(0.85, 0.10, 0.10))
	draw_circle(Vector2(-6*d, 0), 3.0, Color(1.00, 1.00, 1.00))

	# Health bar
	var bar_w = 50.0
	var bar_x = -bar_w * 0.5
	draw_rect(Rect2(bar_x, -28, bar_w, 4), Color(0.2, 0.0, 0.0))
	draw_rect(Rect2(bar_x, -28, bar_w * (health / 15.0), 4), Color(0.9, 0.2, 0.1))
