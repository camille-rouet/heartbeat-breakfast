extends Node3D

var camera: Camera3D
var object_speed = 0
@export var INITIAL_OBJECT_SPEED : float = 10.0 #en m/s
@export var spawn_interval : float = 2.0

const SPRITE_SCALE = 0.5

# hitbox
var lineZ # Z position at which the objet can collide curseur
const LINEZ_SHIFT = 0.6 # extra distance between curseur and the line of collision
const CURSEUR_WIDTH = 1.63 # width of curseur
@export var detection_range : float = 3.5 #4.5


@export var Notes : float = 0 # ne pas modifier


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
const SPRITE_HEIGHT = 2.6

# Premier set de sprites
var sprite_textures := {
	"Table": preload("res://assets/images/meubles/tx_table.png"),
	"Cartons": preload("res://assets/images/meubles/tx_cartons.png"),
	"MeubleTV": preload("res://assets/images/meubles/tx_meubletv.png"),
	"Sac": preload("res://assets/images/meubles/tx_sacspoubelles.png"),
	"Bouteilles": preload("res://assets/images/meubles/tx_bouteilles.png"),
	"Note": preload("res://assets/images/note.png")
}

# Deuxième set de sprites
var alternate_sprite_textures := {
	"T-shirt": preload("res://assets/images/vêtements/tx_tshirt.png"),
	"Jeanslip": preload("res://assets/images/vêtements/tx_jeanslip.png"),
	"string_chaussettes": preload("res://assets/images/vêtements/tx_string_chaussettes.png"),
	"T-shirt_soutif": preload("res://assets/images/vêtements/tx_tshirt_soutif.png"),
}

var bonus_sprite_textures := {
	
}

var columns = []
var detected_sprites = []  
var use_alternate_sprites = false  

# Sprites dangereux
var dangerous_sprites = ["Table", "MeubleTV", "Sac","Bouteilles","Cartons"]
var bonus_sprites = ["Note"]
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

var audioGainBasse:AudioEffectAmplify
var audioGainCuica:AudioEffectAmplify
var audioGainGuitare1:AudioEffectAmplify
var audioGainGuitare2:AudioEffectAmplify
var audioGainPiano:AudioEffectAmplify
var audioGainSynth:AudioEffectAmplify


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
var musicPlaying = false
var musicMuted = false
var musicPositionMemo = 0
var blocTempoGood = true

# erreur lorsque l'on a un pb de rhytme
signal rhythmError
signal rhythmOK
signal inputDCDone
var meanDeltaDC = 0 # ecart moyen entre input et DC
var nInput = 0 #nombre d'input cumulé

var sol:MeshInstance3D

var isRunningOnWeb:bool = false

func couleurnote ():
	var  note = $CanvasLayer3/MarginContainer/HBoxContainer.get_children()
	note[0].modulate = Color(255,255,255,1)
	note[1].modulate = Color(255,255,255,1)
	note[2].modulate = Color(255,255,255,1)
	note[3].modulate = Color(255,255,255,1)

#UI Objects
var leftPattern:Control
var centralCurrentPattern:Control
var rightPattern:Control

