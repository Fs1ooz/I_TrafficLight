extends Node3D

@onready var timer: Timer = $"../Timer"

var vehicle_scenes: Array[PackedScene] = [
	preload("res://Scenes/sedan.tscn"),
	# preload("res://Scenes/camion_3d.tscn"),
]

var lanes: Dictionary = {
	"-ztoz": {"spawn_position": Vector3(1.7, 0, -20), "direction": Vector3.BACK, "rotation": Vector3(0, 0, 0)},
	"zto-z": {"spawn_position": Vector3(3.4, 0, 40), "direction": Vector3.FORWARD, "rotation": Vector3(0, PI, 0)},
}

var next_vehicle: PackedScene = vehicle_scenes[0]

func pick_random_vehicle() -> void:
	if vehicle_scenes.size() > 0:
		next_vehicle = vehicle_scenes[randi() % vehicle_scenes.size()]

func spawn_vehicle() -> void:
	pick_random_vehicle()
	var instance1 = next_vehicle.instantiate()
	var instance2 = next_vehicle.instantiate()
	
	await get_tree().create_timer(0.1).timeout

	spawn_at(instance1, lanes["-ztoz"]["spawn_position"], lanes["-ztoz"]["direction"], lanes["-ztoz"]["rotation"])
	spawn_at(instance2, lanes["zto-z"]["spawn_position"], lanes["zto-z"]["direction"], lanes["zto-z"]["rotation"])

func spawn_at(instance: Node3D, pos: Vector3, dir: Vector3, rot: Vector3) -> void:
	get_parent().add_child(instance)
	instance.global_position = pos
	instance.rotation = rot
	instance.direction = dir

func _on_timer_timeout() -> void:
	var vehicles = get_tree().get_nodes_in_group("Vehicles")
	if vehicles.size() > 10:
		return
	spawn_vehicle()
	timer.start()
