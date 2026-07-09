extends Node3D

# ============================================================
# WorldManager — спавнит пол и препятствия, управляет миром
# ============================================================

const SPEED: float = 15.0
const SEGMENT_LENGTH: float = 40.0
const SEGMENT_COUNT: int = 6
const SPAWN_Z: float = -80.0
const RECYCLE_Z: float = 40.0
const RECYCLE_OFFSET: float = -240.0
const LANES: Array = [-2.0, 0.0, 2.0]

var ground_segments: Array[Node3D] = []
var obstacle_timer: Timer


# ============================================================
# _ready
# ============================================================
func _ready() -> void:
	_create_ground_segments()
	_create_obstacle_timer()


# ============================================================
# Спавн 6 сегментов пола
# ============================================================
func _create_ground_segments() -> void:
	for i in range(SEGMENT_COUNT):
		var segment: Node3D = _make_ground_segment()
		segment.position.z = 40.0 - i * SEGMENT_LENGTH
		add_child(segment)
		ground_segments.append(segment)


func _make_ground_segment() -> Node3D:
	var seg: Node3D = Node3D.new()
	seg.name = "GroundSegment"

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(10.0, 1.0, SEGMENT_LENGTH + 0.5)
	mesh_instance.mesh = box
	seg.add_child(mesh_instance)

	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(10.0, 1.0, SEGMENT_LENGTH + 0.5)
	collision_shape.shape = box_shape
	seg.add_child(collision_shape)

	return seg


# ============================================================
# Таймер спавна препятствий
# ============================================================
func _create_obstacle_timer() -> void:
	obstacle_timer = Timer.new()
	obstacle_timer.name = "ObstacleTimer"
	obstacle_timer.wait_time = randf_range(1.5, 2.0)
	obstacle_timer.one_shot = false
	obstacle_timer.timeout.connect(_on_obstacle_timer_timeout)
	add_child(obstacle_timer)
	obstacle_timer.start()


func _on_obstacle_timer_timeout() -> void:
	_spawn_obstacle()
	# Случайный интервал для следующего спавна
	obstacle_timer.wait_time = randf_range(1.5, 2.0)


# ============================================================
# Спавн препятствия
# ============================================================
func _spawn_obstacle() -> void:
	var obstacle: Node3D = _make_obstacle()
	add_child(obstacle)


func _make_obstacle() -> Node3D:
	var obs: Node3D = Node3D.new()
	obs.name = "Obstacle"

	# Случайная полоса
	var lane_x: float = LANES[randi() % LANES.size()]

	# Случайный тип: 0 = нижнее (Jump), 1 = верхнее (Duck), 2 = стена (Dodge)
	var type_idx: int = randi() % 3
	var size_y: float
	var y_pos: float

	match type_idx:
		0:  # Нижнее — лежит на полу, нужно перепрыгнуть
			size_y = 1.0
			y_pos = 1.0   # центр куба на высоте 1.0, низ касается пола (Y=0.5)
		1:  # Верхнее — поднято, нужно проскользнуть под ним
			size_y = 1.0
			y_pos = 2.5   # нижняя грань на Y=2.0, свободное пространство снизу
		2:  # Стена — перекрывает всю полосу, нужно уклоняться влево/вправо
			size_y = 3.0
			y_pos = 2.0   # центр на Y=2.0, перекрывает от пола (0.5) до Y=3.5

	obs.position = Vector3(lane_x, y_pos, SPAWN_Z)

	# Меш препятствия
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(1.5, size_y, 1.5)
	mesh_instance.mesh = box

	# Красный материал
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color.RED
	mesh_instance.material_override = material

	obs.add_child(mesh_instance)

	# Коллизия
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(1.5, size_y, 1.5)
	collision_shape.shape = box_shape
	obs.add_child(collision_shape)

	# Прикрепляем mover.gd
	var mover_script: Script = load("res://mover.gd")
	obs.set_script(mover_script)

	return obs


# ============================================================
# _process — движение и рециклинг сегментов пола
# ============================================================
func _process(delta: float) -> void:
	for seg in ground_segments:
		seg.position.z += SPEED * delta
		if seg.position.z > RECYCLE_Z:
			seg.position.z += RECYCLE_OFFSET