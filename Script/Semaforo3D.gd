extends Node3D

@export var red_light: OmniLight3D
@export var yellow_light: OmniLight3D
@export var green_light: OmniLight3D

@export var red_time := 5.0
@export var yellow_time := 3.0
@export var green_time := 2.0

var current_light := "green"

func _ready():
	update_lights()
	start_cycle()

func start_cycle():
	match current_light:
		"red":
			await get_tree().create_timer(red_time).timeout
			current_light = "green"
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
