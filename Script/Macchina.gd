extends CharacterBody3D

@export var speed: int = 2


func _physics_process(delta: float) -> void:
	velocity = speed * Vector3.RIGHT
	move_and_slide()
