extends Node3D

@export var time_scale: int = 1.0
@export var sensor_left: InfraredSensor
@export var sensor_right: InfraredSensor  
@export var traffic_light_left: TrafficLight
@export var traffic_light_right: TrafficLight
@export var max_green_time: float = 60.0
@export var min_green_time: float = 20.0
@export var exit_wait_time: float = 10.0
@export var check_interval: float = 0.5

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
	var left_turn = true
	
	while is_running:
		print("=== INIZIO CICLO ===")
		
		# Calcola i veicoli in attesa per ogni lato
		var waiting_left = max(0, sensor_left.get_vehicle_count() - traffic_light_left.get_exit_count())
		var waiting_right = max(0, sensor_right.get_vehicle_count() - traffic_light_right.get_exit_count())
		
		print("Veicoli in attesa - Sinistra: ", waiting_left, " Destra: ", waiting_right)
		
		# LOGICA SEMPLIFICATA: se un lato non ha traffico, salta
		if waiting_left == 0 and waiting_right == 0:
			print("Nessun traffico, aspetto...")
			await get_tree().create_timer(2.0).timeout
			continue
		elif waiting_left == 0:
			print("Nessun traffico a sinistra, servo solo destra")
			await execute_right_phase()
		elif waiting_right == 0:
			print("Nessun traffico a destra, servo solo sinistra")
			await execute_left_phase()
		else:
			# Entrambi hanno traffico, alterna normalmente
			if left_turn:
				await execute_left_phase()
			else:
				await execute_right_phase()
			left_turn = !left_turn
		
		# Pausa breve tra cicli
		traffic_light_left.current_light = "red"
		traffic_light_right.current_light = "red"
		traffic_light_left.update_lights()
		traffic_light_right.update_lights()
		
		await get_tree().create_timer(1.0).timeout
		print("=== FINE CICLO ===\n")

func execute_left_phase():
	print("=== FASE SINISTRA ===")
	
	print("Contatori iniziali - Sinistra arrivi: ", sensor_left.get_vehicle_count(), " uscite: ", traffic_light_left.get_exit_count())
	print("Contatori iniziali - Destra arrivi: ", sensor_right.get_vehicle_count(), " uscite: ", traffic_light_right.get_exit_count())
	
	# Calcola quanti veicoli sono in attesa a sinistra
	var initial_waiting_left = max(0, sensor_left.get_vehicle_count() - traffic_light_left.get_exit_count())
	var target_exits = traffic_light_left.get_exit_count() + initial_waiting_left
	print("Veicoli in attesa a sinistra: ", initial_waiting_left)
	print("Target uscite da raggiungere: ", target_exits)
	
	# Verde sinistra, rosso destra
	traffic_light_left.current_light = "green"
	traffic_light_right.current_light = "red"
	traffic_light_left.update_lights()
	traffic_light_right.update_lights()
	
	var green_duration = 0.0
	var last_arrival_count_right = sensor_right.get_vehicle_count()
	var time_without_new_exits = 0.0
	var last_exit_count = traffic_light_left.get_exit_count()
	
	# Aspetta almeno il tempo minimo (quello originale)
	while green_duration < min_green_time:
		await get_tree().create_timer(check_interval).timeout
		green_duration += check_interval
		
		var current_exits = traffic_light_left.get_exit_count()
		var current_arrivals_right = sensor_right.get_vehicle_count()
		var new_arrivals_right = current_arrivals_right - last_arrival_count_right
		
		print("Verde sinistra - Durata: ", green_duration, "s")
		print("  Uscite attuali: ", current_exits, "/", target_exits)
		print("  Nuovi arrivi destra: ", new_arrivals_right, " (tot: ", current_arrivals_right, ")")
		
		# Aggiorna contatori
		if current_exits > last_exit_count:
			time_without_new_exits = 0.0
			last_exit_count = current_exits
		else:
			time_without_new_exits += check_interval
		
		last_arrival_count_right = current_arrivals_right
	
	# Continua fino al tempo massimo o fino a quando tutti i veicoli sono usciti
	while green_duration < max_green_time:
		await get_tree().create_timer(check_interval).timeout
		green_duration += check_interval
		time_without_new_exits += check_interval
		
		var current_exits = traffic_light_left.get_exit_count()
		var current_arrivals_right = sensor_right.get_vehicle_count()
		var new_arrivals_right = current_arrivals_right - last_arrival_count_right
		var waiting_right = max(0, current_arrivals_right - traffic_light_right.get_exit_count())
		
		print("Verde sinistra - Durata: ", green_duration, "s")
		print("  Uscite attuali: ", current_exits, "/", target_exits)
		print("  Nuovi arrivi destra: ", new_arrivals_right, " (tot: ", current_arrivals_right, ")")
		print("  Veicoli in attesa destra: ", waiting_right)
		print("  Tempo senza nuove uscite: ", time_without_new_exits, "s")
		
		# Reset timer se ci sono nuove uscite
		if current_exits > last_exit_count:
			time_without_new_exits = 0.0
			last_exit_count = current_exits
		
		# Condizioni per terminare il verde (mantengo quelle originali più semplici)
		var all_vehicles_exited = current_exits >= target_exits
		var no_activity = time_without_new_exits >= exit_wait_time
		var pressure_from_right = new_arrivals_right > 0 and time_without_new_exits > exit_wait_time / 2
		
		if all_vehicles_exited:
			print("Tutti i veicoli sono usciti, termino verde sinistra")
			break
		elif no_activity:
			print("Nessuna attività da ", exit_wait_time, "s, termino verde sinistra")
			break
		elif pressure_from_right:
			print("Pressione da destra e nessuna uscita recente, termino verde sinistra")
			break
		
		last_arrival_count_right = current_arrivals_right
	
	# RESET ALLA FINE
	print("Reset contatori sinistra dopo aver servito tutti i veicoli")
	sensor_left.reset_count()
	traffic_light_left.reset_exit_count()

