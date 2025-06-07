extends Node3D
class_name TrafficLight

@export var red_light: OmniLight3D
@export var yellow_light: OmniLight3D
@export var green_light: OmniLight3D
@export var infrared_sensor: Node3D

@export var red_time: float = 60.0
@export var green_time: float = 30.0 
@export var yellow_time: float = 3.0

@export var current_light: String

func _ready():
	update_lights()
	start_cycle()

func start_cycle():
	match current_light:
		"red":
			await get_tree().create_timer(red_time).timeout
			current_light = "green"
			green_time = infrared_sensor.get_in_transit_time()
		"green":
			await get_tree().create_timer(green_time).timeout
			current_light = "yellow"
		"yellow":
			await get_tree().create_timer(yellow_time).timeout
			current_light = "red"
	update_lights()
	start_cycle()

func update_lights():
	red_light.visible = current_light == "red"
	yellow_light.visible = current_light == "yellow"
	green_light.visible = current_light == "green"
