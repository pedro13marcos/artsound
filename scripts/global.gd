extends Node2D




#@export var bpm: float;
#
#@onready var soundTrack = $Player/soundTrack;
#
#
#
#var secondsPerBeat;
#var referencePosition;
#
func _ready() -> void:
	#to set up locations
	TranslationServer.set_locale("pt");
	#bpm = 120;
	#secondsPerBeat = 60.0/bpm;
	pass;
#
#func _process(delta: float) -> void:
	#pass;
		#
#
#func judgeHit():
	#var songPosition;
	#var currentBeat;
	#
	##time and song - to be implemented on the world and not the player
	#songPosition = soundTrack.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency();
	#currentBeat = int(floor(songPosition/secondsPerBeat));
	#
	##Check if the song is closer to current or next beat
	#if abs(songPosition - (currentBeat*secondsPerBeat))<abs(((currentBeat+1)*secondsPerBeat)-songPosition):
		#referencePosition = songPosition - (currentBeat*secondsPerBeat);
	#else:
		#referencePosition = ((currentBeat+1)*secondsPerBeat)-songPosition;
		#
	##check how close it is from the beat
	#var offset = abs(referencePosition - songPosition);
	#if offset < 0.05:
		#print("PERFECT!");
	#elif offset < 0.10:
		#print("GREAT");
	#elif offset < 0.15:
		#print("GOOD");
	#else:
		#print("MISS");

	
