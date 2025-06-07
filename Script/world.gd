extends Node3D

#@export var raycast: RayCast3D
@export var time_scale: int = 1.0


func _process(delta: float) -> void:
	Engine.time_scale = time_scale
	var vehicles: Array = get_tree().get_nodes_in_group("Vehicles")
	for vehicle in vehicles:
		if vehicle.global_position.distance_to(Vector3(0,0,0)) > 50:
			vehicle.queue_free()
