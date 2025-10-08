#enemy.gd
extends CharacterBody2D


@export var max_speed: float = 140.0
@export var max_force: float = 600.0
@export var arrive_radius: float = 120.0
@export var stop_radius: float = 36.0
@export var separation_distance: float = 28.0
@export var separation_weight: float = 1.5
@export var drag: float = 6.0
@export var focus_group: StringName = &"focus_points"

var _enemies: Array = []
var _current_focus: Node2D
var _stopped: bool = false

func _on_ready():
	add_to_group("old")
	
func set_peers(list: Array) -> void:
	_enemies = list

func _physics_process(delta: float) -> void:
	var focus := _choose_focus()
	var desired := Vector2.ZERO
	
	if focus:
		var to_focus := focus.global_position - global_position
		var dist := to_focus.length()
		
		if dist > stop_radius:
			# Smooth "arrive": speed scales down as we enter arrive_radius
			var target_speed := max_speed
			if dist < arrive_radius:
				var t : float = clamp((dist - stop_radius) / max(arrive_radius - stop_radius, 0.001), 0.0, 1.0)
				target_speed = lerp(0.0, max_speed, t)
			desired = to_focus.normalized() * target_speed
			_stopped = false
		else:
			desired = Vector2.ZERO
			_stopped = true
	
	# Steering toward target
	var steer := (desired - velocity)
	if steer.length() > max_force:
		steer = steer.normalized() * max_force
	
	# Local separation (simple, cheap)
	steer += _separation() * separation_weight
	
	# Viscous drag to kill residual jitter
	steer -= velocity * drag * delta
	
	velocity += steer * delta
	if velocity.length() > max_speed:
		velocity = velocity.normalized() * max_speed
	
	# If we're "stopped", hard-zero tiny drift to avoid micro-jitter
	if _stopped and velocity.length_squared() < 9.0:
		velocity = Vector2.ZERO
	
	move_and_slide()

func _separation() -> Vector2:
	var push := Vector2.ZERO
	for peer in _enemies:
		if peer == self: 
			continue
		var diff  : Vector2 = global_position - peer.global_position
		var d : float = diff.length()
		if d > 0.0 and d < separation_distance:
			# Inverse-distance push away
			push += diff / d
	return push

func _choose_focus() -> Node2D:
	# Cache is fine; if it disappears we'll re-pick
	if _current_focus and is_instance_valid(_current_focus):
		return _current_focus
	var best: Node2D
	var best_d2 := INF
	for n in get_tree().get_nodes_in_group(focus_group):
		if n is Node2D:
			var d2 : float= (n.global_position - global_position).length_squared()
			if d2 < best_d2:
				best_d2 = d2
				best = n
	_current_focus = best
	return best