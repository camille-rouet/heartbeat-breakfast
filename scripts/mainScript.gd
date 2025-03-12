extends Node3D

var tween_list = []

var camera: Camera3D
var vitesse_defilement = 0
@export var INITIAL_OBJECT_SPEED : float = 10.0 #en m/s
@export var spawn_interval : float = 2.0
var bonus_spawn_interval = 4.5
var tutoriel_ending_interval = 6

const SPRITE_SCALE = 0.5

# hitbox
var lineZ # Z position at which the objet can collide curseur
const LINEZ_SHIFT = 0.6 # extra distance between curseur and the line of collision
const CURSEUR_WIDTH = 1.63 # width of curseur
@export var detection_range : float = 3.5 #4.5


var nCollectedNotes : float = 0 # ne pas modifier


var dificult = 0
var time_counter = 0.0
# Points de vie
var player_health := 4
const BASE_HEALTH = 4
var phase = 0
# Premier set de textures
@export var table_obs : Texture
@export var cartons : Texture
@export var meubletv : Texture
@export var sac_poubelle : Texture
@export var bouteilles : Texture

# Deuxième set de textures (après 60 secondes)
@export var chaise : Texture
@export var palette : Texture
@export var canapé : Texture
@export var valise : Texture
@export var boite : Texture
const SPRITE_HEIGHT = 2.5

# Premier set de sprites
var items_textures := {
	"Table": preload("res://assets/images/meubles/tx_table.png"),
	"Cartons": preload("res://assets/images/meubles/tx_cartons.png"),
	"MeubleTV": preload("res://assets/images/meubles/tx_meubletv.png"),
	"Sac": preload("res://assets/images/meubles/tx_sacspoubelles.png"),
	"Bouteilles": preload("res://assets/images/meubles/tx_bouteilles.png")
}

var note_textures := {
	"Note": preload("res://assets/images/note_vide.png")
	}
	
# Deuxième set de sprites
var alternate_items_textures := {
	"T-shirt": preload("res://assets/images/vêtements/tx_tshirt.png"),
	"Jeanslip": preload("res://assets/images/vêtements/tx_jeanslip.png"),
	"string_chaussettes": preload("res://assets/images/vêtements/tx_string_chaussettes.png"),
	"T-shirt_soutif": preload("res://assets/images/vêtements/tx_tshirt_soutif.png"),
}

enum PHASE_TUTORIAL {A_INIT, B_GAUCHE, C_DROITE, D_CONCLUSION, E_FINI}
var phaseTutorial = PHASE_TUTORIAL.A_INIT
var nTutorialSuccess = 0 
var nTargetTutorialSuccess = 4

var note_color := [Color.hex(0x0062B9E9),
					Color.hex(0x009e21ff),
					Color.hex(0xecbb00ff),
					Color.hex(0xff55c8ff)]

var note_collected = [false, false, false, false]
var allNotesCollected = false


var columns = []
var detected_sprites:Node 

var mainLight:DirectionalLight3D
var theWorld:WorldEnvironment

## 
const BPM = 85 # in beat per minute # 73 pour tribal # 85 ou 95 pour la samba de etienne
const BARS = 4  #beat in one measure
const BEAT_OFFSET = 0 # number of beat before the first beat of a bar of the music

const ACCEPTABLE_DELTA = 65 # acceptable error in ms

var LATENCY = 0 # in ms
var audioServerLatency

#const COMPENSATE_FRAMES = 2
#const COMPENSATE_HZ = 60.0

var beatLength # 60/ BPM, in sec
var DCLength # beatLength / 4, in sec


var musiqueCible:AudioStreamPlayer
var musiqueTimeStart = -1
var useEngineTimeInsteadOfPlaybackPosition:bool = false
var currentBeat = 0
var currentDC = 0 # double croche

var currentPatternDelta = [null, null, null, null] # chaque entrée definit le temps (en ms) entre l'input et la double-croche la plus proche, si pas d'input pour une double croche : null
var currentPatternDeltaCompleted = false # Si true, currentPatternDelta est complet

var currentPatternInput = [0,0,0,0] #conversion de currentPatternDelta en valeur 0, 1 ou "R"
var lastPatternInput = null # enregistrement du pattern input precedent

# gestion du curseur
var curseur
var curseurBasePosition
var curseurSpeed = 0 # in m / sec
var curseurAccel = 0 # in m / sec / sec
const BRAKE = 0.995
const MAX_SPEED = 10 # in m / sec
const ADDED_SPEED = 2 # in m / sec

var tetePerso:Node3D

var audioGainCuica:AudioEffectAmplify
var audioGainGuitare1:AudioEffectAmplify
var audioGainGuitare2:AudioEffectAmplify
var audioGainPiano:AudioEffectAmplify
var audioGainSynth:AudioEffectAmplify
var audioGainBasse:AudioEffectAmplify
var audioGainPercu:AudioEffectAmplify


var debugMsg:String
var showDebugMenu:bool = false

# Motif rythmiques jouables
const RHYTHMIC_PATTERN = {
	"O": [0, 0, 0, 0],
	"A": [1, 0, 0, 0],
	"B": [1, 0, 0, 1],
	"C": [1, 1, 1, 1],
	"D": [1, 1, 1, 0]
} # Les 4 entrées des tableaux rythmiques sont les subdivision d'un temps avec 4 doubles croches


# musique de fond
var partieEnCours = false
var musicPlaying = false
var musicMuted = false
var musicPositionMemo = 0
var partieTimeStart = -1

# erreur lorsque l'on a un pb de rhytme
signal rhythmError
signal rhythmOK
signal inputDCDone
var meanDeltaDC = 0 # ecart moyen entre input et DC
var nInput = 0 #nombre d'input cumulé

var sol:MeshInstance3D

var isRunningOnWeb:bool = false

func couleurnote ():
	var  note = $GUI/CanvasLayerNotes/MarginContainer/HBoxContainer.get_children()
	note[0].modulate = Color(255,255,255,1)
	note[1].modulate = Color(255,255,255,1)
	note[2].modulate = Color(255,255,255,1)
	note[3].modulate = Color(255,255,255,1)

#UI Objects
var leftPattern:Control
var centralCurrentPattern:Control
var rightPattern:Control



