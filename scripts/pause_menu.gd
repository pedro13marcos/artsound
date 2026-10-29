extends CanvasLayer
class_name PauseMenu

@onready var main_container: VBoxContainer = $Control/VBoxContainer
@onready var options_container: VBoxContainer = $Control/OptionsContainer
@onready var fullscreen_check: CheckBox = $Control/OptionsContainer/FullscreenCheck
@onready var resume_btn: Button = $Control/VBoxContainer/Resume

var is_paused: bool = false

func _ready() -> void:
	# Make sure pause menu processes even while scene tree is paused!
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	options_container.visible = false
	main_container.visible = true
	
	# Set current fullscreen state
	var current_mode = DisplayServer.window_get_mode()
	fullscreen_check.button_pressed = (current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if options_container.visible:
			_on_options_back_pressed()
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	is_paused = !is_paused
	get_tree().paused = is_paused
	visible = is_paused
	
	if is_paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		main_container.visible = true
		options_container.visible = false
		resume_btn.grab_focus()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_resume_button_up() -> void:
	toggle_pause()

func _on_options_button_up() -> void:
	main_container.visible = false
	options_container.visible = true
	fullscreen_check.grab_focus()

func _on_options_back_pressed() -> void:
	options_container.visible = false
	main_container.visible = true
	resume_btn.grab_focus()

func _on_fullscreen_toggled(button_pressed: bool) -> void:
	if button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_menu_button_up() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _on_quit_button_up() -> void:
	get_tree().quit()
