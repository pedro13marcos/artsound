extends Node2D
class_name RhythmEnemy

signal player_hit(player: Node2D, side: String, beat_offset: float)
signal damage_taken(amount: int, remaining_hp: int)

enum EnemyMode { IDLE, COMBAT }
enum CombatSubState { READY, ATTACKING, SHARPENING }

@export var entity_name: String = "Blade Master"
## Maximum distance (in pixels) within which the player can interact.
## Set to 0 to disable the range restriction.
@export var max_interaction_range: float = 350.0
## Horizontal raycast distance (left and right) to detect the player on the same horizontal line.
@export var line_detection_range: float = 650.0
## Enemy health prepared for when player attacks are wired in.
@export var max_health: int = 3

# Light / outline glow settings
@export var attack_light_color: Color = Color(1.0, 0.2, 0.25, 1.0) # Red on attack
@export var sharpen_light_color: Color = Color(0.2, 1.0, 0.4, 1.0) # Green on sharpen/vulnerable
@export var light_energy: float = 2.0
@export var glow_thickness: float = 6.0

# State machine tracking
var current_mode: EnemyMode = EnemyMode.IDLE
var current_sub_state: CombatSubState = CombatSubState.READY
## -1 = player is on the left side, 1 = player is on the right side
var facing_dir: int = -1
var current_health: int = 3
var is_vulnerable: bool = false

# Sprites for each state
var tex_idle: Texture2D = preload("res://image/blademaster.png")
var tex_attack_left: Texture2D = preload("res://image/blademaster_attack_left.png")
var tex_attack_right: Texture2D = preload("res://image/blademaster_attack_right.png")
var tex_sharpen_left: Texture2D = preload("res://image/blademaster_sharpen_left.png")
var tex_sharpen_right: Texture2D = preload("res://image/blademaster_sharpen_right.png")

# Scene node references
var reticle: Node2D = null
var soundtrack_ref: AudioStreamPlayer = null
var sprite_node: Sprite2D = null
var outline_material: ShaderMaterial = null
var ray_left: RayCast2D = null
var ray_right: RayCast2D = null
var hurtbox_area: Area2D = null
var hitbox_left: Area2D = null
var hitbox_right: Area2D = null
var hitbox_left_shape: CollisionShape2D = null
var hitbox_right_shape: CollisionShape2D = null

# Pulse & pose reset tracking
var last_pulse_time: float = -999.0
var _pose_reset_timer: float = 0.0
var _hitbox_active_timer: float = 0.0

func _ready() -> void:
	current_health = max_health
	add_to_group("lockable_targets")
	_find_sprite()
	_setup_raycasts()
	_setup_combat_areas()
	_create_reticle()
	_create_outline_shader()
	_apply_idle_pose()

func _find_sprite() -> void:
	sprite_node = get_node_or_null("Sprite2D")
	if sprite_node == null:
		sprite_node = get_node_or_null("Sprite2D2")

func _setup_raycasts() -> void:
	ray_left = get_node_or_null("LineRaycastLeft")
	if ray_left == null:
		ray_left = RayCast2D.new()
		ray_left.name = "LineRaycastLeft"
		ray_left.position = Vector2(0, -62)
		add_child(ray_left)
	ray_left.enabled = true
	ray_left.exclude_parent = true
	ray_left.collide_with_bodies = true
	ray_left.collide_with_areas = false
	ray_left.target_position = Vector2(-line_detection_range, 0)

	ray_right = get_node_or_null("LineRaycastRight")
	if ray_right == null:
		ray_right = RayCast2D.new()
		ray_right.name = "LineRaycastRight"
		ray_right.position = Vector2(0, -62)
		add_child(ray_right)
	ray_right.enabled = true
	ray_right.exclude_parent = true
	ray_right.collide_with_bodies = true
	ray_right.collide_with_areas = false
	ray_right.target_position = Vector2(line_detection_range, 0)

