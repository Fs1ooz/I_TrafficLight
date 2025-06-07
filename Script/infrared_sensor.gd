extends Node3D

@onready var raycast_A: RayCast3D = $InfraredA
@onready var raycast_B: RayCast3D = $InfraredB
var previous_state: String = ""
var was_A_colliding = false
var was_B_colliding = false


signal add_time
var vehicles_waiting = []
var vehicles_in_transit = []

func _process(delta: float) -> void:
	if not raycast_A or not raycast_B:
		print("Raycast non assegnato!")
		return
	
	var current_state = ""
	var is_A_colliding = raycast_A.is_colliding()
	var is_B_colliding = raycast_B.is_colliding()
	
	var collider_A = raycast_A.get_collider()
	var collider_B = raycast_B.get_collider()
	
	# Se entrambi stanno collidendo
	if is_A_colliding and is_B_colliding:
		# Se A ha iniziato a collidere prima (era già in collisione)
		if was_A_colliding and not was_B_colliding:
			vehicles_in_transit.append(collider_A)
			current_state = "sinistra"
		# Se B ha iniziato a collidere prima
		elif was_B_colliding and not was_A_colliding:
			vehicles_in_transit.append(collider_B)
			current_state = "destra"
			
		# Se hanno iniziato insieme, usa la distanza come fallback

		if current_state != previous_state:
			print("direzione: ", current_state, " Collider A ", collider_A, " B ", collider_B)
			previous_state = current_state
	else:
		previous_state = ""
	
	# Aggiorna lo stato precedente
	was_A_colliding = is_A_colliding
	was_B_colliding = is_B_colliding
	
	
func get_in_transit_time() -> float:
	if vehicles_in_transit.size() == 0:
		return 0.0
	return VehiclesManager.max_green_time / vehicles_in_transit.size()
