extends Node2D

var bpm: float = 120.0;

func _enter_tree() -> void:
	Global.reset_player_health()

func _ready() -> void:
	$soundTrack.play();
	$soundTrack.finished.connect(func(): $soundTrack.play())
	

func _process(_delta: float) -> void:
	var _world_state = Rhythm.rythymState($soundTrack, bpm);
