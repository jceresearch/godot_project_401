extends Node2D

# Graph2D.gd (Godot 4.x) — attach to a Node2D

# ---------- Tunables ----------
const SPRING_LENGTH: float = 140.0
const SPRING_K: float = 0.06				# spring stiffness
const REPULSION_K: float = 2300.0			# node-node repulsive constant
const DAMPING: float = 0.85					# velocity damping
const MAX_FORCE: float = 2000.0				# clamp to avoid explosions
const NODE_RADIUS: float = 10.0
const EDGE_WIDTH: float = 2.0
const LABEL_OFFSET := Vector2(0, -18)
const STEPS_PER_FRAME: int =2				# >1 for extra stability

# ---------- Graph storage ----------
var nodes: Array[Vector2] = []				# positions
var vels: Array[Vector2] = []				# velocities
var pinned: Array[bool] = []				# true while dragging (or permanently pinned)
var labels: Array[String] = []				# optional labels (drawn)
var edges: Array[Vector2i] = []				# pairs of node indices

# ---------- Interaction ----------
var _drag_index: int = -1
var _drag_offset: Vector2 = Vector2.ZERO

# ---------- Demo setup ----------
func _ready() -> void:
	pass
	#generate_network()
	
func generate_network() -> void:
	randomize()
	# Build a small sample graph
	var n := 10
	for i in n:
		var p := Vector2(
			randf() * 800.0 - 400.0,
			randf() * 500.0 - 250.0
		)
		nodes.append(p)
		vels.append(Vector2.ZERO)
		pinned.append(false)
		labels.append("N%d" % i)
	
	# A few edges (random-ish)
	var dest_node=null
	for i in n:
		for j in n:
			if randf()>.60:
				dest_node= randi_range(j,n)
				if dest_node==n or j<i:
					continue
				_add_edge(i, dest_node)
	
	queue_redraw()	# trigger initial draw

# ---------- Public API (build your own graph programmatically) ----------
func add_node(pos: Vector2, label: String = "") -> int:
	nodes.append(pos)
	vels.append(Vector2.ZERO)
	pinned.append(false)
	labels.append(label)
	queue_redraw()
	return nodes.size() - 1

func add_edge(a: int, b: int) -> void:
	_add_edge(a, b)
	queue_redraw()

func pin_node(i: int, is_pinned: bool = true) -> void:
	if i >= 0 and i < pinned.size():
		pinned[i] = is_pinned

# ---------- Simulation ----------
func _process(delta: float) -> void:
	# multiple small steps per frame helps stability
	for _i in STEPS_PER_FRAME:
		_step_layout(delta / float(max(1, STEPS_PER_FRAME)))
	queue_redraw()

func _step_layout(dt: float) -> void:
	if nodes.is_empty():
		return
	
	var n := nodes.size()
	var forces: Array[Vector2] = []
	forces.resize(n)
	for i in n:
		forces[i] = Vector2.ZERO
	
	# REPULSION (O(n^2) — fine for small/medium graphs)
	for i in n:
		for j in range(i + 1, n):
			var delta := nodes[i] - nodes[j]
			var dist := max(1.0, delta.length()) as float 	# avoid div-by-zero as
			var dir := delta / dist
			var f_mag := REPULSION_K / (dist * dist)
			var f := dir * f_mag
			forces[i] += f
			forces[j] -= f
	
	# SPRINGS along edges
	for e in edges:
		var a := e.x
		var b := e.y
		var delta := nodes[b] - nodes[a]
		var dist := max(1.0, delta.length()) as float
		var dir := delta / dist
		var stretch := dist - SPRING_LENGTH
		var f := dir * (SPRING_K * stretch)
		forces[a] += f
		forces[b] -= f
	
	# Integrate
	for i in n:
		if pinned[i]:
			vels[i] = Vector2.ZERO
			continue
		
		# Clamp forces to avoid numerical blow-ups
		var f := forces[i]
		if f.length() > MAX_FORCE:
			f = f.normalized() * MAX_FORCE
		
		vels[i] = (vels[i] + f * dt) * DAMPING
		nodes[i] += vels[i] * dt

# ---------- Rendering ----------
func _draw() -> void:
	var center := get_viewport_rect().size * 0.5
	# Edges
	for e in edges:
		var a := nodes[e.x] + center
		var b := nodes[e.y] + center
		draw_line(a, b, Color(0.7, 0.7, 0.8), EDGE_WIDTH, true)
	
	# Nodes + labels
	for i in nodes.size():
		var p := nodes[i] + center
		var c := Color(0.8, 0.3, 0.3) if pinned[i] else Color(0.2, 0.6, 1.0)
		draw_circle(p, NODE_RADIUS, c)
		if labels[i] != "":
			var font := ThemeDB.fallback_font
			draw_string(
				font,
				p + LABEL_OFFSET,
				labels[i],
				HORIZONTAL_ALIGNMENT_CENTER,
				-1.0,
				16,
				Color(0.1, 0.1, 0.1)
			)

# ---------- Input (drag to pin/unpin nodes) ----------
func _unhandled_input(event: InputEvent) -> void:
	var center := get_viewport_rect().size * 0.5
	
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			# pick nearest node under cursor
			var mouse := mb.position - center
			var idx := _pick_node(mouse, 20.0)
			if idx != -1:
				_drag_index = idx
				_drag_offset = nodes[idx] - mouse
				pinned[idx] = true		# pinned while dragging
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			if _drag_index != -1:
				# release keeps it pinned if you hold Shift, else unpin
				if not Input.is_key_pressed(KEY_SHIFT):
					pinned[_drag_index] = false
			_drag_index = -1
	
	if event is InputEventMouseMotion and _drag_index != -1:
		var mm := event as InputEventMouseMotion
		nodes[_drag_index] = (mm.position - center) + _drag_offset
		vels[_drag_index] = Vector2.ZERO

# ---------- Helpers ----------
func _add_edge(a: int, b: int) -> void:
	if a == b:
		return
	if a < 0 or b < 0 or a >= nodes.size() or b >= nodes.size():
		return
	# prevent duplicates
	for e in edges:
		if (e.x == a and e.y == b) or (e.x == b and e.y == a):
			return
	edges.append(Vector2i(a, b))

func _pick_node(local_mouse: Vector2, radius: float) -> int:
	var r2 := radius * radius
	var best := -1
	var best_d2 := INF
	for i in nodes.size():
		var d2 := (nodes[i] - local_mouse).length_squared()
		if d2 <= r2 and d2 < best_d2:
			best_d2 = d2
			best = i
	return best