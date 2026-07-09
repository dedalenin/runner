extends Node3D

# ============================================================
# WorldManager — спавнит пол и препятствия, управляет миром
# ============================================================

# Переключатели типов препятствий (чекбоксы в Inspector)
@export var enable_jump: bool = true   # Нижнее — нужно перепрыгнуть
@export var enable_duck: bool = true   # Верхнее — нужно пригнуться
@export var enable_wall: bool = true   # Стена — нужно уклоняться

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
	_setup_environment()
	var floor_material: StandardMaterial3D = _make_floor_material()
	_create_ground_segments(floor_material)
	_create_obstacle_timer()


# ============================================================
# Создание материала пола с текстурой
# ============================================================
func _make_floor_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	var texture: Texture2D = load("res://floor_texture.jpg")
	material.albedo_texture = texture
	material.uv1_scale = Vector3(10, 10, 10)
	return material


# ============================================================
# Спавн 6 сегментов пола
# ============================================================
func _create_ground_segments(floor_material: StandardMaterial3D) -> void:
	for i in range(SEGMENT_COUNT):
		var segment: Node3D = _make_ground_segment(floor_material)
		segment.position.z = 40.0 - i * SEGMENT_LENGTH
		add_child(segment)
		ground_segments.append(segment)


func _make_ground_segment(floor_material: StandardMaterial3D) -> Node3D:
	var seg: Node3D = Node3D.new()
	seg.name = "GroundSegment"

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(10.0, 1.0, SEGMENT_LENGTH + 0.5)
	mesh_instance.mesh = box
	mesh_instance.material_override = floor_material
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
	# Взвешенные паттерны: [0] (центр) с высоким шансом
	var weighted_patterns: Array = [
		[0.0],          # центр — 3× вес
		[0.0],
		[0.0],
		[-2.0],         # лево
		[2.0],          # право
		[-2.0, 0.0],    # лево + центр
		[0.0, 2.0],     # центр + право
		[-2.0, 2.0],    # лево + право
		[-2.0, 0.0, 2.0],  # все полосы
	]

	var chosen_pattern: Array = weighted_patterns[randi() % weighted_patterns.size()]

	# Формируем список доступных типов препятствий по чекбоксам
	var available_types: Array = []
	if enable_jump:
		available_types.append(0)
	if enable_duck:
		available_types.append(1)
	if enable_wall:
		available_types.append(2)

	# Если все чекбоксы выключены — ничего не спавним
	if available_types.size() == 0:
		return

	# Генерируем типы для каждой линии паттерна
	var types: Array = []
	for i in range(chosen_pattern.size()):
		types.append(available_types[randi() % available_types.size()])

	# Защита от непроходимости: если все 3 — Стены и доступна только Стена,
	# удаляем одно препятствие из ряда (не спавним его)
	if chosen_pattern.size() == 3 and available_types.size() == 1 and available_types[0] == 2:
		# Убираем случайное препятствие — останется проход
		chosen_pattern.remove_at(randi() % chosen_pattern.size())
		types.resize(chosen_pattern.size())

	# Спавним препятствия по паттерну
	for i in range(chosen_pattern.size()):
		var obstacle: Node3D = _make_obstacle_for_lane(chosen_pattern[i], types[i])
		add_child(obstacle)


func _make_obstacle_for_lane(lane_x: float, type_idx: int) -> Node3D:
	var obs: Node3D = Node3D.new()
	obs.name = "Obstacle"

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


# ============================================================
# Хоррор-окружение — WorldEnvironment (черный фон + туман)
# ============================================================
func _setup_environment() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)

	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.08
	env.volumetric_fog_albedo = Color(0.1, 0.1, 0.1)

	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)