extends Node3D

var vehicle_scene_paths: Array = ["res://Scenes/macchina_3d.tscn"]
var vehicles: Array = []

func _ready() -> void:
	_spawn_vehicle_timer()

func _spawn_vehicle_timer() -> void:
	# Crea il timer solo una volta!
	var timer = get_tree().create_timer(4.0)
	timer.timeout.connect(_on_spawn_vehicle)

func _on_spawn_vehicle() -> void:
	var path = vehicle_scene_paths[0]  # Se è solo uno, usa l'indice 0
	var scene = load(path)
	var instance = scene.instantiate()
	get_parent().add_child(instance)
	vehicles.append(instance)

	# Ri-crea il timer per la prossima spawnata
	_spawn_vehicle_timer()
