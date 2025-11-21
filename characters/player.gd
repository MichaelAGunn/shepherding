extends CharacterBody3D
class_name Player

var player_sm: LimboHSM
var paused: bool = false
var movement_input := Vector2.ZERO
var _mouse_input_dir := Vector2.ZERO
var mouse_sensitivity: float = 0.15
var _last_movement_dir := Vector3.BACK
var attack_time: float
var block_time: float
var hurt_time: float
var death_time: float
var health: int = 5

@export var run_speed: float = 12.0
@export var sneak_speed: float = 2.0
@export var jump_height: float = 1.0
@export var jump_time_to_peak: float = 0.4
@export var jump_time_to_descent: float = 0.3

@onready var jump_velocity: float = ((2.0 * jump_height) / jump_time_to_peak)
@onready var jump_gravity: float = ((-2.0 * jump_height) / (jump_time_to_peak ** 2))
@onready var fall_gravity: float = ((-2.0 * jump_height) / (jump_time_to_descent ** 2))

@onready var follow = $FollowRange
@onready var close = $CloseRange
@onready var interact = $MeshInstance3D/InteractRange
@onready var camera_control = $CameraControl
@onready var spring_arm_3d = $CameraControl/SpringArm3D
@onready var camera_3d = $CameraControl/SpringArm3D/Camera3D
@onready var anima = $AnimationPlayer
@onready var body = $MeshInstance3D

func _ready() -> void:
	Global.player = self
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Global.bite.connect(_on_predator_bites)
	initialize_state_machine()

