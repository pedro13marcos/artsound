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

# Mouse flick/direction lock-on settings
@export var mouse_flick_threshold: float = 25.0 # Minimum mouse motion delta (pixels) to trigger flick
var mouse_flick_cooldown: float = 0.0

@export var max_los_distance: float = 800.0 # Maximum distance to look/interact via line of sight
@onready var los_raycast: RayCast2D = null

# Rhythm Hop, Smooth Walk, and Leap State
var is_rhythm_hopping: bool = false
const HOP_STEP_DISTANCE: float = 72.0  # Horizontal distance of each beat-hop
const HOP_HEIGHT: float = 24.0         # Height of normal ground hop arc

# Rhythm walking state machine:
# "IDLE": no walking input held
# "HOPPING": performing discrete beat-hops
# "SMOOTH_WALKING": smoothly walking because player pressed on-beat and held button
# "LOCKED_OUT": mistimed press; disabled until key is released
enum MoveMode { IDLE, HOPPING, SMOOTH_WALKING, LOCKED_OUT }
var current_move_mode: MoveMode = MoveMode.IDLE
var active_walk_dir: float = 0.0

func _ready() -> void:
	_create_los_raycast()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _create_los_raycast() -> void:
	los_raycast = RayCast2D.new()
	los_raycast.name = "LOSRaycast"
	los_raycast.enabled = true
	los_raycast.exclude_parent = true
	los_raycast.collide_with_areas = false
	los_raycast.collide_with_bodies = true
	add_child(los_raycast)

## Checks whether the player has clear line-of-sight to the given target
func has_line_of_sight_to(target: Node) -> bool:
	if not is_instance_valid(target) or not target is Node2D:
		return false
		
	var target_center: Vector2
	if target is RhythmPlatform:
		target_center = target.get_landing_position(global_position)
	else:
		target_center = target.global_position + Vector2(0, -50.0)
		
	var origin = global_position + Vector2(0, -30.0) # Eye level
	var to_target = target_center - origin
	var dist = to_target.length()
	
	# Check distance limit if configured on target
	var max_range = max_los_distance
	if "max_interaction_range" in target and target.max_interaction_range > 0.0:
		max_range = target.max_interaction_range
		
	if dist > max_range:
		return false
		
	if los_raycast == null:
		return true
		
	los_raycast.global_position = origin
	los_raycast.target_position = to_target
	los_raycast.force_raycast_update()
	
	if not los_raycast.is_colliding():
		return true
		
	var collider = los_raycast.get_collider()
	# Clear view if raycast hit nothing or hit the target itself directly
	if collider == target or collider == self:
		return true
		
	# If collider is child of target or target is ancestor
	if collider is Node and (target.is_ancestor_of(collider) or collider.is_ancestor_of(target)):
		return true
		
	return false

func _unhandled_input(event: InputEvent) -> void:
	# Directional Mouse Flick: Flicking the mouse selects/switches targets in that direction
	if event is InputEventMouseMotion:
		var motion = event.relative
		if motion.length() >= mouse_flick_threshold and mouse_flick_cooldown <= 0.0:
			mouse_flick_cooldown = 0.22 # Short debounce to prevent rapid cycling on a single flick
			_switch_target_in_direction(motion.normalized())
	
	# Right-click unlocks / clears target
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
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
		
	# Always use player's position as the origin reference point
	var origin_pos = global_position
	var best_target: Node = null
	var best_score = -999.0
	
	for t in targets:
		if not is_instance_valid(t) or not t is Node2D:
			continue
		
		# Skip target if line of sight is obstructed
		if not has_line_of_sight_to(t):
			continue
			
		var target_pos: Vector2
		if t is RhythmPlatform:
			target_pos = t.get_landing_position(origin_pos)
		else:
			target_pos = t.global_position
			
		var to_target = target_pos - origin_pos
		var dist = to_target.length()
		var to_dir = to_target.normalized()
		
		# Alignment dot product with pushed direction (1.0 = direct match, 0 = 90 deg, -1 = opposite)
		var dot = dir.dot(to_dir)
		
		# Must be in the general hemisphere (dot > 0.15)
		if dot > 0.15:
			# Prioritize targets with highest directional alignment and proximity
			# Scoring weights alignment heavily while keeping closer targets favored
			var score = (dot * 2.5) - (dist / 800.0)
			
			# If already locking on this target, give a penalty to encourage switching to another
			if t == current_target:
				score -= 0.5
				
			if score > best_score:
				best_score = score
				best_target = t
				
	if best_target != null:
		set_lock_target(best_target)

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
	if mouse_flick_cooldown > 0.0:
		mouse_flick_cooldown -= delta
		
	_handle_controller_lock_switch()
	
	# Keep reticle positioned at the corner closest to the player dynamically
	if current_target != null and current_target is RhythmPlatform and current_target.has_method("update_reticle_position"):
		current_target.update_reticle_position(global_position)
	
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
			# Enforce interaction range
			var hud = get_parent().get_node_or_null("RhythmHUD")
			var in_range = true
			if hud and not hud.target_in_range:
				in_range = false
			
			if not in_range:
				_play_mistime_feedback()  # Reuse stumble feedback for "too far"
				return
			
			var rating = Rhythm.rythymState(soundTrack, current_bpm)
			if rating != "MISS" and rating != "error":
				_execute_platform_leap(current_target, current_bpm)
				return
			else:
				_play_mistime_feedback()
				return

	# ----------------------------------------------------
	# 2. RHYTHM WALKING (A / D, Left / Right Arrow, D-Pad)
	# ----------------------------------------------------
	var input_x = Input.get_axis("ui_left", "ui_right")
	
	# Key Released -> Reset to IDLE
	if input_x == 0.0:
		current_move_mode = MoveMode.IDLE
		velocity.x = 0.0
		move_and_slide()
		return
		
	var dir_sign = sign(input_x)
	if $Sprite2D:
		$Sprite2D.flip_h = (dir_sign < 0)
		
	# CASE 1: Locked Out (Mistimed press was made and is still being held)
	# Don't try again until player releases the key!
	if current_move_mode == MoveMode.LOCKED_OUT:
		velocity.x = 0.0
		move_and_slide()
		return
		
	# CASE 2: Smooth Walking (Initiated on-beat and held)
	if current_move_mode == MoveMode.SMOOTH_WALKING:
		velocity.x = dir_sign * SPEED
		move_and_slide()
		return
		
	# CASE 3: Fresh Press from IDLE
	if current_move_mode == MoveMode.IDLE:
		var rating = Rhythm.rythymState(soundTrack, current_bpm)
		if rating != "MISS" and rating != "error":
			# Pressed on tempo! Enter SMOOTH_WALKING mode immediately for smooth continuous movement
			current_move_mode = MoveMode.SMOOTH_WALKING
			velocity.x = dir_sign * SPEED
			move_and_slide()
		else:
			# Pressed off tempo! Lock out until released so it won't auto-trigger
			current_move_mode = MoveMode.LOCKED_OUT
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
	
	var target_pos = plat.get_landing_position(global_position)
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
		# Perform a collision snap onto the floor surface so physics detects floor immediately
		move_and_slide()
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
		
