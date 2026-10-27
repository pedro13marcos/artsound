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

# Rhythm Hop and Leap State
var is_rhythm_hopping: bool = false
const HOP_STEP_DISTANCE: float = 72.0  # Horizontal distance of each beat-hop
const HOP_HEIGHT: float = 24.0         # Height of normal ground hop arc

# Input buffering for hop directions
var buffered_direction: float = 0.0

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
	
	var current_bpm = get_parent().bpm if "bpm" in get_parent() else 120.0
	
	# If currently performing a tweened rhythm hop/leap, skip standard physics
	if is_rhythm_hopping:
		return

	# Add the gravity when falling or mid-air
	if not is_on_floor():
		velocity += (get_gravity() * 1.4) * delta
		move_and_slide()
		return

	# ----------------------------------------------------
	# 1. RHYTHM PLATFORM LEAP (Spacebar / Interact key)
	# ----------------------------------------------------
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interact"):
		# Check if locked onto a rhythm platform
		if current_target != null and current_target is RhythmPlatform:
			var rating = Rhythm.rythymState(soundTrack, current_bpm)
			if rating != "MISS" and rating != "error":
				_execute_platform_leap(current_target, current_bpm)
				return
			else:
				_play_mistime_feedback()
				return

	# ----------------------------------------------------
	# 2. TILE / GRID-BASED RHYTHM STEPPING (Left / Right)
	# ----------------------------------------------------
	var input_x = Input.get_axis("ui_left", "ui_right")
	if input_x != 0.0:
		var dir_sign = sign(input_x)
		# Face direction of movement
		if $Sprite2D:
			$Sprite2D.flip_h = (dir_sign < 0)
			
		var rating = Rhythm.rythymState(soundTrack, current_bpm)
		if rating != "MISS" and rating != "error":
			_execute_ground_hop(dir_sign, current_bpm)
		else:
			_play_mistime_feedback()
		return

	velocity.x = 0.0
	move_and_slide()

# Ground hop to next "tile" / step distance in tempo
func _execute_ground_hop(dir: float, bpm: float) -> void:
	is_rhythm_hopping = true
	var seconds_per_beat = Rhythm.getTimePerBeat(bpm)
	var hop_duration = seconds_per_beat * 0.45  # Lands before next beat window opens
	
	var target_x = global_position.x + (dir * HOP_STEP_DISTANCE)
	var start_y = global_position.y
	
	var tween = create_tween().set_parallel(true)
	# Horizontal advance
	tween.tween_property(self, "global_position:x", target_x, hop_duration)\
		.set_trans(Tween.TRANS_LINEAR)
	
	# Vertical bounce arc
	var y_tween = create_tween()
	y_tween.tween_property(self, "global_position:y", start_y - HOP_HEIGHT, hop_duration * 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	y_tween.tween_property(self, "global_position:y", start_y, hop_duration * 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	y_tween.finished.connect(func():
		is_rhythm_hopping = false
	)

# High-flying leap to locked-on platform
func _execute_platform_leap(plat: RhythmPlatform, bpm: float) -> void:
	is_rhythm_hopping = true
	var seconds_per_beat = Rhythm.getTimePerBeat(bpm)
	var leap_duration = seconds_per_beat * 0.65 # Smooth aerial flight
	
	var target_pos = plat.get_landing_position()
	var start_pos = global_position
	var apex_y = min(start_pos.y, target_pos.y) - 90.0 # High jump arc above both points
	
	var tween = create_tween().set_parallel(true)
	# Horizontal leap
	tween.tween_property(self, "global_position:x", target_pos.x, leap_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Vertical arc (rise to apex then descend onto platform)
	var y_tween = create_tween()
	y_tween.tween_property(self, "global_position:y", apex_y, leap_duration * 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	y_tween.tween_property(self, "global_position:y", target_pos.y, leap_duration * 0.55)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	y_tween.finished.connect(func():
		is_rhythm_hopping = false
		velocity = Vector2.ZERO
	)

# Subtle shake/stumble when pressing off-beat
func _play_mistime_feedback() -> void:
	is_rhythm_hopping = true
	var tw = create_tween()
	var start_x = global_position.x
	tw.tween_property(self, "global_position:x", start_x + 6.0, 0.04)
	tw.tween_property(self, "global_position:x", start_x - 6.0, 0.04)
	tw.tween_property(self, "global_position:x", start_x, 0.04)
	tw.finished.connect(func():
		is_rhythm_hopping = false
	)

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
		
