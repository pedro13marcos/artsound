extends CanvasLayer
class_name RhythmHUD

# Track configurations
@export var track_width: float = 500.0        # Total track width (left + right = 250px each)
@export var beats_ahead: float = 2.0          # Number of beats visible in advance
@export var auto_find_soundtrack: bool = true

# Textures assigned in the scene
@export var icon_enemy_texture: Texture2D
@export var icon_platform_texture: Texture2D

# Theme Colors
const COLOR_METRONOME_BEAT  = Color(0.2, 0.8, 1.0, 0.9)
const COLOR_METRONOME_SUB   = Color(0.2, 0.8, 1.0, 0.25)
const COLOR_ENEMY_ATTACK    = Color(1.0, 0.2, 0.3, 0.95)
const COLOR_ENEMY_SHARPEN   = Color(0.2, 1.0, 0.45, 0.95)
const COLOR_ENEMY_NEUTRAL   = Color(1.0, 0.85, 0.2, 0.9)
const COLOR_OUT_OF_RANGE    = Color(0.8, 0.5, 0.15, 0.85)

@onready var heart: Sprite2D         = $CenterContainer/Control/Heart
@onready var track_drawer: Control   = $CenterContainer/Control/TrackDrawer
@onready var target_icon: Sprite2D   = $CenterContainer/Control/TargetIcon
@onready var target_label: Label     = $CenterContainer/Control/TargetLabel
@onready var range_label: Label      = $CenterContainer/Control/RangeLabel

var soundtrack: AudioStreamPlayer
var current_bpm: float = 120.0
var last_pulsed_beat: int = -1

var locked_target: Node = null
var target_cues: Array[Dictionary] = []

# Cached player reference for range check
var _player: Node2D = null

# True when the player is within the target's interaction range
var target_in_range: bool = false

func _ready() -> void:
	if auto_find_soundtrack:
		soundtrack = get_tree().current_scene.find_child("soundTrack", true, false)
		if get_tree().current_scene.get("bpm") != null:
			current_bpm = get_tree().current_scene.bpm
	
	_player = get_tree().current_scene.find_child("Player", true, false)
	
	# Load textures from the scene exports if not set already
	if icon_enemy_texture == null:
		icon_enemy_texture = load("res://image/icon_enemy.png")
	if icon_platform_texture == null:
		icon_platform_texture = load("res://image/icon_platform.png")
	
	# Connect TrackDrawer draw signal to custom draw function
	track_drawer.draw.connect(_on_track_draw)
	
	# Position TargetIcon at the right end of the track
	target_icon.position = Vector2(track_width / 2.0 + 32.0, 0)
	target_icon.visible = false

func _process(_delta: float) -> void:
	if soundtrack == null or not soundtrack.playing:
		# Retry finding soundtrack if not found yet
		if auto_find_soundtrack and soundtrack == null:
			soundtrack = get_tree().current_scene.find_child("soundTrack", true, false)
		return
	
	if get_tree().current_scene.get("bpm") != null:
		current_bpm = get_tree().current_scene.bpm
		
	var song_pos = Rhythm.getSongPosition(soundtrack)
	var seconds_per_beat = Rhythm.getTimePerBeat(current_bpm)
	var current_beat = int(floor(song_pos / seconds_per_beat))
	
	# Pulse heart on beat arrival
	if current_beat > last_pulsed_beat:
		last_pulsed_beat = current_beat
		pulse_heart(seconds_per_beat)
	
	# Update pattern cues from locked target if available
	if locked_target != null and locked_target.has_method("get_upcoming_rhythm_cues"):
		target_cues = locked_target.get_upcoming_rhythm_cues(song_pos, beats_ahead * seconds_per_beat)
	
	# Update range check and icon tint
	_update_range_state()
	
	# Redraw moving rhythm bars
	track_drawer.queue_redraw()