func execute_right_phase():
	print("=== FASE DESTRA ===")
	
	print("Contatori iniziali - Sinistra arrivi: ", sensor_left.get_vehicle_count(), " uscite: ", traffic_light_left.get_exit_count())
	print("Contatori iniziali - Destra arrivi: ", sensor_right.get_vehicle_count(), " uscite: ", traffic_light_right.get_exit_count())
	
	# Calcola quanti veicoli sono in attesa a destra
	var initial_waiting_right = max(0, sensor_right.get_vehicle_count() - traffic_light_right.get_exit_count())
	var target_exits = traffic_light_right.get_exit_count() + initial_waiting_right
	print("Veicoli in attesa a destra: ", initial_waiting_right)
	print("Target uscite da raggiungere: ", target_exits)
	
	# Verde destra, rosso sinistra
	traffic_light_right.current_light = "green"
	traffic_light_left.current_light = "red"
	traffic_light_right.update_lights()
	traffic_light_left.update_lights()
	
	var green_duration = 0.0
	var last_arrival_count_left = sensor_left.get_vehicle_count()
	var time_without_new_exits = 0.0
	var last_exit_count = traffic_light_right.get_exit_count()
	
	# Aspetta almeno il tempo minimo (quello originale)
	while green_duration < min_green_time:
		await get_tree().create_timer(check_interval).timeout
		green_duration += check_interval
		
		var current_exits = traffic_light_right.get_exit_count()
		var current_arrivals_left = sensor_left.get_vehicle_count()
		var new_arrivals_left = current_arrivals_left - last_arrival_count_left
		
		print("Verde destra - Durata: ", green_duration, "s")
		print("  Uscite attuali: ", current_exits, "/", target_exits)
		print("  Nuovi arrivi sinistra: ", new_arrivals_left, " (tot: ", current_arrivals_left, ")")
		
		# Aggiorna contatori
		if current_exits > last_exit_count:
			time_without_new_exits = 0.0
			last_exit_count = current_exits
		else:
			time_without_new_exits += check_interval
		
		last_arrival_count_left = current_arrivals_left
	
	# Continua fino al tempo massimo o fino a quando tutti i veicoli sono usciti
	while green_duration < max_green_time:
		await get_tree().create_timer(check_interval).timeout
		green_duration += check_interval
		time_without_new_exits += check_interval
		
		var current_exits = traffic_light_right.get_exit_count()
		var current_arrivals_left = sensor_left.get_vehicle_count()
		var new_arrivals_left = current_arrivals_left - last_arrival_count_left
		var waiting_left = max(0, current_arrivals_left - traffic_light_left.get_exit_count())
		
		print("Verde destra - Durata: ", green_duration, "s")
		print("  Uscite attuali: ", current_exits, "/", target_exits)
		print("  Nuovi arrivi sinistra: ", new_arrivals_left, " (tot: ", current_arrivals_left, ")")
		print("  Veicoli in attesa sinistra: ", waiting_left)
		print("  Tempo senza nuove uscite: ", time_without_new_exits, "s")
		
		# Reset timer se ci sono nuove uscite
		if current_exits > last_exit_count:
			time_without_new_exits = 0.0
			last_exit_count = current_exits
		
		# Condizioni per terminare il verde (mantengo quelle originali più semplici)
		var all_vehicles_exited = current_exits >= target_exits
		var no_activity = time_without_new_exits >= exit_wait_time
		var pressure_from_left = new_arrivals_left > 0 and time_without_new_exits > exit_wait_time / 2
		
		if all_vehicles_exited:
			print("Tutti i veicoli sono usciti, termino verde destra")
			break
		elif no_activity:
			print("Nessuna attività da ", exit_wait_time, "s, termino verde destra")
			break
		elif pressure_from_left:
			print("Pressione da sinistra e nessuna uscita recente, termino verde destra")
			break
		
		last_arrival_count_left = current_arrivals_left
	
	# RESET ALLA FINE
	print("Reset contatori destra dopo aver servito tutti i veicoli")
	sensor_right.reset_count()
	traffic_light_right.reset_exit_count()

func calculate_green_time(vehicle_count: int) -> float:
	if vehicle_count <= 0:
		return min_green_time
	
	# 8 secondi per veicolo + tempo minimo
	var calculated_time = min_green_time + (vehicle_count * 8.0)
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
