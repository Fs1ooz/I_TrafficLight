extends Node3D
class_name TrafficLight

@export var red_light: OmniLight3D
@export var yellow_light: OmniLight3D
@export var green_light: OmniLight3D
@export var yellow_time: float = 3.0
@export var current_light: String = "red"
@export var exit_sensor: RayCast3D

var current_green_time: float = 30.0
var exit_count: int = 0
var was_exit_colliding: bool = false
var vehicles_passed: Array = []

func _ready():
	update_lights()

func _process(delta: float) -> void:
	# Monitora il sensore di uscita se presente
	if exit_sensor:
		var is_colliding = exit_sensor.is_colliding()
		var collider = exit_sensor.get_collider()

		# Rileva nuovo veicolo che passa
		if is_colliding and not was_exit_colliding:
			if collider and collider.is_in_group("Vehicles"):
				if collider not in vehicles_passed:
					vehicles_passed.append(collider)
					exit_count += 1

		# Pulisci memoria veicoli
		if vehicles_passed.size() > 20:
			vehicles_passed = vehicles_passed.slice(-20)

		was_exit_colliding = is_colliding

#func set_green_time(time: float):
	#current_green_time = max(time, 5.0)

func update_lights():
	if red_light: red_light.visible = current_light == "red"
	if yellow_light: yellow_light.visible = current_light == "yellow"
	if green_light: green_light.visible = current_light == "green"

func force_state(new_state: String):
	current_light = new_state
	update_lights()

func get_exit_count() -> int:
	return exit_count

func reset_exit_count():
	exit_count = 0
	vehicles_passed.clear()
	#print("Reset contatore uscite semaforo")
