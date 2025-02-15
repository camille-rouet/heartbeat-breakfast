extends Node2D

const BPM = 73
const BARS = 4
var beatLength 

const COMPENSATE_FRAMES = 2
const COMPENSATE_HZ = 60.0

var musicPlaying:bool = false

var musique:AudioStreamPlayer
var feedbackRect:ColorRect
var feedbackRect2:ColorRect

var tempsVu = false
var dernierBeat = -1
var lastBeatTimeCode = -1

var initTimeCode # in sec

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	beatLength = 1.0 / float(BPM) * 60.0
	feedbackRect = $ColorRect1
	feedbackRect2 = $ColorRect2
	musique = $"musique-tribal"
	
	initTimeCode = Time.get_ticks_usec() / 1000000.0 # in sec


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if musicPlaying:
		var time = musique.get_playback_position() - AudioServer.get_output_latency() + (1 / COMPENSATE_HZ) * COMPENSATE_FRAMES
		
		
		var beat = int(time * BPM / 60.0)
		var seconds = int(time)
		var seconds_total = int(musique.stream.get_length())
		@warning_ignore("integer_division")
		var text = str("BEAT: ", beat % BARS + 1, "/", BARS, " TIME: ", seconds / 60, ":", strsec(seconds % 60), " / ", seconds_total / 60, ":", strsec(seconds_total % 60))
		#print(text)
		
		if(beat > dernierBeat):
			lastBeatTimeCode = time
			dernierBeat = beat
			feedbackRect.scale = Vector2(2,2)
			var aTween = feedbackRect.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			aTween.tween_property(feedbackRect, "scale", Vector2(1,1), 0.4)
			


func strsec(secs):
	var s = str(secs)
	if (secs < 10):
		s = "0" + s
	return s

func _on_texture_button_pressed() -> void:
	musicPlaying = !musicPlaying
	if !$PlayButton.button_pressed:
		musique.stop()
	else:
		musique.play()


func _unhandled_input(event):
	if event.is_action_pressed("ToucheA"):
		var time = musique.get_playback_position() - AudioServer.get_output_latency() - 0.100
		var lastBeat = int(time / beatLength)
		var lastBeatTime = lastBeat * beatLength
		
		var retardTouche = time - lastBeatTime
		# le beat de référence est le précédent
		var deltaTouche = retardTouche
		# le beat de référence est le suivant
		if retardTouche > beatLength * 0.5:
			deltaTouche = time - (lastBeatTime + beatLength)
		
		print("")
		print("Ecart au beat (ms) " + str(deltaTouche * 1000) )
		
		
		var basePosition = $ColorRect3.position
		feedbackRect2.position = Vector2(basePosition.x + deltaTouche * 1000, basePosition.y)
		
