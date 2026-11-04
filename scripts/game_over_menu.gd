extends CanvasLayer
class_name GameOverMenu

@onready var control_root: Control = $Control
@onready var restart_btn: Button = $Control/VBoxContainer/Restart

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	control_root.modulate.a = 0.0
	Global.player_died.connect(_on_player_died)

func _on_player_died() -> void:
	show_game_over()

func show_game_over() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	var tw = create_tween()
	tw.tween_property(control_root, "modulate:a", 1.0, 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func():
		if restart_btn:
			restart_btn.grab_focus()
	)

func _on_restart_button_up() -> void:
	Global.reset_player_health()
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_menu_button_up() -> void:
	Global.reset_player_health()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _on_quit_button_up() -> void:
	get_tree().quit()
