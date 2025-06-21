extends Node

signal vehicle_entered(direction, current_entries)


var traffic_lights_infos: Dictionary = {
	"left" = {
		"color": " ",
		"time": 0.00,
	},
	"right" = {
		"color": " ",
		"time": 0.00,
	}
}
var current_time

@onready var vehicles: Array = get_tree().get_nodes_in_group("Vehicles")


func get_traffic_light_infos():
	return traffic_lights_infos
