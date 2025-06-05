extends CharacterBody3D

@export var speed: float = 5.0
@export var slow_speed: float = 0.2
@export var stop_threshold: float = 5.0
@export var car_stop_distance: float = 2.0  # distanza minima dalle altre auto

@onready var traffic_lights: Array = get_tree().get_nodes_in_group("Traffic Lights")
@onready var starting_position: float = -12
@onready var vehicles: Array = get_tree().get_nodes_in_group("Vehicles")  # gruppo per tutte le auto

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_down"):
		global_position.z = starting_position

func _ready() -> void:
	global_position.z = starting_position

func _physics_process(delta: float) -> void:
	var should_stop = false

	for vehicle in vehicles:
		if vehicle == self:
			continue  # ignora la macchina stessa
		var distance_z = abs(global_position.z - vehicle.global_position.z)
		var distance_x = abs(global_position.x - vehicle.global_position.x)
		if distance_x < 1.0 and distance_z < car_stop_distance:
			should_stop = true
			break

	
	if should_stop:
		# Rallenta o ferma la macchina
		velocity = velocity.lerp(Vector3.ZERO, delta * 4.0)
	else:
		# Altrimenti rispetta il semaforo
		var traffic_action = get_traffic_action()
		match traffic_action:
			"stop":
				if velocity != Vector3.ZERO:
					velocity = velocity.lerp(Vector3.ZERO, delta * 4.0)
			"slow":
				velocity = velocity.lerp(slow_speed * Vector3.BACK, delta * 3.0)
			"go":
				velocity = velocity.lerp(speed * Vector3.BACK, delta)
	
	move_and_slide()

func get_traffic_action() -> String:
	for traffic_light in traffic_lights:
		if is_near_traffic_light(traffic_light):
			match traffic_light.current_light:
				"red":
					return "stop"
				"yellow":
					return "slow"
				"green":
					return "go"
	return "go"

func is_near_traffic_light(traffic_light) -> bool:
	if traffic_light.global_position.z <= global_position.z:
		return false
	var distance_x = abs(global_position.x - traffic_light.global_position.x)
	var distance_z = abs(global_position.z - traffic_light.global_position.z)
	return distance_x < stop_threshold and distance_z < stop_threshold
