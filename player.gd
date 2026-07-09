extends Node3D

# ============================================================
# Player — First-Person View (летающая камера, без физики)
# ============================================================

# === Конфигурация полос ===
const LANE_DISTANCE: float = 2.0
const LANE_COUNT: int = 3
const LANE_X: Array[float] = [-2.0, 0.0, 2.0]

# === Конфигурация камеры ===
const BASE_CAMERA_Y: float = 2.0
const JUMP_PEAK_Y: float = 3.5
const CROUCH_Y: float = 1.0

# === Тайминги ===
const LANE_SWITCH_DURATION: float = 0.2
const JUMP_UP_DURATION: float = 0.3
const JUMP_DOWN_DURATION: float = 0.3
const CROUCH_DOWN_DURATION: float = 0.15
const CROUCH_HOLD_DURATION: float = 0.5
const CROUCH_UP_DURATION: float = 0.2

# === Camera Shake ===
const SHAKE_INTENSITY: float = 0.08
const SHAKE_DURATION: float = 0.15

# === Head Bobbing ===
const BOB_SPEED: float = 12.0
const BOB_INTENSITY: float = 0.05

# === Состояние ===
var current_lane: int = 1          # 0=лево, 1=центр, 2=право
var camera: Camera3D
var head: Node3D                   # контейнер для перемещений (полосы, прыжок, подкат)
var bob: Node3D                    # контейнер для покачивания и тряски
var is_jumping: bool = false
var is_crouching: bool = false
var is_switching_lane: bool = false

# === Head Bobbing ===
var bob_time: float = 0.0

# ============================================================
# _ready — создаём Head → Bob → Camera + фонарик
# ============================================================
func _ready() -> void:
	# Head — контейнер для движения (полосы, прыжок, подкат)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(LANE_X[current_lane], BASE_CAMERA_Y, 0.0)
	add_child(head)

	# Bob — контейнер для покачивания и тряски
	bob = Node3D.new()
	bob.name = "Bob"
	head.add_child(bob)

	# Камера
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera.position = Vector3(0, 0, 0)
	bob.add_child(camera)

	_setup_flashlight()


# ============================================================
# _process — ввод, покачивание
# ============================================================
func _process(delta: float) -> void:
	_handle_input()
	_update_head_bob(delta)


# ============================================================
# Head Bobbing — синусоидальное покачивание камеры
# ============================================================
func _update_head_bob(delta: float) -> void:
	bob_time += delta * BOB_SPEED
	var bob_offset: float = sin(bob_time) * BOB_INTENSITY
	bob.position.y = bob_offset


# ============================================================
# Ввод
# ============================================================
func _handle_input() -> void:
	# Смена полосы (A/D или стрелки)
	if Input.is_action_just_pressed("ui_left"):
		_move_lane(-1)
	if Input.is_action_just_pressed("ui_right"):
		_move_lane(1)

	# Прыжок (Space)
	if Input.is_action_just_pressed("ui_accept") and not is_jumping and not is_crouching:
		_do_jump()

	# Подкат (Ctrl / стрелка вниз)
	if Input.is_action_just_pressed("ui_down") and not is_jumping and not is_crouching:
		_do_crouch()


# ============================================================
# Смена полосы — Tween по X (head)
# ============================================================
func _move_lane(direction: int) -> void:
	var new_lane: int = clamp(current_lane + direction, 0, LANE_COUNT - 1)
	if new_lane == current_lane:
		return

	current_lane = new_lane

	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(head, "position:x", LANE_X[current_lane], LANE_SWITCH_DURATION)


# ============================================================
# Фейковый прыжок — Tween по Y (head) + Shake на приземлении
# ============================================================
func _do_jump() -> void:
	is_jumping = true

	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	# Вверх
	tween.tween_property(head, "position:y", JUMP_PEAK_Y, JUMP_UP_DURATION)

	# Вниз
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(head, "position:y", BASE_CAMERA_Y, JUMP_DOWN_DURATION)

	# Ждём завершения, затем shake и разблокировка
	tween.tween_callback(_on_jump_land)


func _on_jump_land() -> void:
	_camera_shake()
	is_jumping = false


# ============================================================
# Фейковый подкат — Tween вниз → пауза → Tween вверх (head)
# ============================================================
func _do_crouch() -> void:
	is_crouching = true

	var down_tween: Tween = create_tween()
	down_tween.tween_property(head, "position:y", CROUCH_Y, CROUCH_DOWN_DURATION)
	down_tween.tween_callback(_crouch_hold)


func _crouch_hold() -> void:
	await get_tree().create_timer(CROUCH_HOLD_DURATION).timeout

	var up_tween: Tween = create_tween()
	up_tween.tween_property(head, "position:y", BASE_CAMERA_Y, CROUCH_UP_DURATION)
	up_tween.tween_callback(func(): is_crouching = false)


# ============================================================
# Camera Shake — тряска на приземлении (bob)
# ============================================================
func _camera_shake() -> void:
	var shake_tween: Tween = create_tween()
	var original_pos: Vector3 = bob.position

	# Серия быстрых микро-смещений
	var steps: int = 6
	var step_duration: float = SHAKE_DURATION / float(steps)

	for i in range(steps):
		var offset: Vector3 = Vector3(
			randf_range(-SHAKE_INTENSITY, SHAKE_INTENSITY),
			randf_range(-SHAKE_INTENSITY * 0.5, SHAKE_INTENSITY * 0.5),
			0.0
		)
		shake_tween.tween_property(bob, "position",
			original_pos + offset, step_duration)

	# Возврат в исходную позицию (с bob-ом)
	shake_tween.tween_property(bob, "position", original_pos, step_duration * 0.5)


# ============================================================
# Фонарик — SpotLight3D, прикреплённый к камере
# ============================================================
func _setup_flashlight() -> void:
	var flashlight: SpotLight3D = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.spot_range = 80.0   # было 30.0 — теперь дальний свет
	flashlight.spot_angle = 35.0
	flashlight.light_energy = 5.0  # было 3.0 — теперь ярче
	flashlight.shadow_enabled = true
	camera.add_child(flashlight)