func _setup_combat_areas() -> void:
	# 1. Hurtbox (Enemy defense / vulnerability collision)
	hurtbox_area = get_node_or_null("HurtboxArea")
	if hurtbox_area == null:
		hurtbox_area = Area2D.new()
		hurtbox_area.name = "HurtboxArea"
		hurtbox_area.position = Vector2(0, -62)
		var hurt_col = CollisionShape2D.new()
		var hurt_rect = RectangleShape2D.new()
		hurt_rect.size = Vector2(64, 130)
		hurt_col.shape = hurt_rect
		hurtbox_area.add_child(hurt_col)
		add_child(hurtbox_area)

	# 2. Left Attack Hitbox (Matches left sword slash arc outside left of body)
	hitbox_left = get_node_or_null("AttackHitboxLeft")
	if hitbox_left == null:
		hitbox_left = Area2D.new()
		hitbox_left.name = "AttackHitboxLeft"
		hitbox_left.position = Vector2(-46, -62)
		var col_l = CollisionShape2D.new()
		col_l.name = "CollisionShape2D"
		var rect_l = RectangleShape2D.new()
		rect_l.size = Vector2(56, 124)
		col_l.shape = rect_l
		col_l.disabled = true
		hitbox_left.add_child(col_l)
		add_child(hitbox_left)
	hitbox_left_shape = hitbox_left.get_node_or_null("CollisionShape2D")
	if not hitbox_left.body_entered.is_connected(_on_attack_hitbox_left_body_entered):
		hitbox_left.body_entered.connect(_on_attack_hitbox_left_body_entered)

	# 3. Right Attack Hitbox (Matches right sword slash arc outside right of body)
	hitbox_right = get_node_or_null("AttackHitboxRight")
	if hitbox_right == null:
		hitbox_right = Area2D.new()
		hitbox_right.name = "AttackHitboxRight"
		hitbox_right.position = Vector2(46, -62)
		var col_r = CollisionShape2D.new()
		col_r.name = "CollisionShape2D"
		var rect_r = RectangleShape2D.new()
		rect_r.size = Vector2(56, 124)
		col_r.shape = rect_r
		col_r.disabled = true
		hitbox_right.add_child(col_r)
		add_child(hitbox_right)
	hitbox_right_shape = hitbox_right.get_node_or_null("CollisionShape2D")
	if not hitbox_right.body_entered.is_connected(_on_attack_hitbox_right_body_entered):
		hitbox_right.body_entered.connect(_on_attack_hitbox_right_body_entered)

	_disable_attack_hitboxes()

func _create_outline_shader() -> void:
	if sprite_node == null:
		return
	var shader = load("res://shaders/sprite_glow_outline.gdshader")
	outline_material = ShaderMaterial.new()
	outline_material.shader = shader
	outline_material.set_shader_parameter("glow_color", attack_light_color)
	outline_material.set_shader_parameter("glow_thickness", glow_thickness)
	outline_material.set_shader_parameter("intensity", 0.3)
	sprite_node.material = outline_material

func _create_reticle() -> void:
	reticle = Node2D.new()
	reticle.name = "TargetReticle"
	reticle.visible = false
	add_child(reticle)
	
	# Drawing callback for the diamond reticle
	var reticle_drawer = Control.new()
	reticle_drawer.draw.connect(func():
		var col = Color(1.0, 0.25, 0.35, 0.9)
		# Draw targeting diamond / brackets around enemy
		var pts = PackedVector2Array([
			Vector2(0, -145), Vector2(30, -115),
			Vector2(0, -85), Vector2(-30, -115),
			Vector2(0, -145)
		])
		reticle_drawer.draw_polyline(pts, col, 2.5, true)
		reticle_drawer.draw_circle(Vector2(0, -115), 3.0, Color.WHITE)
	)
	reticle.add_child(reticle_drawer)

func _physics_process(delta: float) -> void:
	_update_line_of_sight_state()

	# Disable attack hitboxes once the strike window finishes
	if _hitbox_active_timer > 0.0:
		_hitbox_active_timer -= delta
		if _hitbox_active_timer <= 0.0:
			_disable_attack_hitboxes()

	# Return to ready/idle sprite after beat action pose duration finishes
	if _pose_reset_timer > 0.0:
		_pose_reset_timer -= delta
		if _pose_reset_timer <= 0.0:
			_apply_idle_pose()

func _update_line_of_sight_state() -> void:
	var detected_player: Node2D = null
	var detected_dir: int = 0

	if ray_left and ray_left.is_colliding():
		var col_l = ray_left.get_collider()
		if _is_player_node(col_l):
			detected_player = col_l
			detected_dir = -1

	if detected_player == null and ray_right and ray_right.is_colliding():
		var col_r = ray_right.get_collider()
		if _is_player_node(col_r):
			detected_player = col_r
			detected_dir = 1

	if detected_player != null:
		facing_dir = detected_dir
		if current_mode != EnemyMode.COMBAT:
			current_mode = EnemyMode.COMBAT
		# Keep idle/ready pose oriented toward the player's side
		if current_sub_state == CombatSubState.READY and sprite_node:
			sprite_node.flip_h = (facing_dir > 0)
	else:
		if current_mode == EnemyMode.COMBAT:
			current_mode = EnemyMode.IDLE
			_disable_attack_hitboxes()
			_apply_idle_pose()

func _is_player_node(node: Object) -> bool:
	if node == null or not (node is Node2D):
		return false
	return node.name == "Player" or node.is_in_group("player")

