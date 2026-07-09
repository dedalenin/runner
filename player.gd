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

# === Состояние ===
var current_lane: int = 1          # 0=лево, 1=центр, 2=право
var camera: Camera3D
var is_jumping: bool = false
var is_crouching: bool = false
var is_switching_lane: bool = false


# ============================================================
# _ready — создаём только камеру
# ============================================================
func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera.position = Vector3(LANE_X[current_lane], BASE_CAMERA_Y, 0.0)
	add_child(camera)
	_setup_flashlight()


# ============================================================
# _process — только ввод (без физики)
# ============================================================
func _process(_delta: float) -> void:
	_handle_input()


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
# Смена полосы — Tween по X
# ============================================================
func _move_lane(direction: int) -> void:
	var new_lane: int = clamp(current_lane + direction, 0, LANE_COUNT - 1)
	if new_lane == current_lane:
		return

	current_lane = new_lane

	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(camera, "position:x", LANE_X[current_lane], LANE_SWITCH_DURATION)


# ============================================================
# Фейковый прыжок — Tween по Y + Shake на приземлении
# ============================================================
func _do_jump() -> void:
	is_jumping = true

	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	# Вверх
	tween.tween_property(camera, "position:y", JUMP_PEAK_Y, JUMP_UP_DURATION)

	# Вниз
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(camera, "position:y", BASE_CAMERA_Y, JUMP_DOWN_DURATION)

	# Ждём завершения, затем shake и разблокировка
	tween.tween_callback(_on_jump_land)


func _on_jump_land() -> void:
	_camera_shake()
	is_jumping = false


# ============================================================
# Фейковый подкат — Tween вниз → пауза → Tween вверх
# ============================================================
func _do_crouch() -> void:
	is_crouching = true

	var down_tween: Tween = create_tween()
	down_tween.tween_property(camera, "position:y", CROUCH_Y, CROUCH_DOWN_DURATION)
	down_tween.tween_callback(_crouch_hold)


func _crouch_hold() -> void:
	await get_tree().create_timer(CROUCH_HOLD_DURATION).timeout

	var up_tween: Tween = create_tween()
	up_tween.tween_property(camera, "position:y", BASE_CAMERA_Y, CROUCH_UP_DURATION)
	up_tween.tween_callback(func(): is_crouching = false)


# ============================================================
# Camera Shake — лёгкая тряска на приземлении
# ============================================================
func _camera_shake() -> void:
	var shake_tween: Tween = create_tween()
	var original_pos: Vector3 = camera.position

	# Серия быстрых микро-смещений
	var steps: int = 6
	var step_duration: float = SHAKE_DURATION / float(steps)

	for i in range(steps):
		var offset: Vector3 = Vector3(
			randf_range(-SHAKE_INTENSITY, SHAKE_INTENSITY),
			randf_range(-SHAKE_INTENSITY * 0.5, SHAKE_INTENSITY * 0.5),
			0.0
		)
		shake_tween.tween_property(camera, "position",
			original_pos + offset, step_duration)

	# Возврат в исходную позицию
	shake_tween.tween_property(camera, "position", original_pos, step_duration * 0.5)


# ============================================================
# Фонарик — SpotLight3D, прикреплённый к камере
# ============================================================
func _setup_flashlight() -> void:
	var flashlight: SpotLight3D = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.spot_range = 30.0
	flashlight.spot_angle = 35.0
	flashlight.light_energy = 3.0
	flashlight.shadow_enabled = true
	camera.add_child(flashlight)