# Timer pour changer les sprites après 60s
var phase_timer_0: Timer
var phase_timer_1: Timer
var last_phase_timer : Timer
var spawn_timer :Timer
var bonus_spawn_timer :Timer
var tutoriel_ending_timer :Timer

func _ready():
	detected_sprites = $Items
	isRunningOnWeb = OS.has_feature("web")
	
	if isRunningOnWeb:
		print("Running on web")
		useEngineTimeInsteadOfPlaybackPosition = true
	else:
		print("Running on " + OS.get_name())
	
	# Timers
	phase_timer_0 = Timer.new()
	phase_timer_0.wait_time = 20
	phase_timer_0.one_shot = true
	phase_timer_0.autostart = false
	phase_timer_0.timeout.connect(increment_phase)
	add_child(phase_timer_0)
	
	phase_timer_1 = Timer.new()
	phase_timer_1.wait_time = 40
	phase_timer_1.one_shot = true
	phase_timer_1.autostart = false
	phase_timer_1.timeout.connect(increment_phase)
	add_child(phase_timer_1)
	
	# 
	last_phase_timer = Timer.new()
	last_phase_timer.wait_time = 60
	last_phase_timer.one_shot = true
	last_phase_timer.autostart = false
	last_phase_timer.timeout.connect(increment_phase)
	add_child(last_phase_timer)
	
	# Timer pour la génération des sprites (toutes les 2s)
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.autostart = false
	spawn_timer.timeout.connect(_generate_sprite)
	add_child(spawn_timer)
	
	
	# Timer pour la génération des notes (toutes les 2s)
	bonus_spawn_timer = Timer.new()
	bonus_spawn_timer.wait_time = bonus_spawn_interval
	bonus_spawn_timer.autostart = false
	bonus_spawn_timer.timeout.connect(_generate_sprite.bind(true))
	add_child(bonus_spawn_timer)
	
	tutoriel_ending_timer = Timer.new()
	tutoriel_ending_timer.wait_time = tutoriel_ending_interval
	tutoriel_ending_timer.one_shot = true
	tutoriel_ending_timer.autostart = false
	tutoriel_ending_timer.timeout.connect(_tuto_fin_phase_D)
	add_child(tutoriel_ending_timer)
	
	
	leftPattern = $GUI/CanvasLayerPattern/leftPattern/HBoxContainer
	centralCurrentPattern = $GUI/CanvasLayerPattern/currentPattern/HBoxContainer
	rightPattern = $GUI/CanvasLayerPattern/rightPattern/HBoxContainer
	mainLight = $DirectionalLight3D
	theWorld = $WorldEnvironment
	sol = $Nodes3D/Sol
	rhythmError.connect(_on_rhythm_error)
	rhythmOK.connect(_on_rhythm_ok)
	inputDCDone.connect(_on_inputDCDone)
	
	
	audioGainCuica = AudioServer.get_bus_effect(4, 0)
	audioGainGuitare1 = AudioServer.get_bus_effect(5, 0)
	audioGainPiano = AudioServer.get_bus_effect(6, 0)
	audioGainSynth = AudioServer.get_bus_effect(7, 0)
	audioGainGuitare2 = AudioServer.get_bus_effect(8, 0)
	audioGainBasse = AudioServer.get_bus_effect(9, 0)
	audioGainPercu = AudioServer.get_bus_effect(10, 0)
	
	audioServerLatency = AudioServer.get_output_latency()
	
	
	
	
	# calcul de la durée du beat et de la DC
	beatLength = 1.0 / float(BPM) * 60.0
	DCLength = beatLength / 4.0
	
	print("beat length (ms): " + str(roundi(beatLength * 1000)))
	print("DC length (ms): " + str(roundi(DCLength * 1000)))
	print("")
	match BPM:
		73:
			musiqueCible = $"Audio/Electro-tribal-beat-179094"
			musiqueCible.play()
			musiqueTimeStart = Time.get_ticks_msec() * 0.001
			musicPlaying = true
		85:
			musiqueCible = $Audio/Samba85/Percussions
		95:
			musiqueCible = $Audio/Samba95/Percussions
	
	curseur = $Nodes3D/Perso
	curseurBasePosition = curseur.position
	lineZ = curseur.position.z
	tetePerso = $Nodes3D/Perso/AnimatedSpritePersoTete
	
	# Récupérer la caméra et les colonnes
	camera = $Camera3D  
	columns.append($Nodes3D/MeshInstance3D)  
	columns.append($Nodes3D/MeshInstance3D2)  
	columns.append($Nodes3D/MeshInstance3D3)  
	columns.append($Nodes3D/MeshInstance3D4)  
	
	showStartMenu()
	
	couleurnote()
	
	
	# Affichage du motif de gauche
	updateMotif(leftPattern, RHYTHMIC_PATTERN.A)
	# Affichage du motif de droite
	updateMotif(rightPattern, RHYTHMIC_PATTERN.B)

func showStartMenu():
	$Menus/StartMenu.show()
	$Menus/IntroMenu.hide()
	$Menus/EndMenu.hide()
	$GUI/SkipButtonMarginContainer.hide()
	$GUI/TimeMarginContainer.hide()
	$GUI/StartMenuButtonMarginContainer.hide()
	$GUI/CanvasLayerPattern.hide()
	$GUI/CanvasLayerCoeur.hide()
	$GUI/CanvasLayerNotes.hide()
	
	spawn_timer.stop()
	bonus_spawn_timer.stop()
	phase_timer_0.stop()
	phase_timer_1.stop()
	last_phase_timer.stop()
	tutoriel_ending_timer.stop()
	partieEnCours = false
	stopMusique()
	removeAllItems(detected_sprites)

func showMenuIntro():
	$Menus/StartMenu.hide()
	$Menus/EndMenu.hide()
	$Menus/IntroMenu.show()
	$GUI/SkipButtonMarginContainer.hide()
	$GUI/TimeMarginContainer.hide()
	$GUI/StartMenuButtonMarginContainer.show()
	$GUI/CanvasLayerPattern.hide()
	$GUI/CanvasLayerCoeur.hide()
	$GUI/CanvasLayerNotes.hide()
	
	removeAllItems(detected_sprites)


