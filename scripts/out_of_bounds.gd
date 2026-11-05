extends Area2D
class_name OutOfBounds
## Detects when the player clips or falls outside the map boundaries
## and resets them to the map's initial spawn position.

func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)

func _physics_process(_delta: float) -> void:
	if not monitoring:
		return
	for body in get_overlapping_bodies():
		_check_and_reset_body(body)

func _on_body_entered(body: Node2D) -> void:
	_check_and_reset_body(body)

func _check_and_reset_body(body: Node) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body.is_in_group("player") or body.name == "Player":
		if body.has_method("reset_to_spawn"):
			body.reset_to_spawn()
