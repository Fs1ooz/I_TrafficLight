extends Node3D

#enum TrafficState {
	#LEFT,
	#RIGHT,
	#UP,
	#DOWN,
#}
#
#enum TrafficLightColor {
	#GREEN,
	#YELLOW,
	#RED,
#}


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
@export var seconds_per_vehicle: float = 6.0
@export var initial_wait_time: float = 3.0

var is_running = false
var current_active_phase = ""  # "left", "right", "none"
#var current_color: TrafficLightColor = TrafficLightColor.RED
# Contatori per tracciare i segnali
var last_left_entries = 0
var last_right_entries = 0
var last_left_exits = 0
var last_right_exits = 0

func _process(_delta: float) -> void:
	Engine.time_scale = time_scale
	var vehicles: Array = get_tree().get_nodes_in_group("Vehicles")
	for vehicle in vehicles:
		if vehicle.global_position.distance_to(Vector3(0,0,0)) > 80:
			vehicle.queue_free()

	# Controlla sempre le entrate, ma le uscite solo durante le fasi attive
	check_entries()
	if current_active_phase == "left":
		check_left_exits()
	elif current_active_phase == "right":
		check_right_exits()

	TrafficManager.traffic_lights_infos["left"]["color"] = traffic_light_left.current_light
	TrafficManager.traffic_lights_infos["right"]["color"] = traffic_light_right.current_light


func _ready():
	# Inizializza i contatori
	if sensor_left:
		last_left_entries = sensor_left.get_vehicle_count()
	if sensor_right:
		last_right_entries = sensor_right.get_vehicle_count()
	if traffic_light_left:
		last_left_exits = traffic_light_left.get_exit_count()
	if traffic_light_right:
		last_right_exits = traffic_light_right.get_exit_count()

	start_traffic_system()

func start_traffic_system():
	if is_running:
		return

	is_running = true
	traffic_cycle()

func traffic_cycle():
	while is_running:
		print("=== INIZIO CICLO OTTIMIZZATO ===")
		current_active_phase = "none"

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
		current_active_phase = "none"
		await get_tree().create_timer(1.0).timeout
		print("=== FINE CICLO OTTIMIZZATO ===\n")

func execute_left_phase_with_time(allocated_time: float):
	print("=== FASE SINISTRA (", allocated_time, "s allocati) ===")
	current_active_phase = "left"  # ATTIVA il controllo delle uscite a sinistra
	TrafficManager.traffic_lights_infos["left"]["time"] = allocated_time
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

		TrafficManager.traffic_lights_infos["left"]["time"] = allocated_time - green_duration

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

		if min_time_passed and (no_more_waiting or no_activity):
			var reason = ""
			if no_more_waiting: reason += "nessuna attesa "
			if no_activity: reason += "inattività "
			print("Terminazione anticipata: ", reason)
			break

	print("Fase verde sinistra completata in ", green_duration, "s")
	print("Veicoli processati totali: ", traffic_light_right.get_exit_count() - initial_exit_count)

	# *** FASE GIALLA SINISTRA ***
	await execute_yellow_phase_left()

func execute_right_phase_with_time(allocated_time: float):
	print("=== FASE DESTRA (", allocated_time, "s allocati) ===")
	current_active_phase = "right"  # ATTIVA il controllo delle uscite a destra
	TrafficManager.traffic_lights_infos["right"]["time"] = allocated_time

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

		TrafficManager.traffic_lights_infos["right"]["time"] = allocated_time - green_duration

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

		if min_time_passed and (no_more_waiting or no_activity):
			var reason = ""
			if no_more_waiting: reason += "nessuna attesa "
			if no_activity: reason += "inattività "
			print("Terminazione anticipata: ", reason)
			break

	print("Fase verde destra completata in ", green_duration, "s")
	print("Veicoli processati totali: ", traffic_light_left.get_exit_count() - initial_exit_count)

	# *** FASE GIALLA DESTRA ***
	await execute_yellow_phase_right()

