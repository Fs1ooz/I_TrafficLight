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
	TrafficManager.connect("vehicle_entered", _vehicle_entered)
	TrafficManager.connect("vehicle_exited", _vehicle_exited)


func _process(delta: float) -> void:
	var traffic_light_infos = TrafficManager.get_traffic_light_infos()
	color_1.text = traffic_light_infos["left"]["color"]
	color_2.text = traffic_light_infos["right"]["color"]
	time_1.text = str(traffic_light_infos["left"]["time"]).left(4)
	time_2.text = str(traffic_light_infos["right"]["time"]).left(4)

func _on_spawn_pressed():
	var left_count = int(left_input.value)
	var right_count = int(right_input.value)
	spawn_machines(left_count, right_count)


func spawn_machines(left_count: int, right_count: int):
	vehicle_spawner.spawn_vehicles(left_count, right_count)


func _on_button_pressed() -> void:
	var vehicles = get_tree().get_nodes_in_group("Vehicles")
	vehicle_counterA.text = ""
	vehicle_counterB.text = ""
	for vehicle in vehicles:
		vehicle.queue_free()
	get_tree().reload_current_scene()



func _vehicle_entered(direction: String):
	match direction:
		"-ztoz":
			var count = int(vehicle_counterA.text)
			count += 1
			vehicle_counterA.text = str(count)
		"zto-z":
			var count = int(vehicle_counterB.text)
			count += 1
			vehicle_counterB.text = str(count)

func _vehicle_exited(direction: String):
	match direction:
		"-ztoz":
			var count = int(vehicle_counterA.text)
			count = max(0, count - 1)
			vehicle_counterA.text = str(count)
		"zto-z":
			var count = int(vehicle_counterB.text)
			count = max(0, count - 1)
			vehicle_counterB.text = str(count)
