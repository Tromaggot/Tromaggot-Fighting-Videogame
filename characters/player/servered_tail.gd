class_name SeveredTail
extends CharacterBody2D

@export_group("Physics")
@export var gravity: float = 980.0
@export var ground_friction: float = 150.0       # Abbremsen am Boden, wenn niemand schiebt
@export var air_friction: float = 20.0
@export var fall_free_distance: float = 300.0    # so weit unter der Startposition wird das Stück entfernt

@export_group("Pushing")
@export var push_transfer: float = 0.6           # Anteil des Tempos des Schiebenden, den das Stück übernimmt
@export var push_acceleration: float = 600.0     # wie schnell es auf dieses Tempo kommt
@export var min_push_speed: float = 2.0          # so schnell muss der Charakter mindestens sein
@export var trigger_size_scale: float = 1.0      # Größe der Schiebe-Zone im Verhältnis zur Grafik

@export_group("Rolling")
@export var roll_radius: float = 6.0             # 0 = automatisch aus der Texturhöhe
@export var roll_factor: float = 1.5             # 1 = echtes Abrollen, kleiner = weniger Drehung
@export var max_roll_degrees: float = 0     # max. Drehung am Boden (0 = unbegrenzt)

@export var push_spin_degrees: float = 90.0   # Grad pro Sekunde, solange geschoben wird

@export_group("Look")
@export var sprite_offset_y: float = 0.0         # positiv = Grafik sitzt tiefer

var _sprite: Sprite2D
var _trigger: Area2D
var _base_rotation: float = 0.0
var _radius: float = 8.0
var _start_y: float = INF
var _armed: bool = false


func setup(texture: Texture2D, flipped: bool, rotation_deg: float, z: int) -> void:
	z_index = z
	z_as_relative = false

	# Niemand stößt gegen das Stück, es selbst kollidiert nur mit dem Boden
	collision_layer = 0
	collision_mask = 1

	var tex_size: Vector2 = texture.get_size()
	_radius = roll_radius if roll_radius > 0.0 else maxf(2.0, minf(tex_size.x, tex_size.y) * 0.5)

	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.flip_h = flipped
	_sprite.rotation_degrees = rotation_deg
	_sprite.position.y = sprite_offset_y
	add_child(_sprite)
	_base_rotation = _sprite.rotation

	var body_shape := CircleShape2D.new()
	body_shape.radius = _radius
	var body_collision := CollisionShape2D.new()
	body_collision.shape = body_shape
	add_child(body_collision)

	# Zone, in der Charaktere das Stück anschieben
	_trigger = Area2D.new()
	_trigger.collision_layer = 0
	_trigger.collision_mask = 1
	_trigger.monitorable = false
	var trigger_shape := RectangleShape2D.new()
	trigger_shape.size = tex_size * trigger_size_scale
	var trigger_collision := CollisionShape2D.new()
	trigger_collision.shape = trigger_shape
	_trigger.add_child(trigger_collision)
	add_child(_trigger)


func _ready() -> void:
	# Die Charaktere sollen über das Stück kriechen können, nicht dagegen laufen
	for p in get_tree().get_nodes_in_group("players"):
		if p is PhysicsBody2D:
			add_collision_exception_with(p)
	# Schonfrist, damit der Charakter, dem der Schwanz abfällt, ihn nicht sofort mitschiebt
	get_tree().create_timer(0.4).timeout.connect(func() -> void: _armed = true)


func _physics_process(delta: float) -> void:
	if _start_y == INF:
		_start_y = global_position.y   # erst jetzt steht die Spawn-Position fest

	if not is_on_floor():
		velocity.y += gravity * delta

	var pushed := false
	if _armed:
		for body in _trigger.get_overlapping_bodies():
			var mover := body as CharacterBody2D
			if mover == null or not mover.is_in_group("players") or mover.get("is_dead"):
				continue
			if not mover.is_on_floor() or absf(mover.velocity.x) < min_push_speed:
				continue
			velocity.x = move_toward(velocity.x, mover.velocity.x * push_transfer, push_acceleration * delta)
			pushed = true
			_sprite.rotation += signf(mover.velocity.x) * deg_to_rad(push_spin_degrees) * delta

	if not pushed:
		var friction: float = ground_friction if is_on_floor() else air_friction
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	move_and_slide()
	_update_roll(delta)

	# Vom Rand gefallen: aufräumen, sobald es weit genug unten ist
	if global_position.y > _start_y + fall_free_distance:
		queue_free()


func _update_roll(delta: float) -> void:
	var speed_x: float = get_real_velocity().x
	_sprite.rotation += (speed_x / _radius) * roll_factor * delta
	if is_on_floor() and max_roll_degrees > 0.0:
		var limit: float = deg_to_rad(max_roll_degrees)
		_sprite.rotation = clampf(_sprite.rotation, _base_rotation - limit, _base_rotation + limit)
