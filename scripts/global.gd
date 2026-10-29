extends Node2D

# Selected language option:
# "auto" = Automatic (detects OS locale), or explicit locale code: "pt_BR", "en", "es", "fr", "ja", "zh"
var current_language_mode: String = "auto"

const SUPPORTED_LANGUAGES: Array[Dictionary] = [
	{"id": "auto",  "label_key": "lang_auto", "native_name": ""},
	{"id": "pt_BR", "label_key": "",          "native_name": "Português (BR)"},
	{"id": "en",    "label_key": "",          "native_name": "English"},
	{"id": "es",    "label_key": "",          "native_name": "Español"},
	{"id": "fr",    "label_key": "",          "native_name": "Français"},
	{"id": "ja",    "label_key": "",          "native_name": "日本語"},
	{"id": "zh",    "label_key": "",          "native_name": "中文"}
]

func _ready() -> void:
	_load_csv_translations("res://translation/translation.csv")
	set_language_mode("auto")
	_create_watermark()

## Parses translation CSV at runtime and registers all locale columns (pt_BR, en, es, fr, ja, zh)
## with TranslationServer so new languages and keys work immediately.
func _load_csv_translations(csv_path: String) -> void:
	if not FileAccess.file_exists(csv_path):
		return
	var file = FileAccess.open(csv_path, FileAccess.READ)
	if file == null:
		return

	var headers: PackedStringArray = file.get_csv_line()
	if headers.size() < 2:
		return

	var translations_by_locale: Dictionary = {}
	for i in range(1, headers.size()):
		var loc = headers[i].strip_edges()
		if not loc.is_empty():
			var tr_res = Translation.new()
			tr_res.locale = loc
			translations_by_locale[i] = tr_res

	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < 2:
			continue
		var key = row[0].strip_edges()
		if key.is_empty():
			continue
		for i in range(1, min(row.size(), headers.size())):
			if translations_by_locale.has(i):
				translations_by_locale[i].add_message(key, row[i])

	for idx in translations_by_locale.keys():
		var tr_res: Translation = translations_by_locale[idx]
		TranslationServer.add_translation(tr_res)
		# Also register base 2-letter alias for pt_BR -> pt so OS locale "pt" resolves cleanly
		if tr_res.locale == "pt_BR":
			var pt_alias = Translation.new()
			pt_alias.locale = "pt"
			for msg_key in tr_res.get_message_list():
				pt_alias.add_message(msg_key, tr_res.get_message(msg_key))
			TranslationServer.add_translation(pt_alias)

## Sets language to "auto" (OS locale) or a specific language code ("pt_BR", "en", "es", "fr", "ja", "zh")
func set_language_mode(mode: String) -> void:
	current_language_mode = mode
	if mode == "auto":
		var os_loc = OS.get_locale()
		var resolved = _resolve_supported_locale(os_loc)
		TranslationServer.set_locale(resolved)
	else:
		TranslationServer.set_locale(mode)

func _resolve_supported_locale(raw_locale: String) -> String:
	var lower = raw_locale.to_lower()
	if lower.begins_with("pt"):
		return "pt_BR"
	elif lower.begins_with("es"):
		return "es"
	elif lower.begins_with("fr"):
		return "fr"
	elif lower.begins_with("ja"):
		return "ja"
	elif lower.begins_with("zh"):
		return "zh"
	elif lower.begins_with("en"):
		return "en"
	return "pt_BR"

func _create_watermark() -> void:
	# Persistent canvas layer on top of all scenes
	var canvas = CanvasLayer.new()
	canvas.name = "WatermarkLayer"
	canvas.layer = 120 # Top-most layer above menus and HUD
	add_child(canvas)
	
	var label = Label.new()
	label.name = "WatermarkLabel"
	label.text = "pre-alpha version 0.18"
	
	# Add child to the CanvasLayer first so anchors calculate against the viewport
	canvas.add_child(label)
	
	# Bottom wide alignment
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -36.0
	label.offset_bottom = -8.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	
	# Clean, semi-transparent watermark styling
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.65))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
