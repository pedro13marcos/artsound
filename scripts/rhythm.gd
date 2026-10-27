extends Node

#constants of closeness
const PERFECT = 0.05
const GREAT = 0.1
const GOOD = 0.15

const DIVISIONPERBEAT = 4

var currentDivision = 0


func rythymState(backgroundMusic, BPM):
	var secondsPerDivision = getTimePerBeat(BPM)/4.0;
	#var currentBeat = getCurrentBeat(backgroundMusic,BPM);
	#Check if there's music playing
	if getCurrentDivision(backgroundMusic,BPM) == null:
		return "error";
	else:
		currentDivision = getCurrentDivision(backgroundMusic,BPM);
		#compare how good is the moment
		#Test for the current beat
		match abs(getSongPosition(backgroundMusic)-(getClosestDivision(backgroundMusic,BPM)*secondsPerDivision)):
		#match abs(getSongPosition(backgroundMusic)-(getClosestBeat(backgroundMusic,BPM)*(secondsPerBeat/(4.0/divisionBeat)))):
			var h when h <= PERFECT:
				return "PERFECT";
			var h when h <= GREAT:
				return "GREAT";
			var h when h <= GOOD:
				return "GOOD"
			_:
				return "MISS";
		
		
		
#func getDivision(backgroundMusic, BPM):
	##get the time of the division
	#var timeDivision = getTimePerBeat(BPM)/DIVISIONPERBEAT
	# #Make sure there's a song playing
	#if backgroundMusic == null or not backgroundMusic.playing:
		#return null
	#else:
		#var songPosition = getSongPosition(backgroundMusic);
		#return int(floor(songPosition/timeDivision));
	

func getCurrentDivision(backgroundMusic, BPM):
	var secondsPerDivision = getTimePerBeat(BPM)/4.0;
	#Confirm if there's any music playing
	if backgroundMusic == null or not backgroundMusic.playing:
		return null;
	else:
		var songPosition = getSongPosition(backgroundMusic);
		return (int(floor(songPosition/secondsPerDivision)))%16;

#func getCurrentBeat(backgroundMusic, BPM):
	#var secondsPerBeat = getTimePerBeat(BPM);
	##Confirm if there's any music playing
	#if backgroundMusic == null or not backgroundMusic.playing:
		#return null;
	#else:
		#var songPosition = getSongPosition(backgroundMusic);
		#return int(floor(songPosition/secondsPerBeat));

func getClosestDivision(BackgroundMusic, BPM):
	#4 subdivision per beat
	var secondsPerDivision = getTimePerBeat(BPM)/4.0;
	#Confirm if there's any music playing
	if BackgroundMusic == null or not BackgroundMusic.playing:
		return null;
	else:
		var songPosition = getSongPosition(BackgroundMusic);
	# Remova o int(), deixe como float para manter a precisão ao multiplicar de volta
		return round(songPosition/secondsPerDivision);
	#else:
		#var songPosition = getSongPosition(BackgroundMusic);
		#return int(round(songPosition/secondsPerDivision));
	#pass;

#func getClosestBeat(backgroundMusic,BPM):
	##4 subdivision per beat
	#var secondsPerBeat = getTimePerBeat(BPM);
	##Confirm if there's any music playing
	#if backgroundMusic == null or not backgroundMusic.playing:
		#return null;
	#else:
		#var songPosition = getSongPosition(backgroundMusic);
		#return int(round(songPosition/secondsPerBeat));


func getSongPosition(backgroundMusic):
	return backgroundMusic.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency();

func getTimePerBeat(BPM):
	return 60.0/BPM;
