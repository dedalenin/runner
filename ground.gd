extends AnimatableBody3D

# ============================================================
# Ground — сегмент земли, движется на игрока (бесконечно)
# ============================================================

const SPEED: float = 8.0
const SEGMENT_LENGTH: float = 100.0

func _physics_process(delta: float) -> void:
	# Двигаемся на игрока
	move_and_collide(Vector3(0, 0, -SPEED * delta))

	# Когда сегмент ушёл далеко назад — переставляем вперёд
	if global_position.z < -SEGMENT_LENGTH:
		global_position.z += SEGMENT_LENGTH * 3