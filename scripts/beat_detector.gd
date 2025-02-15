extends Node

var beat_tolerance = 100  # Tolérance en millisecondes
var last_beat_time = 0
var button_pressed_1 = false  # Flag pour vérifier si "motif1" a été activé
var button_pressed_2 = false  # Flag pour vérifier si "motif2" a été activé

func _ready():
	$"../RhythmNotifier".beats(1).connect(func(_count):
		last_beat_time = Time.get_ticks_msec()
	)

func _process(delta):
	# Gérer motif1
	if Input.is_action_pressed("motif1") and not button_pressed_1:  # Détecte l'appui unique pour motif1
		button_pressed_1 = true  # Marque que motif1 a été pressé
		var current_time = Time.get_ticks_msec()
		var delta_time = abs(current_time - last_beat_time)
		
		if delta_time <= beat_tolerance:
			print("Parfait ! motif1")
		elif delta_time <= beat_tolerance * 2:
			print("Correct motif1")
		else:
			print("Raté motif1")
	
	# Gérer motif2
	if Input.is_action_pressed("motif2") and not button_pressed_2:  # Détecte l'appui unique pour motif2
		button_pressed_2 = true  # Marque que motif2 a été pressé
		var current_time = Time.get_ticks_msec()
		var delta_time = abs(current_time - last_beat_time)
		
		if delta_time <= beat_tolerance:
			print("Parfait ! motif2")
		elif delta_time <= beat_tolerance * 2:
			print("Correct motif2")
		else:
			print("Raté motif2")

	# Réinitialisation des flags lorsque les boutons sont relâchés
	if not Input.is_action_pressed("motif1"):
		button_pressed_1 = false
	
	if not Input.is_action_pressed("motif2"):
		button_pressed_2 = false
