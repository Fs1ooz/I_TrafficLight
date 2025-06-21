extends Node3D

var min_timer: float = 1.0  # tempo minimo tra spawn (secondi)
var max_timer: float = 2.0  # tempo massimo tra spawn (secondi)
var max_vehicles: int = 15   # numero massimo di veicoli da spawnare
var vehicle_scenes: Array[PackedScene] = [
	preload("res://Scenes/sedan.tscn"),
	# preload("res://Scenes/camion_3d.tscn"),
]
var lanes: Dictionary = {
	"-ztoz": {"spawn_position": Vector3(1.7, 0, -55), "direction": Vector3.BACK, "rotation": Vector3(0, 0, 0)},
	"zto-z": {"spawn_position": Vector3(3.4, 0, 60), "direction": Vector3.FORWARD, "rotation": Vector3(0, PI, 0)},
}
var next_vehicle: PackedScene = vehicle_scenes[0]
var is_spawning: bool = false
var spawn_timer: Timer
@onready var vehicles_spawned = get_tree().get_nodes_in_group("Vehicles").size()

func _ready():
	# Crea un timer per controllare periodicamente se può riprendere lo spawn
	spawn_timer = Timer.new()
	spawn_timer.wait_time = 1.0  # Controlla ogni secondo
	spawn_timer.timeout.connect(_check_spawn_conditions)
	add_child(spawn_timer)
	spawn_timer.start()

	# Avvia lo spawn automatico quando il nodo è pronto
	start_random_spawning()

func _check_spawn_conditions():
	# Aggiorna il conteggio dei veicoli
	vehicles_spawned = get_tree().get_nodes_in_group("Vehicles").size()

	# Se non sta spawnando e ci sono meno veicoli del massimo, riavvia lo spawn
	if not is_spawning and vehicles_spawned < max_vehicles:
		print("Riavvio spawn: ", vehicles_spawned, "/", max_vehicles, " veicoli presenti")
		start_random_spawning()

func pick_random_vehicle() -> void:
	if vehicle_scenes.size() > 0:
		next_vehicle = vehicle_scenes[randi() % vehicle_scenes.size()]

func get_random_lane() -> String:
	var lane_keys = lanes.keys()
	return lane_keys[randi() % lane_keys.size()]

func get_random_timer() -> float:
	return randf_range(min_timer, max_timer)

func start_random_spawning() -> void:
	if is_spawning:
		return
	is_spawning = true
	spawn_vehicles_randomly()

func stop_spawning() -> void:
	is_spawning = false

func spawn_vehicles_randomly() -> void:
	while is_spawning:
		# Aggiorna il conteggio dei veicoli ad ogni iterazione
		vehicles_spawned = get_tree().get_nodes_in_group("Vehicles").size()

		# Se abbiamo raggiunto il massimo, ferma temporaneamente lo spawn
		if vehicles_spawned >= max_vehicles:
			print("Massimo veicoli raggiunto (", vehicles_spawned, "/", max_vehicles, "), pausa spawn...")
			is_spawning = false
			break

		# Attendi un tempo casuale prima del prossimo spawn
		var wait_time = get_random_timer()
		await get_tree().create_timer(wait_time).timeout

		if not is_spawning:
			break

		# Spawna un veicolo in una corsia casuale
		spawn_single_vehicle()
		vehicles_spawned = get_tree().get_nodes_in_group("Vehicles").size()
		print("Veicolo spawnato: ", vehicles_spawned, "/", max_vehicles, " - Prossimo spawn in: ", get_random_timer(), " secondi")

func spawn_single_vehicle() -> void:
	pick_random_vehicle()
	var lane_key = get_random_lane()
	var lane_data = lanes[lane_key]
	var instance = next_vehicle.instantiate()
	spawn_at(instance, lane_data["spawn_position"], lane_data["direction"], lane_data["rotation"])

# Funzione per spawnare un numero specifico di veicoli (opzionale)
func spawn_vehicles(left_count: int, right_count: int) -> void:
	spawn_A(left_count)
	spawn_B(right_count)

func spawn_A(left_count: int) -> void:
	for i in left_count:
		pick_random_vehicle()
		var instance = next_vehicle.instantiate()
		spawn_at(instance, lanes["-ztoz"]["spawn_position"], lanes["-ztoz"]["direction"], lanes["-ztoz"]["rotation"])
		var wait_time = get_random_timer()
		await get_tree().create_timer(wait_time).timeout

func spawn_B(right_count: int) -> void:
	for i in right_count:
		pick_random_vehicle()
		var instance = next_vehicle.instantiate()
		spawn_at(instance, lanes["zto-z"]["spawn_position"], lanes["zto-z"]["direction"], lanes["zto-z"]["rotation"])
		var wait_time = get_random_timer()
		await get_tree().create_timer(wait_time).timeout

func spawn_at(instance: Node3D, pos: Vector3, dir: Vector3, rot: Vector3) -> void:
	get_parent().add_child(instance)
	instance.global_position = pos
	instance.rotation = rot
	instance.direction = dir
