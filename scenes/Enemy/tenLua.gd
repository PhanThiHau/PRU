extends Area2D

var speed: float = 200.0
var fall_velocity_y: float = 0.0
var damage: int = 2
var explosion_radius: float = 80.0
var is_exploded: bool = false

@onready var sprite = $AnimatedSprite2D
@onready var sfx_no = $SfxNo

func _ready():
	# Enable collision with terrain (layer 1) and player (layer 1)
	# The Area2D will detect StaticBody2D (tilemap) and CharacterBody2D (player)
	collision_layer = 0
	collision_mask = 1  # Layer 1 = terrain tilemap + player
	monitoring = true
	
	body_entered.connect(_on_body_entered)
	
	if sprite:
		sprite.stop()
		sprite.frame = 0

func _process(delta):
	if is_exploded:
		return
	
	# Gravity acceleration
	fall_velocity_y += 500.0 * delta
	position.y += fall_velocity_y * delta
	
	# Rotate to face fall direction
	rotation = Vector2(0, fall_velocity_y).angle() - PI / 2.0
	
	# Also check player proximity manually (in case collision misses at high speed)
	_check_player_hit()
	
	if position.y > 2000.0:
		queue_free()


func _check_player_hit():
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and not p.is_dead:
			if global_position.distance_to(p.global_position) <= 30.0:
				if p.has_method("take_damage"):
					p.take_damage(damage)
				_explode()
				return
	
	var allies = get_tree().get_nodes_in_group("allies")
	for a in allies:
		if is_instance_valid(a):
			if global_position.distance_to(a.global_position) <= 30.0:
				if a.has_method("take_damage"):
					a.take_damage(damage)
				_explode()
				return

func _on_body_entered(body):
	if is_exploded:
		return
	
	# Hit player directly
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		_explode()
		return
	
	# Hit ally directly
	if body.is_in_group("allies"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		_explode()
		return
	
	# Hit terrain (TileMap or any other static body) → explode
	_explode()

func _explode():
	if is_exploded:
		return
	is_exploded = true
	speed = 0.0
	fall_velocity_y = 0.0
	rotation = 0.0
	
	# Deal damage to nearby player and allies within explosion radius
	_deal_explosion_damage()
	
	if sprite:
		sprite.play("shoot")
	
	if sfx_no:
		sfx_no.play()
	
	_shake_camera()
	# Wait for explosion animation to finish
	if sprite:
		await sprite.animation_finished
	elif sfx_no:
		await sfx_no.finished
	else:
		await get_tree().create_timer(1.0).timeout
		
	queue_free()

func _deal_explosion_damage():
	# Damage player if within explosion radius
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and p.has_method("take_damage"):
			if global_position.distance_to(p.global_position) <= explosion_radius:
				p.take_damage(damage)
	
	# Damage allies if within explosion radius
	var allies = get_tree().get_nodes_in_group("allies")
	for a in allies:
		if is_instance_valid(a) and a.has_method("take_damage"):
			if global_position.distance_to(a.global_position) <= explosion_radius:
				a.take_damage(damage)

func _shake_camera():
	var cam = get_viewport().get_camera_2d()
	if not cam:
		return
	var tw = create_tween()
	var shake_amount = 12.0
	for i in range(8):
		tw.tween_property(cam, "offset", Vector2(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount, shake_amount)), 0.05)
		shake_amount *= 0.8
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.05)
