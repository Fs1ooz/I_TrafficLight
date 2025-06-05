extends Node3D

@export var raycast: RayCast3D
@export var time_scale: int = 1.0



func _process(delta: float) -> void:
	Engine.time_scale = time_scale
#func _process(delta):
	#if not raycast:
		#print("Raycast non assegnato!")
		#return
   #
	#if raycast.is_colliding():
		#var collider = raycast.get_collider()
		#var collision_point = raycast.get_collision_point()
		#print("Colpito: ", collider.name, " a distanza: ", raycast.global_position.distance_to(collision_point))