func increment_phase():
	phase += 1
	print("Phase is now: ", phase)
	
	match phase:
		0:
			pass
		1:
			pass
		2:
			pass
		3:
			_set_win()
	


func _set_win():
	if player_health > 0 :
		print("bravo vous êtes arrivée a la fin ")
		_game_over(true)



# Changer la liste des sprites après 60 secondes

# Générer un sprite
func _generate_sprite(note:bool=false):
	if columns.size() == 0:
		print("⚠️ Erreur: 'columns' est vide, impossible de générer un sprite.")
		return

	var rand_column = randi() % columns.size()
	var column = columns[rand_column]  
	var start_pos = column.get_node("Start").global_position
	
	start_pos.y += SPRITE_HEIGHT
	
	
	# Initialisation de sprite_list
	var sprite_list = {} 
	
	if phase == 0:
		sprite_list = items_textures
	elif phase == 1:
		sprite_list = items_textures.duplicate(true)
		sprite_list.merge(alternate_items_textures)
	elif phase == 2:
		sprite_list = alternate_items_textures

	var keys = sprite_list.keys()
	var rand_key = keys[randi() % keys.size()]
	
	#var rand_key = keys[5]
	var rand_texture = sprite_list[rand_key]
	
	if note:
		rand_texture = note_textures["Note"]
		rand_key = "Note"
	

	# Vérifier si la texture est bien chargée
	if rand_texture == null:
		print("⚠️ Erreur: la texture de ", rand_key, " est NULL !")
		return
	
	#print("✅ Génération de: ", rand_key, " avec la texture: ", rand_texture.resource_path)

	var spriteColorModulate = Color.WHITE
	if note:
		if allNotesCollected:
			spriteColorModulate = Color.from_hsv(randf(), 0.7 + 0.3 * randf(), 0.9 + 0.1 * randf())
		else:
			var i_match = 0
			var arange = range(note_color.size())
			arange.shuffle()
			for i in arange:
				if note_collected[i] == false:
					i_match = i
					break
			spriteColorModulate = note_color[i_match]
			
		start_pos.y = start_pos.y + 0.3
	
	# Appliquer la texture
	var new_sprite:Sprite3D = Sprite3D.new()
	new_sprite.texture = rand_texture
	new_sprite.position = start_pos
	new_sprite.set_meta("name", rand_key)
	new_sprite.scale = Vector3.ONE * SPRITE_SCALE  # Ajuste la taille à 50%
	detected_sprites.add_child(new_sprite)
	
	new_sprite.shaded = true
	new_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	new_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	
		

	## Calculer la distance entre start_pos et end_pos
	#var distance = start_pos.distance_to(end_pos)
#
	## Calculer le temps nécessaire pour parcourir la distance à la vitesse donnée
	#var duration = distance / vitesse_defilement
	
	## Animation de déplacement
	#var tween = get_tree().create_tween()
	#tween.tween_property(new_sprite, "position", end_pos, duration).set_trans(Tween.TRANS_LINEAR)
	#tween.tween_callback(new_sprite.queue_free)
	#tween.tween_callback(func(): detected_sprites.erase(new_sprite))

	# Animation de transparence
	new_sprite.modulate = Color.TRANSPARENT
	var tween2 = get_tree().create_tween()
	tween2.tween_property(new_sprite, "modulate", spriteColorModulate, 1).set_trans(Tween.TRANS_LINEAR)



func _physics_process(delta: float) -> void:
	
	moveCursor(delta)
	
	# move sprites
	for sprite:Sprite3D in detected_sprites.get_children():
		sprite.position.z = sprite.position.z + delta * vitesse_defilement
	
	
	# Vérifier la proximité des sprites avec le joueur
	_check_proximity()
	
	

