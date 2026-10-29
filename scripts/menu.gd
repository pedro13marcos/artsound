extends Control

@onready var main_container: VBoxContainer = $VBoxContainer
@onready var options_container: VBoxContainer = $OptionsContainer
@onready var fullscreen_check: CheckBox = $OptionsContainer/FullscreenCheck
@onready var language_select: OptionButton = $OptionsContainer/LanguageContainer/LanguageSelect
@onready var play_btn: Button = $VBoxContainer/Play

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	main_container.visible = true
	options_container.visible = false
	_sync_options_state()


func _sync_options_state() -> void:
	if fullscreen_check != null:
		var current_mode = DisplayServer.window_get_mode()
		fullscreen_check.button_pressed = (current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	_populate_language_options()


func _populate_language_options() -> void:
	if language_select == null:
		return
	language_select.clear()
	var selected_idx: int = 0
	for i in range(Global.SUPPORTED_LANGUAGES.size()):
		var lang_info: Dictionary = Global.SUPPORTED_LANGUAGES[i]
		var display_text: String = ""
		if lang_info["id"] == "auto":
			display_text = tr("lang_auto")
		else:
			display_text = lang_info["native_name"]
		language_select.add_item(display_text, i)
		if lang_info["id"] == Global.current_language_mode:
			selected_idx = i
	language_select.select(selected_idx)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and options_container.visible:
		_on_options_back_pressed()
		get_viewport().set_input_as_handled()


func _on_options_button_up() -> void:
	_sync_options_state()
	main_container.visible = false
	options_container.visible = true
	if language_select:
		language_select.grab_focus()


func _on_options_back_pressed() -> void:
	options_container.visible = false
	main_container.visible = true
	if play_btn:
		play_btn.grab_focus()


func _on_fullscreen_toggled(button_pressed: bool) -> void:
	if button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_language_selected(index: int) -> void:
	if index < 0 or index >= Global.SUPPORTED_LANGUAGES.size():
		return
	var lang_id: String = Global.SUPPORTED_LANGUAGES[index]["id"]
	Global.set_language_mode(lang_id)
	# Refresh the "Automatic" label in the dropdown so it displays in the newly selected language
	if language_select != null and language_select.item_count > 0:
		language_select.set_item_text(0, tr("lang_auto"))


# "Play" starts the real game (Level 1)
func _on_play_button_up() -> void:
	get_tree().change_scene_to_file("res://scenes/level_1.tscn");


func _on_test_map_button_up() -> void:
	get_tree().change_scene_to_file("res://scenes/test_map.tscn");


func _on_exit_button_up() -> void:
	get_tree().quit();
