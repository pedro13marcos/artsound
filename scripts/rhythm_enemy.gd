extends Node2D
class_name RhythmEnemy

@export var entity_name: String = "Blade Master"
## Maximum distance (in pixels) within which the player can interact.
## Set to 0 to disable the range restriction.
@export var max_interaction_range: float = 350.0

# Light settings
@export var attack_light_color: Color = Color(1.0, 0.2, 0.25, 1.0) # Red on attack
@export var sharpen_light_color: Color = Color(0.2, 1.0, 0.4, 1.0) # Green on sharpen/vulnerable
@export var light_energy: float = 2.0
@export var glow_thickness: float = 2.5

# Target reticle indicator
var reticle: Node2D = null
var soundtrack_ref: AudioStreamPlayer = null
var sprite_node: Sprite2D = null
var outline_material: ShaderMaterial = null

# Pulse tracking by measure beat
var last_pulse_time: float = -999.0

func _ready() -> void:
	add_to_group("lockable_targets")
	_find_sprite()
	_create_reticle()
	_create_outline_shader()

func _find_sprite() -> void:
	sprite_node = get_node_or_null("Sprite2D")
	if sprite_node == null:
		sprite_node = get_node_or_null("Sprite2D2")

func _create_outline_shader() -> void:
	if sprite_node == null:
		return
	var shader = load("res://shaders/sprite_glow_outline.gdshader")
	outline_material = ShaderMaterial.new()
	outline_material.shader = shader
	outline_material.set_shader_parameter("glow_color", attack_light_color)
	outline_material.set_shader_parameter("glow_thickness", glow_thickness)
	outline_material.set_shader_parameter("intensity", 0.3)
	sprite_node.material = outline_material

func _create_reticle() -> void:
	reticle = Node2D.new()
	reticle.name = "TargetReticle"
	reticle.visible = false
	add_child(reticle)
	
	# Drawing callback for the diamond reticle
	var reticle_drawer = Control.new()
	reticle_drawer.draw.connect(func():
		var col = Color(1.0, 0.25, 0.35, 0.9)
		# Draw targeting diamond / brackets around enemy
		var pts = PackedVector2Array([
			Vector2(0, -90), Vector2(30, -60),
			Vector2(0, -30), Vector2(-30, -60),
			Vector2(0, -90)
		])
		reticle_drawer.draw_polyline(pts, col, 2.5, true)
		reticle_drawer.draw_circle(Vector2(0, -60), 3.0, Color.WHITE)
	)
	reticle.add_child(reticle_drawer)

func _process(_delta: float) -> void:
	if soundtrack_ref == null or not soundtrack_ref.playing:
		soundtrack_ref = get_tree().current_scene.find_child("soundTrack", true, false)
		if soundtrack_ref == null or not soundtrack_ref.playing:
			return
			
	var bpm = get_parent().bpm if "bpm" in get_parent() else 120.0
	var seconds_per_beat = Rhythm.getTimePerBeat(bpm)
	var measure_duration = PATTERN_DURATION_BEATS * seconds_per_beat
	var song_pos = Rhythm.getSongPosition(soundtrack_ref)
	
	# Current measure index & time elapsed within this measure
	var current_measure = int(floor(song_pos / measure_duration))
	var measure_start = current_measure * measure_duration
	
	# Check each action in the sequence across the current measure (and early lead-in to next measure)
	for act in action_sequence:
		var cue_abs_time = measure_start + (act["beat_offset"] * seconds_per_beat)
		# Trigger pulse as soon as song position reaches/crosses cue_abs_time (with a generous 0.09s tolerance)
		var diff = song_pos - cue_abs_time
		if diff >= -0.02 and diff < 0.08:
			if abs(last_pulse_time - cue_abs_time) > 0.15:
				last_pulse_time = cue_abs_time
				_pulse_light(act["type"], seconds_per_beat)
				break

func _pulse_light(action_type: String, seconds_per_beat: float) -> void:
	var is_green = (action_type == "sharpen" or action_type == "vulnerable")
	var target_col = sharpen_light_color if is_green else attack_light_color
	
	# Animate the pixel outline shader around visible parts of the sprite
	if outline_material != null:
		outline_material.set_shader_parameter("glow_color", target_col)
		var decay_time = seconds_per_beat * 0.45
		var tw = create_tween()
		outline_material.set_shader_parameter("intensity", light_energy)
		tw.tween_method(func(val: float):
			if outline_material:
				outline_material.set_shader_parameter("intensity", val)
		, light_energy, 0.25, decay_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# The lock-on symbol pulses with the glow, tinted by the action
	if reticle != null and reticle.visible:
		reticle.modulate = Color(target_col.r, target_col.g, target_col.b, 1.0)
		reticle.scale = Vector2(1.25, 1.25)
		var tw_ret = create_tween().set_parallel(true)
		tw_ret.tween_property(reticle, "scale", Vector2.ONE, seconds_per_beat * 0.45)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_ret.tween_property(reticle, "modulate:a", 0.65, seconds_per_beat * 0.45)

func set_targeted(is_targeted: bool) -> void:
	if reticle:
		reticle.visible = is_targeted
		if is_targeted:
			var tw = create_tween()
			reticle.scale = Vector2(1.4, 1.4)
			tw.tween_property(reticle, "scale", Vector2(1.0, 1.0), 0.2)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Rhythmic pattern represented by musical intervals (in beats)
# Based on your musical pattern:
# Bar has:
# - Two eighth notes (0.5 beats each) + quarter note (1 beat) -> Attack!
# - Followed by two quarter notes (1 beat each) -> Sharpening/Vulnerable!
const PATTERN_DURATION_BEATS = 4.0

# Relative beat offsets within a 4-beat measure:
# Beat 0.0: Attack 1 (eighth note)
# Beat 0.5: Attack 2 (eighth note)
# Beat 1.0: Attack 3 (quarter note)
# Beat 2.0: Sharpen 1 (quarter note - opportunity to hit!)
# Beat 3.0: Sharpen 2 (quarter note - opportunity to hit!)
var action_sequence = [
	{"beat_offset": 0.0, "type": "attack"},
	{"beat_offset": 0.5, "type": "attack"},
	{"beat_offset": 1.0, "type": "attack"},
	{"beat_offset": 2.0, "type": "sharpen"},
	{"beat_offset": 3.0, "type": "sharpen"}
]

# This function is automatically queried by RhythmHUD when this enemy is locked on!
func get_upcoming_rhythm_cues(current_song_time: float, lookahead_duration: float) -> Array[Dictionary]:
	var cues: Array[Dictionary] = []
	var bpm = get_parent().bpm if "bpm" in get_parent() else 120.0
	var seconds_per_beat = Rhythm.getTimePerBeat(bpm)
	var measure_duration = PATTERN_DURATION_BEATS * seconds_per_beat
	
	# Determine current measure index
	var current_measure = int(floor(current_song_time / measure_duration))
	
	# Check this measure and next measure
	for m in [current_measure, current_measure + 1]:
		var measure_start = m * measure_duration
		for action in action_sequence:
			var cue_time = measure_start + (action["beat_offset"] * seconds_per_beat)
			if cue_time >= current_song_time - 0.05 and cue_time <= current_song_time + lookahead_duration:
				cues.append({
					"time": cue_time,
					"type": action["type"]
				})
	return cues
