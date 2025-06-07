extends Node

@onready var vehicles: Array = get_tree().get_nodes_in_group("Vehicles")
@onready var traffic_lights: Array = get_tree().get_nodes_in_group("Traffic Lights")

#@export var max_red_time: float = 120
@export var max_green_time: float = 20