# Déplacement fluide de la caméra
func _process(delta):
	
	var ms = roundi(musiqueCible.get_playback_position() * 100) % 100
	var ms_str = str(ms)
	if ms < 10 :
		ms_str = "0" + ms_str
	var timepartie = Time.get_ticks_msec() - partieTimeStart 
	$GUI/TimeMarginContainer/MarginContainer/TimeLabel.text = Time.get_time_string_from_unix_time(timepartie*0.001).substr(3) + ":" + ms_str
	
	if showDebugMenu :
		$Menus/DebugMenu.show()
		
		debugMsg = "Time :" +  str((Time.get_ticks_msec())) + " FPS: " + str(Engine.get_frames_per_second()) + " delta: " + str(roundi(delta*1e3))  +\
		"\nPlayback pos: " + str(roundi(musiqueCible.get_playback_position()*1000)) +\
		"\ncurrentBeat and currentDC: " + str(currentBeat) + " - " + str(currentDC) +\
		" (" + str((currentBeat) % BARS + 1) + "/" + str(BARS) + " - " + str((currentDC) % 4 + 1) + "/4)" +\
		"\nmeanDeltaDC: " + str(roundi(meanDeltaDC*1000)) + " ms (on " + str(nInput) + " inputs)" +\
		"\ncurrentPatternDelta: " + str(currentPatternDelta) +\
		"\ncurrentPatternInput: " + str(currentPatternInput) +\
		"\ncurrentPatternDeltaCompleted: " + str(currentPatternDeltaCompleted)
	else:
		$Menus/DebugMenu.hide()
	
	
	if musicPlaying:
		
		if partieEnCours:
			time_counter += delta  # Incrémente le compteur de temps avec le delta (temps écoulé)
			if time_counter >= 10.0:  # Vérifie si 10 secondes se sont écoulées
				time_counter = 0.0
				
				dificult +=1
				print("\nNiveau de difficulté ", dificult)
				if dificult <= 10 :
					vitesse_defilement *= 1.1 # augment la vitesse des sprites de 10%
					spawn_interval *=0.9 # augmentation du taux d'apparition des sprites de 10%
					print("Vitesse augmentée de 10%")
				elif dificult <= 15:
					vitesse_defilement *= 1.4 # augment la vitesse des sprites de 10%
					spawn_interval *=0.6 # augmentation du taux d'apparition des sprites de 10%
					print("Vitesse augmentée de 40%")
				else :
					print("Vitesse max atteinte")
				
				print("Vitesse des sprites : ", round(vitesse_defilement * 100) * 0.01)
				print("Taux d'apparition des sprites : ", round(spawn_interval * 100) * 0.01)
		
		var time = musiqueCible.get_playback_position()  - audioServerLatency - LATENCY * 0.001
		if useEngineTimeInsteadOfPlaybackPosition:
			time = ((Time.get_ticks_msec()*0.001) - audioServerLatency - LATENCY * 0.001)  - musiqueTimeStart
		
		if time < DCLength:
			resetRhythm()
		
		var beat = int(time * BPM / 60.0)
		var beatInMeasure = (beat - BEAT_OFFSET) % BARS + 1
		if(beat > currentBeat):
			currentBeat = beat
		var DC = int(time / DCLength)
		var DCInBeat = (DC) % 4 + 1
		
		match phaseTutorial:
			PHASE_TUTORIAL.A_INIT:
				$Nodes3D/Perso/Nuage1/AnimatedSpriteButton.play()
			PHASE_TUTORIAL.B_GAUCHE:
				$Nodes3D/Perso/Nuage1/AnimatedSpriteButton.stop()
				if  DCInBeat == 1 && (time / DCLength - floor(time / DCLength)) < 0.15 || DCInBeat == 4 && (time / DCLength - floor(time / DCLength)) > 0.9:
					$Nodes3D/Perso/Nuage1/AnimatedSpriteButton.frame = 0
				else:
					$Nodes3D/Perso/Nuage1/AnimatedSpriteButton.frame = 1
			PHASE_TUTORIAL.C_DROITE:
				$Nodes3D/Perso/Nuage1/AnimatedSpriteButton.stop()
				if  DCInBeat == 1 && (time / DCLength - floor(time / DCLength)) < 0.15 || DCInBeat == 4 && (time / DCLength - floor(time / DCLength)) > 0.9:
					$Nodes3D/Perso/Nuage1/AnimatedSpriteButton.frame = 0
				elif  DCInBeat == 4 && (time / DCLength - floor(time / DCLength)) < 0.15 || DCInBeat == 3 && (time / DCLength - floor(time / DCLength)) > 0.9:
					$Nodes3D/Perso/Nuage1/AnimatedSpriteButton.frame = 0
				else:
					$Nodes3D/Perso/Nuage1/AnimatedSpriteButton.frame = 1
			
		if(DC > currentDC):
			currentDC = DC
			#var text = str("DC: ", DCInBeat, "/", "4")
			#print(text)
			currentPatternInput = patternDeltaToPatternInput(currentPatternDelta)
			
			# update Canvas DC texture
			updateMotif(centralCurrentPattern, currentPatternInput, DCInBeat)
						
		# définition de la fenetre de tir pour observer le motif donné en input
		if DCInBeat == 4:
			var DC4_time = currentDC * DCLength
			var DC5_time = (currentDC+1) * DCLength
			var debFenetre_time = DC4_time + ACCEPTABLE_DELTA * 0.001
			var finFenetre_time = DC5_time - ACCEPTABLE_DELTA * 0.001
			
			
			
			# quand on passe la fin de possibilité de input la 4eme DC
			if !currentPatternDeltaCompleted:
				if time >= debFenetre_time && time < finFenetre_time:
					currentPatternDeltaCompleted = true
					currentPatternInput = patternDeltaToPatternInput(currentPatternDelta)
					lastPatternInput = currentPatternInput # enregistrement du pattern
					interpretPattern(currentPatternInput)
		
			# quand on arrive à la possibilité de input la 1ere DC 
			if currentPatternDeltaCompleted:
				if time >= finFenetre_time:
					currentPatternDelta = [null, null, null, null]
					currentPatternInput = patternDeltaToPatternInput(currentPatternDelta)
					updateMotif(centralCurrentPattern, currentPatternInput)
					currentPatternDeltaCompleted = false
	
	# defilement du sol
	var material:StandardMaterial3D = sol.get_surface_override_material(0)
	# un offset de 1 fait bouger le motif d'une fois
	var planeMesh:PlaneMesh = sol.mesh
	var tailleMotifBase = planeMesh.size.y / material.uv1_scale.y
	var decalageFrame = delta * vitesse_defilement
	material.uv1_offset.y = material.uv1_offset.y - decalageFrame / tailleMotifBase
	
	$Menus/DebugMenu/MarginContainer/Label.text = debugMsg

## Aligner la caméra sur la colonne actuelle
#func _align_camera_to_column(instant := false):
	#target_camera_position = columns[camera_column_index].position
	#target_camera_position.z = 30
	#target_camera_position.y = 4
	#target_camera_position.x = -3
	#if instant:
		#camera.position = target_camera_position

# Vérifier la proximité des sprites avec le joueur
func _check_proximity():
	for sprite:Sprite3D in detected_sprites.get_children():
		
		if sprite.position.z > lineZ - LINEZ_SHIFT:
			var objSizeX = sprite.get_item_rect().size.x * SPRITE_SCALE * sprite.pixel_size
			var objMinX = sprite.position.x - 0.5 * objSizeX
			var objMaxX = sprite.position.x + 0.5 * objSizeX
			var curseurMinxX = curseur.position.x - 0.5 * CURSEUR_WIDTH
			var curseurMaxX = curseur.position.x + 0.5 * CURSEUR_WIDTH
			if objMinX < curseurMinxX && curseurMinxX < objMaxX || objMinX < curseurMaxX && curseurMaxX < objMaxX :
				# collision !
				var sprite_name = sprite.get_meta("name")

				# Vérifier si l'objet est dangereux
				if sprite_name in items_textures.keys() || sprite_name in alternate_items_textures.keys():
					_take_damage()
				if sprite_name in note_textures.keys():
					_bonus(sprite)
				
				detected_sprites.remove_child(sprite)
				sprite.queue_free()
		
		if sprite.position.z > lineZ + 2 * LINEZ_SHIFT :
			# Supprimer après dépassement
			detected_sprites.remove_child(sprite)
			sprite.queue_free()
				

func resetBonus():
	nCollectedNotes = 0
	allNotesCollected = false
	note_collected = [false, false, false, false]
	var notem = $GUI/CanvasLayerNotes/MarginContainer/HBoxContainer.get_children()
	for note:TextureRect in notem:
		note.modulate = Color.WHITE