func _update_range_state() -> void:
	if locked_target == null or _player == null:
		target_in_range = false
		if range_label:
			range_label.text = ""
		return
	
	# Determine if player has clear line-of-sight using raycast
	var has_los = true
	if _player.has_method("has_line_of_sight_to"):
		has_los = _player.has_line_of_sight_to(locked_target)
	
	var max_range: float = 0.0
	if "max_interaction_range" in locked_target:
		max_range = locked_target.max_interaction_range
	
	var dist = _player.global_position.distance_to(locked_target.global_position)
	var in_distance = (max_range <= 0.0) or (dist <= max_range)
	
	target_in_range = has_los and in_distance
	
	# Show line-of-sight & distance feedback below the target name
	if range_label:
		if not has_los:
			range_label.text = "No line of sight (Blocked)"
			range_label.modulate = Color(1.0, 0.3, 0.3, 0.9)
		elif in_distance:
			range_label.text = "Target in sight  [%.0f / %.0f]" % [dist, max_range] if max_range > 0 else "Target in sight"
			range_label.modulate = Color(0.4, 1.0, 0.55, 0.85)
		else:
			range_label.text = "Out of view range  [%.0f / %.0f]" % [dist, max_range]
			range_label.modulate = Color(1.0, 0.5, 0.25, 0.85)