func _ready():
	isRunningOnWeb = OS.has_feature("web")
	
	if isRunningOnWeb:
		print("Running on web")
		useEngineTimeInsteadOfPlaybackPosition = true
	else:
		print("Running on " + OS.get_name())
	
	# Timer de 60 secondes
	switch_timer = Timer.new()
	switch_timer.wait_time = 30
	switch_timer.one_shot = true
	switch_timer.autostart = false
	switch_timer.timeout.connect(_switch_sprites)
	add_child(switch_timer)

	# Timer de 85 secondes
	phase_timer = Timer.new()
	phase_timer.wait_time = 45
	phase_timer.one_shot = true
	phase_timer.autostart = false
	phase_timer.timeout.connect(_set_phase_to_1)

	add_child(phase_timer)
	
	
	phase_timer2 = Timer.new()
	phase_timer2.wait_time = 60
	phase_timer2.one_shot = true
	phase_timer2.autostart = false
	phase_timer2.timeout.connect(_set_phase_to_2)
	add_child(phase_timer2)
	
	win_timer = Timer.new()
	win_timer.wait_time = 70
	win_timer.one_shot = true
	win_timer.autostart = false
	win_timer.timeout.connect(_set_win)
	add_child(win_timer)
	# Timer pour la génération des sprites (toutes les 2s)
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.autostart = false
	spawn_timer.timeout.connect(_generate_sprite)
	add_child(spawn_timer)
	
	
	couleurnote()
	leftPattern = $CanvasLayer/leftPattern/HBoxContainer
	centralCurrentPattern = $CanvasLayer/currentPattern/HBoxContainer
	rightPattern = $CanvasLayer/rightPattern/HBoxContainer
	mainLight = $DirectionalLight3D
	theWorld = $WorldEnvironment
	sol = $Sol
	rhythmError.connect(_on_rhythm_error)
	rhythmOK.connect(_on_rhythm_ok)
	inputDCDone.connect(_on_inputDCDone)
		
	audioGainCuica = AudioServer.get_bus_effect(4, 0)
	audioGainGuitare1 = AudioServer.get_bus_effect(5, 0)
	audioGainPiano = AudioServer.get_bus_effect(6, 0)
	audioGainSynth = AudioServer.get_bus_effect(7, 0)
	audioGainGuitare2 = AudioServer.get_bus_effect(8, 0)
	audioGainBasse = AudioServer.get_bus_effect(9, 0)
	
	audioServerLatency = AudioServer.get_output_latency()
	
	
	# Affichage du motif de gauche
	updateMotif(leftPattern, RHYTHMIC_PATTERN.A)
	# Affichage du motif de droite
	updateMotif(rightPattern, RHYTHMIC_PATTERN.B)
	
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
	
	curseur = $Perso	
	curseurBasePosition = curseur.position
	lineZ = curseur.position.z - LINEZ_SHIFT
	tetePerso = $Perso/AnimatedSpritePersoTete
	
	# Récupérer la caméra et les colonnes
	camera = $Camera3D  
	columns.append($MeshInstance3D)  
	columns.append($MeshInstance3D2)  
	columns.append($MeshInstance3D3)  
	columns.append($MeshInstance3D4)  

	## Position initiale de la caméra
	#_align_camera_to_column(true)

	

	# Timer pour changer les sprites après 60s

var switch_timer: Timer
var phase_timer: Timer
var phase_timer2: Timer
var win_timer : Timer
var spawn_timer :Timer
func _switch_sprites():
	# Code pour changer les sprites
	if phase == 1 :
		print("entrée dans la phase 1")
	pass

func _set_phase_to_1():
	phase = 1
	print("Phase is now: ", phase)
func _set_win():
	if player_health >0 :
		print("bravo vous êtes arrivée a la fin ")
		_game_over(true)
		
func _set_phase_to_2():
	phase = 2
	print("Phase is now: ", phase)
		

# Changer la liste des sprites après 60 secondes

