extends Control
@export var left_input: SpinBox
@export var right_input: SpinBox
@export var button: Button
@export var vehicle_spawner: Node3D
@onready var vehicle_counterA: Label = $"LeftV/VehicleCounterA"
@onready var vehicle_counterB: Label = $"RightV/VehicleCounterB"
@onready var color_1: Label = $VBoxContainer5/Color1
@onready var time_1: Label = $VBoxContainer5/Time1
@onready var color_2: Label = $VBoxContainer6/Color2
@onready var time_2: Label = $VBoxContainer6/Time2

func _ready() -> void:
	TrafficManager.connect("vehicle_entered", vehicle_entered)

func _process(delta: float) -> void:
	var traffic_light_infos = TrafficManager.get_traffic_light_infos()
	color_1.text = traffic_light_infos["left"]["color"]
	color_2.text = traffic_light_infos["right"]["color"]
	time_1.text = str(traffic_light_infos["left"]["time"]).left(4)
	time_2.text = str(traffic_light_infos["right"]["time"]).left(4)

func on_spawn_pressed():
	var left_count = int(left_input.value)
	var right_count = int(right_input.value)
	spawn_machines(left_count, right_count)

func spawn_machines(left_count: int, right_count: int):
	vehicle_spawner.spawn_vehicles(left_count, right_count)

func on_button_pressed() -> void:
	var vehicles = get_tree().get_nodes_in_group("Vehicles")
	vehicle_counterA.text = ""
	vehicle_counterB.text = ""
	for vehicle in vehicles:
		vehicle.queue_free()
	get_tree().reload_current_scene()

func vehicle_entered(direction: String, current_entries: int):
	# Mostra il numero di veicoli in attesa (già calcolato correttamente nel TrafficController)
	match direction:
		"-ztoz":
			vehicle_counterA.text = str(current_entries)
		"zto-z":
			vehicle_counterB.text = str(current_entries)

# Rimuovi questa funzione se usi la soluzione semplice
# func vehicle_exited(direction: String):
#     # Non serve più
