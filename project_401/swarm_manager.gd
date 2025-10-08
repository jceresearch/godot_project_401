extends Node2D
# SwarmManager2D.gd (Godot 4.4)

@export var enemy_group: String= "enemies"
@export var cell_size: float = 100.0 # ~ your separation_distance
@export var separation_distance: float = 100.0 # must match Enemy.gd
@export var max_neighbors: int = 20 # cap to stabilize cost and remove outliers
@export var update_every_n_frames: int = 1 #compute separation every N physics frames

var _enemies: Array[Node2D] = []
var _grid := {}		# Dictionary<Vector2i, Array[Node2D]>
var _frame: int = 0
var _sep_dist2: float

func _ready() -> void:
	_sep_dist2 = separation_distance * separation_distance
	_collect_enemies()
	print("Enemies:",len(_enemies))

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame % update_every_n_frames != 0:
		return
	
	_build_grid()
	_apply_separation()

func _collect_enemies() -> void:
	_enemies.clear()
	print("Trying to get enemies in group:", enemy_group)
	await get_tree().process_frame
	var nodes := get_tree().get_nodes_in_group(enemy_group)  # accepts String or StringName
	print("Group '", enemy_group, "' size: ", nodes.size())
	for n in get_tree().get_nodes_in_group(enemy_group):
		if n is Node2D and n.is_inside_tree():
			_enemies.append(n)
		else:
			print("Debug skipped enemies not node2d?")

func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floor(p.x / cell_size), floor(p.y / cell_size))

func _build_grid() -> void:
	_grid.clear()
	for e in _enemies:
		var c := _cell_of(e.global_position)
		if not _grid.has(c):
			_grid[c] = []
		_grid[c].append(e)

func _apply_separation() -> void:
	for e in _enemies:
		var pos := e.global_position
		var base := _cell_of(pos)
		var push := Vector2.ZERO
		var taken := 0
		
		# scan this cell and 8 neighbors
		for dy in range(-1,2):
			for dx in range(-1,2):
				var c := Vector2i(base.x + dx, base.y + dy)
				var bucket :Array= _grid.get(c,[])
				if bucket.is_empty():
					continue
				for peer in bucket:
					if peer == e:
						continue
					var diff :Vector2= pos - peer.global_position
					var d2 : float = diff.length_squared()
					if d2 > 0.0 and d2 < _sep_dist2:
						# inverse-distance push without sqrt: diff / sqrt(d2)
						push += diff / sqrt(d2)
						taken += 1
						if taken >= max_neighbors:
							break
				if taken >= max_neighbors:
					break
			if taken >= max_neighbors:
				break
		
		# hand off the separation vector to the enemy
		if e.has_method("set_external_separation"):
			e.set_external_separation(push)