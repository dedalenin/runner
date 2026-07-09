extends Node3D

# ============================================================
# Mover — универсальный скрипт движения навстречу камере
# Объект движется по +Z и удаляется, когда уходит за спину
# ============================================================

@export var speed: float = 15.0
@export var destroy_z: float = 15.0


func _process(delta: float) -> void:
	global_position.z += speed * delta

	if global_position.z > destroy_z:
		queue_free()