func _process(_delta: float) -> void:
	if soundtrack_ref == null or not soundtrack_ref.playing:
		soundtrack_ref = get_tree().current_scene.find_child("soundTrack", true, false)
		if soundtrack_ref == null or not soundtrack_ref.playing:
			return
			
	var bpm = get_parent().bpm if "bpm" in get_parent() else 120.0
	var seconds_per_beat = Rhythm.getTimePerBeat(bpm)
	var measure_duration = PATTERN_DURATION_BEATS * seconds_per_beat
	var song_pos = Rhythm.getSongPosition(soundtrack_ref)
	
	# Current measure index & time elapsed within this measure
	var current_measure = int(floor(song_pos / measure_duration))
	var measure_start = current_measure * measure_duration
	
	# Check each action in the sequence across the current measure
	for act in action_sequence:
		var cue_abs_time = measure_start + (act["beat_offset"] * seconds_per_beat)
		var diff = song_pos - cue_abs_time
		if diff >= -0.02 and diff < 0.08:
			if abs(last_pulse_time - cue_abs_time) > 0.15:
				last_pulse_time = cue_abs_time
				_on_rhythm_cue(act["type"], act["beat_offset"], seconds_per_beat)
				break

func _on_rhythm_cue(action_type: String, beat_offset: float, seconds_per_beat: float) -> void:
	_pulse_light(action_type, seconds_per_beat)
	
	# Only perform physical attacks & sharpening transitions when player is in the same horizontal line (COMBAT mode)
	if current_mode != EnemyMode.COMBAT:
		return

	if action_type == "attack":
		_perform_combat_attack(beat_offset, seconds_per_beat)
	elif action_type == "sharpen" or action_type == "vulnerable":
		_perform_combat_sharpen(beat_offset, seconds_per_beat)

func _perform_combat_attack(beat_offset: float, seconds_per_beat: float) -> void:
	current_sub_state = CombatSubState.ATTACKING
	is_vulnerable = false
	_disable_attack_hitboxes()

	# Both attacks are directed toward the player's side (facing_dir):
	# Alternate between Sword 1 and Sword 2 across the 3 attack beats (0.0, 0.5, 1.0)
	var use_second_sword: bool = is_equal_approx(beat_offset, 0.5)

	if sprite_node:
		if facing_dir < 0:
			# Player is on the LEFT side -> Both attacks slash into the LEFT hitbox area
			if not use_second_sword:
				sprite_node.texture = tex_attack_left
				sprite_node.flip_h = false
			else:
				sprite_node.texture = tex_attack_right
				sprite_node.flip_h = true
		else:
			# Player is on the RIGHT side -> Both attacks slash into the RIGHT hitbox area
			if not use_second_sword:
				sprite_node.texture = tex_attack_right
				sprite_node.flip_h = false
			else:
				sprite_node.texture = tex_attack_left
				sprite_node.flip_h = true

		# Quick combat lunge punch scale feedback
		sprite_node.scale = Vector2(0.122, 0.122)
		var tw = create_tween()
		tw.tween_property(sprite_node, "scale", Vector2(0.115, 0.115), seconds_per_beat * 0.35)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Activate the attack collision area on the side the enemy is attacking
	_enable_attack_hitbox_for_side(facing_dir)
	var hold_beats = 0.42 if beat_offset < 0.9 else 0.75
	_hitbox_active_timer = seconds_per_beat * (hold_beats * 0.75)
	_pose_reset_timer = seconds_per_beat * hold_beats

func _perform_combat_sharpen(beat_offset: float, seconds_per_beat: float) -> void:
	current_sub_state = CombatSubState.SHARPENING
	is_vulnerable = true
	_disable_attack_hitboxes()

	if sprite_node:
		# Beat 2.0: Sharpen Left Blade | Beat 3.0: Sharpen Right Blade
		if beat_offset < 2.5:
			sprite_node.texture = tex_sharpen_left
		else:
			sprite_node.texture = tex_sharpen_right
		# Orient toward player's side
		sprite_node.flip_h = (facing_dir > 0)

	_pose_reset_timer = seconds_per_beat * 0.80

func _apply_idle_pose() -> void:
	current_sub_state = CombatSubState.READY
	is_vulnerable = false
	if sprite_node:
		sprite_node.texture = tex_idle
		sprite_node.scale = Vector2(0.115, 0.115)
		sprite_node.flip_h = (facing_dir > 0) if current_mode == EnemyMode.COMBAT else false

func _enable_attack_hitbox_for_side(dir: int) -> void:
	if dir < 0:
		if hitbox_left:
			hitbox_left.monitoring = true
			hitbox_left.monitorable = true
		if hitbox_left_shape:
			hitbox_left_shape.disabled = false
	else:
		if hitbox_right:
			hitbox_right.monitoring = true
			hitbox_right.monitorable = true
		if hitbox_right_shape:
			hitbox_right_shape.disabled = false

