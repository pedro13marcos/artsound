extends StaticBody2D
class_name RhythmPlatform

@export var entity_name: String = "Platform"
@export var landing_offset_y: float = -65.0 # Landing point above the platform surface
## Maximum distance (in pixels) within which the player can interact.
## Set to 0 to disable the range restriction.
@export var max_interaction_range: float = 600.0

# Light and glow settings
@export var light_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var light_energy: float = 1.2
## Thickness of the glow around the platform (pixels)
@export var glow_size: float = 26.0
## How far the lock-on symbol sits above the platform edge (smaller = closer)
@export var reticle_edge_height: float = 14.0
## How far the lock-on symbol sits inward from the platform's corner
@export var reticle_edge_inset: float = 10.0

var reticle: Node2D = null
var base_modulate: Color = Color(0.133, 0.133, 0.133, 1.0)
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var glow: GlowOutline = null
var last_pulsed_beat: int = -1
var soundtrack_ref: AudioStreamPlayer = null

func _ready() -> void:
	add_to_group("lockable_targets")
	add_to_group("rhythm_platforms")
	if sprite:
		base_modulate = sprite.modulate
	_create_reticle()
	_create_light()

func _create_reticle() -> void:
	reticle = Node2D.new()
	reticle.name = "PlatformReticle"
	reticle.visible = false
	reticle.top_level = true # Draw at world position so corner offset isn't affected by parent transform
	add_child(reticle)
	
	# Drawing callback for platform jump landing beacon
	var reticle_drawer = Control.new()
	reticle_drawer.draw.connect(func():
		var col = Color(0.3, 0.85, 1.0, 0.95)
		var center = Vector2.ZERO
		reticle_drawer.draw_arc(center, 18.0, 0, TAU, 32, col, 2.5)
		reticle_drawer.draw_circle(center, 4.0, Color.WHITE)
		# Arrow pointing down to landing spot
		reticle_drawer.draw_line(center + Vector2(0, -25), center + Vector2(0, -10), col, 2.5)
		reticle_drawer.draw_line(center + Vector2(-6, -16), center + Vector2(0, -10), col, 2.5)
		reticle_drawer.draw_line(center + Vector2(6, -16), center + Vector2(0, -10), col, 2.5)
	)
	reticle.add_child(reticle_drawer)

func _create_light() -> void:
	# Glow around the whole platform (world-space node so the body's scale doesn't distort it)
	glow = GlowOutline.new()
	glow.name = "RhythmGlow"
	glow.top_level = true
	add_child(glow)
	glow.global_position = global_position
	glow.setup(_get_half_extents(), light_color, glow_size)

func _process(_delta: float) -> void:
	if soundtrack_ref == null or not soundtrack_ref.playing:
		soundtrack_ref = get_tree().current_scene.find_child("soundTrack", true, false)
		if soundtrack_ref == null or not soundtrack_ref.playing:
			return
			
	var bpm = get_parent().bpm if "bpm" in get_parent() else 120.0
	var seconds_per_beat = Rhythm.getTimePerBeat(bpm)
	var song_pos = Rhythm.getSongPosition(soundtrack_ref)
	var current_beat = int(floor(song_pos / seconds_per_beat))
	
	if current_beat > last_pulsed_beat:
		last_pulsed_beat = current_beat
		_pulse_light(seconds_per_beat)

func _pulse_light(seconds_per_beat: float) -> void:
	if glow != null:
		glow.pulse(seconds_per_beat * 0.7, light_energy, 0.2)
	# The lock-on symbol pulses together with the glow
	if reticle != null and reticle.visible:
		reticle.scale = Vector2(1.3, 1.3)
		reticle.modulate.a = 1.0
		var tw = create_tween().set_parallel(true)
		tw.tween_property(reticle, "scale", Vector2.ONE, seconds_per_beat * 0.6)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(reticle, "modulate:a", 0.65, seconds_per_beat * 0.6)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _get_half_extents() -> Vector2:
	var half_w = 100.0
	var half_h = 30.0
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var rect = collision_shape.shape as RectangleShape2D
		half_w = (rect.size.x * scale.x) / 2.0
		half_h = (rect.size.y * scale.y) / 2.0
	elif sprite and sprite.texture:
		half_w = (sprite.texture.get_width() * sprite.scale.x * scale.x) / 2.0
		half_h = (sprite.texture.get_height() * sprite.scale.y * scale.y) / 2.0
	return Vector2(half_w, half_h)

## Lock-on symbol position: right above the platform edge nearest to the player
func get_reticle_position(player_pos: Vector2) -> Vector2:
	var ext = _get_half_extents()
	var left = Vector2(global_position.x - ext.x + reticle_edge_inset, global_position.y - ext.y - reticle_edge_height)
	var right = Vector2(global_position.x + ext.x - reticle_edge_inset, left.y)
	return left if player_pos.distance_to(left) <= player_pos.distance_to(right) else right

## Calculate the corner of the platform closest to the player
func get_closest_corner_to(player_pos: Vector2) -> Vector2:
	var half_w = _get_half_extents().x
	var half_h = _get_half_extents().y
	var top_surface_y = global_position.y - half_h + landing_offset_y
	var left_corner = Vector2(global_position.x - half_w, top_surface_y)
	var right_corner = Vector2(global_position.x + half_w, top_surface_y)
	
	if player_pos.distance_to(left_corner) <= player_pos.distance_to(right_corner):
		return left_corner
	else:
		return right_corner

func update_reticle_position(player_pos: Vector2) -> void:
	if reticle and reticle.visible:
		reticle.global_position = get_reticle_position(player_pos)

func set_targeted(is_targeted: bool) -> void:
	if reticle:
		reticle.visible = is_targeted
		if is_targeted:
			var player = get_tree().current_scene.find_child("Player", true, false)
			if player:
				reticle.global_position = get_reticle_position(player.global_position)
			else:
				reticle.global_position = get_landing_position()
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

func get_landing_position(player_pos: Vector2 = Vector2.ZERO) -> Vector2:
	if player_pos != Vector2.ZERO:
		return get_closest_corner_to(player_pos)
	return global_position + Vector2(0, landing_offset_y)
