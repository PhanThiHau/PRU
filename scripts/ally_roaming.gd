extends CharacterBody2D

## Ally Roaming - Dong doi tuan tra tu do tren map
## Su dung model ve giong Enemy Soldier (M1 helmet, khaki, M16)
## AI: PATROL -> ENGAGE -> RETURN

enum State { PATROL, ENGAGE, RETURN }

@export var speed: float = 100.0
@export var gravity: float = 900.0
@export var patrol_radius: float = 500.0
@export var engage_range: float = 400.0
@export var shoot_range: float = 350.0
@export var shoot_cooldown: float = 0.7
@export var max_health: int = 5
@export var topdown_mode: bool = false

var health: int = 5
var state: State = State.PATROL
var facing_right: bool = true
var shoot_timer: float = 0.0
var spawn_position: Vector2 = Vector2.ZERO

# Patrol
var patrol_target: Vector2 = Vector2.ZERO
var patrol_wait_timer: float = 0.0
var patrol_change_timer: float = 0.0

# Animation
var is_dead: bool = false
var hit_flash: float = 0.0
var anim_sprite: AnimatedSprite2D

var bullet_scene = preload("res://scenes/objects/bullet.tscn")

func _ready():
	add_to_group("allies")
	z_index = 6
	collision_layer = 32
	collision_mask = 7 # collide with layer 1 (terrain), 2 (enemies), 3
	health = max_health
	scale = Vector2(1.0, 1.0)
	spawn_position = global_position
	
	# Instantiate player to steal its AnimatedSprite2D
	var player_scene = preload("res://scenes/Player/PLayer.tscn")
	var p = player_scene.instantiate()
	anim_sprite = p.get_node("AnimatedSprite2D").duplicate()
	anim_sprite.modulate = Color(0.7, 0.9, 1.0) # Blue tint to distinguish from player
	add_child(anim_sprite)
	p.free()
	
	facing_right = true
	_pick_new_patrol_target()
	
	if topdown_mode:
		set_collision_mask_value(1, false)

func _physics_process(delta):
	if is_dead:
		velocity = Vector2.ZERO
		return
	
	# Gravity (only in side-scroller mode)
	if not is_on_floor() and not topdown_mode:
		velocity.y += gravity * delta
	
	# Update collision mask for topdown
	if topdown_mode and get_collision_mask_value(1):
		set_collision_mask_value(1, false)
	
	# Auto-advance patrol anchor (Tiến lên phía trước)
	spawn_position.x += speed * 0.75 * delta
	
	# State machine
	var enemy = _find_nearest_enemy()
	
	match state:
		State.PATROL:
			_do_patrol(delta)
			if enemy and global_position.distance_to(enemy.global_position) < engage_range:
				state = State.ENGAGE
		
		State.ENGAGE:
			if not enemy or not is_instance_valid(enemy):
				state = State.PATROL
				_pick_new_patrol_target()
			else:
				_do_engage(enemy, delta)
				if global_position.distance_to(enemy.global_position) > engage_range * 1.5:
					state = State.PATROL
					_pick_new_patrol_target()
		
		State.RETURN:
			_do_return(delta)
			if global_position.distance_to(spawn_position) < 60.0:
				state = State.PATROL
				_pick_new_patrol_target()
	
	
	# Allies now ONLY move forward, no RETURN state
	# (Removing old check that triggered RETURN)
	
	# Shooting
	shoot_timer -= delta
	if enemy and is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) < shoot_range:
		if shoot_timer <= 0.0:
			_fire_at(enemy)
			shoot_timer = shoot_cooldown
	
	# Facing direction
	if abs(velocity.x) > 5:
		facing_right = velocity.x > 0
		if anim_sprite:
			anim_sprite.flip_h = not facing_right
	
	# Animations
	if anim_sprite and not is_dead:
		var move_mag = abs(velocity.x) + (abs(velocity.y) if topdown_mode else 0.0)
		var is_shooting_now = shoot_timer > shoot_cooldown - 0.2
		
		if is_shooting_now:
			if anim_sprite.animation != "shoot":
				anim_sprite.play("shoot")
		elif not is_on_floor() and not topdown_mode:
			if anim_sprite.animation != "jump":
				anim_sprite.play("jump")
		elif move_mag > 10:
			if anim_sprite.animation != "run":
				anim_sprite.play("run")
		else:
			if anim_sprite.animation != "idle":
				anim_sprite.play("idle")
	
	# Hit flash
	if hit_flash > 0:
		hit_flash -= delta
		if anim_sprite:
			anim_sprite.modulate.a = 0.3 if fmod(hit_flash, 0.2) > 0.1 else 1.0
	else:
		if anim_sprite and not is_dead:
			anim_sprite.modulate.a = 1.0
	
	move_and_slide()

