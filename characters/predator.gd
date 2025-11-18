class_name Predator extends CharacterBody3D

@onready var body = $MeshInstance3D
@onready var space = $CollisionShape3D
@onready var anima = $AnimationPlayer
@onready var nav = $NavigationAgent3D
@onready var hostility = $HostilityRange
@onready var threat = $ThreatRange

@export var wander_speed: float = 2.0
@export var chase_speed: float = 10.0
@export var strafe_speed: float = 1.0

var state: int
var state_time: int

enum States {
	IDLE,
	WANDER,
	CHASE,
	STRAFE
}

func _ready() -> void:
	Global.predator = self
	state = States.IDLE
	nav.target_position = Vector3.ZERO

func _physics_process(_delta: float) -> void:
	print(state)
	print(state_time)
	state_time -= 1
	match state:
		States.IDLE:
			idle()
		States.WANDER:
			wander()
		States.CHASE:
			chase()
		States.STRAFE:
			strafe()
	move_and_slide()

func idle() -> void:
	velocity = Vector3.ZERO
	if state_time <= 0:
		change_state(States.WANDER)

func wander() -> void:
	moving(wander_speed)
	if state_time <= 0:
		change_state(States.IDLE)

func chase() -> void:
	if state_time <= 0:
		change_state(States.STRAFE)

func strafe() -> void:
	if state_time <= 0:
		change_state(States.CHASE)

func change_state(next_state) -> void:
	# Cleanup before changing state.
	anima.stop()
	match next_state:
		States.IDLE:
			anima.play("idle")
			state_time = 60
			#nav.set_target_position(Vector3.ZERO)
		States.WANDER:
			anima.play("walk")
			state_time = 200
			find_wander_target()
		States.CHASE:
			anima.play("walk")
			state_time = 300
			nav.set_target_position(Global.player.global_position)
		States.STRAFE:
			anima.play("walk")
			state_time = 300
			nav.set_target_position((global_position - Global.predator.global_position).normalized() * 20)
	# Change state now!
	state = next_state
	# Post state changes.

func moving(speed: float) -> void:
	var next_location = nav.get_next_path_position()
	var new_velocity = (next_location - global_transform.origin).normalized() * speed
	velocity = velocity.move_toward(new_velocity, 0.25)
	velocity.y = 0.0
	if velocity == Vector3.ZERO:
		change_state(States.IDLE)

func find_wander_target() -> void:
	var direction: Vector3 = global_transform.origin
	direction.x += randf_range(-5.0, 5.0)
	direction.z += randf_range(-5.0, 5.0)
	nav.set_target_position(direction)
