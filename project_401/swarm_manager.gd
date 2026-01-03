extends Node2D
# SwarmManager2D.gd

@export var enemy_group: String= "enemies"
@export var cell_size: float = 100.0 # ~ your separation_distance
@export var separation_distance: float = 100.0 # must match Enemy.gd
@export var max_neighbors: int = 40 # cap to stabilize cost and remove outliers
@export var update_every_n_frames: int = 3 #compute separation every N physics frames

var _enemies: Array[Node2D] = []
var _grid := {}		# Dictionary<Vector2i, Array[Node2D]>
var _frame: int = 0
var _sep_dist_squared: float

func _ready() -> void:
	_sep_dist_squared = separation_distance * separation_distance
	call_deferred("_collect_enemies")


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame % update_every_n_frames != 0:
		return
	
	_build_grid()
	_apply_separation()

func _collect_enemies() -> void:
	_enemies.clear()
	#await get_tree().process_frame #this would do an extra frame wait
	for n in get_tree().get_nodes_in_group(enemy_group):
		if n is Node2D and n.is_inside_tree():
			_enemies.append(n)
	
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
		for dy in range(-1,2):
			#scan this cell and 8 neighbors
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
					if d2 > 0.0 and d2 < _sep_dist_squared:
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