extends CharacterBody3D

@export var speed: float = 1.5

func _physics_process(delta: float) -> void:
	velocity = speed * Vector3.BACK
	move_and_slide()