func _bonus(touchedSprite:Sprite3D):
	nCollectedNotes += 1
	$"Audio/Bruitages/Bell/133990GmajorrrTriangle".pitch_scale = 0.6 + 0.3 * randf()
	$"Audio/Bruitages/Bell/133990GmajorrrTriangle".play()
	var notem = $GUI/CanvasLayerNotes/MarginContainer/HBoxContainer.get_children()
	var timeFadeIn = 1 # in sec
	
	# Find the value of the touched Note
	var i_match = 0
	var noteTargetColor:Color
	for i in range(note_color.size()):
		noteTargetColor = note_color[i]
		if touchedSprite.modulate == noteTargetColor:
			i_match = i
			break
	
	
	
	# check if you dont have this note yet
	if note_collected[i_match] == false:
		note_collected[i_match] = true
		
		# update allNotesCollected
		allNotesCollected = true
		for abool in note_collected:
			if abool == false:
				allNotesCollected = false
		
		#  modify the GUI note
		notem[i_match].modulate = note_color[i_match]
		
		# modify the music
		var audioGain = audioGainSynth
		match i_match:
			0:
				audioGain = audioGainSynth
			1:
				audioGain = audioGainPiano
			2:
				audioGain = audioGainGuitare1
			3:
				audioGain = audioGainGuitare2
		
		var tween = musiqueCible.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(audioGain, "volume_db", 0, timeFadeIn)
		tween.set_meta("audio_tween", true)
		tween_list.append(tween)
		
		print("nombre de notes obtenues : ", nCollectedNotes)
	
# Gestion des points de vie
func _take_damage():
	$"Audio/Bruitages/ExplRealExplosion1(id1807)Ls".play()
	player_health -= 1
	#print("PV restants : ", player_health)
	
	updateCoeur()
	
	if player_health <= 0:
		_game_over(false)

func updateCoeur():
	var coeurs = $GUI/CanvasLayerCoeur/MarginContainer/HBoxContainer.get_children()
	
	for i in range(BASE_HEALTH):
		if (i+1) <= player_health:
			coeurs[i].show()
		else:
			coeurs[i].hide()

# Fin de partie
func _game_over(gagne:bool):
	audioGainSynth.volume_db = -9
	$"Audio/Samba85/Synth#1".play()
	var score = nCollectedNotes * 10 + player_health * 5
	if gagne:
		score += 100
		$Menus/EndMenu/FinPerdu.hide()
		$Menus/EndMenu/FinGagne.show()
	else:
		$Menus/EndMenu/FinPerdu.show()
		$Menus/EndMenu/FinGagne.hide()
	
	
	$GUI/SkipButtonMarginContainer.hide()
	$GUI/TimeMarginContainer.hide()
	$GUI/StartMenuButtonMarginContainer.show()
	$GUI/CanvasLayerPattern.hide()
	$GUI/CanvasLayerCoeur.show()
	$GUI/CanvasLayerNotes.show()
	
	$GUI/CanvasLayerNotes.offset = Vector2(-400,0)
	$GUI/CanvasLayerNotes.layer = 128
	$Menus/EndMenu/RichTextLabel.text = "Score : " + str(score)
	spawn_timer.stop()
	bonus_spawn_timer.stop()
	phase_timer_0.stop()
	phase_timer_1.stop()
	last_phase_timer.stop()
	tutoriel_ending_timer.stop()
	partieEnCours = false
	
	removeAllItems(detected_sprites)
	
	stopMusique()
	partieEnCours = false
	$Menus/EndMenu.show()


func moveCursor(delta):
	#  update cursor horizontal position and speed
	curseur.position.x = curseur.position.x + delta * curseurSpeed
	curseurSpeed = curseurSpeed + delta * curseurAccel
	
	var replacementShift = 0.01 # (0 to 1) proportion of the shift when encountering wall 
	var maxX = 9.5
	var minX = 0
	if curseur.position.x > maxX:
		curseur.position.x = maxX * (1 - replacementShift)
		curseurSpeed = - curseurSpeed*0.2
		curseurAccel = 0
	if curseur.position.x < minX:
		curseur.position.x = minX * (1 + replacementShift)
		curseurSpeed = - curseurSpeed*0.2
		curseurAccel = 0
	
	curseurSpeed = curseurSpeed * BRAKE
	curseurSpeed = min(curseurSpeed, MAX_SPEED)
	curseurSpeed = max(curseurSpeed, -MAX_SPEED)

# # # # # # # # # METHODES RYTHME
# conversion d'un tableau de delta de DC en tableau de motif input
func patternDeltaToPatternInput(patternDelta):
	var motifInput = [0,0,0,0]
	for  i in range(4):
		var deltaDC = patternDelta[i]
		if deltaDC != null:
			if abs(deltaDC) > ACCEPTABLE_DELTA:
				motifInput[i] = "R"
			else:
				motifInput[i] = 1
	return motifInput

# Executé lorsqu'un motif rythmique a été détecté
func interpretPattern(patternInput):
	#print(str(currentPatternDelta))
	#print(str(patternInput))
	var matchedPattern = findPattern(patternInput)
	#print("Your pattern is " + str(matchedPattern) + "  ..Mean delta = " + str(roundi(meanDeltaDC * 1000)) + " ms")
	#print("")
	
	#match matchedPattern:
		#"A":
			#curseurSpeed -= ADDED_SPEED
		#"B":
			#curseurSpeed += ADDED_SPEED
		#null:
			#rhythmError.emit()
			
	
# find if patternInput match with a rhymitc pattern and returns it
# if no match, return null
func findPattern(patternInput):
	for akey in RHYTHMIC_PATTERN.keys():
		if checkPatternMatch(patternInput, RHYTHMIC_PATTERN.get(akey)):
			return akey
	return null



#check si le pattern input match avec le pattern donné
func checkPatternMatch(patternInput, aPattern):
	var isSimilar = true
	for i in range(4):
		var DCresult = patternInput[i]
		if typeof( DCresult ) == typeof("R"):
			return false
		else :
			if DCresult != aPattern[i]:
				isSimilar = false
	return isSimilar

