extends CharacterBody2D

## Enemy Soldier - Patrol, detect, and shoot player
## Uses AnimatedSprite2D: run, shoot, death

signal enemy_died(enemy)

@export var speed: float = 80.0
@export var health: float = 3.0
@export var damage: int = 1
@export var gravity_force: float = 900.0
@export var detection_range: float = 350.0
@export var shoot_range: float = 300.0
@export var patrol_distance: float = 150.0
@export var topdown_mode: bool = false

enum State { PATROL, CHASE, SHOOT, DEAD }
var state: State = State.PATROL
var facing_right: bool = true
var patrol_origin: float = 0.0
var shoot_timer: float = 0.0
var shoot_cooldown: float = 1.2
var death_timer: float = 0.0

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
var bullet_scene = preload("res://scenes/objects/bullet.tscn")

var sfx_shoot: AudioStreamPlayer2D

func _ready():
	patrol_origin = global_position.x
	add_to_group("enemies")
	z_index = 5
	collision_layer = 2  # Enemy layer
	collision_mask = 1   # Collide with terrain
	
	sfx_shoot = AudioStreamPlayer2D.new()
	sfx_shoot.stream = load("res://assets/audio/ak47_fire.mp3")
	sfx_shoot.volume_db = -8.0
	add_child(sfx_shoot)
	
	# Ensure CollisionShape2D exists
	if not get_node_or_null("CollisionShape2D"):
		var col = CollisionShape2D.new()
		var capsule = CapsuleShape2D.new()
		capsule.radius = 10.0
		capsule.height = 28.0
		col.shape = capsule
		add_child(col)
	else:
		var col = $CollisionShape2D
		if col.shape == null:
			var capsule = CapsuleShape2D.new()
			capsule.radius = 10.0
			capsule.height = 28.0
			col.shape = capsule
	
	if anim_sprite:
		anim_sprite.play("run")

func _physics_process(delta):
	if state == State.DEAD:
		death_timer -= delta
		if death_timer <= 0:
			_drop_health_pickup()
			queue_free()
		return
	
	# Gravity
	if topdown_mode and get_collision_mask_value(1):
		set_collision_mask_value(1, false)
		
	if not is_on_floor() and not topdown_mode:
		velocity.y += gravity_force * delta
	
	# Find player
	var player = _find_player()
	var dist_to_player = INF
	if player and not player.is_dead:
		dist_to_player = global_position.distance_to(player.global_position)
	
	# State machine
	match state:
		State.PATROL:
			_patrol(delta)
			if dist_to_player < detection_range:
				state = State.CHASE
		State.CHASE:
			if player and not player.is_dead:
				_chase(player, delta)
			if dist_to_player < shoot_range:
				state = State.SHOOT
			elif dist_to_player > detection_range * 1.5:
				state = State.PATROL
		State.SHOOT:
			if player and not player.is_dead:
				_shoot_at(player, delta)
			if dist_to_player > shoot_range * 1.3:
				state = State.CHASE
			elif not player or player.is_dead:
				state = State.PATROL
	
	# Update animation
	_update_animation()
	
	move_and_slide()

func _patrol(_delta):
	var dir = 1 if facing_right else -1
	velocity.x = speed * dir
	if topdown_mode: velocity.y = 0
	
	if global_position.x > patrol_origin + patrol_distance:
		facing_right = false
	elif global_position.x < patrol_origin - patrol_distance:
		facing_right = true

func _chase(player: Node2D, _delta):
	if player.global_position.x > global_position.x + 10:
		velocity.x = speed * 1.3
		facing_right = true
	elif player.global_position.x < global_position.x - 10:
		velocity.x = -speed * 1.3
		facing_right = false
	else:
		velocity.x = 0
		
	if topdown_mode:
		if player.global_position.y > global_position.y + 10:
			velocity.y = speed * 1.3
		elif player.global_position.y < global_position.y - 10:
			velocity.y = -speed * 1.3
		else:
			velocity.y = 0

func _shoot_at(player: Node2D, delta):
	velocity.x = 0
	if topdown_mode: velocity.y = 0
	facing_right = player.global_position.x > global_position.x
	
	shoot_timer -= delta
	if shoot_timer <= 0:
		_fire_bullet(player)
		shoot_timer = shoot_cooldown

func _fire_bullet(player: Node2D):
	if not bullet_scene:
		return
	var bullet = bullet_scene.instantiate()
	var dir = Vector2.RIGHT if facing_right else Vector2.LEFT
	if topdown_mode and player:
		dir = (player.global_position - global_position).normalized()
		
	bullet.setup(global_position + dir * 20, dir, 350, damage, Color(1, 0.6, 0.1), false)
	get_tree().current_scene.add_child(bullet)
	if sfx_shoot:
		sfx_shoot.pitch_scale = randf_range(0.9, 1.1)
		sfx_shoot.play()

func _update_animation():
	if not anim_sprite or state == State.DEAD:
		return
	
	anim_sprite.flip_h = not facing_right
	
	match state:
		State.SHOOT:
			if anim_sprite.animation != "shoot":
				anim_sprite.play("shoot")
		_:
			if abs(velocity.x) > 10:
				if anim_sprite.animation != "run":
					anim_sprite.play("run")
			else:
				# Enemy doesn't have idle, use run frame 0
				if anim_sprite.animation != "run":
					anim_sprite.play("run")

func _find_player() -> Node2D:
	var targets = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("allies")
	var closest_target = null
	var closest_dist = INF
	
	for t in targets:
		if "is_dead" in t and t.is_dead: continue
		var dist = global_position.distance_to(t.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest_target = t
			
	return closest_target

func take_damage(amount: float):
	health -= amount
	# Flash white briefly
	if anim_sprite:
		anim_sprite.modulate = Color.WHITE * 2.0
		var tw = create_tween()
		tw.tween_property(anim_sprite, "modulate", Color.WHITE, 0.15)
	if health <= 0:
		die()

func die():
	state = State.DEAD
	velocity = Vector2.ZERO
	GameManager.add_score(100)
	enemy_died.emit(self)
	
	# Play death animation
	if anim_sprite:
		anim_sprite.play("death")
	
	# Disable collision
	var col = get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", true)
	
	# Wait for death anim then free
	death_timer = 0.8

func _drop_health_pickup():
	# 30% chance to drop health
	if randf() > 0.3:
		return
	
	var pickup = Area2D.new()
	pickup.global_position = global_position
	pickup.collision_layer = 16
	pickup.collision_mask = 1
	pickup.z_index = 5
	pickup.set_script(load("res://scenes/Enemy/health_pickup.gd"))
	
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 14
	col.shape = shape
	pickup.add_child(col)
	
	get_tree().current_scene.call_deferred("add_child", pickup)
