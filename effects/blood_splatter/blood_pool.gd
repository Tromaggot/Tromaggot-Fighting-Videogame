class_name BloodPool
extends AnimatedSprite2D

@export var pool_z_index: int = 1            # über dem Boden, unter Schwanz und Charakteren
@export var check_radius: float = 8.0


func start(flipped: bool = false) -> void:
	flip_h = flipped
	z_index = pool_z_index
	z_as_relative = false

	# Über dem Loch im Rohr gibt es keine Lache
	if _is_over_no_stain_zone(global_position):
		queue_free()
		return

	var names: PackedStringArray = sprite_frames.get_animation_names()
	if names.is_empty():
		return
	var anim: StringName = &"blood_on_floor"
	if not sprite_frames.has_animation(anim):
		anim = names[0]
	play(anim)


func _is_over_no_stain_zone(world_pos: Vector2) -> bool:
	var shape := CircleShape2D.new()
	shape.radius = check_radius

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, world_pos)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	for hit in get_world_2d().direct_space_state.intersect_shape(query):
		var collider: Object = hit["collider"]
		if collider is Node and (collider as Node).is_in_group("no_stain_zone"):
			return true
	return false