# Nuove funzioni per gestire le fasi gialle
func execute_yellow_phase_left():
	print("=== FASE GIALLA SINISTRA (", yellow_time, "s) ===")
	TrafficManager.traffic_lights_infos["left"]["time"] = 0.0
	# Giallo sinistra, rosso destra
	traffic_light_left.current_light = "yellow"
	traffic_light_right.current_light = "red"
	traffic_light_left.update_lights()
	traffic_light_right.update_lights()

	# Attesa fissa per il giallo
	await get_tree().create_timer(yellow_time).timeout

	# Alla fine del giallo, metti rosso
	traffic_light_left.current_light = "red"
	traffic_light_left.update_lights()

	print("Fase gialla sinistra completata")

func execute_yellow_phase_right():
	print("=== FASE GIALLA DESTRA (", yellow_time, "s) ===")
	TrafficManager.traffic_lights_infos["right"]["time"] = 0.0
	# Giallo destra, rosso sinistra
	traffic_light_right.current_light = "yellow"
	traffic_light_left.current_light = "red"
	traffic_light_right.update_lights()
	traffic_light_left.update_lights()

	# Attesa fissa per il giallo
	await get_tree().create_timer(yellow_time).timeout

	# Alla fine del giallo, metti rosso
	traffic_light_right.current_light = "red"
	traffic_light_right.update_lights()

	print("Fase gialla destra completata")

func check_entries():
	# Controlla nuovi ingressi da SINISTRA (sensore sinistro rileva -z to z)
	var current_left_entries = sensor_left.get_vehicle_count()
	if current_left_entries > last_left_entries:
		var new_entries = current_left_entries - last_left_entries
		for i in range(new_entries):
			TrafficManager.emit_signal("vehicle_entered", "-ztoz")
			print("Segnale: veicolo entrato da SINISTRA (-ztoz)")
		last_left_entries = current_left_entries

	# Controlla nuovi ingressi da DESTRA (sensore destro rileva z to -z)
	var current_right_entries = sensor_right.get_vehicle_count()
	if current_right_entries > last_right_entries:
		var new_entries = current_right_entries - last_right_entries
		for i in range(new_entries):
			TrafficManager.emit_signal("vehicle_entered", "zto-z")
			print("Segnale: veicolo entrato da DESTRA (zto-z)")
		last_right_entries = current_right_entries

# Funzione separata per controllare le uscite a sinistra (quando il verde è a sinistra)
func check_left_exits():
	# Durante la fase sinistra, controlliamo le uscite dal semaforo DESTRO
	# (i veicoli da sinistra che escono attraverso il semaforo destro)
	var current_right_exits = traffic_light_right.get_exit_count()
	if current_right_exits > last_right_exits:
		var new_exits = current_right_exits - last_right_exits
		for i in range(new_exits):
			TrafficManager.emit_signal("vehicle_exited", "-ztoz")
			print("Segnale: veicolo da SINISTRA uscito (-ztoz)")
		last_right_exits = current_right_exits

# Funzione separata per controllare le uscite a destra (quando il verde è a destra)
func check_right_exits():
	# Durante la fase destra, controlliamo le uscite dal semaforo SINISTRO
	# (i veicoli da destra che escono attraverso il semaforo sinistro)
	var current_left_exits = traffic_light_left.get_exit_count()
	if current_left_exits > last_left_exits:
		var new_exits = current_left_exits - last_left_exits
		for i in range(new_exits):
			TrafficManager.emit_signal("vehicle_exited", "zto-z")
			print("Segnale: veicolo da DESTRA uscito (zto-z)")
		last_left_exits = current_left_exits

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

		# Reset anche dei contatori locali per i segnali
		last_left_entries = 0
		last_right_entries = 0
		last_left_exits = 0
		last_right_exits = 0
	else:
		print("Reset evitato - traffico residuo presente")
