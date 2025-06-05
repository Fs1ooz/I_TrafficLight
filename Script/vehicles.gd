extends Node

@onready var vehicles: Array = get_tree().get_nodes_in_group("Vehicles")
@onready var traffic_lights: Array = get_tree().get_nodes_in_group("Traffic Lights")
