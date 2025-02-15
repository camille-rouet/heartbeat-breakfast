extends Node

var beat_tolerance = 100  # Tolérance en millisecondes
var last_beat_time = 0
var button_pressed_1 = false  
var button_pressed_2 = false  

func _ready():
	$"../RhythmNotifier".beats(1).connect(_on_beat_detected)

func _on_beat_detected(_count):
	last_beat_time = Time.get_ticks_msec()

func _process(delta):
	_check_beat_input("motif1", button_pressed_1)
	_check_beat_input("motif2", button_pressed_2)

	# Réinitialisation des flags
	if not Input.is_action_pressed("motif1"):
		button_pressed_1 = false
	if not Input.is_action_pressed("motif2"):
		button_pressed_2 = false

# Vérifie si un motif est joué sur le rythme
func _check_beat_input(action: String, button_pressed: bool):
	if Input.is_action_pressed(action) and not button_pressed:
		button_pressed = true  
		var current_time = Time.get_ticks_msec()
		var delta_time = abs(current_time - last_beat_time)
		
		if delta_time <= beat_tolerance:
			print("[color=green]Parfait ! " + action)
		elif delta_time <= beat_tolerance * 2:
			print("[color=yellow]Correct " + action)
		else:
			print("[color=red]Raté " + action)
