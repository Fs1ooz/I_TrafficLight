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
@export var seconds_per_vehicle: float = 8.0
@export var initial_wait_time: float = 3.0  # Tempo di attesa iniziale per permettere ai veicoli di arrivare

var is_running = false

func _process(_delta: float) -> void:
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

		# ATTESA INIZIALE per permettere ai veicoli di arrivare completamente
		print("Attesa iniziale per stabilizzare il traffico...")
		await get_tree().create_timer(initial_wait_time).timeout

		# Calcola i veicoli in attesa per ogni lato DOPO l'attesa - AGGIORNAMENTO CONTINUO
		var current_arrivals_left = sensor_left.get_vehicle_count()
		var current_arrivals_right = sensor_right.get_vehicle_count()
		var waiting_left = max(0, current_arrivals_left - traffic_light_left.get_exit_count())
		var waiting_right = max(0, current_arrivals_right - traffic_light_right.get_exit_count())

		print("Conteggio AGGIORNATO - Sinistra: ", waiting_left, " Destra: ", waiting_right)
		print("  Arrivi totali sinistra: ", current_arrivals_left)
		print("  Arrivi totali destra: ", current_arrivals_right)
		print("  Uscite precedenti sinistra: ", traffic_light_left.get_exit_count())
		print("  Uscite precedenti destra: ", traffic_light_right.get_exit_count())

		# NESSUN TRAFFICO
		if waiting_left == 0 and waiting_right == 0:
			print("Nessun traffico, aspetto...")
			await get_tree().create_timer(2.0).timeout
			continue

		# CALCOLO OTTIMALE DEI TEMPI con sistema adattivo
		var left_time = 0.0
		var right_time = 0.0

		if waiting_left > 0 and waiting_right > 0:
			# ENTRAMBI HANNO TRAFFICO - Sistema proporzionale migliorato
			var total_vehicles = waiting_left + waiting_right
			var base_time_per_vehicle = min(seconds_per_vehicle, max_green_time / float(max(waiting_left, waiting_right)))

			left_time = waiting_left * base_time_per_vehicle
			right_time = waiting_right * base_time_per_vehicle

			# Bilanciamento: se uno ha molto più traffico, gli diamo più tempo
			var imbalance_ratio = float(max(waiting_left, waiting_right)) / float(min(waiting_left, waiting_right))
			if imbalance_ratio > 2.0:  # Se c'è grande squilibrio
				var bonus_time = min(10.0, (imbalance_ratio - 1.0) * 2.0)
				if waiting_left > waiting_right:
					left_time += bonus_time
				else:
					right_time += bonus_time

			print("Distribuzione proporzionale bilanciata:")
			print("  Rapporto squilibrio: ", imbalance_ratio)
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

	# Verde sinistra, rosso destra
	traffic_light_left.current_light = "green"
	traffic_light_right.current_light = "red"
	traffic_light_left.update_lights()
	traffic_light_right.update_lights()

	var green_duration = 0.0
	var time_without_new_exits = 0.0
	var last_exit_count = traffic_light_right.get_exit_count()
	var initial_exit_count = last_exit_count

	# Loop principale con monitoraggio dinamico CONTINUO
	while green_duration < allocated_time:
		await get_tree().create_timer(check_interval).timeout
		green_duration += check_interval
		time_without_new_exits += check_interval

		# AGGIORNAMENTO CONTINUO degli arrivi in tempo reale
		var current_arrivals_left = sensor_left.get_vehicle_count()
		var current_exits = traffic_light_right.get_exit_count()
		var vehicles_processed = current_exits - initial_exit_count
		var current_waiting_left = max(0, current_arrivals_left - current_exits)

		# Monitoraggio situazione destra
		var current_arrivals_right = sensor_right.get_vehicle_count()
		var current_waiting_right = max(0, current_arrivals_right - traffic_light_right.get_exit_count())

		print("Verde sinistra - ", green_duration, "/", allocated_time, "s")
		print("  Arrivi AGGIORNATI sinistra: ", current_arrivals_left)
		print("  Uscite totali: ", current_exits)
		print("  Veicoli processati: ", vehicles_processed)
		print("  ATTUALMENTE in attesa sinistra: ", current_waiting_left)
		print("  ATTUALMENTE in attesa destra: ", current_waiting_right)
		print("  Inattività: ", time_without_new_exits, "s")

		# Reset timer se ci sono nuove uscite
		if current_exits > last_exit_count:
			time_without_new_exits = 0.0
			last_exit_count = current_exits

		# Condizioni per terminare anticipatamente BASATE SU DATI AGGIORNATI
		var no_more_waiting = current_waiting_left == 0
		var no_activity = time_without_new_exits >= exit_wait_time
		var min_time_passed = green_duration >= min_green_time
		#var urgent_right_traffic = current_waiting_right > 3  # Traffico urgente dall'altra parte

		if min_time_passed and (no_more_waiting or no_activity):
			var reason = ""
			if no_more_waiting: reason += "nessuna attesa "
			if no_activity: reason += "inattività "
			#if urgent_right_traffic: reason += "traffico urgente destra "
			print("Terminazione anticipata: ", reason)
			break

	print("Fase sinistra completata in ", green_duration, "s")
	print("Veicoli processati totali: ", traffic_light_right.get_exit_count() - initial_exit_count)

