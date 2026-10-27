extends Node2D
class_name RhythmEnemy

@export var entity_name: String = "Blade Master"

# Target reticle indicator
var reticle: Node2D = null

func _ready() -> void:
	add_to_group("lockable_targets")
	_create_reticle()

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
