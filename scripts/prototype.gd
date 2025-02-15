extends Node2D

const BPM = 73 # in beat per minute
const BARS = 4  #beat in one measure
const BEAT_OFFSET = 1 # number of beat before the first beat of a bar of the music

const ACCEPTABLE_DELTA = 60 # acceptable error in ms

const LATENCY = 80 # in ms

const COMPENSATE_FRAMES = 2
const COMPENSATE_HZ = 60.0

var beatLength # 60/ BPM, in sec
var DCLength # beatLength / 4, in sec

var musicPlaying:bool = false

var musique:AudioStreamPlayer
var beatRect:ColorRect

var tempsVu = false
var currentBeat = 0
var currentDC = 0 # double croche


var currentPatternDelta = [null, null, null, null] # chaque entrée definit le temps (en ms) entre l'input et la double-croche la plus proche, si pas d'input pour une double croche : null
var currentPatternDeltaCompleted = false # Si true, currentPatternDelta est complet

var initTimeCode # in sec


var curseur:ColorRect #bouge en fonction des inputs rythmiques
var curseurSpeed = Vector2.ZERO # in pixel / sec
var curseurAccel = Vector2.ZERO # in pixel / sec / sec

# pour le curseur
const BRAKE = 0.99
const ACCEL = 100
const MAX_SPEED = 300

# Motif rythmiques
const RHYTHMIC_PATTERN = {
	"A": [1, 0, 0, 0],
	"B": [1, 0, 1, 0],
	"C": [1, 1, 1, 1],
	"D": [1, 1, 1, 0]
} # Les 4 entrées des tableaux rythmiques sont les subdivision d'un temps avec 4 doubles croches

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	beatLength = 1.0 / float(BPM) * 60.0
	DCLength = beatLength / 4.0
	beatRect = $ColorRect1
	curseur = $CurseurRect
	musique = $"musique-tribal"
	
	initTimeCode = Time.get_ticks_usec() / 1000000.0 # in sec

	print("beat length (ms): " + str(round(beatLength * 1000)))
	print("DC length (ms): " + str(round(DCLength * 1000)))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void: #delta = frame duration in s
	
	if musicPlaying:
		var time = musique.get_playback_position()  - AudioServer.get_output_latency() - LATENCY * 0.001
		
		@warning_ignore("integer_division")
		
		# Print beats
		var beat = int(time * BPM / 60.0)
		if(beat > currentBeat):
			currentBeat = beat
			var currentBeatInMeasure = (beat - BEAT_OFFSET) % BARS + 1
			
			# Rectanle bouge avec le beat
			beatRect.scale = Vector2(2,2)
			var aTween = beatRect.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			aTween.tween_property(beatRect, "scale", Vector2(1,1), beatLength * 0.9)
			
			# afficher les beats
			var seconds = int(time)
			var seconds_total = int(musique.stream.get_length())
			var text = str("BEAT: ", currentBeatInMeasure, "/", BARS, " TIME: ", seconds / 60, ":", strsec(seconds % 60), " / ", seconds_total / 60, ":", strsec(seconds_total % 60))
			#print("\n" + text)
		
		# Print DCs
		var DC = int(time / DCLength)
		var DCInBeat = (DC) % 4 + 1
		if(DC > currentDC):
			currentDC = DC
			#var text = str("DC: ", DCInBeat, "/", "4")
			#print(text)
		
		# définition de la fenetre de tir pour observer le motif donné en input
		if DCInBeat == 4:
			var DC4_time = currentDC * DCLength
			var devFenetre_time = currentDC * DCLength + ACCEPTABLE_DELTA * 0.001
			var finFenetre_time = (currentDC+1) * DCLength - ACCEPTABLE_DELTA * 0.001
			var DC5_time = (currentDC+1) * DCLength
					
			# quand on passe la fin de possibilité de input la 4eme DC
			if !currentPatternDeltaCompleted:
				if time >= devFenetre_time && time < finFenetre_time:
					currentPatternDeltaCompleted = true
					
					var motifInput = patternDeltaToPatternInput(currentPatternDelta)
					interpretPattern(motifInput)
		
			# quand on arrive à la possibilité de input la 1ere DC 
			if currentPatternDeltaCompleted:
				if time >= finFenetre_time:
					currentPatternDelta = [null, null, null, null]
					currentPatternDeltaCompleted = false
		
		moveCursor(delta)


func moveCursor(delta):
	# Move curseur
	curseur.position = curseur.position + delta * curseurSpeed
	curseurSpeed = curseurSpeed + delta * curseurAccel
	
	if curseur.position.x > DisplayServer.window_get_size().x * 0.95:
		curseur.position.x = DisplayServer.window_get_size().x * 0.95 - 20
		curseurSpeed.x = - curseurSpeed.x*0.2
		curseurAccel.x = 0
	if curseur.position.x < DisplayServer.window_get_size().x * 0.05:
		curseur.position.x = DisplayServer.window_get_size().x * 0.05 +20
		curseurSpeed.x = - curseurSpeed.x*0.2
		curseurAccel.x = 0
		
	curseurSpeed.x = curseurSpeed.x * BRAKE
	curseurSpeed.x = min(curseurSpeed.x, MAX_SPEED)
	curseurSpeed.x = max(curseurSpeed.x, -MAX_SPEED)


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



func interpretPattern(patternInput):
	print(str(currentPatternDelta))
	print(str(patternInput))
	var matchedPattern = findPattern(patternInput)
	print("Your pattern is " + str(matchedPattern))
	print("")
	
	match matchedPattern:
		"A":
			curseurAccel.x = -ACCEL
		"B":
			curseurAccel.x = ACCEL



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



func strsec(secs):
	var s = str(secs)
	if (secs < 10):
		s = "0" + s
	return s



func _on_texture_button_pressed() -> void:
	musicPlaying = !musicPlaying
	if $PlayButton.button_pressed:
		musique.play()
	else:
		musique.stop()



func _unhandled_input(event):
	
	# recoit un input "A"
	if musicPlaying && event.is_action_pressed("ToucheA"):
		var time = musique.get_playback_position() - AudioServer.get_output_latency() - LATENCY * 0.001
		
		var deltaToucheBeat = getDeltaBeat(time)
		#print("Ecart au beat (ms) " + str(round(deltaToucheBeat * 1000) ))
		
		
		# reconnaitre la double croche en cours
		var lastDC = int(time / DCLength)
		var lastDCTime = lastDC * DCLength
		
		var closerDC
		
		var retardToucheDC = time - lastDCTime
		var deltaToucheDC = 0
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
		
		#print("Ecart à la DC " + str(closerDCInBeat) + " (ms) " + str(round(deltaToucheDC * 1000)) )
		
		# update the rhytmic pattern delta
		currentPatternDelta[closerDCInBeat - 1] = round(deltaToucheDC * 1000)
		
		

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
