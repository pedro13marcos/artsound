extends Node2D

var bpm: int;

func _ready() -> void:
	$soundTrack.play();
	bpm = 120.0/16;
	

func _process(delta: float) -> void:
	var worldState = Rhythm.rythymState($soundTrack,bpm);
	#linkar o modulate do sprite da interaction area
	if worldState == "PERFECT":
		$"Interaction point/Interaction area/Sprite2D".modulate = Color(0.314, 0.737, 0.086, 0.616);
	elif worldState == "GREAT":
		$"Interaction point/Interaction area/Sprite2D".modulate = Color(0.82, 0.572, 0.0, 0.616);
	elif worldState == "GOOD":
		$"Interaction point/Interaction area/Sprite2D".modulate = Color(1.0, 0.373, 0.534, 0.616);
	else:
		$"Interaction point/Interaction area/Sprite2D".modulate = Color(0.113, 0.119, 0.115, 0.616);
