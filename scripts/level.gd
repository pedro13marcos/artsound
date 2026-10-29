extends Node2D

var bpm: float = 120.0;

func _ready() -> void:
	$soundTrack.play();
	$soundTrack.finished.connect(func(): $soundTrack.play())
	

func _process(delta: float) -> void:
	var worldState = Rhythm.rythymState($soundTrack, bpm);
