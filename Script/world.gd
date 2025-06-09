extends Node3D

@export var time_scale: float = 1.0
@export var sensor_left: InfraredSensor
@export var sensor_right: InfraredSensor  
@export var traffic_light_left: TrafficLight
@export var traffic_light_right: TrafficLight
@export var max_green_time: float = 60.0
@export var min_green_time: float = 5.0
@export var exit_wait_time: float = 15.0
@export var check_interval: float = 0.1
@export var seconds_per_vehicle: float = 8.0  # Tempo medio per veicolo

var is_running = false

func _process(delta: float) -> void:
	Engine.time_scale = time_scale
	var vehicles: Array = get_tree().get_nodes_in_group("Vehicles")
	for vehicle in vehicles:
		if vehicle.global_position.distance_to(Vector3(0,0,0)) > 80:
			vehicle.queue_free()

func _ready():
	start_traffic_system()

func start_traffic_system():
	if is_running:
		return
	
	is_running = true
	traffic_cycle()

func traffic_cycle():
	while is_running:
		print("=== INIZIO CICLO OTTIMIZZATO ===")
		
		# Calcola i veicoli in attesa per ogni lato
		var waiting_left = max(0, sensor_left.get_vehicle_count() - traffic_light_left.get_exit_count())
		var waiting_right = max(0, sensor_right.get_vehicle_count() - traffic_light_right.get_exit_count())
		
		print("Veicoli in attesa - Sinistra: ", waiting_left, " Destra: ", waiting_right)
		
		# NESSUN TRAFFICO
		if waiting_left == 0 and waiting_right == 0:
			print("Nessun traffico, aspetto...")
			await get_tree().create_timer(2.0).timeout
			continue
		
		# CALCOLO OTTIMALE DEI TEMPI
		var total_vehicles = waiting_left + waiting_right
		var total_time_available = max_green_time * 2  # 120s totali disponibili
		
		var left_time = 0.0
		var right_time = 0.0
		
		if waiting_left > 0 and waiting_right > 0:
			# ENTRAMBI HANNO TRAFFICO - Distribuisci proporzionalmente
			var time_per_vehicle = total_time_available / float(total_vehicles)
			left_time = waiting_left * time_per_vehicle
			right_time = waiting_right * time_per_vehicle
			
			print("Distribuzione proporzionale:")
			print("  Tempo per veicolo: ", time_per_vehicle, "s")
			print("  Tempo sinistra: ", left_time, "s (", waiting_left, " veicoli)")
			print("  Tempo destra: ", right_time, "s (", waiting_right, " veicoli)")
		elif waiting_left > 0:
			# SOLO SINISTRA HA TRAFFICO
			left_time = min(waiting_left * seconds_per_vehicle, max_green_time)
			print("Solo sinistra - Tempo calcolato: ", left_time, "s")
		elif waiting_right > 0:
			# SOLO DESTRA HA TRAFFICO
			right_time = min(waiting_right * seconds_per_vehicle, max_green_time)
			print("Solo destra - Tempo calcolato: ", right_time, "s")
		
		# Applica limiti minimi e massimi
		if left_time > 0:
			left_time = clamp(left_time, min_green_time, max_green_time)
		if right_time > 0:
			right_time = clamp(right_time, min_green_time, max_green_time)
		
		print("Tempi finali - Sinistra: ", left_time, "s, Destra: ", right_time, "s")
		
		# ESEGUI LE FASI CON I TEMPI CALCOLATI
		if left_time > 0:
			await execute_left_phase_with_time(left_time)
		if right_time > 0:
			await execute_right_phase_with_time(right_time)
		
		# Pausa breve tra cicli
		await get_tree().create_timer(1.0).timeout
		print("=== FINE CICLO OTTIMIZZATO ===\n")