func _disable_attack_hitboxes() -> void:
	if hitbox_left:
		hitbox_left.monitoring = false
		hitbox_left.monitorable = false
	if hitbox_left_shape:
		hitbox_left_shape.disabled = true
	if hitbox_right:
		hitbox_right.monitoring = false
		hitbox_right.monitorable = false
	if hitbox_right_shape:
		hitbox_right_shape.disabled = true

func _on_attack_hitbox_left_body_entered(body: Node2D) -> void:
	if _is_player_node(body):
		_trigger_player_hit(body, "left")

func _on_attack_hitbox_right_body_entered(body: Node2D) -> void:
	if _is_player_node(body):
		_trigger_player_hit(body, "right")

func _trigger_player_hit(player_body: Node2D, side: String) -> void:
	player_hit.emit(player_body, side, last_pulse_time)
	if player_body.has_method("take_damage"):
		player_body.take_damage(1, self)

## Prepared defense / damage receiver for when the player's attack is implemented.
## Returns true if the hit landed during the green sharpening/vulnerable window,
## or false if blocked during red attack / neutral guard states.
func take_damage(amount: int = 1) -> bool:
	if not is_vulnerable:
		# Blocked! Enemy is in Attack or Guard state
		return false
	current_health = max(0, current_health - amount)
	damage_taken.emit(amount, current_health)
	return true

func _pulse_light(action_type: String, seconds_per_beat: float) -> void:
	var is_green = (action_type == "sharpen" or action_type == "vulnerable")
	var target_col = sharpen_light_color if is_green else attack_light_color
	
	# Animate the pixel outline shader around visible parts of the sprite
	if outline_material != null:
		outline_material.set_shader_parameter("glow_color", target_col)
		var decay_time = seconds_per_beat * 0.45
		var tw = create_tween()
		outline_material.set_shader_parameter("intensity", light_energy)
		tw.tween_method(func(val: float):
			if outline_material:
				outline_material.set_shader_parameter("intensity", val)
		, light_energy, 0.25, decay_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# The lock-on symbol pulses with the glow, tinted by the action
	if reticle != null and reticle.visible:
		reticle.modulate = Color(target_col.r, target_col.g, target_col.b, 1.0)
		reticle.scale = Vector2(1.25, 1.25)
		var tw_ret = create_tween().set_parallel(true)
		tw_ret.tween_property(reticle, "scale", Vector2.ONE, seconds_per_beat * 0.45)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw_ret.tween_property(reticle, "modulate:a", 0.65, seconds_per_beat * 0.45)

func set_targeted(is_targeted: bool) -> void:
	if reticle:
		reticle.visible = is_targeted
		if is_targeted:
			var tw = create_tween()
			reticle.scale = Vector2(1.4, 1.4)
			tw.tween_property(reticle, "scale", Vector2(1.0, 1.0), 0.2)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Rhythmic pattern represented by musical intervals (in beats)
# Based on your musical pattern:
# Bar has:
# - Two eighth notes (0.5 beats each) + quarter note (1 beat) -> Attack!
# - Followed by two quarter notes (1 beat each) -> Sharpening/Vulnerable!
const PATTERN_DURATION_BEATS = 4.0

# Relative beat offsets within a 4-beat measure:
# Beat 0.0: Attack 1 (eighth note)
# Beat 0.5: Attack 2 (eighth note)
# Beat 1.0: Attack 3 (quarter note)
# Beat 2.0: Sharpen 1 (quarter note - opportunity to hit!)
# Beat 3.0: Sharpen 2 (quarter note - opportunity to hit!)
var action_sequence = [
	{"beat_offset": 0.0, "type": "attack"},
	{"beat_offset": 0.5, "type": "attack"},
	{"beat_offset": 1.0, "type": "attack"},
	{"beat_offset": 2.0, "type": "sharpen"},
	{"beat_offset": 3.0, "type": "sharpen"}
]

# This function is automatically queried by RhythmHUD when this enemy is locked on!
func get_upcoming_rhythm_cues(current_song_time: float, lookahead_duration: float) -> Array[Dictionary]:
	var cues: Array[Dictionary] = []
	var bpm = get_parent().bpm if "bpm" in get_parent() else 120.0
	var seconds_per_beat = Rhythm.getTimePerBeat(bpm)
	var measure_duration = PATTERN_DURATION_BEATS * seconds_per_beat
	
	# Determine current measure index
	var current_measure = int(floor(current_song_time / measure_duration))
	
	# Check this measure and next measure
	for m in [current_measure, current_measure + 1]:
		var measure_start = m * measure_duration
		for action in action_sequence:
			var cue_time = measure_start + (action["beat_offset"] * seconds_per_beat)
			if cue_time >= current_song_time - 0.05 and cue_time <= current_song_time + lookahead_duration:
				cues.append({
					"time": cue_time,
					"type": action["type"]
				})
	return cues
