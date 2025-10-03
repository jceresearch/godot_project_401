extends Node2D
#Mob.gs

@export var enemy_scene: PackedScene
@export var count: int = 200
@export var spawn_area: Rect2 = Rect2(Vector2.ZERO, Vector2(1200, 1200))

var _enemies: Array = []

func _ready() -> void:
	_spawn_all()

func _spawn_all() -> void:
	_enemies.clear()
	#var e := enemy_scene.instantiate() as CharacterBody2D
	var e_ori = $Boid as Node2D
	if e_ori == null:
		push_error("Mob.gd: $Enemy not found")
		return
	
	# Optional: use the original as a hidden template
	#e_ori.visible = false
	#e_ori.process_mode = Node.PROCESS_MODE_DISABLED
	
	for i in count:
		# Duplicate with scripts/groups; USE_INSTANCING keeps scene links if any
		var dup_flags := Node.DUPLICATE_SCRIPTS | Node.DUPLICATE_GROUPS 
		var e := e_ori.duplicate(dup_flags) as Node2D
		if e == null:
			push_error("Mob.gd: duplicate() failed.")
			continue
		e.visible=true
		e.process_mode = Node.PROCESS_MODE_ALWAYS
		e.add_to_group("enemies")
		e.name = "Enemy_%d" % i
		
		var p = Vector2(
			randf_range(spawn_area.position.x, spawn_area.position.x + spawn_area.size.x),
			randf_range(spawn_area.position.y, spawn_area.position.y + spawn_area.size.y)
		)
		e.global_position =  p
		add_child(e)
		_enemies.append(e)
	
	# Give each enemy the list for separation
	#for j in _enemies:
	#	j.set_peers(_enemies)