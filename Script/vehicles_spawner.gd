extends Node3D

var timer: float = 1.2

var vehicle_scenes: Array[PackedScene] = [
	preload("res://Scenes/sedan.tscn"),
	# preload("res://Scenes/camion_3d.tscn"),
]

var lanes: Dictionary = {
	"-ztoz": {"spawn_position": Vector3(1.7, 0, -45), "direction": Vector3.BACK, "rotation": Vector3(0, 0, 0)},
	"zto-z": {"spawn_position": Vector3(3.4, 0, 60), "direction": Vector3.FORWARD, "rotation": Vector3(0, PI, 0)},
}

var next_vehicle: PackedScene = vehicle_scenes[0]

func pick_random_vehicle() -> void:
	if vehicle_scenes.size() > 0:
		next_vehicle = vehicle_scenes[randi() % vehicle_scenes.size()]

func spawn_vehicles(left_count: int, right_count: int) -> void:
	spawn_A(left_count)
	spawn_B(right_count)

func spawn_A(left_count: int) -> void:
	for i in left_count:
		pick_random_vehicle()
		var instance = next_vehicle.instantiate()
		spawn_at(instance, lanes["-ztoz"]["spawn_position"], lanes["-ztoz"]["direction"], lanes["-ztoz"]["rotation"])
		await get_tree().create_timer(timer).timeout

func spawn_B(right_count: int) -> void:
	for i in right_count:
		pick_random_vehicle()
		var instance = next_vehicle.instantiate()
		spawn_at(instance, lanes["zto-z"]["spawn_position"], lanes["zto-z"]["direction"], lanes["zto-z"]["rotation"])
		await get_tree().create_timer(timer).timeout


func spawn_at(instance: Node3D, pos: Vector3, dir: Vector3, rot: Vector3) -> void:
	get_parent().add_child(instance)
	instance.global_position = pos
	instance.rotation = rot
	instance.direction = dir
