extends Node2D

func _ready() -> void:
	#to set up locations
	TranslationServer.set_locale("pt");
	_create_watermark()

func _create_watermark() -> void:
	# Persistent canvas layer on top of all scenes
	var canvas = CanvasLayer.new()
	canvas.name = "WatermarkLayer"
	canvas.layer = 120 # Top-most layer above menus and HUD
	add_child(canvas)
	
	var label = Label.new()
	label.name = "WatermarkLabel"
	label.text = "pre-alpha version 0.17"
	
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
#
#func _process(delta: float) -> void:
	#pass;
		#
#
#func judgeHit():
	#var songPosition;
	#var currentBeat;
	#
	##time and song - to be implemented on the world and not the player
	#songPosition = soundTrack.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency();
	#currentBeat = int(floor(songPosition/secondsPerBeat));
	#
	##Check if the song is closer to current or next beat
	#if abs(songPosition - (currentBeat*secondsPerBeat))<abs(((currentBeat+1)*secondsPerBeat)-songPosition):
		#referencePosition = songPosition - (currentBeat*secondsPerBeat);
	#else:
		#referencePosition = ((currentBeat+1)*secondsPerBeat)-songPosition;
		#
	##check how close it is from the beat
	#var offset = abs(referencePosition - songPosition);
	#if offset < 0.05:
		#print("PERFECT!");
	#elif offset < 0.10:
		#print("GREAT");
	#elif offset < 0.15:
		#print("GOOD");
	#else:
		#print("MISS");

	