# Générer un sprite
func _generate_sprite():
	if columns.size() == 0:
		print("⚠️ Erreur: 'columns' est vide, impossible de générer un sprite.")
		return

	var rand_column = randi() % columns.size()
	var column = columns[rand_column]  
	var start_pos = column.get_node("Start").global_position
	var end_pos = column.get_node("End").global_position
	
	start_pos.y += SPRITE_HEIGHT
	end_pos.y += SPRITE_HEIGHT
	
	
	# Initialisation de sprite_list
	var sprite_list = {} 
	
	if phase == 0:
		sprite_list = sprite_textures
	elif phase == 1:
		sprite_list = sprite_textures.duplicate(true)
		sprite_list.merge(alternate_sprite_textures)
	elif phase == 2:
		sprite_list = alternate_sprite_textures

	var keys = sprite_list.keys()
	var rand_key = keys[randi() % keys.size()]
	var rand_texture = sprite_list[rand_key]

	# Vérifier si la texture est bien chargée
	if rand_texture == null:
		print("⚠️ Erreur: la texture de ", rand_key, " est NULL !")
		return
	
	#print("✅ Génération de: ", rand_key, " avec la texture: ", rand_texture.resource_path)

	# Appliquer la texture
	var new_sprite:Sprite3D = Sprite3D.new()
	new_sprite.texture = rand_texture
	new_sprite.position = start_pos
	new_sprite.set_meta("name", rand_key)
	new_sprite.scale = Vector3.ONE * SPRITE_SCALE  # Ajuste la taille à 50%
	add_child(new_sprite)  
	detected_sprites.append(new_sprite)

	# Calculer la distance entre start_pos et end_pos
	var distance = start_pos.distance_to(end_pos)

	# Calculer le temps nécessaire pour parcourir la distance à la vitesse donnée
	var duration = distance / object_speed
	
	# Animation de transparence
	new_sprite.modulate = Color.TRANSPARENT
	var tween2 = get_tree().create_tween()
	tween2.tween_property(new_sprite, "modulate", Color.WHITE, 1).set_trans(Tween.TRANS_LINEAR)

	# Animation de déplacement
	var tween = get_tree().create_tween()
	tween.tween_property(new_sprite, "position", end_pos, duration).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(new_sprite.queue_free)
	tween.tween_callback(func(): detected_sprites.erase(new_sprite))






# Déplacement fluide de la caméra
func _process(delta):
	if showDebugMenu :
		$DebugMenu.show()
		
		debugMsg = "Time :" +  str((Time.get_ticks_msec())) + " FPS: " + str(Engine.get_frames_per_second()) + " delta: " + str(roundi(delta*1e3))  +\
		"\nPlayback pos: " + str(roundi(musiqueCible.get_playback_position()*1000)) +\
		"\ncurrentBeat and currentDC: " + str(currentBeat) + " - " + str(currentDC) +\
		" (" + str((currentBeat) % BARS + 1) + "/" + str(BARS) + " - " + str((currentDC) % 4 + 1) + "/4)" +\
		"\nmeanDeltaDC: " + str(roundi(meanDeltaDC*1000)) + " ms (on " + str(nInput) + " inputs)" +\
		"\ncurrentPatternDelta: " + str(currentPatternDelta) +\
		"\ncurrentPatternInput: " + str(currentPatternInput) +\
		"\ncurrentPatternDeltaCompleted: " + str(currentPatternDeltaCompleted)
	else:
		$DebugMenu.hide()
	
	time_counter += delta  # Incrémente le compteur de temps avec le delta (temps écoulé)
	if time_counter >= 10.0:  # Vérifie si 10 secondes se sont écoulées
		print("\nAugmentation de la difficulté")
		time_counter = 0.0
		if dificult <= 10 :
			
			object_speed *= 1.1 # augment la vitesse des sprites de 10%
			spawn_interval *=0.9 # augmentation du taux d'apparition des sprites de 10%
			print("Difficulté augmenté de : 10%")
		
		dificult +=1
		if dificult >= 10 :
			print("phase finale en cours la difficulté va fortement augmenter")
			if dificult >= 15 :
				print("dificulté max atteinte")
			object_speed *= 1.4 # augment la vitesse des sprites de 10%
			spawn_interval *=0.6 # augmentation du taux d'apparition des sprites de 10%
			print("Difficulté augmenté de : 40%")
		
		print("nouvelle vitesse des sprites : ",object_speed)
		print("nouveau taux d'apparition est de ",spawn_interval)
		print ("le niveau de difficulté passe de ", dificult ," à ", dificult+1)
	
	
	if musicPlaying:
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
		
	moveCursor(delta)
	
	# defilement du sol
	var material:StandardMaterial3D = sol.get_surface_override_material(0)
	# un offset de 1 fait bouger le motif d'une fois
	var planeMesh:PlaneMesh = sol.mesh
	var tailleMotifBase = planeMesh.size.y / material.uv1_scale.y
	var decalageFrame = delta * object_speed
	material.uv1_offset.y = material.uv1_offset.y - decalageFrame / tailleMotifBase
	#if Input.is_action_just_pressed("motif1") and camera_column_index > 0:
		#camera_column_index -= 1
		#_align_camera_to_column()
