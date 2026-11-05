@tool
extends TileMapLayer
class_name RhythmTileMapLayer

## If true, automatically scans for platform tiles and creates targetable rhythm segments on ready.
@export var auto_generate_platforms: bool = true

## Custom data property name on tiles in the TileSet that flags them as a rhythm platform.
@export var platform_data_key: String = "is_platform"

## If true, every cell drawn in this TileMapLayer is considered a rhythm platform.
@export var treat_all_cells_as_platforms: bool = false

## Height of the platform surface within the 64x64 cell (pixels from the top of the cell).
@export var platform_visual_height: float = 32.0

## Vertical offset above the platform top surface where the player lands.
@export var landing_offset_y: float = -65.0

## Maximum distance from which the player can lock onto a platform (0 = unlimited).
@export var max_interaction_range: float = 900.0

## Visual glow settings for platform segments
@export var light_color: Color = Color(0.35, 0.75, 1.0, 1.0)
@export var light_energy: float = 1.2
@export var glow_size: float = 24.0

## Reticle corner offsets
@export var reticle_edge_inset: float = 24.0
@export var reticle_edge_height: float = 14.0

var platform_segments: Array[RhythmPlatformSegment] = []

func _ready() -> void:
	if auto_generate_platforms:
		# Call deferred to ensure tile data and tree transforms are fully initialized
		call_deferred("rebuild_platforms")

## Rebuilds all platform segments from the currently painted tiles.
func rebuild_platforms() -> void:
	# Clear existing segments
	for seg in platform_segments:
		if is_instance_valid(seg):
			seg.queue_free()
	platform_segments.clear()
	
	var platform_cells: Array[Vector2i] = []
	var used_cells = get_used_cells()
	
	for cell in used_cells:
		if treat_all_cells_as_platforms:
			platform_cells.append(cell)
		else:
			var data = get_cell_tile_data(cell)
			if data != null:
				var is_plat = data.get_custom_data(platform_data_key)
				if is_plat == true:
					platform_cells.append(cell)
					
	if platform_cells.is_empty():
		return
		
	# Group cells by Y coordinate (row)
	var rows: Dictionary = {}
	for cell in platform_cells:
		if not rows.has(cell.y):
			rows[cell.y] = []
		rows[cell.y].append(cell.x)
		
	var cell_size: Vector2 = Vector2(64.0, 64.0)
	if tile_set != null:
		cell_size = Vector2(tile_set.tile_size)
		
	for y in rows.keys():
		var x_list: Array = rows[y]
		x_list.sort()
		
		var seg_start_x: int = x_list[0]
		var seg_prev_x: int = x_list[0]
		
		for i in range(1, x_list.size()):
			var curr_x: int = x_list[i]
			if curr_x == seg_prev_x + 1:
				seg_prev_x = curr_x
			else:
				_spawn_segment(seg_start_x, seg_prev_x, y, cell_size)
				seg_start_x = curr_x
				seg_prev_x = curr_x
				
		_spawn_segment(seg_start_x, seg_prev_x, y, cell_size)

func _spawn_segment(start_x: int, end_x: int, y: int, cell_size: Vector2) -> void:
	# Compute local bounding box from tile cell coordinates
	var start_center = map_to_local(Vector2i(start_x, y))
	var end_center = map_to_local(Vector2i(end_x, y))
	
	var left_local_x = start_center.x - cell_size.x / 2.0
	var right_local_x = end_center.x + cell_size.x / 2.0
	var top_local_y = start_center.y - cell_size.y / 2.0
	var width_local = right_local_x - left_local_x
	var height_local = platform_visual_height
	
	# Convert local bounds to global world coordinates
	var top_left_global = to_global(Vector2(left_local_x, top_local_y))
	var bottom_right_global = to_global(Vector2(right_local_x, top_local_y + height_local))
	
	var global_bounds = Rect2(
		top_left_global,
		Vector2(bottom_right_global.x - top_left_global.x, bottom_right_global.y - top_left_global.y)
	)
	
	var segment = RhythmPlatformSegment.new()
	segment.name = "PlatSeg_" + str(start_x) + "_" + str(end_x) + "_" + str(y)
	add_child(segment)
	
	segment.setup_segment(
		global_bounds,
		self,
		landing_offset_y,
		max_interaction_range,
		light_color,
		glow_size,
		reticle_edge_inset,
		reticle_edge_height
	)
	
	platform_segments.append(segment)