func pulse_heart(seconds_per_beat: float) -> void:
	var tween = create_tween()
	heart.scale = Vector2(0.48, 0.48)
	tween.tween_property(heart, "scale", Vector2(0.40, 0.40), seconds_per_beat * 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func lock_on_target(target: Node) -> void:
	if locked_target == target:
		return
	if locked_target != null and locked_target.has_method("set_targeted"):
		locked_target.set_targeted(false)
		
	locked_target = target
	if locked_target != null and locked_target.has_method("set_targeted"):
		locked_target.set_targeted(true)
		
	if target != null and "entity_name" in target:
		target_label.text = "[ " + str(target.entity_name) + " ]"
	elif target != null:
		target_label.text = "[ " + target.name + " ]"
	else:
		target_label.text = ""
	
	# Update the target icon with the right graphic and show it
	_refresh_target_icon(target)

func _refresh_target_icon(target: Node) -> void:
	if target == null:
		target_icon.visible = false
		if range_label:
			range_label.text = ""
		return
	
	# Pick icon based on type
	if target is RhythmPlatform:
		target_icon.texture = icon_platform_texture
		target_icon.modulate = Color(0.3, 0.85, 1.0, 0.95)
	else:
		# Default: enemy / interactable
		target_icon.texture = icon_enemy_texture
		target_icon.modulate = Color(1.0, 0.35, 0.5, 0.95)
	
	# Animate in
	target_icon.visible = true
	target_icon.scale = Vector2(1.1, 1.1)
	var tw = create_tween()
	tw.tween_property(target_icon, "scale", Vector2(0.7, 0.7), 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func clear_target() -> void:
	if locked_target != null and locked_target.has_method("set_targeted"):
		locked_target.set_targeted(false)
	locked_target = null
	target_cues.clear()
	target_label.text = ""
	target_icon.visible = false
	if range_label:
		range_label.text = ""
	target_in_range = false

func _on_track_draw() -> void:
	if soundtrack == null or not soundtrack.playing:
		return
		
	var half_width = track_width / 2.0
	var song_pos = Rhythm.getSongPosition(soundtrack)
	var seconds_per_beat = Rhythm.getTimePerBeat(current_bpm)
	var view_window = beats_ahead * seconds_per_beat
	
	# ----------------------------------------------------
	# 1. DRAW BASE TRACK LINES (Background rails)
	# ----------------------------------------------------
	# Left rail (Metronome)
	track_drawer.draw_line(Vector2(-half_width, 0), Vector2(-18, 0), Color(0.2, 0.5, 0.8, 0.4), 3.0)
	# Right rail (Enemy / Target cues)
	var right_rail_color = Color(0.8, 0.3, 0.3, 0.4) if locked_target != null else Color(0.5, 0.5, 0.5, 0.25)
	track_drawer.draw_line(Vector2(18, 0), Vector2(half_width, 0), right_rail_color, 3.0)
	
	# Center strike goal markers
	track_drawer.draw_arc(Vector2.ZERO, 20.0, 0, TAU, 32, Color(1, 1, 1, 0.3), 1.5)
	
	# ----------------------------------------------------
	# 2. LEFT TRACK: GLOBAL TEMPO (Metronome Bars)
	# ----------------------------------------------------
	# Calculate current and upcoming beats
	var base_beat = int(floor(song_pos / seconds_per_beat))
	
	for i in range(int(beats_ahead) + 2):
		var target_beat = base_beat + i
		var beat_timestamp = target_beat * seconds_per_beat
		var time_diff = beat_timestamp - song_pos
		
		# If it's incoming within our lookahead window
		if time_diff >= 0.0 and time_diff <= view_window:
			var progress = time_diff / view_window  # 1.0 (far left) to 0.0 (center)
			var x_pos = -progress * half_width
			
			# Main beat bar
			var bar_height = 24.0
			var bar_width = 3.5
			track_drawer.draw_line(Vector2(x_pos, -bar_height / 2.0), Vector2(x_pos, bar_height / 2.0), COLOR_METRONOME_BEAT, bar_width)
			
			# Subdivision (eighth-note guide)
			if i < int(beats_ahead) + 1:
				var sub_timestamp = beat_timestamp + (seconds_per_beat / 2.0)
				var sub_diff = sub_timestamp - song_pos
				if sub_diff >= 0.0 and sub_diff <= view_window:
					var sub_progress = sub_diff / view_window
					var sub_x = -sub_progress * half_width
					track_drawer.draw_line(Vector2(sub_x, -bar_height / 4.0), Vector2(sub_x, bar_height / 4.0), COLOR_METRONOME_SUB, 2.0)

	# ----------------------------------------------------
	# 3. RIGHT TRACK: LOCKED TARGET ACTIONS (Attacks / Vulnerability)
	# ----------------------------------------------------
	if locked_target == null:
		# Draw subtle idle tick guides when not targeting an enemy
		for i in range(1, int(beats_ahead) + 1):
			var idle_x = (float(i) / beats_ahead) * half_width
			track_drawer.draw_line(Vector2(idle_x, -5), Vector2(idle_x, 5), Color(1, 1, 1, 0.15), 1.5)
		return
	
	# If out of range, draw a faint "out of range" overlay across the right track
	if not target_in_range:
		var oor_color = COLOR_OUT_OF_RANGE
		for i in range(1, int(beats_ahead) + 1):
			var idle_x = (float(i) / beats_ahead) * half_width
			track_drawer.draw_line(Vector2(idle_x, -10), Vector2(idle_x, 10), Color(oor_color.r, oor_color.g, oor_color.b, 0.25), 2.0)
		# Diagonal "locked" X in the right half
		track_drawer.draw_line(Vector2(20, -14), Vector2(half_width - 20, 14), Color(oor_color.r, oor_color.g, oor_color.b, 0.35), 1.5)
		track_drawer.draw_line(Vector2(20, 14), Vector2(half_width - 20, -14), Color(oor_color.r, oor_color.g, oor_color.b, 0.35), 1.5)
		return
	
	# Draw cues provided by target (only when in range)
	for cue in target_cues:
		var cue_time: float = cue.get("time", 0.0)
		var cue_type: String = cue.get("type", "attack")
		var time_diff = cue_time - song_pos
		
		if time_diff >= -0.05 and time_diff <= view_window:
			var progress = max(0.0, time_diff) / view_window
			var x_pos = progress * half_width
			
			var cue_color = COLOR_ENEMY_ATTACK
			var cue_height = 28.0
			var cue_thickness = 4.0
			
			if cue_type == "sharpen" or cue_type == "vulnerable":
				cue_color = COLOR_ENEMY_SHARPEN
				cue_height = 32.0
				cue_thickness = 5.0
			elif cue_type == "neutral":
				cue_color = COLOR_ENEMY_NEUTRAL
				cue_height = 20.0
			
			# Draw the incoming cue bar on the right side
			track_drawer.draw_line(Vector2(x_pos, -cue_height / 2.0), Vector2(x_pos, cue_height / 2.0), cue_color, cue_thickness)
			
			# Draw an accent pip on top
			track_drawer.draw_circle(Vector2(x_pos, -cue_height / 2.0 - 5.0), 3.0, Color(1.0, 1.0, 1.0, 0.9))