func _do_patrol(delta):
	patrol_change_timer -= delta
	if patrol_change_timer <= 0.0:
		_pick_new_patrol_target()
	
	var dir_to_target = patrol_target - global_position
	var dist = dir_to_target.length()
	
	if dist < 20.0:
		velocity.x = move_toward(velocity.x, 0.0, speed * 3.0 * delta)
		if topdown_mode:
			velocity.y = move_toward(velocity.y, 0.0, speed * 3.0 * delta)
		patrol_wait_timer -= delta
		if patrol_wait_timer <= 0.0:
			_pick_new_patrol_target()
	else:
		var move_dir = dir_to_target.normalized()
		velocity.x = move_toward(velocity.x, move_dir.x * speed, speed * 4.0 * delta)
		if topdown_mode:
			velocity.y = move_toward(velocity.y, move_dir.y * speed, speed * 4.0 * delta)

func _do_engage(enemy: Node2D, delta):
	var dir_to_enemy = enemy.global_position - global_position
	var dist = dir_to_enemy.length()
	
	if dist > shoot_range * 0.6:
		var move_dir = dir_to_enemy.normalized()
		velocity.x = move_toward(velocity.x, move_dir.x * speed * 1.2, speed * 5.0 * delta)
		if topdown_mode:
			velocity.y = move_toward(velocity.y, move_dir.y * speed * 1.2, speed * 5.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 3.0 * delta)
		if topdown_mode:
			velocity.y = move_toward(velocity.y, 0.0, speed * 3.0 * delta)

func _do_return(delta):
	var dir_to_spawn = spawn_position - global_position
	var move_dir = dir_to_spawn.normalized()
	velocity.x = move_toward(velocity.x, move_dir.x * speed, speed * 4.0 * delta)
	if topdown_mode:
		velocity.y = move_toward(velocity.y, move_dir.y * speed, speed * 4.0 * delta)

func _pick_new_patrol_target():
	var offset = Vector2(
		randf_range(0.0, patrol_radius),
		randf_range(-patrol_radius * 0.5, patrol_radius * 0.5) if topdown_mode else 0.0
	)
	patrol_target = spawn_position + offset
	patrol_change_timer = randf_range(3.0, 6.0)
	patrol_wait_timer = randf_range(1.0, 2.5)

func _find_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var best = engage_range
	for e in enemies:
		if not e or not is_instance_valid(e):
			continue
		var d = global_position.distance_to(e.global_position)
		if d < best:
			best = d
			nearest = e
	return nearest

func _fire_at(target: Node2D):
	if not bullet_scene:
		return
	var bullet = bullet_scene.instantiate()
	var dir = (target.global_position - global_position).normalized()
	bullet.setup(global_position + dir * 18, dir, 600, 1, Color(0.9, 0.9, 0.2), true)
	get_tree().current_scene.add_child(bullet)

func take_damage(amount: int = 1):
	if is_dead:
		return
	health = max(health - max(1, amount), 0)
	hit_flash = 0.15
	if health <= 0:
		die()

func die():
	is_dead = true
	if anim_sprite:
		anim_sprite.play("death")
	
	var col = get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", true)
		
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.5)
	tween.tween_callback(queue_free)