func _input(event: InputEvent) -> void:
	# Essential Buttons
	if Input.is_action_just_pressed("exit"):
		get_tree().quit()
	if event.is_action_pressed("pause"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			# Enter Live Play
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			paused = true
		elif Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			# Enter Pause Menu
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			paused = false

func _unhandled_input(event: InputEvent) -> void:
	# Rotate Camera
	var is_mouse_motion := (
		event is InputEventMouseMotion and
		Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	)
	if is_mouse_motion:
		_mouse_input_dir = event.screen_relative * mouse_sensitivity
	# Zoom Camera
	if event.is_action_pressed("zoomin"):
		spring_arm_3d.spring_length -= 1
		spring_arm_3d.spring_length = clamp(spring_arm_3d.spring_length, 2.0, 12.0)
	elif event.is_action_pressed("zoomout"):
		spring_arm_3d.spring_length += 1
		spring_arm_3d.spring_length = clamp(spring_arm_3d.spring_length, 2.0, 12.0)
	# Running
	if (velocity.x != 0.0 or velocity.z != 0.0):
		player_sm.dispatch(&"to_run")
	# Attacking
	if event.is_action_pressed("attack"):
		player_sm.dispatch(&"to_attack")
		Global.attack.emit()
	# Blocking
	if event.is_action_pressed("block"):
		player_sm.dispatch(&"to_block")
	if event.is_action_pressed("rally"):
		Global.rally.emit()
	if event.is_action_pressed("interact"):
		Global.interact.emit()
	# For debug purposes only!
	if event.is_action_pressed("debug"):
		Global.all_struggle.emit()

func _physics_process(delta: float) -> void:
	#print(player_sm.get_active_state())
	#print(anima.get_current_animation())
	if not is_on_floor() and velocity.y < 0.0:
		player_sm.dispatch(&"to_fall")
	# Camera by Mouse
	camera_control.rotation.x -= _mouse_input_dir.y * delta
	camera_control.rotation.x = clamp(camera_control.rotation.x, -PI/2.0, PI/8.0)
	camera_control.rotation.y -= _mouse_input_dir.x * delta
	_mouse_input_dir = Vector2.ZERO
	# Move the PC
	moving(delta)
	jumping(delta)
	move_and_slide()

func moving(delta: float) -> void:
	movement_input = Input.get_vector("leftward", "rightward", "forward", "backward") \
		.rotated(-camera_control.global_rotation.y)
	var vel_2d = Vector2(velocity.x, velocity.z)
	if movement_input != Vector2.ZERO:
		vel_2d += movement_input * run_speed * delta
		vel_2d = vel_2d.limit_length(run_speed)
	else:
		vel_2d = vel_2d.move_toward(Vector2.ZERO, (run_speed ** 2) * delta)
	velocity.x = vel_2d.x
	velocity.z = vel_2d.y
	if movement_input.length() > 0.2:
		_last_movement_dir = velocity
	var target_angle := Vector3.BACK.signed_angle_to(_last_movement_dir, Vector3.UP)
	body.global_rotation.y = target_angle

func jumping(delta: float) -> void:
	var gravity = jump_gravity if velocity.y > 0.0 else fall_gravity
	velocity.y += gravity * delta
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y += jump_velocity

func initialize_state_machine() -> void:
	player_sm = LimboHSM.new()
	add_child(player_sm)
	var idle_state = LimboState.new().named("idle").call_on_enter(idle_start).call_on_update(idle_update)
	var run_state = LimboState.new().named("run").call_on_enter(run_start).call_on_update(run_update)
	var hop_state = LimboState.new().named("hop").call_on_enter(hop_start).call_on_update(hop_update)
	var leap_state = LimboState.new().named("leap").call_on_enter(leap_start).call_on_update(leap_update)
	var fall_state = LimboState.new().named("fall").call_on_enter(fall_start).call_on_update(fall_update)
	var attack_state = LimboState.new().named("attack").call_on_enter(attack_start).call_on_update(attack_update)
	var block_state = LimboState.new().named("block").call_on_enter(block_start).call_on_update(block_update)
	var hurt_state = LimboState.new().named("hurt").call_on_enter(hurt_start).call_on_update(hurt_update)
	var death_state = LimboState.new().named("death").call_on_enter(death_start).call_on_update(death_update)
	player_sm.add_child(idle_state)
	player_sm.add_child(run_state)
	player_sm.add_child(hop_state)
	player_sm.add_child(leap_state)
	player_sm.add_child(fall_state)
	player_sm.add_child(attack_state)
	player_sm.add_child(block_state)
	player_sm.add_child(hurt_state)
	player_sm.add_child(death_state)
	player_sm.initial_state = idle_state
	player_sm.add_transition(idle_state, run_state, &"to_run")
	player_sm.add_transition(player_sm.ANYSTATE, idle_state, &"state_ended")
	player_sm.add_transition(idle_state, hop_state, &"to_hop")
	player_sm.add_transition(run_state, leap_state, &"to_leap")
	player_sm.add_transition(player_sm.ANYSTATE, fall_state, &"to_fall")
	player_sm.add_transition(player_sm.ANYSTATE, attack_state, &"to_attack")
	player_sm.add_transition(player_sm.ANYSTATE, block_state, &"to_block")
	player_sm.add_transition(player_sm.ANYSTATE, hurt_state, &"to_hurt")
	player_sm.add_transition(hurt_state, death_state, &"to_death")
	player_sm.initialize(self)
	player_sm.set_active(true)

func idle_start() -> void:
	anima.play("idle")

func idle_update(_delta: float) -> void:
	if is_on_floor() and (velocity.x != 0.0 or velocity.z != 0.0):
		player_sm.dispatch(&"to_run")
	elif not is_on_floor() and velocity.y > 0.0:
		player_sm.dispatch(&"to_hop")

func run_start() -> void:
	anima.play("run")

func run_update(_delta: float) -> void:
	if is_on_floor() and velocity.x == 0.0 and velocity.y == 0.0 and velocity.z == 0.0:
		player_sm.dispatch(&"state_ended")
	elif not is_on_floor() and velocity.y > 0.0:
		player_sm.dispatch(&"to_leap")

func hop_start() -> void:
	anima.play("hop")

func hop_update(_delta: float) -> void:
	if is_on_floor():
		player_sm.dispatch(&"state_ended")

func jump_start() -> void:
	anima.play("jump")

func jump_update(_delta: float) -> void:
	if is_on_floor():
		player_sm.dispatch(&"state_ended")

func leap_start() -> void:
	anima.play("leap")

func leap_update(_delta: float) -> void:
	if is_on_floor():
		player_sm.dispatch(&"state_ended")

func fall_start() -> void:
	anima.play("fall")

func fall_update(_delta: float) -> void:
	if is_on_floor():
		player_sm.dispatch(&"state_ended")

func attack_start() -> void:
	attack_time = 1.0
	anima.play("attack")

func attack_update(_delta: float) -> void:
	attack_time -= 0.1 # Works better than a timer!
	if attack_time <= 0.0:
		player_sm.dispatch(&"state_ended")

func block_start() -> void:
	block_time = 1.0
	anima.play("block")

func block_update(_delta: float) -> void:
	block_time -= 0.1 # Works better than a timer!
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor(): # Float in air while attacking
		velocity.y = 0.2
	if block_time <= 0.0:
		player_sm.dispatch(&"state_ended")

func hurt_start() -> void:
	hurt_time = 1.0
	anima.play("hurt")
	health -= 1
	print("Player health: ", health)
	if health == 0:
		player_sm.dispatch(&"to_death")

func hurt_update(_delta: float) -> void:
	hurt_time -= 0.1 # Works better than a timer!
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor(): # Float in air while attacking
		velocity.y = 0.2
	if hurt_time <= 0.0:
		player_sm.dispatch(&"state_ended")

func death_start() -> void:
	anima.play("death")

func death_update(_delta: float) -> void:
	pass

func _on_predator_bites() -> void:
	if self in Global.predator.threat.get_overlapping_bodies():
		player_sm.dispatch(&"to_hurt")
