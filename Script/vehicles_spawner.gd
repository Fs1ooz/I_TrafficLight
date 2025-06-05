extends Node3D

@onready var timer: Timer = $"../Timer"

# Pre-carica le scene a tempo di compilazione (ZERO lag)
var vehicle_scenes: Array[PackedScene] = [
	preload("res://Scenes/sedan.tscn"),
	# Aggiungi altri veicoli qui
	# preload("res://Scenes/camion_3d.tscn"),
]

var next_vehicle: PackedScene = vehicle_scenes[0]

# Sceglie una scena casuale dai veicoli disponibili
func pick_random_vehicle() -> void:
	if vehicle_scenes.size() > 0:
		next_vehicle = vehicle_scenes[randi() % vehicle_scenes.size()]

# Spawna un veicolo nella scena
func spawn_vehicle() -> void:
	pick_random_vehicle()
	var instance = next_vehicle.instantiate()
	await get_tree().create_timer(0.1).timeout
	get_parent().add_child(instance)

# Callback del timer - spawna un veicolo e riavvia il timer
func _on_timer_timeout() -> void:
	spawn_vehicle()
	timer.start()
