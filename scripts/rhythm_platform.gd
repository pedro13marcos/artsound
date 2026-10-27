extends StaticBody2D
class_name RhythmPlatform

@export var entity_name: String = "Platform"
@export var landing_offset_y: float = -65.0 # Landing point above the platform surface

var reticle: Node2D = null
var base_modulate: Color = Color(0.133, 0.133, 0.133, 1.0)
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("lockable_targets")
	add_to_group("rhythm_platforms")
	if sprite:
		base_modulate = sprite.modulate
	_create_reticle()

func _create_reticle() -> void:
	reticle = Node2D.new()
	reticle.name = "PlatformReticle"
	reticle.visible = false
	add_child(reticle)
	
	# Drawing callback for platform jump landing beacon
	var reticle_drawer = Control.new()
	reticle_drawer.draw.connect(func():
		var col = Color(0.3, 0.85, 1.0, 0.95)
		# Landing marker above platform
		var center = Vector2(0, landing_offset_y)
		reticle_drawer.draw_arc(center, 18.0, 0, TAU, 32, col, 2.5)
		reticle_drawer.draw_circle(center, 4.0, Color.WHITE)
		# Arrow pointing down to landing spot
		reticle_drawer.draw_line(center + Vector2(0, -25), center + Vector2(0, -10), col, 2.5)
		reticle_drawer.draw_line(center + Vector2(-6, -16), center + Vector2(0, -10), col, 2.5)
		reticle_drawer.draw_line(center + Vector2(6, -16), center + Vector2(0, -10), col, 2.5)
	)
	reticle.add_child(reticle_drawer)

func set_targeted(is_targeted: bool) -> void:
	if reticle:
		reticle.visible = is_targeted
		if is_targeted:
			var tw = create_tween()
			reticle.scale = Vector2(1.3, 1.3)
			tw.tween_property(reticle, "scale", Vector2(1.0, 1.0), 0.18)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if sprite:
		if is_targeted:
			sprite.modulate = Color(0.35, 0.55, 0.85, 1.0)
		else:
			sprite.modulate = base_modulate

# Provides rhythmic cues to RhythmHUD when locked onto this platform
func get_upcoming_rhythm_cues(current_song_time: float, lookahead_duration: float) -> Array[Dictionary]:
	var cues: Array[Dictionary] = []
	var bpm = get_parent().bpm if "bpm" in get_parent() else 120.0
	var seconds_per_beat = Rhythm.getTimePerBeat(bpm)
	
	# Platforms can be jumped to on any beat!
	var current_beat = int(floor(current_song_time / seconds_per_beat))
	for b in range(current_beat, current_beat + 4):
		var cue_time = b * seconds_per_beat
		if cue_time >= current_song_time - 0.05 and cue_time <= current_song_time + lookahead_duration:
			cues.append({
				"time": cue_time,
				"type": "sharpen" # Green cue: Opportunity to interact / jump!
			})
	return cues

func get_landing_position() -> Vector2:
	return global_position + Vector2(0, landing_offset_y)