func execute_right_phase_with_time(allocated_time: float):
	print("=== FASE DESTRA (", allocated_time, "s allocati) ===")

	# Verde destra, rosso sinistra
	traffic_light_right.current_light = "green"
	traffic_light_left.current_light = "red"
	traffic_light_right.update_lights()
	traffic_light_left.update_lights()

	var green_duration = 0.0
	var time_without_new_exits = 0.0
	var last_exit_count = traffic_light_left.get_exit_count()
	var initial_exit_count = last_exit_count

	# Loop principale con monitoraggio dinamico CONTINUO
	while green_duration < allocated_time:
		await get_tree().create_timer(check_interval).timeout
		green_duration += check_interval
		time_without_new_exits += check_interval

		# AGGIORNAMENTO CONTINUO degli arrivi in tempo reale
		var current_arrivals_right = sensor_right.get_vehicle_count()
		var current_exits = traffic_light_left.get_exit_count()
		var vehicles_processed = current_exits - initial_exit_count
		var current_waiting_right = max(0, current_arrivals_right - current_exits)

		# Monitoraggio situazione sinistra
		var current_arrivals_left = sensor_left.get_vehicle_count()
		var current_waiting_left = max(0, current_arrivals_left - traffic_light_left.get_exit_count())

		print("Verde destra - ", green_duration, "/", allocated_time, "s")
		print("  Arrivi AGGIORNATI destra: ", current_arrivals_right)
		print("  Uscite totali: ", current_exits)
		print("  Veicoli processati: ", vehicles_processed)
		print("  ATTUALMENTE in attesa destra: ", current_waiting_right)
		print("  ATTUALMENTE in attesa sinistra: ", current_waiting_left)
		print("  Inattività: ", time_without_new_exits, "s")

		# Reset timer se ci sono nuove uscite
		if current_exits > last_exit_count:
			time_without_new_exits = 0.0
			last_exit_count = current_exits

		# Condizioni per terminare anticipatamente BASATE SU DATI AGGIORNATI
		var no_more_waiting = current_waiting_right == 0
		var no_activity = time_without_new_exits >= exit_wait_time
		var min_time_passed = green_duration >= min_green_time
		#var urgent_left_traffic = current_waiting_left > 3  # Traffico urgente dall'altra parte

		if min_time_passed and (no_more_waiting or no_activity):
			var reason = ""
			if no_more_waiting: reason += "nessuna attesa "
			if no_activity: reason += "inattività "
			#if urgent_left_traffic: reason += "traffico urgente sinistra "
			print("Terminazione anticipata: ", reason)
			break

	print("Fase destra completata in ", green_duration, "s")
	print("Veicoli processati totali: ", traffic_light_left.get_exit_count() - initial_exit_count)

# Funzione per resettare i contatori solo quando necessario
func smart_reset_counters():
	# Reset solo se non ci sono veicoli in attesa
	var waiting_left = max(0, sensor_left.get_vehicle_count() - traffic_light_left.get_exit_count())
	var waiting_right = max(0, sensor_right.get_vehicle_count() - traffic_light_right.get_exit_count())

	if waiting_left == 0 and waiting_right == 0:
		print("Reset completo dei contatori - nessun traffico residuo")
		sensor_left.reset_count()
		sensor_right.reset_count()
		traffic_light_left.reset_exit_count()
		traffic_light_right.reset_exit_count()
	else:
		print("Reset evitato - traffico residuo presente")

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
