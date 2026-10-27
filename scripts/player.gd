extends CharacterBody2D


@onready var soundTrack = get_node("../soundTrack");

#@onready var soundTrack = $soundTrack;


var secondsPerBeat;
var referencePosition;


const SPEED = 300.0
const JUMP_VELOCITY = -800.0

var isInArea = false;

func _ready() -> void:
	pass
#	$soundTrack.play();
	

func _physics_process(delta: float) -> void:
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
		var hud = get_parent().get_node_or_null("RhythmHUD")
		if hud:
			hud.lock_on_target(get_node("../Interaction point"))


func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		isInArea = false;
		var hud = get_parent().get_node_or_null("RhythmHUD")
		if hud:
			hud.clear_target()
		
