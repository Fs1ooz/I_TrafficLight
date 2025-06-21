extends Node3D

enum TrafficPhase {
	NONE,
	LEFT,
	RIGHT
}

enum TrafficLightColor {
	GREEN,
	YELLOW,
	RED,
}

@export var time_scale: float = 1.0
@export var sensor_left: InfraredSensor
@export var sensor_right: InfraredSensor
@export var traffic_light_left: TrafficLight
@export var traffic_light_right: TrafficLight
@export var max_green_time: float = 60.0
@export var min_green_time: float = 5.0
@export var yellow_time: float = 3.0
@export var exit_wait_time: float = 15.0
@export var check_interval: float = 0.1
@export var initial_wait_time: float = 2.0

var last_left_exits = 0
var last_right_exits = 0
var is_running = false
var current_active_phase: TrafficPhase = TrafficPhase.NONE
var seconds_per_vehicle: float = 8.0

# NUOVE VARIABILI per sincronizzazione
var reset_in_progress = false
var pending_resets = []

func _ready():
	start_traffic_system()

func _process(_delta: float) -> void:
	Engine.time_scale = time_scale
	var vehicles: Array = get_tree().get_nodes_in_group("Vehicles")
	for vehicle in vehicles:
		if vehicle.global_position.distance_to(Vector3(0,0,0)) > 80:
			vehicle.queue_free()

	TrafficManager.traffic_lights_infos["left"]["color"] = traffic_light_left.current_light
	TrafficManager.traffic_lights_infos["right"]["color"] = traffic_light_right.current_light

func start_traffic_system():
	if is_running:
		return
	is_running = true
	traffic_cycle()

func traffic_cycle():
	while is_running:
		print("=== INIZIO CICLO ===")
		current_active_phase = TrafficPhase.NONE

		# ATTESA INIZIALE per permettere ai veicoli di arrivare completamente
		print("Attesa iniziale per stabilizzare il traffico...")
		await get_tree().create_timer(initial_wait_time).timeout

		# Calcola i veicoli in attesa per ogni lato DOPO l'attesa - AGGIORNAMENTO CONTINUO
		var current_arrivals_left = sensor_left.get_vehicle_count()
		var current_arrivals_right = sensor_right.get_vehicle_count()
		var waiting_left = max(0, current_arrivals_left)
		var waiting_right = max(0, current_arrivals_right)

		if current_active_phase == TrafficPhase.NONE:
			check_entries("loading...", "loading...")

		print("Conteggio AGGIORNATO - Sinistra: ", waiting_left, " Destra: ", waiting_right)
		print("  Arrivi totali sinistra: ", current_arrivals_left)
		print("  Arrivi totali destra: ", current_arrivals_right)
		print("  Uscite precedenti sinistra: ", traffic_light_left.get_exit_count())
		print("  Uscite precedenti destra: ", traffic_light_right.get_exit_count())

		# NESSUN TRAFFICO
		if waiting_left == 0 and waiting_right == 0:
			print("Nessun traffico, aspetto...")
			await get_tree().create_timer(initial_wait_time).timeout
			continue

		# CALCOLO OTTIMALE DEI TEMPI con sistema adattivo
		var left_time = 0.0
		var right_time = 0.0

		if waiting_left > 0 and waiting_right > 0:
			var base_time_per_vehicle = min(seconds_per_vehicle, max_green_time / float(waiting_left + waiting_right))
			left_time = waiting_left * base_time_per_vehicle
			right_time = waiting_right * base_time_per_vehicle
			print("  Tempo sinistra: ", left_time, "s (", waiting_left, " veicoli)")
			print("  Tempo destra: ", right_time, "s (", waiting_right, " veicoli)")
		elif waiting_left > 0:
			left_time = min(waiting_left * seconds_per_vehicle, max_green_time)
			print("Solo sinistra - Tempo calcolato: ", left_time, "s")
		elif waiting_right > 0:
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
			await execute_phase(TrafficPhase.LEFT, left_time)
		if right_time > 0:
			await execute_phase(TrafficPhase.RIGHT, right_time)

		# Pausa breve tra cicli
		current_active_phase = TrafficPhase.NONE
		await get_tree().create_timer(1.0).timeout
		print("=== FINE CICLO OTTIMIZZATO ===\n")

