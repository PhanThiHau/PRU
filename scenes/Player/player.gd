extends CharacterBody2D

## Player - Chiến sĩ Giải phóng (AnimatedSprite2D version)
## Uses existing animations: idle, run, jump, shoot, death

signal player_died
signal health_changed(new_health: int)
signal weapon_changed(weapon_name: String)

@export var speed: float = 280.0
@export var jump_force: float = -350.0
@export var gravity_force: float = 980.0
@export var max_health: int = 10
@export var max_fall_speed: float = 1000.0
@export var topdown_mode: bool = false

var in_tank: bool = false
var health: int = 10
var facing_right: bool = true
var is_dead: bool = false
var invincible: bool = false
var invincible_timer: float = 0.0
var flash_timer: float = 0.0
var aim_direction: Vector2 = Vector2.RIGHT

# Shooting
var shoot_timer: float = 0.0
var is_shooting: bool = false
var shoot_anim_timer: float = 0.0

# Ammo / Reload
var ammo_in_mag: Dictionary = {}
var is_reloading: bool = false
var reload_timer: float = 0.0
var infinite_ammo_timer: float = 0.0

# Powerups
var shield_active: bool = false
var shield_timer: float = 0.0
var speed_boost_timer: float = 0.0

# References
@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
var bullet_scene = preload("res://scenes/objects/bullet.tscn")
var sfx_shoot: AudioStreamPlayer
var sfx_reload: AudioStreamPlayer
var sfx_death: AudioStreamPlayer

func _ready():
	GameManager.set_weapon(0)
	health = max_health
	_init_magazines()
	z_index = 10
	add_to_group("player")
	collision_layer = 1
	collision_mask = 1  # collide with terrain (layer 1)
	if topdown_mode:
		set_collision_mask_value(1, false)

	weapon_changed.emit(GameManager.get_weapon_data().name)
	_setup_audio()
	
	# Ensure CollisionShape2D has a proper shape
	var col = get_node_or_null("CollisionShape2D")
	if col and col.shape == null:
		var capsule = CapsuleShape2D.new()
		capsule.radius = 10.0
		capsule.height = 28.0
		col.shape = capsule
	elif col and col.shape is CapsuleShape2D:
		if col.shape.radius == 0:
			col.shape.radius = 10.0
			col.shape.height = 28.0
	
	# Start idle animation
	if anim_sprite:
		anim_sprite.play("idle")

func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return
	
	# --- Gravity ---
	if topdown_mode and get_collision_mask_value(1):
		set_collision_mask_value(1, false)
		
	if not is_on_floor() and not topdown_mode:
		velocity.y += gravity_force * delta
		velocity.y = minf(velocity.y, max_fall_speed)
	
	# --- Horizontal movement ---
	var move_speed = speed
	if speed_boost_timer > 0:
		move_speed *= 1.5
		speed_boost_timer -= delta
	
	var input_dir = Input.get_axis("move_left", "move_right")
	var input_y = Input.get_axis("move_up", "move_down") if topdown_mode else 0.0
	
	if input_dir != 0:
		velocity.x = input_dir * move_speed
		facing_right = input_dir > 0
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed * 5.0 * delta)
		
	if topdown_mode:
		if input_y != 0:
			velocity.y = input_y * move_speed
		else:
			velocity.y = move_toward(velocity.y, 0, move_speed * 5.0 * delta)
	
	# --- Aim direction (8 directions via WASD) ---
	var aim = Vector2.ZERO
	if Input.is_action_pressed("move_right"):
		aim.x = 1
	elif Input.is_action_pressed("move_left"):
		aim.x = -1
	if Input.is_action_pressed("move_up"):
		aim.y = -1
	elif Input.is_action_pressed("move_down"):
		aim.y = 1
	
	if aim != Vector2.ZERO:
		aim_direction = aim.normalized()
	else:
		aim_direction = Vector2.RIGHT if facing_right else Vector2.LEFT
	
	# --- Jump ---
	if Input.is_action_just_pressed("jump") and is_on_floor() and not topdown_mode:
		velocity.y = jump_force
	
	# --- Weapon controls ---
	_handle_weapon_controls(delta)
	
	# --- Shooting ---
	shoot_timer -= delta
	if Input.is_action_pressed("shoot") and shoot_timer <= 0 and not is_reloading:
		shoot()
		var weapon = GameManager.get_weapon_data()
		shoot_timer = weapon.fire_rate
		is_shooting = true
		shoot_anim_timer = 0.3
	
	if shoot_anim_timer > 0:
		shoot_anim_timer -= delta
		if shoot_anim_timer <= 0:
			is_shooting = false
	
	# --- Invincibility ---
	if invincible:
		invincible_timer -= delta
		flash_timer += delta
		if invincible_timer <= 0:
			invincible = false
			if anim_sprite:
				anim_sprite.modulate.a = 1.0
	
	# --- Shield timer ---
	if shield_active:
		shield_timer -= delta
		if shield_timer <= 0:
			shield_active = false
	
	# --- Infinite ammo timer ---
	if infinite_ammo_timer > 0:
		infinite_ammo_timer -= delta
	
	# --- Move ---
	move_and_slide()
	
	# --- Update animation ---
	_update_animation()
	
	# --- Invincibility flash ---
	if invincible and anim_sprite:
		anim_sprite.modulate.a = 0.3 if fmod(flash_timer, 0.2) > 0.1 else 1.0