#
	#if Input.is_action_just_pressed("motif2") and camera_column_index < columns.size() - 1:
		#camera_column_index += 1
		#_align_camera_to_column()

	# Animation fluide vers la position cible
	#camera.position = camera.position.lerp(target_camera_position, camera_speed * delta)
	# Vérifier la proximité des sprites avec le joueur
	_check_proximity()
	
	
	$DebugMenu/MarginContainer/Label.text = debugMsg

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
	for sprite:Sprite3D in detected_sprites:
		
		#var distance = curseur.position.distance_to(sprite.position)
		##print("Distance entre", sprite.get_meta("name"), "et le curseur:", distance)
		#if distance < detection_range:
		
		if sprite.position.z > lineZ :
			var objSizeX = sprite.get_item_rect().size.x * SPRITE_SCALE * sprite.pixel_size
			var objMinX = sprite.position.x - 0.5 * objSizeX
			var objMaxX = sprite.position.x + 0.5 * objSizeX
			var curseurMinxX = curseur.position.x - 0.5 * CURSEUR_WIDTH
			var curseurMaxX = curseur.position.x + 0.5 * CURSEUR_WIDTH
			if objMinX < curseurMinxX && curseurMinxX < objMaxX || objMinX < curseurMaxX && curseurMaxX < objMaxX :
				# collision !
				var sprite_name = sprite.get_meta("name")
				print(sprite_name, " touché !")

				# Vérifier si l'objet est dangereux
				if sprite_name in dangerous_sprites:
					_take_damage()
				if sprite_name in bonus_sprites:
					_bonus()
				
				# Supprimer après détection
				sprite.modulate = Color.TRANSPARENT
				detected_sprites.erase(sprite)
				

func resetBonus():
	Notes = 0
	var notem = $CanvasLayer3/MarginContainer/HBoxContainer.get_children()
	for note:TextureRect in notem:
		note.modulate = Color.WHITE

func _bonus():
	#print("vous avez obtenu un bonus")
	var notem = $CanvasLayer3/MarginContainer/HBoxContainer.get_children()
	var timeFadeIn = 1 # in sec
	#print("bonus " + str(Notes))
	if Notes == 0 :
		notem[Notes].modulate = Color.hex(0x002cd8ff)
		
		var tween = musiqueCible.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(audioGainSynth, "volume_db", 0, timeFadeIn)
		
	if Notes == 1 :
		notem[Notes].modulate = Color.hex(0x009e21ff)
		var tween = musiqueCible.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(audioGainPiano, "volume_db", 0, timeFadeIn)
	if Notes == 2 :
		notem[Notes].modulate = Color.hex(0xecbb00ff)
		var tween = musiqueCible.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(audioGainGuitare1, "volume_db", 0, timeFadeIn)
	if Notes == 3 :
		notem[Notes].modulate = Color.hex(0xff55c8ff)
		var tween = musiqueCible.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(audioGainGuitare2, "volume_db", 0, timeFadeIn)
	Notes += 1
	print("nombre de Note obtenue : ",Notes)
	
# Gestion des points de vie
func _take_damage():
	$"ExplRealExplosion1(id1807)Ls".play()
	player_health -= 1
	#print("PV restants : ", player_health)
	
	updateCoeur()
	
	if player_health <= 0:
		_game_over(false)

func updateCoeur():
	var coeurs = $CanvasLayer2/MarginContainer/HBoxContainer.get_children()
	
	for i in range(BASE_HEALTH):
		if (i+1) <= player_health:
			coeurs[i].show()
		else:
			coeurs[i].hide()

