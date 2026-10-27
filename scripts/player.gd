extends CharacterBody2D


@onready var soundTrack = get_node("../soundTrack");

#@onready var soundTrack = $soundTrack;


var secondsPerBeat;
var referencePosition;


const SPEED = 300.0
const JUMP_VELOCITY = -800.0

var isInArea = false;

# Lock-on tracking variables
var current_target: Node = null
var stick_target_switched: bool = false
const STICK_DEADZONE: float = 0.5
const MOUSE_LOCK_RADIUS: float = 80.0

func _ready() -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	# Mouse Click to lock on target (Left click)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_world_pos = get_global_mouse_position()
		_try_mouse_lock(mouse_world_pos)

func _try_mouse_lock(mouse_world_pos: Vector2) -> void:
	var targets = get_tree().get_nodes_in_group("lockable_targets")
	var closest_target: Node = null
	var closest_dist: float = MOUSE_LOCK_RADIUS
	
	for t in targets:
		if not is_instance_valid(t) or not t is Node2D:
			continue
		var dist = mouse_world_pos.distance_to(t.global_position + Vector2(0, -40))
		if dist < closest_dist:
			closest_dist = dist
			closest_target = t
			
	if closest_target != null:
		set_lock_target(closest_target)
	elif current_target != null:
		# Clicking empty space unlocks target
		clear_lock_target()

func _handle_controller_lock_switch() -> void:
	# Right Analog Stick on Gamepad (Joypad Axis 2: Right Stick X, Axis 3: Right Stick Y)
	var rx = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var ry = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	var stick_vec = Vector2(rx, ry)
	
	if stick_vec.length() > STICK_DEADZONE:
		if not stick_target_switched:
			stick_target_switched = true
			_switch_target_in_direction(stick_vec.normalized())
	else:
		stick_target_switched = false

func _switch_target_in_direction(dir: Vector2) -> void:
	var targets = get_tree().get_nodes_in_group("lockable_targets")
	if targets.is_empty():
		return
		
	# If no target yet, pick closest in stick direction or closest overall
	if current_target == null:
		var best_target = null
		var best_score = -999.0
		for t in targets:
			var to_target = (t.global_position - global_position).normalized()
			var dot = dir.dot(to_target)
			if dot > best_score:
				best_score = dot
				best_target = t
		if best_target:
			set_lock_target(best_target)
		return

	# If already targeting, find next target in the direction pushed
	var current_pos = current_target.global_position
	var next_target = null
	var min_angle_diff = 999.0
	
	for t in targets:
		if t == current_target:
			continue
		var to_new = (t.global_position - current_pos).normalized()
		var dot = dir.dot(to_new)
		if dot > 0.3: # In the general hemisphere of stick push
			var angle_diff = acos(clamp(dot, -1.0, 1.0))
			if angle_diff < min_angle_diff:
				min_angle_diff = angle_diff
				next_target = t
				
	if next_target != null:
		set_lock_target(next_target)

func set_lock_target(target: Node) -> void:
	current_target = target
	var hud = get_parent().get_node_or_null("RhythmHUD")
	if hud:
		hud.lock_on_target(target)

func clear_lock_target() -> void:
	current_target = null
	var hud = get_parent().get_node_or_null("RhythmHUD")
	if hud:
		hud.clear_target()


func _physics_process(delta: float) -> void:
	_handle_controller_lock_switch()
	
	# Add the gravity.
	if not is_on_floor():
		velocity += (get_gravity()*1.4) * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

#Teste of the function of tempo -->
	if Input.is_action_just_pressed("interact") && isInArea:
	#		judgeHit();
			var current_bpm = get_parent().bpm if "bpm" in get_parent() else 120.0
			OS.alert("interacted " + Rhythm.rythymState(soundTrack, current_bpm));

#entrando e saindo da area de colisão -->
func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		isInArea = true;
		# Auto-lock as fallback if nothing is locked yet
		if current_target == null:
			set_lock_target(get_node("../Interaction point"))


func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		isInArea = false;
		# Optional: keep lock on or release when walking away
		if current_target == get_node_or_null("../Interaction point"):
			clear_lock_target()
		
