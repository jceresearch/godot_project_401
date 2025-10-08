
extends Camera2D
# CameraFitTargets2D.gd (Godot 4.4)

@export var target_a: NodePath
@export var target_b: NodePath
@export var extra_targets: Array[NodePath] = [] # optional: any number of extra targets
@export var padding_world: float = 10.0 # extra space around the outermost targets (in world units)
@export var min_zoom: float = 1 # smallest zoom (zooms IN the most)
@export var max_zoom: float = 7.0 # largest zoom (zooms OUT the most)
@export var pos_lerp_speed: float = 3.0 # higher = snappier camera movement
@export var zoom_lerp_speed: float = 1.0 # higher = snappier zoom changes
@export var keep_upright: bool = true # if true, zero rotation each frame
@export var manual_zoom_step: float = 0.4	# step per press
@export var manual_zoom_strength: float = 1.0	# multiplier applied to auto zoom

var _wanted_pos: Vector2
var _wanted_zoom: Vector2 = Vector2.ONE
var _manual_zoom_factor: float = 1.0	# updated from input



func _ready() -> void:
	make_current()
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom_in"):
		_manual_zoom_factor = max(_manual_zoom_factor - manual_zoom_step, min_zoom)
		print("zoom in")
	elif event.is_action_pressed("zoom_out"):
		_manual_zoom_factor = min(_manual_zoom_factor + manual_zoom_step, max_zoom)
		print("zoom out")
		
func _physics_process(delta: float) -> void:
	var points := _collect_target_positions()
	if points.is_empty():
		return
	
	# compute bounding box of all targets
	var aabb_pos := points[0]
	var aabb_end := points[0]
	for p in points:
		aabb_pos.x = min(aabb_pos.x, p.x)
		aabb_pos.y = min(aabb_pos.y, p.y)
		aabb_end.x = max(aabb_end.x, p.x)
		aabb_end.y = max(aabb_end.y, p.y)
	
	var center := (aabb_pos + aabb_end) * 0.5
	var size := (aabb_end - aabb_pos).abs()
	# avoid zero-size (single target cases)
	size.x = max(size.x, 1.0)
	size.y = max(size.y, 1.0)
	# add world-space padding
	size += Vector2.ONE * (padding_world * 2.0)
	
	# viewport size in pixels
	var vp := get_viewport_rect().size
	
	# how much zoom is needed so vp * zoom >= size
	var zx : float = size.x / max(vp.x, 1.0)
	var zy : float = size.y / max(vp.y, 1.0)
	var z : float = max(zx, zy)
	z = clamp(z, min_zoom, max_zoom)

	
	# apply manual override factor
	_wanted_pos = center
	_wanted_zoom = Vector2(z, z) * _manual_zoom_factor
	
	global_position = global_position.lerp(_wanted_pos, 1.0 - exp(-pos_lerp_speed * delta))
	zoom = zoom.lerp(_wanted_zoom, 1.0 - exp(-zoom_lerp_speed * delta))
	if keep_upright:
		rotation = 0.0

func _collect_target_positions() -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var n: Node2D
	
	if target_a != NodePath(""):
		n = get_node_or_null(target_a)
		if n:
			pts.append(n.global_position)
	if target_b != NodePath(""):
		n = get_node_or_null(target_b)
		if n:
			pts.append(n.global_position)
	for p in extra_targets:
		n = get_node_or_null(p)
		if n:
			pts.append(n.global_position)
	
	return pts