extends Node

# Constants of closeness (in seconds)
const PERFECT = 0.05
const GREAT = 0.10
const GOOD = 0.15

const DIVISIONPERBEAT = 4

var songOffset: float = 0.0
var currentBeat: int = 0
var currentDivision: int = 0


func rythymState(backgroundMusic, BPM = 120.0, useDivision: bool = false):
	# Check if there's music playing
	if backgroundMusic == null or not backgroundMusic.playing:
		return "error"
	
	var songPosition = getSongPosition(backgroundMusic)
	var secondsPerBeat = getTimePerBeat(BPM)
	var secondsPerDivision = secondsPerBeat / float(DIVISIONPERBEAT)
	
	# Update current beat and division tracker
	currentBeat = int(floor(songPosition / secondsPerBeat))
	currentDivision = posmod(int(floor(songPosition / secondsPerDivision)), 16)
	
	# Test against beat (default) or subdivision
	var step = secondsPerDivision if useDivision else secondsPerBeat
	var closestStep = round(songPosition / step)
	var diff = abs(songPosition - (closestStep * step))
	
	if diff <= PERFECT:
		return "PERFECT"
	elif diff <= GREAT:
		return "GREAT"
	elif diff <= GOOD:
		return "GOOD"
	else:
		return "MISS"


func getCurrentDivision(backgroundMusic, BPM):
	if backgroundMusic == null or not backgroundMusic.playing:
		return null
	var secondsPerDivision = getTimePerBeat(BPM) / float(DIVISIONPERBEAT)
	var songPosition = getSongPosition(backgroundMusic)
	return posmod(int(floor(songPosition / secondsPerDivision)), 16)


func getCurrentBeat(backgroundMusic, BPM):
	if backgroundMusic == null or not backgroundMusic.playing:
		return null
	var secondsPerBeat = getTimePerBeat(BPM)
	var songPosition = getSongPosition(backgroundMusic)
	return int(floor(songPosition / secondsPerBeat))


func getClosestDivision(backgroundMusic, BPM):
	if backgroundMusic == null or not backgroundMusic.playing:
		return null
	var secondsPerDivision = getTimePerBeat(BPM) / float(DIVISIONPERBEAT)
	var songPosition = getSongPosition(backgroundMusic)
	return round(songPosition / secondsPerDivision)


func getClosestBeat(backgroundMusic, BPM):
	if backgroundMusic == null or not backgroundMusic.playing:
		return null
	var secondsPerBeat = getTimePerBeat(BPM)
	var songPosition = getSongPosition(backgroundMusic)
	return round(songPosition / secondsPerBeat)


func getSongPosition(backgroundMusic, offset: float = 0.0):
	if backgroundMusic == null:
		return 0.0
	var pos = backgroundMusic.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	return max(0.0, pos - songOffset - offset)


func getTimePerBeat(BPM):
	return 60.0 / BPM

