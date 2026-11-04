extends Area2D
class_name HeartPickupItem

@export var health_restore: int = 1
@export var float_amplitude: float = 8.0
@export var float_speed: float = 3.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var glow: Sprite2D = $Glow

var _base_y: float = 0.0
var _time_passed: float = 0.0
var _collected: bool = false
var _soundtrack: AudioStreamPlayer = null
var _last_pulsed_beat: int = -1
var _reject_cooldown: float = 0.0

func _ready() -> void:
	_base_y = position.y
	body_entered.connect(_on_body_entered)
	_soundtrack = get_tree().current_scene.find_child("soundTrack", true, false)

func _process(delta: float) -> void:
	if _reject_cooldown > 0.0:
		_reject_cooldown -= delta

	if _collected:
		return
	
	_time_passed += delta
	# Smooth floating bobbing
	position.y = _base_y + sin(_time_passed * float_speed) * float_amplitude
	
	# Rhythm-sync pulse if soundtrack is playing
	if _soundtrack != null and _soundtrack.playing:
		var bpm = get_parent().bpm if "bpm" in get_parent() else 120.0
		var seconds_per_beat = Rhythm.getTimePerBeat(bpm)
		var song_pos = Rhythm.getSongPosition(_soundtrack)
		var current_beat = int(floor(song_pos / seconds_per_beat))
		if current_beat > _last_pulsed_beat:
			_last_pulsed_beat = current_beat
			_pulse_on_beat(seconds_per_beat)

func _pulse_on_beat(seconds_per_beat: float) -> void:
	if sprite == null:
		return
	var tw = create_tween()
	sprite.scale = Vector2(0.62, 0.62)
	tw.tween_property(sprite, "scale", Vector2(0.52, 0.52), seconds_per_beat * 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if not _is_player(body):
		return
	
	# Cannot be collected if player is already at full health!
	if Global.player_current_health >= Global.player_max_health:
		if _reject_cooldown <= 0.0:
			_reject_cooldown = 0.5
			# Subtle wobble feedback indicating health is already full
			var tw_rej = create_tween()
			tw_rej.tween_property(sprite, "rotation", deg_to_rad(12.0), 0.06)
			tw_rej.tween_property(sprite, "rotation", deg_to_rad(-12.0), 0.06)
			tw_rej.tween_property(sprite, "rotation", 0.0, 0.06)
		return
	
	_collected = true
	# Immediately disable further collision
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Heal player (does not increase max health)
	Global.heal_player(health_restore)
	
	# Play energetic collection animation (float up, pop, fade out)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(self, "position:y", position.y - 45.0, 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	tw.chain().tween_callback(queue_free)

func _is_player(node: Node) -> bool:
	if node == null:
		return false
	return node.name == "Player" or node.is_in_group("player")