# Fin de partie
func _game_over(gagne:bool):
	if gagne:
		$EndMenu/FinPerdu.hide()
		$EndMenu/FinGagne.show()
	else:
		$EndMenu/FinPerdu.show()
		$EndMenu/FinGagne.hide()
	
	$CanvasLayer3.offset = Vector2(-400,0)
	$CanvasLayer3.layer = 128
	spawn_timer.stop()
	switch_timer.stop()
	phase_timer.stop()
	phase_timer2.stop()
	win_timer.stop()
	
	stopMusique()
	$EndMenu.show()


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
	print("Your pattern is " + str(matchedPattern) + "  ..Mean delta = " + str(roundi(meanDeltaDC * 1000)) + " ms")
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
	blocTempoGood = true
	
# # # # # # METHODES AUDIO

func stopMusique():
	if musicPlaying:
		for i:AudioStreamPlayer in musiqueCible.get_parent().get_children():
			musicPositionMemo = i.get_playback_position()
			i.stop()
	musicPlaying = false

func launchMusique():
	#if musicPlaying:
		#for i:AudioStreamPlayer in musiqueCible.get_parent().get_children():
			#musicPositionMemo = i.get_playback_position()
			#i.stop()
	musiqueTimeStart = Time.get_ticks_msec() * 0.001
	for i:AudioStreamPlayer in musiqueCible.get_parent().get_children():
		i.play()
	
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
		if abs(deltaToucheDC) > ACCEPTABLE_DELTA * 0.001:
			rhythmError.emit()
			blocTempoGood = false
		
		# update the rhytmic pattern delta
		currentPatternDelta[closerDCInBeat - 1] = roundi(deltaToucheDC * 1000)
		currentPatternInput = patternDeltaToPatternInput(currentPatternDelta)
		
		# update the mean error on DC
		meanDeltaDC = (meanDeltaDC * (nInput-1) + deltaToucheDC) / nInput
		
		#joue un son
		if blocTempoGood:
			$Audio/Bruitages/BlocGood.play()
		else:
			$Audio/Bruitages/BlocBad.play()
		blocTempoGood = true
		
		#change l'affichage du motif central
		
		
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
				"R":
					pass
				 
		
	
	
	if event.is_action_pressed("mute_switch"):
		switchMuteMusique()
		
	#if event.is_action_pressed("pause_switch"):
		#switchPauseMusique()

	

#update a canvasPattern, given a pattern input and a DCinBeat
func updateMotif(canvaPattern, patternInput, DCInBeat = -1):
	var index = 0
	for textRect:TextureRect in canvaPattern.get_children():
		match patternInput[index]:
			0:
				textRect.texture = get_node_and_resource("CanvasLayer:textureDCvide")[1]
				if (index+1) == DCInBeat:
					textRect.texture = get_node_and_resource("CanvasLayer:textureDCpassage")[1]
			1:
				textRect.texture = get_node_and_resource("CanvasLayer:textureDCreussite")[1]
			"R":
				textRect.texture = get_node_and_resource("CanvasLayer:textureDCrate")[1]
		index = index + 1

func menuIntro():
	$StartMenu.hide()
	$IntroMenu.show()

func lancementPartie():
	$StartMenu.hide()
	$IntroMenu.hide()
	$EndMenu.hide()
	resetRhythm()
	musicPlaying = false
	musicMuted = false
	spawn_timer.start()
	switch_timer.start()
	phase_timer.start()
	phase_timer2.start()
	win_timer.start()
	dificult = 0
	object_speed = INITIAL_OBJECT_SPEED
	spawn_interval = 2.0
	
	for obj in detected_sprites:
		obj.queue_free
	detected_sprites = []
	launchMusique()
	player_health = BASE_HEALTH
	updateCoeur()
	resetBonus()
	$CanvasLayer3.offset = Vector2(400,-550)
	$CanvasLayer3.layer = 1
	phase = 0
