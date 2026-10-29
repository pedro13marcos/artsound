@tool
extends StaticBody2D
class_name RhythmPlatform

@export var entity_name: String = "Platform"
## Physical size of the platform in pixels (Width, Height).
## Changing this automatically resizes the collision shape, sprite/texture, and glow outline!
@export var size: Vector2 = Vector2(200.0, 36.0):
	set(val):
		size = val
		_apply_size()

## Optional custom texture/tileset image. If null, a clean styled platform surface is drawn.
@export var custom_texture: Texture2D = null:
	set(val):
		custom_texture = val
		_apply_size()

@export var platform_color: Color = Color(0.133, 0.133, 0.16, 1.0):
	set(val):
		platform_color = val
		_apply_size()

@export var border_color: Color = Color(0.35, 0.5, 0.8, 0.8):
	set(val):
		border_color = val
		_apply_size()

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
var glow: GlowOutline = null
var last_pulsed_beat: int = -1
var soundtrack_ref: AudioStreamPlayer = null

var collision_shape: CollisionShape2D = null
var visual_rect: Control = null
var sprite_node: Node2D = null

func _ready() -> void:
	add_to_group("lockable_targets")
	add_to_group("rhythm_platforms")
	_resolve_child_nodes()
	
	if not Engine.is_editor_hint():
		_create_reticle()
		_create_light()
		
	_apply_size()

func _resolve_child_nodes() -> void:
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape2D")
	if visual_rect == null:
		visual_rect = get_node_or_null("VisualRect")
	if sprite_node == null:
		sprite_node = get_node_or_null("Sprite2D")

func _apply_size() -> void:
	_resolve_child_nodes()
		
	if collision_shape:
		# If it's a standalone modular platform with custom size property
		if visual_rect != null:
			if collision_shape.shape == null or not collision_shape.shape is RectangleShape2D:
				collision_shape.shape = RectangleShape2D.new()
			(collision_shape.shape as RectangleShape2D).size = size
			collision_shape.position = Vector2.ZERO
		
	if visual_rect:
		visual_rect.size = size
		visual_rect.position = -size / 2.0
		if custom_texture != null and visual_rect is NinePatchRect:
			(visual_rect as NinePatchRect).texture = custom_texture
		if custom_texture == null:
			visual_rect.self_modulate = platform_color
		else:
			visual_rect.self_modulate = Color.WHITE
			
	if glow != null:
		glow.setup(_get_half_extents(), light_color, glow_size)

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
	glow = GlowOutline.new()
	glow.name = "RhythmGlow"
	glow.top_level = true
	add_child(glow)
	glow.global_position = global_position
	glow.setup(_get_half_extents(), light_color, glow_size)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
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
		glow.global_position = global_position
		glow.setup(_get_half_extents(), light_color, glow_size)
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
	_resolve_child_nodes()
	if visual_rect != null:
		return size / 2.0
	if collision_shape != null and collision_shape.shape is RectangleShape2D:
		var raw_size: Vector2 = (collision_shape.shape as RectangleShape2D).size
		# Scale by collision shape's local scale AND the platform node's scale
		var total_scale: Vector2 = Vector2(abs(scale.x * collision_shape.scale.x), abs(scale.y * collision_shape.scale.y))
		return raw_size * total_scale / 2.0
	if sprite_node != null and sprite_node is Sprite2D and (sprite_node as Sprite2D).texture != null:
		var tex: Texture2D = (sprite_node as Sprite2D).texture
		var total_scale: Vector2 = Vector2(abs(scale.x * sprite_node.scale.x), abs(scale.y * sprite_node.scale.y))
		return Vector2(tex.get_width(), tex.get_height()) * total_scale / 2.0
	return size / 2.0

## Lock-on symbol position: right above the platform edge nearest to the player
func get_reticle_position(player_pos: Vector2) -> Vector2:
	var ext = _get_half_extents()
	var left = Vector2(global_position.x - ext.x + reticle_edge_inset, global_position.y - ext.y - reticle_edge_height)
	var right = Vector2(global_position.x + ext.x - reticle_edge_inset, left.y)
	return left if player_pos.distance_to(left) <= player_pos.distance_to(right) else right

## Calculate the corner of the platform closest to the player
func get_closest_corner_to(player_pos: Vector2) -> Vector2:
	var ext = _get_half_extents()
	var half_w = ext.x
	var half_h = ext.y
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
			tw.tween_property(reticle, "scale", Vector2.ONE, 0.18)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if visual_rect:
		if is_targeted:
			visual_rect.self_modulate = Color(0.35, 0.55, 0.9, 1.0)
		else:
			visual_rect.self_modulate = platform_color
	elif sprite_node:
		if is_targeted:
			sprite_node.self_modulate = Color(0.35, 0.55, 0.9, 1.0)
		else:
			sprite_node.self_modulate = Color(0.133, 0.133, 0.133, 1.0)

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
