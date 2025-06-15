extends CharacterBody3D

@export var speed: float = 10.0
@export var slow_speed: float = 1.0
@export var stop_threshold: float = 5.0
@export var car_stop_distance: float = 3.8
@export var lane_width: float = 1.7  # distanza laterale massima per considerare il semaforo "nella stessa corsia"
@onready var traffic_lights = TrafficManager.traffic_lights
@onready var vehicles: Array = get_tree().get_nodes_in_group("Vehicles")
@onready var should_stop: bool
var direction: Vector3 = Vector3.BACK

func _process(delta: float) -> void:
	should_stop = check_vehicles()

func _physics_process(delta: float) -> void:
	if should_stop:
		velocity = velocity.lerp(Vector3.ZERO, delta * 8.0)
	else:
		var traffic_action = get_traffic_action()
		match traffic_action:
			"stop":
				if velocity != Vector3.ZERO:
					velocity = velocity.lerp(Vector3.ZERO, delta * 8.0)
			"slow":
				velocity = velocity.lerp(slow_speed * direction, delta * 6.0)
			"go":
				velocity = velocity.lerp(speed * direction, delta)
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
	var to_light = traffic_light.global_position - global_position

	# Calcola se il semaforo è davanti
	var dot_product = direction.dot(to_light)
	if dot_product <= 0:
		return false

	# Calcola la distanza perpendicolare (lateralmente) rispetto alla direzione
	var perpendicular_distance = get_perpendicular_distance(to_light, direction)
	if perpendicular_distance > lane_width:
		return false

	# Controlla la distanza totale
	var distance = to_light.length()
	return distance < stop_threshold


func check_vehicles() -> bool:
	var my_pos = global_position

	for vehicle in vehicles:
		if vehicle == self or not is_instance_valid(vehicle):
			continue

		var other_pos = vehicle.global_position
		var to_other = other_pos - my_pos

		# Calcola se l'altro veicolo è davanti
		var dot_product = direction.dot(to_other)
		if dot_product <= 0:
			continue

		# Calcola la distanza laterale
		var perpendicular_distance = get_perpendicular_distance(to_other, direction)
		if perpendicular_distance > lane_width:
			continue  # troppo laterale: non è nella stessa corsia

		# Calcola la distanza davanti
		var distance_along_direction = dot_product
		if distance_along_direction > car_stop_distance:
			continue

		return true

	return false


# Funzione helper per calcolare la distanza perpendicolare
func get_perpendicular_distance(vector: Vector3, _direction: Vector3) -> float:
	# Proietta il vettore sulla direzione
	var projection = _direction * _direction.dot(vector)
	# Calcola il vettore perpendicolare
	var perpendicular = vector - projection
	# Ritorna la lunghezza del vettore perpendicolare
	return perpendicular.length()
