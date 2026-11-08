class_name SeveredTail
extends Area2D

@export var wiggle_degrees: float = 12.0        # wie stark das Stück angestupst wird
@export var wiggle_duration: float = 0.5        # Dauer des Nachwippens
@export var settle_fraction: float = 0.4        # Anteil des Stupsers, der als neue Lage bleibt
@export var max_drift_degrees: float = 30.0     # max. Abweichung der Drehung von der Startlage
@export var roll_distance: float = 5.0          # Pixel, die das Stück pro Stupser mitrollt
@export var max_roll_drift: float = 24.0        # max. Abstand von der Startposition (Pixel)
@export var trigger_size_scale: float = 0.8     # Größe der Auslösezone im Verhältnis zur Grafik

var _sprite: Sprite2D
var _base_rotation: float = 0.0
var _current_rest: float = 0.0
var _base_x: float = 0.0
var _current_rest_x: float = 0.0
var _tween: Tween
var _armed: bool = false


func setup(texture: Texture2D, flipped: bool, rotation_deg: float, z: int) -> void:
	z_index = z
	z_as_relative = false

	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.flip_h = flipped
	_sprite.rotation_degrees = rotation_deg
	add_child(_sprite)

	var shape := RectangleShape2D.new()
	shape.size = texture.get_size() * trigger_size_scale
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)

	_base_rotation = rotation_deg
	_current_rest = rotation_deg

	collision_layer = 0
	collision_mask = 1
	monitorable = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Nach der Schonfrist steht die Position fest, dann wird sie als Startpunkt gemerkt
	get_tree().create_timer(0.4).timeout.connect(_arm)


func _arm() -> void:
	_base_x = global_position.x
	_current_rest_x = _base_x
	_armed = true


func _on_body_entered(body: Node2D) -> void:
	_react_to(body, 1.0)


func _on_body_exited(body: Node2D) -> void:
	_react_to(body, 0.5)


func _react_to(body: Node2D, strength: float) -> void:
	if not _armed or not body.is_in_group("players"):
		return

	var direction: float = 0.0
	if body is CharacterBody2D:
		direction = signf((body as CharacterBody2D).velocity.x)
	if direction == 0.0:
		direction = signf(global_position.x - body.global_position.x)
	if direction == 0.0:
		direction = 1.0

	_wiggle(direction, strength)


func _wiggle(direction: float, strength: float) -> void:
	# Drehung
	var push: float = direction * wiggle_degrees * strength
	var peak: float = _current_rest + push
	_current_rest = clampf(
		_current_rest + push * settle_fraction,
		_base_rotation - max_drift_degrees,
		_base_rotation + max_drift_degrees
	)

	# Rollen: gleiche Richtung wie die Drehung (nach rechts = im Uhrzeigersinn)
	var roll: float = direction * roll_distance * strength
	var peak_x: float = clampf(_current_rest_x + roll, _base_x - max_roll_drift, _base_x + max_roll_drift)
	_current_rest_x = clampf(_current_rest_x + roll * settle_fraction, _base_x - max_roll_drift, _base_x + max_roll_drift)

	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()

	# Phase 1: schneller Ausschlag (Drehung und Rollen gleichzeitig)
	_tween.set_parallel(true)
	_tween.tween_property(_sprite, "rotation_degrees", peak, wiggle_duration * 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_position:x", peak_x, wiggle_duration * 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Phase 2: Nachwippen in die neue Ruhelage
	_tween.chain().set_parallel(true)
	_tween.tween_property(_sprite, "rotation_degrees", _current_rest, wiggle_duration * 0.7) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_position:x", _current_rest_x, wiggle_duration * 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
