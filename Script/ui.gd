extends Control

@export var left_input: SpinBox
@export var right_input: SpinBox
@export var button: Button
@export var vehicle_spawner: Node3D

func _on_spawn_pressed():
	var left_count = int(left_input.value)
	var right_count = int(right_input.value)
	spawn_machines(left_count, right_count)

func spawn_machines(left_count: int, right_count: int):
	vehicle_spawner.spawn_vehicles(left_count , right_count)


func _on_button_pressed() -> void:
	var vehicles = get_tree().get_nodes_in_group("Vehicles")
	for vehicle in vehicles:
		vehicle.queue_free()
