extends Node2D
class_name GlowOutline
## Soft glow drawn all around a rectangular area (uses a StyleBoxFlat shadow).

var half_size: Vector2 = Vector2(50, 20)
var glow_color: Color = Color.WHITE
var base_glow_size: float = 26.0
var corner_radius: int = 6

## 0..1, animated by pulse()
var intensity: float = 0.25:
	set(value):
		intensity = value
		queue_redraw()

var _style := StyleBoxFlat.new()

func _ready() -> void:
	z_index = -1
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_style.bg_color = Color(0, 0, 0, 0)
	_style.set_corner_radius_all(corner_radius)

func setup(size_half: Vector2, color: Color, glow_size: float = 26.0) -> void:
	half_size = size_half
	glow_color = color
	base_glow_size = glow_size
	queue_redraw()

func pulse(duration: float, peak: float = 1.0, resting: float = 0.2) -> void:
	var tw = create_tween()
	intensity = peak
	tw.tween_property(self, "intensity", resting, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _draw() -> void:
	_style.shadow_size = int(base_glow_size * (0.6 + 0.8 * intensity))
	_style.shadow_color = Color(glow_color.r, glow_color.g, glow_color.b, clamp(glow_color.a * intensity, 0.0, 1.0))
	draw_style_box(_style, Rect2(-half_size, half_size * 2.0))
