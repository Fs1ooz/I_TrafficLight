extends Node3D
@export var raycast: RayCast3D

func _ready():
   # Assicurati che il raycast sia configurato
	if raycast:
		raycast.enabled = true
		raycast.debug_shape_thickness = 3

func _process(delta):
	if not raycast:
		print("Raycast non assegnato!")
		return
   
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		var collision_point = raycast.get_collision_point()
		print("Colpito: ", collider.name, " a distanza: ", raycast.global_position.distance_to(collision_point))
	else:
		print("Nessuna collisione - raggio libero")