# return the error in sec between time and the close beat
func getDeltaBeat(time):
	var lastBeat = int(time / beatLength)
	var lastBeatTime = lastBeat * beatLength
	
	var retardToucheBeat = time - lastBeatTime
	var deltaToucheBeat = 0
	if retardToucheBeat < beatLength * 0.5:
		# le beat de référence est le précédent
		deltaToucheBeat = retardToucheBeat
	else:
		# le beat de référence est le suivant
		deltaToucheBeat = time - (lastBeatTime + beatLength)
	return deltaToucheBeat


func _on_rhythm_error() -> void:
	#$Audio/Bruitages/BlocBad.play()
	var aTween = centralCurrentPattern.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_parallel(false)
	aTween.tween_property(centralCurrentPattern, "modulate", Color.TOMATO, DCLength * 0.5)
	aTween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	aTween.tween_property(centralCurrentPattern, "modulate", Color.WHITE, DCLength * 0.5)

func _on_rhythm_ok(lastDCInput):
	var aTween = centralCurrentPattern.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_parallel(false)
	aTween.tween_property(centralCurrentPattern, "modulate", Color.FOREST_GREEN, DCLength * 0.5)
	aTween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	aTween.tween_property(centralCurrentPattern, "modulate", Color.WHITE, DCLength * 0.5)
	
	var aControl:Control
	var aControlShouldFlash = false
	var controlToRight = true
	match lastDCInput:
		0:
			aControl = leftPattern
			aControlShouldFlash = true
			controlToRight = false
		1:
			aControl = rightPattern
			aControlShouldFlash = true
			controlToRight = true
			
	if aControlShouldFlash:
		var aTween2 = aControl.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_parallel(false)
		aTween2.tween_property(aControl, "modulate", Color.FOREST_GREEN, DCLength * 0.5)
		aTween2.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		aTween2.tween_property(aControl, "modulate", Color.WHITE, DCLength * 0.5)
		
		var turnHeadAngle = 25
		if controlToRight:
			turnHeadAngle = -turnHeadAngle
		else:
			turnHeadAngle = turnHeadAngle
		var aTween3 = tetePerso.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_parallel(false)
		aTween3.tween_property(tetePerso, "rotation_degrees:z", turnHeadAngle, DCLength * 0.5)
		aTween3.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		aTween3.tween_property(tetePerso, "rotation_degrees:z", 0, DCLength * 0.5)
		


func _on_inputDCDone():
	var jumpHeight = 0.1
	var basePosition = curseur.position
	var basePositionOnSoil = Vector3(basePosition.x, curseurBasePosition.y, basePosition.z) 
	var aTween = curseur.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_parallel(false)
	aTween.tween_property(curseur, "position:y", basePositionOnSoil.y + jumpHeight, DCLength * 0.3)
	aTween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	aTween.tween_property(curseur, "position:y", basePositionOnSoil.y, DCLength * 0.3)


func resetRhythm():
	currentPatternDeltaCompleted = false
	currentBeat = 0
	currentDC = 0
	
# # # # # # METHODES AUDIO

func stopMusique():
	if musicPlaying:
		for i:AudioStreamPlayer in musiqueCible.get_parent().get_children():
			musicPositionMemo = i.get_playback_position()
			i.stop()
	musicPlaying = false

func lancerMusique(nobass:bool = false):
	musiqueTimeStart = Time.get_ticks_msec() * 0.001
	
	for i:AudioStreamPlayer in musiqueCible.get_parent().get_children():
		i.play()
	
	
	for twe:Tween in tween_list.duplicate():
		if twe.has_meta("audio_tween"):
			tween_list.erase(twe)
			twe.kill()
	
	audioGainPercu.volume_db = 0
	if nobass:
		audioGainBasse.volume_db = -80
	else:
		audioGainBasse.volume_db = 0
		
	audioGainCuica.volume_db = -80
	audioGainGuitare1.volume_db = -80
	audioGainGuitare2.volume_db = -80
	audioGainPiano.volume_db = -80
	audioGainSynth.volume_db = -80
	
	resetRhythm()
	musicPlaying = true



func switchMuteMusique():
	musicMuted = !musicMuted
	AudioServer.set_bus_mute(1, musicMuted)
		
		