func execute_left_phase_with_time(allocated_time: float):
	print("=== FASE SINISTRA (", allocated_time, "s allocati) ===")
	
	var initial_waiting_left = max(0, sensor_left.get_vehicle_count() - traffic_light_left.get_exit_count())
	var target_exits = traffic_light_left.get_exit_count() + initial_waiting_left
	
	print("Veicoli in attesa: ", initial_waiting_left)
	print("Target uscite: ", target_exits)
	
	# Verde sinistra, rosso destra
	traffic_light_left.current_light = "green"
	traffic_light_right.current_light = "red"
	traffic_light_left.update_lights()
	traffic_light_right.update_lights()
	
	var green_duration = 0.0
	var time_without_new_exits = 0.0
	var last_exit_count = traffic_light_left.get_exit_count()
	
	# Loop principale con tempo allocato
	while green_duration < allocated_time:
		await get_tree().create_timer(check_interval).timeout
		green_duration += check_interval
		time_without_new_exits += check_interval
		
		var current_exits = traffic_light_right.get_exit_count()
		var current_arrivals_right = sensor_right.get_vehicle_count()
		var waiting_right = max(0, current_arrivals_right - traffic_light_right.get_exit_count())
		
		print("Verde sinistra - ", green_duration, "/", allocated_time, "s")
		print("  Uscite: ", current_exits, "/", target_exits)
		print("  Attesa destra: ", waiting_right)
		print("  Inattività: ", time_without_new_exits, "s")
		
		# Reset timer se ci sono nuove uscite
		if current_exits > last_exit_count:
			time_without_new_exits = 0.0
			last_exit_count = current_exits
		
		# Condizioni per terminare anticipatamente
		var all_vehicles_exited = current_exits >= target_exits
		var no_activity = time_without_new_exits >= exit_wait_time
		var min_time_passed = green_duration >= min_green_time
		
		if min_time_passed and (all_vehicles_exited or no_activity):
			print("Terminazione anticipata: tutti usciti=", all_vehicles_exited, ", inattività=", no_activity)
			break
	
	print("Fase sinistra completata in ", green_duration, "s")
	
	# RESET ALLA FINE
	sensor_left.reset_count()
	traffic_light_left.reset_exit_count()

func execute_right_phase_with_time(allocated_time: float):
	print("=== FASE DESTRA (", allocated_time, "s allocati) ===")
	
	var initial_waiting_right = max(0, sensor_right.get_vehicle_count() - traffic_light_right.get_exit_count())
	var target_exits = traffic_light_right.get_exit_count() + initial_waiting_right
	
	print("Veicoli in attesa: ", initial_waiting_right)
	print("Target uscite: ", target_exits)
	
	# Verde destra, rosso sinistra
	traffic_light_right.current_light = "green"
	traffic_light_left.current_light = "red"
	traffic_light_right.update_lights()
	traffic_light_left.update_lights()
	
	var green_duration = 0.0
	var time_without_new_exits = 0.0
	var last_exit_count = traffic_light_right.get_exit_count()
	
	# Loop principale con tempo allocato
	while green_duration < allocated_time:
		await get_tree().create_timer(check_interval).timeout
		green_duration += check_interval
		time_without_new_exits += check_interval
		
		var current_exits = traffic_light_left.get_exit_count()
		var current_arrivals_left = sensor_left.get_vehicle_count()
		var waiting_left = max(0, current_arrivals_left - traffic_light_left.get_exit_count())
		
		print("Verde destra - ", green_duration, "/", allocated_time, "s")
		print("  Uscite: ", current_exits, "/", target_exits)
		print("  Attesa sinistra: ", waiting_left)
		print("  Inattività: ", time_without_new_exits, "s")
		
		# Reset timer se ci sono nuove uscite
		if current_exits > last_exit_count:
			time_without_new_exits = 0.0
			last_exit_count = current_exits
		
		# Condizioni per terminare anticipatamente
		var all_vehicles_exited = current_exits >= target_exits
		var no_activity = time_without_new_exits >= exit_wait_time
		var min_time_passed = green_duration >= min_green_time
		
		if min_time_passed and (all_vehicles_exited or no_activity):
			print("Terminazione anticipata: tutti usciti=", all_vehicles_exited, ", inattività=", no_activity)
			break
	
	print("Fase destra completata in ", green_duration, "s")
	
	# RESET ALLA FINE
	sensor_right.reset_count()
	traffic_light_right.reset_exit_count()

# Mantieni le funzioni originali per compatibilità
func execute_left_phase():
	await execute_left_phase_with_time(max_green_time)

func execute_right_phase():
	await execute_right_phase_with_time(max_green_time)

func calculate_green_time(vehicle_count: int) -> float:
	if vehicle_count <= 0:
		return min_green_time
	
	var calculated_time = min_green_time + (vehicle_count * seconds_per_vehicle)
	return min(calculated_time, max_green_time)

func stop_traffic_system():
	is_running = false

func get_current_status() -> Dictionary:
	return {
		"left_arrivals": sensor_left.get_current_count(),
		"right_arrivals": sensor_right.get_current_count(),
		"left_exits": traffic_light_left.get_exit_count(),
		"right_exits": traffic_light_right.get_exit_count(),
		"left_waiting": max(0, sensor_left.get_current_count() - traffic_light_left.get_exit_count()),
		"right_waiting": max(0, sensor_right.get_current_count() - traffic_light_right.get_exit_count()),
		"left_light": traffic_light_left.current_light,
		"right_light": traffic_light_right.current_light,
		"is_running": is_running
	}

func force_cycle():
	if is_running:
		stop_traffic_system()
		await get_tree().process_frame
		start_traffic_system()
