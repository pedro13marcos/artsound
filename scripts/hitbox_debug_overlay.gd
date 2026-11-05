extends Node2D

var _collected_shapes: Array[CollisionShape2D] = []
var _scan_timer: float = 0.0

func _process(delta: float) -> void:
	if not Global.debug_show_hitboxes:
		return
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.25 # Refresh shape list 4 times a second
		_refresh_shapes()
	queue_redraw()

func _refresh_shapes() -> void:
	_collected_shapes.clear()
	var scene = get_tree().current_scene
	if scene:
		_recurse_collect(scene)

func _recurse_collect(node: Node) -> void:
	if node == null:
		return
	if node is CollisionShape2D and node.shape != null:
		_collected_shapes.append(node)
	for child in node.get_children():
		_recurse_collect(child)

func _draw() -> void:
	if not Global.debug_show_hitboxes:
		return
	
	for shape_node in _collected_shapes:
		if not is_instance_valid(shape_node) or not shape_node.is_inside_tree() or shape_node.shape == null:
			continue
		
		var p = shape_node.get_parent()
		var p_name = p.name.to_lower() if p else ""
		var is_disabled = shape_node.disabled or (p is Area2D and (not p.monitoring and not p.monitorable))
		
		var fill_col: Color
		var line_col: Color
		var label_text: String = ""
		
		if "attack" in p_name or "hitbox" in p_name:
			if not is_disabled:
				fill_col = Color(1.0, 0.15, 0.2, 0.45) # Active Attack Hitbox (Red)
				line_col = Color(1.0, 0.2, 0.3, 0.95)
				label_text = "ATTACK [ACTIVE]"
			else:
				fill_col = Color(0.8, 0.2, 0.2, 0.10) # Inactive Hitbox (Dim Red)
				line_col = Color(0.8, 0.2, 0.2, 0.35)
				label_text = "ATTACK [IDLE]"
		elif "hurtbox" in p_name or "defense" in p_name:
			fill_col = Color(0.2, 1.0, 0.4, 0.35) # Enemy Hurtbox (Green)
			line_col = Color(0.2, 1.0, 0.4, 0.95)
			label_text = "HURTBOX"
		elif p is CharacterBody2D or (p and (p.name == "Player" or p.is_in_group("player"))):
			var player_ref = p as Node2D
			if "is_parrying" in player_ref and player_ref.is_parrying:
				fill_col = Color(1.0, 0.85, 0.2, 0.6) # Parry Guard (Gold)
				line_col = Color(1.0, 0.9, 0.3, 1.0)
				label_text = "PARRY ACTIVE"
			else:
				fill_col = Color(0.2, 0.7, 1.0, 0.35) # Player Body (Cyan)
				line_col = Color(0.2, 0.7, 1.0, 0.95)
				label_text = "PLAYER"
		elif p is OutOfBounds or "outofbounds" in p_name:
			fill_col = Color(0.75, 0.2, 0.9, 0.15) # Out of Bounds (Purple)
			line_col = Color(0.85, 0.3, 1.0, 0.75)
			label_text = "OUT OF BOUNDS"
		else:
			continue # Only show combat relevant hitboxes/hurtboxes
		
		# Draw shape in world space (as child of current_scene, local coords = world coords)
		var xform = shape_node.global_transform
		if shape_node.shape is RectangleShape2D:
			var rect_shape = shape_node.shape as RectangleShape2D
			var extents = rect_shape.size * 0.5
			var points = PackedVector2Array([
				xform * Vector2(-extents.x, -extents.y),
				xform * Vector2(extents.x, -extents.y),
				xform * Vector2(extents.x, extents.y),
				xform * Vector2(-extents.x, extents.y)
			])
			draw_colored_polygon(points, fill_col)
			points.append(points[0])
			draw_polyline(points, line_col, 2.0)
			
			if label_text != "":
				var text_pos = xform.origin + Vector2(-30, -extents.y - 6)
				draw_string(ThemeDB.fallback_font, text_pos, label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11, line_col)
		elif shape_node.shape is CircleShape2D:
			var circ = shape_node.shape as CircleShape2D
			draw_circle(xform.origin, circ.radius, fill_col)
			draw_arc(xform.origin, circ.radius, 0, TAU, 32, line_col, 2.0)
