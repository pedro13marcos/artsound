@tool
extends RhythmPlatform
class_name RhythmPlatformSegment

## Contiguous bounding rectangle of this platform segment in global world coordinates.
var segment_bounds: Rect2 = Rect2()
## The TileMap or TileMapLayer that owns these platform tiles.
var source_tile_map: Node = null

func setup_segment(
	p_bounds: Rect2,
	p_source_map: Node,
	p_landing_offset: float = -65.0,
	p_max_range: float = 900.0,
	p_light_color: Color = Color(0.35, 0.75, 1.0, 1.0),
	p_glow_size: float = 24.0,
	p_reticle_inset: float = 24.0,
	p_reticle_height: float = 14.0
) -> void:
	segment_bounds = p_bounds
	source_tile_map = p_source_map
	landing_offset_y = p_landing_offset
	max_interaction_range = p_max_range
	light_color = p_light_color
	glow_size = p_glow_size
	reticle_edge_inset = p_reticle_inset
	reticle_edge_height = p_reticle_height
	
	size = p_bounds.size
	entity_name = "Platform " + str(int(p_bounds.position.x)) + "x" + str(int(p_bounds.position.y))
	
	# Center of the platform in world space
	global_position = p_bounds.position + p_bounds.size / 2.0
	
	if glow != null:
		glow.global_position = global_position
		glow.setup(_get_half_extents(), light_color, glow_size)

func _get_half_extents() -> Vector2:
	return segment_bounds.size / 2.0

## Returns the landing corner (left or right) of the platform closest to the player
func get_closest_corner_to(player_pos: Vector2) -> Vector2:
	var top_y = segment_bounds.position.y + landing_offset_y
	var left_x = segment_bounds.position.x + reticle_edge_inset
	var right_x = segment_bounds.position.x + segment_bounds.size.x - reticle_edge_inset
	
	# Narrow platform safety: avoid crossed corners
	if left_x > right_x:
		var mid = (left_x + right_x) / 2.0
		left_x = mid
		right_x = mid
		
	var left_corner = Vector2(left_x, top_y)
	var right_corner = Vector2(right_x, top_y)
	
	if player_pos.distance_to(left_corner) <= player_pos.distance_to(right_corner):
		return left_corner
	return right_corner

## Returns the reticle position just above the closest platform corner
func get_reticle_position(player_pos: Vector2) -> Vector2:
	var top_y = segment_bounds.position.y - reticle_edge_height
	var left_x = segment_bounds.position.x + reticle_edge_inset
	var right_x = segment_bounds.position.x + segment_bounds.size.x - reticle_edge_inset
	
	if left_x > right_x:
		var mid = (left_x + right_x) / 2.0
		left_x = mid
		right_x = mid
		
	var left_pos = Vector2(left_x, top_y)
	var right_pos = Vector2(right_x, top_y)
	
	if player_pos.distance_to(left_pos) <= player_pos.distance_to(right_pos):
		return left_pos
	return right_pos

func get_landing_position(player_pos: Vector2 = Vector2.ZERO) -> Vector2:
	if player_pos != Vector2.ZERO:
		return get_closest_corner_to(player_pos)
	return Vector2(global_position.x, segment_bounds.position.y + landing_offset_y)

func set_targeted(is_targeted: bool) -> void:
	super.set_targeted(is_targeted)
	if glow != null:
		if is_targeted:
			glow.pulse(0.2, light_energy * 1.5, 0.6)
		else:
			glow.pulse(0.2, light_energy, 0.2)
