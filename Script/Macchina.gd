extends CharacterBody3D

@export var speed: float = 5.0
@export var slow_speed: float = 0.5
@export var stop_threshold: float = 5.0
@export var car_stop_distance: float = 4.0

@onready var traffic_lights = VehiclesManager.traffic_lights

@onready var starting_position: Vector3 = Vector3(1.7, 0, -12)
@onready var vehicles: Array = get_tree().get_nodes_in_group("Vehicles") 

@onready var should_stop: bool

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_down"):
		global_position = starting_position

func _ready() -> void:
	global_position = starting_position

func _process(delta: float) -> void:
	should_stop = check_vehicles()

func _physics_process(delta: float) -> void:
	if should_stop:
		velocity = velocity.lerp(Vector3.ZERO, delta * 4.0)
	else:
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

func check_vehicles() -> bool:
	var my_pos = global_position
	
	for vehicle in vehicles:
		if vehicle == self or not is_instance_valid(vehicle):
			continue
		
		var other_pos = vehicle.global_position
		
		var distance_z = other_pos.z - my_pos.z
		if distance_z <= 0 or distance_z > car_stop_distance: 
			continue
		
		var distance_x = abs(my_pos.x - other_pos.x)
		if distance_x < car_stop_distance:
			return true
	
	return false
