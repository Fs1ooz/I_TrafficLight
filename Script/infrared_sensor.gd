extends Node3D
class_name InfraredSensor
@onready var raycast_A: RayCast3D = $InfraredA
@onready var raycast_B: RayCast3D = $InfraredB
@export var associated_traffic_light: TrafficLight
@export_enum("-ztoz", "zto-z") var sensor_direction: String

# ─── Aggiungi questa variabile ─────────────────────────────────────────────────
var last_trigger: String = ""

var was_A_colliding = false
var was_B_colliding = false
var vehicle_count = 0
var vehicles_detected = []

# ─── Rinominazione di process() in _physics_process() ────────────────────────────
func _physics_process(delta: float) -> void:
	if not raycast_A or not raycast_B:
		printerr("Raycast non assegnato!")
		return

	var is_A_colliding = raycast_A.is_colliding()
	var is_B_colliding = raycast_B.is_colliding()

	# ─── RISING EDGE DETECTION ────────────────────────────────────────────────────
	if not was_A_colliding and is_A_colliding:
		last_trigger = "A"
	if not was_B_colliding and is_B_colliding:
		last_trigger = "B"

	# ─── Conta veicolo solo quando entrambi attivi e last_trigger corrisponde ───────
	if is_A_colliding and is_B_colliding:
		match sensor_direction:
			"-ztoz":
				if last_trigger == "A":
					var vehicle = raycast_B.get_collider()
					if vehicle not in vehicles_detected:

						vehicles_detected.append(vehicle)
			"zto-z":
				if last_trigger == "B":
					var vehicle = raycast_A.get_collider()
					if vehicle not in vehicles_detected:

						vehicles_detected.append(vehicle)
		last_trigger = ""    # reset dopo la conta

	# ─── Salva gli stati per il prossimo frame ──────────────────────────────────────
	was_A_colliding = is_A_colliding
	was_B_colliding = is_B_colliding

	if vehicles_detected.size() > 50:
		vehicles_detected = vehicles_detected.slice(-30)
	vehicle_count = vehicles_detected.size()



func get_vehicle_count() -> int:
	return vehicle_count

func reset_count():
	vehicle_count = 0
	vehicles_detected.clear()
