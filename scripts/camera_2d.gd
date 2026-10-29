extends Camera2D

@export var player: CharacterBody2D

# Maximum pan offset from player position
@export var max_offset: Vector2 = Vector2(240.0, 140.0)
@export var pan_smooth_speed: float = 6.0
## Camera zoom. Below 1.0 shows more of the world (zoomed out).
@export var camera_zoom: float = 0.8

var current_pan_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	zoom = Vector2(camera_zoom, camera_zoom)

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	var target_offset = Vector2.ZERO
	
	# ----------------------------------------------------
	# 1. Controller Right Stick Look-Ahead
	# ----------------------------------------------------
	var rx = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var ry = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	var stick_vec = Vector2(rx, ry)
	
	if stick_vec.length() > 0.2:
		target_offset = Vector2(stick_vec.x * max_offset.x, stick_vec.y * max_offset.y)

	# Smoothly interpolate pan offset
	current_pan_offset = current_pan_offset.lerp(target_offset, delta * pan_smooth_speed)
	
	# Keep player in view (offset from player)
	position = player.global_position + current_pan_offset
