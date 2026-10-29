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
	var viewport = get_viewport()
	
	# ----------------------------------------------------
	# 1. Controller Right Stick Look-Ahead
	# ----------------------------------------------------
	# Check if player is NOT currently locking onto an object with the stick
	var rx = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var ry = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	var stick_vec = Vector2(rx, ry)
	
	if stick_vec.length() > 0.2:
		target_offset = Vector2(stick_vec.x * max_offset.x, stick_vec.y * max_offset.y)
	elif viewport:
		# ----------------------------------------------------
		# 2. Mouse Edge / Look-Ahead Panning
		# ----------------------------------------------------
		var mouse_pos = viewport.get_mouse_position()
		var view_size = viewport.get_visible_rect().size
		
		if view_size.x > 0 and view_size.y > 0:
			# Normalized viewport position: -1.0 (left/top) to +1.0 (right/bottom)
			var norm_x = ((mouse_pos.x / view_size.x) - 0.5) * 2.0
			var norm_y = ((mouse_pos.y / view_size.y) - 0.5) * 2.0
			
			# Add a deadzone in the center so the camera stays centered unless moving toward the edges
			var deadzone = 0.35
			var edge_x = 0.0
			var edge_y = 0.0
			
			if abs(norm_x) > deadzone:
				edge_x = sign(norm_x) * ((abs(norm_x) - deadzone) / (1.0 - deadzone))
			if abs(norm_y) > deadzone:
				edge_y = sign(norm_y) * ((abs(norm_y) - deadzone) / (1.0 - deadzone))
				
			target_offset = Vector2(edge_x * max_offset.x, edge_y * max_offset.y)

	# Smoothly interpolate pan offset
	current_pan_offset = current_pan_offset.lerp(target_offset, delta * pan_smooth_speed)
	
	# Keep player in view (offset from player)
	position = player.global_position + current_pan_offset
