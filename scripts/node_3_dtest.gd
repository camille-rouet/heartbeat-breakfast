extends Node3D

@export var object_speed : float = 5.0  # Vitesse des objets
@export var max_speed : float = 10.0  # Vitesse maximale des objets
@export var camera_speed : float = 5.0  # Vitesse de déplacement de la caméra
@export var spawn_interval : float = 1  # Intervalle entre chaque cube (remplacé par le rythme)
@onready var rhythm_notifier = get_node("RhythmNotifier")  # Adapte le chemin selon ta scène
  # Référence au RhythmNotifier

var columns = []  # Liste des colonnes
var box_mesh : BoxMesh  # Mesh pour les cubes
var camera : Camera3D  # Caméra
var camera_column_index : int = 0  # Index de la colonne actuelle de la caméra
var target_camera_position : Vector3  # Position cible de la caméra

var detected_cubes = []  # Liste des cubes déjà détectés

var musicPlaying = false
var musicPositionMemo = 0

func _ready():
	# Récupérer la caméra et les colonnes
	camera = $Camera3D  
	columns.append($MeshInstance3D)  
	columns.append($MeshInstance3D2)  
	columns.append($MeshInstance3D3)  
	columns.append($MeshInstance3D4)  

	# Position initiale de la caméra
	_align_camera_to_column(true)

	# Création du BoxMesh pour les cubes
	box_mesh = BoxMesh.new()  

	# Connecter le rythme pour générer les cubes sur le beat
	if rhythm_notifier:
		rhythm_notifier.beats(1).connect(_on_beat_detected)

# Quand un beat est détecté
func _on_beat_detected(_count):
	_generate_cube()

# Générer un cube sur une colonne aléatoire
func _generate_cube():
	var rand_column = randi() % columns.size()
	var column = columns[rand_column]  
	
	var start_pos = column.get_node("Start").global_position
	var end_pos = column.get_node("End").global_position
	
	var new_object = MeshInstance3D.new()
	new_object.mesh = box_mesh  
	new_object.rotation_degrees.x = -39.1  
	new_object.position = start_pos
	add_child(new_object)  

	# Ajouter à la liste des cubes détectables
	detected_cubes.append(new_object)

	# Animation de déplacement avec un tween
	var tween = get_tree().create_tween()
	tween.tween_property(new_object, "position", end_pos, 1.0).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(new_object.queue_free)
	tween.tween_callback(func(): detected_cubes.erase(new_object))  # Supprime de la liste une fois disparu

# Déplacement fluide de la caméra
func _process(delta):
	if Input.is_action_just_pressed("motif1") and camera_column_index > 0:
		camera_column_index -= 1
		_align_camera_to_column()

	if Input.is_action_just_pressed("motif2") and camera_column_index < columns.size() - 1:
		camera_column_index += 1
		_align_camera_to_column()

	# Animation fluide vers la position cible
	camera.position = camera.position.lerp(target_camera_position, camera_speed * delta)

# Aligner la caméra sur la colonne actuelle
func _align_camera_to_column(instant := false):
	target_camera_position = columns[camera_column_index].position
	target_camera_position.z = 5  # Ajuster la distance de la caméra
	target_camera_position.y = -2

	if instant:
		camera.position = target_camera_position  # Déplacer directement lors du premier chargement

# Détecter les cubes uniquement quand ils passent devant la caméra
func _check_proximity(obj: Node3D):
	if obj in detected_cubes:
		var distance_to_camera = camera.position.distance_to(obj.position)

		if distance_to_camera < 15.0:
			var column = columns[camera_column_index]
			var column_position = column.position
			if abs(obj.position.x - column_position.x) < 1.0:
				print("Cube colonne ", camera_column_index + 1, " touché !")
				detected_cubes.erase(obj)  # Supprimer de la liste après détection unique


func switchPauseMusique():
	musicPlaying = !musicPlaying
	if musicPlaying:
		for i:AudioStreamPlayer in $Audio/Samba.get_children():
			musicPositionMemo = i.get_playback_position()
			i.stop()
	else:
		for i:AudioStreamPlayer in $Audio/Samba.get_children():
			i.play(musicPositionMemo)
	
		
func switchMuteMusique():
	musicPlaying = !musicPlaying
	AudioServer.set_bus_mute(1, musicPlaying)
		
func _unhandled_input(event):
	
	if event.is_action_pressed("mute_switch"):
		switchMuteMusique()
		
	if event.is_action_pressed("pause_switch"):
		switchPauseMusique()
	