# Gestion des inputs
func _unhandled_input(event):
	
	if event.is_action_released("latency_update"):
		print("\nLatency update")
		LATENCY = LATENCY + meanDeltaDC
		meanDeltaDC = 0
		nInput = 0
		
		
	if event.is_action_pressed("ToucheH"):
		showDebugMenu = !showDebugMenu
	
	if event.is_action_released("ToucheA") && !partieEnCours :
		match phaseTutorial:
			PHASE_TUTORIAL.A_INIT:
				_tuto_fin_phase_A()
		
	if event.is_action_pressed("ToucheA") || event.is_action_pressed("ToucheT") || event.is_action_pressed("inputManette"):
		nInput = nInput + 1
		
		
		# petit saut du perso
		inputDCDone.emit()
		
		var time = musiqueCible.get_playback_position() - audioServerLatency - LATENCY * 0.001
		
		if useEngineTimeInsteadOfPlaybackPosition:
			time = ((Time.get_ticks_msec()*0.001) - audioServerLatency - LATENCY * 0.001)  - musiqueTimeStart
			
		var deltaToucheBeat = getDeltaBeat(time)
		#print("Ecart au beat (ms) " + str(roundi(deltaToucheBeat * 1000) ))
		
		# reconnaitre la double croche en cours
		var lastDC = int(time / DCLength)
		var lastDCTime = lastDC * DCLength
		
		
		# evalue le delta entre input et DC
		var retardToucheDC = time - lastDCTime
		var deltaToucheDC
		var closerDC
		if retardToucheDC < DCLength * 0.5:
			# la DC de référence est la précédente
			deltaToucheDC = retardToucheDC
			closerDC = lastDC 
		else: 
			# la DC de référence est la suivante
			deltaToucheDC = time - (lastDCTime + DCLength)
			closerDC = lastDC + 1
			
		var currentDCInBeat = (lastDC) % 4 + 1
		var closerDCInBeat = (closerDC) % 4 + 1
		#print("Ecart à la DC " + str(closerDCInBeat) + " (ms) " + str(roundi(deltaToucheDC * 1000)) )
		
		#envoie une erreur en cas de defaillance rhytmique
		var DCtempoGood = true
		if abs(deltaToucheDC) > ACCEPTABLE_DELTA * 0.001:
			DCtempoGood = false
		
		# update the rhytmic pattern delta
		currentPatternDelta[closerDCInBeat - 1] = roundi(deltaToucheDC * 1000)
		currentPatternInput = patternDeltaToPatternInput(currentPatternDelta)
		
		# update the mean error on DC
		meanDeltaDC = (meanDeltaDC * (nInput-1) + deltaToucheDC) / nInput
		
		
		# deplacement du personnage au premier beat
		if closerDCInBeat == 1 && lastPatternInput != null:
			var firstDCinput = currentPatternInput[0]
			match firstDCinput:
				0:
					pass
				1:
					var lastDCInput = lastPatternInput[3]
					rhythmOK.emit(lastDCInput)
					match lastDCInput:
							0:
								if curseurSpeed > 0:
									curseurSpeed = -ADDED_SPEED
								else:
									curseurSpeed += -ADDED_SPEED
							1:
								if curseurSpeed < 0:
									curseurSpeed = ADDED_SPEED
								else:
									curseurSpeed += ADDED_SPEED
					if phaseTutorial == PHASE_TUTORIAL.A_INIT:
						curseurSpeed = 0
				"R":
					pass
				 
		
		# gestion du tutorial
		var lastDC4input = 0
		if lastPatternInput != null :
			lastDC4input = lastPatternInput[3]
		match phaseTutorial:
			PHASE_TUTORIAL.A_INIT, PHASE_TUTORIAL.D_CONCLUSION, PHASE_TUTORIAL.E_FINI:
				DCtempoGood = true
			
			PHASE_TUTORIAL.B_GAUCHE:
				
				if DCtempoGood && closerDCInBeat == 1 && typeof(lastDC4input) != TYPE_STRING && lastDC4input == 0:
					nTutorialSuccess += 1
					updateTutorialSuccessLabel()
					if nTutorialSuccess < nTargetTutorialSuccess:
						$"Audio/Bruitages/Bell/517609SamuelgremaudClaves".pitch_scale=0.85
						$"Audio/Bruitages/Bell/517609SamuelgremaudClaves".play()
					else:
						$"Audio/Bruitages/Bell/517609SamuelgremaudClaves".pitch_scale += 0.4
						$"Audio/Bruitages/Bell/517609SamuelgremaudClaves".play()
						_tuto_fin_phase_B()
				else:
					DCtempoGood = false
					nTutorialSuccess = 0
					updateTutorialSuccessLabel()
					
			PHASE_TUTORIAL.C_DROITE:
				if DCtempoGood && closerDCInBeat == 1 && typeof(lastDC4input) != TYPE_STRING && lastDC4input == 1 :
					nTutorialSuccess += 1
					updateTutorialSuccessLabel()
					if nTutorialSuccess < nTargetTutorialSuccess:
						$"Audio/Bruitages/Bell/517609SamuelgremaudClaves".pitch_scale=0.85
						$"Audio/Bruitages/Bell/517609SamuelgremaudClaves".play()
					else:
						$"Audio/Bruitages/Bell/517609SamuelgremaudClaves".pitch_scale += 0.4
						$"Audio/Bruitages/Bell/517609SamuelgremaudClaves".play()
						_tuto_fin_phase_C()
				elif DCtempoGood && closerDCInBeat == 4 :
					pass
				else:
					DCtempoGood = false
					nTutorialSuccess = 0
					updateTutorialSuccessLabel()
		
		
		
		
		
		#joue un son
		if DCtempoGood:
			$Audio/Bruitages/BlocGood.play()
		else:
			$Audio/Bruitages/BlocBad.play()
			rhythmError.emit()
	
	
	if event.is_action_pressed("mute_switch"):
		switchMuteMusique()

	

#update a canvasPattern, given a pattern input and a DCinBeat
func updateMotif(canvaPattern, patternInput, DCInBeat = -1):
	var index = 0
	for textRect:TextureRect in canvaPattern.get_children():
		match patternInput[index]:
			0:
				textRect.texture = get_node_and_resource("GUI/CanvasLayerPattern:textureDCvide")[1]
				if (index+1) == DCInBeat:
					textRect.texture = get_node_and_resource("GUI/CanvasLayerPattern:textureDCpassage")[1]
			1:
				textRect.texture = get_node_and_resource("GUI/CanvasLayerPattern:textureDCreussite")[1]
			"R":
				textRect.texture = get_node_and_resource("GUI/CanvasLayerPattern:textureDCrate")[1]
		index = index + 1


func lancementTutorial():
	removeAllItems(detected_sprites)
	phaseTutorial = PHASE_TUTORIAL.A_INIT
	$Menus/StartMenu.hide()
	$Menus/IntroMenu.hide()
	$Menus/EndMenu.hide()
	$GUI/TimeMarginContainer.hide()
	$GUI/SkipButtonMarginContainer.show()
	$GUI/StartMenuButtonMarginContainer.show()
	$GUI/CanvasLayerPattern.show()
	$GUI/CanvasLayerCoeur.show()
	$GUI/CanvasLayerNotes.show()
	$Nodes3D/Perso/Nuage1/Label3D.show()
	$Nodes3D/Perso/Nuage1.modulate = Color.WHITE
	
	$GUI/CanvasLayerPattern/currentPattern.hide()
	$GUI/CanvasLayerPattern/leftPattern.hide()
	$GUI/CanvasLayerPattern/rightPattern.hide()
	
	musicPlaying = false
	musicMuted = false
	phase = 0
	dificult = 0
	vitesse_defilement = 0
	spawn_interval = 2.0
	curseurSpeed = 0
	curseurAccel = 0
	curseur.position = curseurBasePosition
	lancerMusique(true)
	player_health = BASE_HEALTH
	updateTutorialSuccessLabel()
	updateCoeur()
	resetBonus()
	resetRhythm()
	$GUI/CanvasLayerNotes.offset = Vector2(400,-550)
	$GUI/CanvasLayerNotes.layer = 2
	$Nodes3D/Perso/Nuage1.show()
	$Nodes3D/Perso/Nuage1/AnimatedSpriteButton.hide()
	
	
	var timer = Timer.new()
	timer.name = "timer_bouton"
	timer.wait_time = 2
	timer.one_shot = true
	timer.autostart = false
	add_child(timer)
	timer.timeout.connect($Nodes3D/Perso/Nuage1/AnimatedSpriteButton.show)
	timer.start()