func _update_animation():
	if is_dead or not anim_sprite:
		return
	
	# Flip sprite based on facing direction
	anim_sprite.flip_h = not facing_right
	
	var is_moving = abs(velocity.x) > 10 or (topdown_mode and abs(velocity.y) > 10)
	
	# Choose animation
	if is_shooting:
		if anim_sprite.animation != "shoot":
			anim_sprite.play("shoot")
	elif not is_on_floor() and not topdown_mode:
		if anim_sprite.animation != "jump":
			anim_sprite.play("jump")
	elif is_moving:
		if anim_sprite.animation != "run":
			anim_sprite.play("run")
	else:
		if anim_sprite.animation != "idle":
			anim_sprite.play("idle")

func shoot():
	if not bullet_scene:
		return
	if not _can_fire_current_weapon():
		_start_reload()
		return
	
	var bullet = bullet_scene.instantiate()
	var weapon = GameManager.get_weapon_data()
	var dir = aim_direction
	var spread_rad = deg_to_rad(weapon.spread)
	dir = dir.rotated(randf_range(-spread_rad, spread_rad))
	var spawn_pos = global_position + aim_direction * 25
	bullet.setup(spawn_pos, dir, weapon.speed, weapon.damage, weapon.color, true)
	get_tree().current_scene.add_child(bullet)
	_play_sfx(sfx_shoot)
	
	if infinite_ammo_timer <= 0.0:
		var widx = GameManager.current_weapon
		ammo_in_mag[widx] = maxi(0, int(ammo_in_mag.get(widx, int(weapon.mag_size))) - 1)

func take_damage(amount: int = 1):
	if invincible or shield_active or is_dead or GameManager.god_mode:
		return
	health = max(health - max(1, amount), 0)
	health_changed.emit(health)
	invincible = true
	invincible_timer = 1.2
	flash_timer = 0
	if health <= 0:
		die()

func die():
	is_dead = true
	velocity = Vector2.ZERO
	_play_sfx(sfx_death)
	
	# Play death animation
	if anim_sprite:
		anim_sprite.play("death")
	
	var col = get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", true)
	
	player_died.emit()

func heal(amount: int):
	health = min(health + amount, max_health)
	health_changed.emit(health)

func activate_shield(duration: float = 5.0):
	shield_active = true
	shield_timer = duration

func activate_speed_boost(duration: float = 5.0):
	speed_boost_timer = duration

func activate_infinite_ammo(duration: float = 5.0):
	infinite_ammo_timer = duration

# --- Ammo / Reload ---
func _init_magazines():
	ammo_in_mag.clear()
	for i in range(GameManager.weapons.size()):
		var w = GameManager.weapons[i]
		ammo_in_mag[i] = int(w.mag_size)

func _handle_weapon_controls(delta: float):
	if Input.is_action_just_pressed("reload"):
		_start_reload()
	
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			var widx = GameManager.current_weapon
			ammo_in_mag[widx] = int(GameManager.get_weapon_data().mag_size)
			is_reloading = false

func _can_fire_current_weapon() -> bool:
	if infinite_ammo_timer > 0.0:
		return true
	var widx = GameManager.current_weapon
	if not ammo_in_mag.has(widx):
		ammo_in_mag[widx] = int(GameManager.get_weapon_data().mag_size)
	return int(ammo_in_mag[widx]) > 0

func _start_reload():
	if infinite_ammo_timer > 0.0 or is_reloading:
		return
	var widx = GameManager.current_weapon
	var weapon = GameManager.get_weapon_data()
	if int(ammo_in_mag.get(widx, int(weapon.mag_size))) >= int(weapon.mag_size):
		return
	is_reloading = true
	reload_timer = float(weapon.reload_time)
	_play_sfx(sfx_reload)

func get_ammo_current() -> int:
	if infinite_ammo_timer > 0.0:
		return get_ammo_max()
	var widx = GameManager.current_weapon
	if not ammo_in_mag.has(widx):
		ammo_in_mag[widx] = int(GameManager.get_weapon_data().mag_size)
	return int(ammo_in_mag[widx])

func get_ammo_max() -> int:
	return int(GameManager.get_weapon_data().mag_size)

func is_weapon_reloading() -> bool:
	return is_reloading

func refill_current_magazine():
	var widx = GameManager.current_weapon
	ammo_in_mag[widx] = int(GameManager.get_weapon_data().mag_size)
	is_reloading = false
	reload_timer = 0.0

func _setup_audio():
	sfx_shoot = _create_sfx_player("res://assets/audio/ak47_fire.mp3", -7.0)
	sfx_reload = _create_sfx_player("res://assets/audio/reload_ak47.mp3", -8.0)
	sfx_death = _create_sfx_player("res://assets/audio/reload_ak47.mp3", -9.0)
	sfx_death.pitch_scale = 0.55

func _create_sfx_player(path: String, volume_db: float) -> AudioStreamPlayer:
	var p = AudioStreamPlayer.new()
	if ResourceLoader.exists(path):
		p.stream = load(path)
	p.volume_db = volume_db
	add_child(p)
	return p

func _play_sfx(p: AudioStreamPlayer):
	if not p or not p.stream:
		return
	if p.playing:
		p.stop()
	p.play()
