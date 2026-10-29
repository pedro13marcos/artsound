extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


# "Play" starts the real game (Level 1)
func _on_play_button_up() -> void:
	get_tree().change_scene_to_file("res://scenes/level_1.tscn");


func _on_test_map_button_up() -> void:
	get_tree().change_scene_to_file("res://scenes/test_map.tscn");


func _on_exit_button_up() -> void:
	get_tree().quit();