func _tuto_fin_phase_A():
	phaseTutorial = PHASE_TUTORIAL.B_GAUCHE
	nTutorialSuccess = 0
	updateTutorialSuccessLabel()
	
	$GUI/CanvasLayerPattern/currentPattern.show()
	$GUI/CanvasLayerPattern/leftPattern.show()
	$GUI/CanvasLayerPattern/rightPattern.hide()


func _tuto_fin_phase_B():
	phaseTutorial = PHASE_TUTORIAL.C_DROITE
	nTutorialSuccess = 0
	updateTutorialSuccessLabel()
	$GUI/CanvasLayerPattern/currentPattern.show()
	$GUI/CanvasLayerPattern/leftPattern.show()
	$GUI/CanvasLayerPattern/rightPattern.show()
	

func _tuto_fin_phase_C():
	phaseTutorial = PHASE_TUTORIAL.D_CONCLUSION
	nTutorialSuccess = 0
	updateTutorialSuccessLabel()
	curseurSpeed = 0
	curseurAccel = 0
	
	# animation : perso revient au point initial + musique fade out + bulle qui disparait
	var tween = musiqueCible.create_tween()
	tween.set_parallel(true)
	tween.tween_property(audioGainPercu, "volume_db", -30, 0.9 * tutoriel_ending_interval)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(curseur, "position", curseurBasePosition, 0.9 * tutoriel_ending_interval)	
	tween.set_meta("audio_tween", true)
	tween_list.append(tween)
	
	var tween3:Tween = tutoriel_ending_timer.create_tween()
	tween3.set_trans(Tween.TRANS_EXPO)
	tween3.set_ease(Tween.EASE_OUT)
	tween3.tween_interval(0.66 * tutoriel_ending_interval)
	tween3.tween_callback($Nodes3D/Perso/Nuage1/Label3D.hide)
	tween3.tween_property($Nodes3D/Perso/Nuage1, "modulate", Color.TRANSPARENT, 0.16 * tutoriel_ending_interval)
	
	$GUI/SkipButtonMarginContainer.hide()
	tutoriel_ending_timer.start()
	
	


func _tuto_fin_phase_D():
	if phaseTutorial == PHASE_TUTORIAL.D_CONCLUSION:
		phaseTutorial = PHASE_TUTORIAL.E_FINI
		nTutorialSuccess = 0
		lancementPartie()

func lancementPartie():
	phaseTutorial = PHASE_TUTORIAL.E_FINI
	partieTimeStart = Time.get_ticks_msec()
	$Menus/StartMenu.hide()
	$Menus/IntroMenu.hide()
	$Menus/EndMenu.hide()
	$Nodes3D/Perso/Nuage1.hide()
	$GUI/SkipButtonMarginContainer.hide()
	$GUI/TimeMarginContainer.show()
	$GUI/StartMenuButtonMarginContainer.show()
	$GUI/CanvasLayerPattern.show()
	$GUI/CanvasLayerCoeur.show()
	$GUI/CanvasLayerNotes.show()
	
	$GUI/CanvasLayerPattern/currentPattern.show()
	$GUI/CanvasLayerPattern/leftPattern.show()
	$GUI/CanvasLayerPattern/rightPattern.show()
	resetRhythm()
	partieEnCours = true
	musicMuted = false
	spawn_timer.start()
	bonus_spawn_timer.start()
	phase_timer_0.start()
	phase_timer_1.start()
	last_phase_timer.start()
	dificult = 0
	
	#vitesse de défilement augmente petit a petit
	vitesse_defilement = 0.3 * INITIAL_OBJECT_SPEED
	sol.create_tween().tween_property(self, "vitesse_defilement", INITIAL_OBJECT_SPEED, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	spawn_interval = 2.0
	curseurSpeed = 0
	curseurAccel = 0
	curseur.position = curseurBasePosition
	#var atween:Tween = curseur.create_tween()
	#atween.set_trans(Tween.TRANS_SINE)
	#atween.set_ease(Tween.EASE_OUT)
	#atween.tween_property(curseur, "position", curseurBasePosition, 0.2)
	removeAllItems(detected_sprites)
	lancerMusique()
	player_health = BASE_HEALTH
	updateCoeur()
	resetBonus()
	$GUI/CanvasLayerNotes.offset = Vector2(400,-550)
	$GUI/CanvasLayerNotes.layer = 2
	phase = 0


func updateTutorialSuccessLabel():
	var msg = ""
	
	match phaseTutorial:
		PHASE_TUTORIAL.A_INIT:
			msg = "Quel mal de crâne !\nJe dois suivre la musique pour garder l’équilibre..."
		PHASE_TUTORIAL.B_GAUCHE:
			msg = "Commençons par aller à gauche.\nJe dois taper tous les temps :\ntap tap tap...\n"
			$Nodes3D/Perso/Nuage1/AnimatedSpriteButton.show()
		PHASE_TUTORIAL.C_DROITE:
			msg = "Yeah ça groove !\nPour aller à droite, c'est le\nstyle samba :\ntam ta-tam ta-tam...\n"
			$Nodes3D/Perso/Nuage1/AnimatedSpriteButton.show()
		PHASE_TUTORIAL.D_CONCLUSION:
			msg = "Je maîtrise ! Plus qu’à traverser le salon pour rejoindre la chambre.\nJ’arrive mon amour !!\n"
			$Nodes3D/Perso/Nuage1/AnimatedSpriteButton.hide()
	
	
	
	if phaseTutorial in [PHASE_TUTORIAL.B_GAUCHE, PHASE_TUTORIAL.C_DROITE]:
		for i in range(nTutorialSuccess):
			msg = msg + " 𝅘𝅥"
		for i in range(nTargetTutorialSuccess - nTutorialSuccess):
			msg = msg + " -"
	$Nodes3D/Perso/Nuage1/Label3D.text = msg


# suppression de tous les items
func removeAllItems(detected_sprites):
	for sprite in detected_sprites.get_children():
		detected_sprites.remove_child(sprite)
		sprite.queue_free()
