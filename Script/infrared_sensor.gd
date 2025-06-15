extends Node3D
class_name InfraredSensor

@onready var raycast_A: RayCast3D = $InfraredA
@onready var raycast_B: RayCast3D = $InfraredB
@export var associated_traffic_light: TrafficLight
@export var sensor_direction: String = "-ztoz"

var was_A_colliding = false
var was_B_colliding = false
var vehicle_count = 0
var vehicles_detected = []

func _process(delta: float) -> void:
	if not raycast_A or not raycast_B:
		print("Raycast non assegnato!")
		return

	var is_A_colliding = raycast_A.is_colliding()
	var is_B_colliding = raycast_B.is_colliding()

	# Conta tutti i veicoli che arrivano, indipendentemente dal semaforo
	# (Il semaforo conta separatamente quelli che passano)
	if is_A_colliding and not was_A_colliding:
		var collider_A = raycast_A.get_collider()
		if collider_A and collider_A.is_in_group("Vehicles"):
			if collider_A not in vehicles_detected:
				vehicles_detected.append(collider_A)
				vehicle_count += 1
				#print("Arrivo rilevato sensore ", sensor_direction, " #", vehicle_count)

	# Pulisci memoria
	if vehicles_detected.size() > 30:
		vehicles_detected = vehicles_detected.slice(-30)

	was_A_colliding = is_A_colliding
	was_B_colliding = is_B_colliding

func get_vehicle_count() -> int:
	return vehicle_count

func reset_count():
	vehicle_count = 0
	vehicles_detected.clear()
	#print("Counter reset per sensore ", sensor_direction)

func get_current_count() -> int:
	return vehicle_count