func execute_phase(phase: TrafficPhase, allocated_time: float):
	var phase_name = "SINISTRA" if phase == TrafficPhase.LEFT else "DESTRA"
	var traffic_info_key = "left" if phase == TrafficPhase.LEFT else "right"

	var active_light = traffic_light_left if phase == TrafficPhase.LEFT else traffic_light_right
	var inactive_light = traffic_light_right if phase == TrafficPhase.LEFT else traffic_light_left
	var exit_light = traffic_light_right if phase == TrafficPhase.LEFT else traffic_light_left
	var arrival_sensor = sensor_left if phase == TrafficPhase.LEFT else sensor_right
	var other_sensor = sensor_right if phase == TrafficPhase.LEFT else sensor_left

	print("=== FASE ", phase_name, " (", allocated_time, "s allocati) ===")
	current_active_phase = phase
	TrafficManager.traffic_lights_infos[traffic_info_key]["time"] = allocated_time

	# Imposta i semafori: verde per la fase attiva, rosso per l'altra
	active_light.current_light = "green"
	inactive_light.current_light = "red"
	active_light.update_lights()
	inactive_light.update_lights()

	var green_duration = 0.0
	var time_without_new_exits = 0.0
	var last_exit_count = exit_light.get_exit_count()
	var initial_exit_count = last_exit_count

	# Loop principale con monitoraggio dinamico CONTINUO
	while green_duration < max_green_time:
		await get_tree().create_timer(check_interval).timeout
		green_duration += check_interval
		time_without_new_exits += check_interval

		var current_arrivals = arrival_sensor.get_vehicle_count()
		var current_exits = exit_light.get_exit_count()
		var vehicles_processed = current_exits - initial_exit_count
		var current_waiting = max(0, current_arrivals - vehicles_processed)

		var other_arrivals = other_sensor.get_vehicle_count()
		var other_waiting = max(0, other_arrivals)

		TrafficManager.traffic_lights_infos[traffic_info_key]["time"] = allocated_time - green_duration

		if phase == TrafficPhase.LEFT:
			check_entries(current_waiting, other_waiting)
		else:
			check_entries(other_waiting, current_waiting)

		print("Verde ", phase_name.to_lower(), " - ", green_duration, "/", allocated_time, "s")
		print("  Arrivi AGGIORNATI ", phase_name.to_lower(), ": ", current_arrivals)
		print("  Uscite totali: ", current_exits)
		print("  Veicoli processati: ", vehicles_processed)
		print("  ATTUALMENTE in attesa ", phase_name.to_lower(), ": ", current_waiting)
		print("  ATTUALMENTE in attesa ", ("destra" if phase == TrafficPhase.LEFT else "sinistra"), ": ", other_waiting)
		print("  Inattività: ", time_without_new_exits, "s")

		if current_exits > last_exit_count:
			time_without_new_exits = 0.0
			last_exit_count = current_exits

		var no_more_waiting = current_waiting == 0
		var no_activity = time_without_new_exits >= exit_wait_time
		var min_time_passed = green_duration >= min_green_time

		var needed_time = current_waiting * seconds_per_vehicle
		var should_continue = current_waiting > 0 and green_duration < needed_time

		print("  CALCOLO DINAMICO - Veicoli in attesa: ", current_waiting, " Tempo necessario: ", needed_time, "s")

		if min_time_passed and (!should_continue or no_activity):
			var reason = ""
			if no_more_waiting: reason += "nessuna attesa "
			if no_activity: reason += "inattività "
			if !should_continue and current_waiting == 0: reason += "tempo sufficiente "
			print("Terminazione anticipata: ", reason)
			break

	print("Fase verde ", phase_name.to_lower(), " completata in ", green_duration, "s")
	print("Veicoli processati totali: ", exit_light.get_exit_count() - initial_exit_count)

	# *** FASE GIALLA ***
	await execute_yellow_phase(phase)

	# RESET SINCRONIZZATO - Eseguito in un frame atomico
	await perform_synchronized_reset(phase, exit_light, arrival_sensor)

func execute_yellow_phase(phase: TrafficPhase):
	var phase_name = "SINISTRA" if phase == TrafficPhase.LEFT else "DESTRA"
	var traffic_info_key = "left" if phase == TrafficPhase.LEFT else "right"
	var active_light = traffic_light_left if phase == TrafficPhase.LEFT else traffic_light_right
	var inactive_light = traffic_light_right if phase == TrafficPhase.LEFT else traffic_light_left

	print("=== FASE GIALLA ", phase_name, " (", yellow_time, "s) ===")
	TrafficManager.traffic_lights_infos[traffic_info_key]["time"] = 0.0

	active_light.current_light = "yellow"
	inactive_light.current_light = "red"
	active_light.update_lights()
	inactive_light.update_lights()

	var yellow_elapsed = 0.0
	while yellow_elapsed < yellow_time:
		await get_tree().create_timer(check_interval).timeout
		yellow_elapsed += check_interval
		check_entries("loading...", "loading...")

	active_light.current_light = "red"
	active_light.update_lights()
	print("Fase gialla ", phase_name.to_lower(), " completata")

# NUOVA FUNZIONE: Reset sincronizzato per evitare perdita di veicoli
func perform_synchronized_reset(phase: TrafficPhase, exit_light: TrafficLight, arrival_sensor: InfraredSensor):
	print("=== INIZIO RESET SINCRONIZZATO ===")
	reset_in_progress = true

	# Pausa brevissima per permettere a eventuali veicoli in arrivo di essere registrati
	await get_tree().process_frame

	# Cattura lo stato finale prima del reset
	var final_arrivals = arrival_sensor.get_vehicle_count()
	var final_exits = exit_light.get_exit_count()

	print("Stato pre-reset - Arrivi: ", final_arrivals, " Uscite: ", final_exits)

	# Reset atomico - tutti i contatori vengono azzerati nello stesso frame
	exit_light.reset_exit_count()
	arrival_sensor.reset_count()

	# Aspetta un frame per essere sicuri che il reset sia completato
	await get_tree().process_frame

	# Verifica che i nuovi arrivi dopo il reset siano correttamente conteggiati
	var post_reset_arrivals = arrival_sensor.get_vehicle_count()
	print("Stato post-reset - Nuovi arrivi: ", post_reset_arrivals)

	reset_in_progress = false
	print("=== FINE RESET SINCRONIZZATO ===")

func check_entries(waiting_left, waiting_right):
	# Se è in corso un reset, non aggiornare i dati per evitare inconsistenze
	if reset_in_progress:
		return

	if waiting_left is not String:
		if waiting_left == 0 and waiting_right == 0:
			waiting_left = "loading..."
			waiting_right = "loading..."

	TrafficManager.emit_signal("vehicle_entered", "-ztoz", waiting_left)
	TrafficManager.emit_signal("vehicle_entered", "zto-z", waiting_right)
