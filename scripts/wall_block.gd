@tool
extends StaticBody2D
class_name WallBlock
## Simple solid rectangle (visual + collision). The node origin is the top-left corner.

@export var size: Vector2 = Vector2(100, 36):
	set(value):
		size = value
		_rebuild()
@export var color: Color = Color(0.11, 0.11, 0.14, 1.0):
	set(value):
		color = value
		queue_redraw()
@export var outline_color: Color = Color(0.55, 0.62, 0.85, 0.9):
	set(value):
		outline_color = value
		queue_redraw()

var _shape: CollisionShape2D = null

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape2D.new()
		_shape.shape = RectangleShape2D.new()
		add_child(_shape)
	(_shape.shape as RectangleShape2D).size = size
	_shape.position = size / 2.0
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), color)
	draw_rect(Rect2(Vector2.ZERO, size), outline_color, false, 3.0)
