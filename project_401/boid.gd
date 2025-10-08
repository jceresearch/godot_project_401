extends Node2D
# EnemyNoPhysics.gd

@export var max_speed: float = 300.0
@export var max_force: float = 800.0
@export var arrive_radius: float = 100
@export var stop_radius: float = 50.0
@export var separation_weight: float = 1.5  #originally 1.5
@export var drag: float = 4.0
@export var collision_radius: float =70.0	# radius for simple circle collision
@export var focus_group: StringName = &"focus_points"

var velocity: Vector2 = Vector2.ZERO
var _current_focus: Node2D
var _stopped: bool = false
var _external_sep: Vector2 = Vector2.ZERO

func _ready():
	var sprite_size: Vector2= $Sprite2D.texture.get_size()
	collision_radius= max(sprite_size.x/2 , sprite_size.y/2)
	stop_radius=collision_radius * 3 # originally x3
	
	
	
	
	
func set_external_separation(v: Vector2) -> void:
	_external_sep = v

func _physics_process(delta: float) -> void:
	var focus := _choose_focus()
	var desired := Vector2.ZERO
	
	if focus:
		var to_focus := focus.global_position - global_position
		var dist := to_focus.length()
		
		if dist > stop_radius:
			var target_speed := max_speed
			if dist < arrive_radius:
				var t : float = clamp((dist - stop_radius) / max(arrive_radius - stop_radius, 0.001), 0.0, 1.0)
				target_speed = lerp(0.0, max_speed, t)
			desired = to_focus.normalized() * target_speed
			_stopped = false
		else:
			desired = Vector2.ZERO
			_stopped = true
	
	var steer := (desired - velocity)
	if steer.length() > max_force:
		steer = steer.normalized() * max_force
	steer += _external_sep * separation_weight
	steer -= velocity * drag * delta
	
	velocity += steer * delta
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
	
	if _stopped and velocity.length_squared() < 9.0:
		velocity = Vector2.ZERO
	
	var old_pos := global_position
	global_position += velocity * delta
	#_resolve_collisions(old_pos)




func _resolve_collisions(old_pos: Vector2) -> void:
	# This is a simple circle vs static bodies example
	# Put static colliders in a group "obstacles"
	for o in get_tree().get_nodes_in_group("obstacles"):
		if not (o is Node2D):
			continue
		var diff : Vector2 = global_position - o.global_position
		var d : float = diff.length()
	
		var obstacle_radius: float = 16.0
		if o.has_meta("radius"):
			obstacle_radius = float(o.get_meta("radius"))
		
		var r: float = collision_radius + obstacle_radius
		if d < r and d > 0.001:
			# rollback to previous safe position
			global_position = old_pos
			velocity = velocity.slide(diff.normalized())
			return	# stop after first hit
			
func _choose_focus() -> Node2D:
	if _current_focus and is_instance_valid(_current_focus):
		return _current_focus
	
	var best: Node2D
	var best_d2 := INF
	for n in get_tree().get_nodes_in_group(focus_group):
		if n is Node2D:
			var d2 :float = (n.global_position - global_position).length_squared()
			if d2 < best_d2:
				best_d2 = d2
				best = n
	_current_focus = best
	return best