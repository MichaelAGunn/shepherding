class_name Predator extends CharacterBody3D

@onready var body = $MeshInstance3D
@onready var space = $CollisionShape3D
@onready var anima = $AnimationPlayer
@onready var nav = $NavigationAgent3D
@onready var hostile = $HostileRange
@onready var threat = $MeshInstance3D/ThreatRange

@export var wander_speed: float = 2.0
@export var chase_speed: float = 5.0

var state: int
var state_time: int
var target: CharacterBody3D

enum States {
	IDLE,
	WANDER,
	CHASE,
	FLEE,
	ROAR,
	BITE,
	HURT,
	DIE
}

func _ready() -> void:
	Global.predator = self
	state = States.IDLE
	nav.target_position = Vector3.ZERO
	Global.interact.connect(_on_player_interacts)
	Global.all_struggle.connect(_debug_struggle)
#
func _debug_struggle() -> void:
	change_state(States.CHASE)

func _physics_process(_delta: float) -> void:
	state_time -= 1
	match state:
		States.IDLE:
			idle()
		States.WANDER:
			wander()
		States.CHASE:
			chase()
		States.FLEE:
			flee()
		States.ROAR:
			roar()
		States.BITE:
			bite()
		States.HURT:
			hurt()
		States.DIE:
			die()
	move_and_slide()

func idle() -> void:
	if state_time <= 0:
		change_state(States.WANDER)
	velocity = Vector3.ZERO

func wander() -> void:
	if state_time <= 0:
		change_state(States.IDLE)
	moving(wander_speed)

func chase() -> void: # TODO: Make it attack a sheep
	if state_time <= 0:
		change_state(States.IDLE)
	if target not in hostile.get_overlapping_bodies():
		change_state(States.IDLE)
	moving(chase_speed)
	if target.global_position != nav.target_position:
		nav.set_target_position(target.global_position)

func flee() -> void:
	if state_time <= 0:
		change_state(States.IDLE)
	moving(chase_speed)

func roar() -> void:
	pass

func bite() -> void:
	pass

func hurt() -> void: # TODO: Make prlayer capable of hurting predator!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	pass

func die() -> void:
	if state_time <= 0:
		queue_free()

func change_state(next_state) -> void:
	# Cleanup before changing state.
	print("FROM: ", States.keys()[state], " TO: ", States.keys()[next_state])
	anima.stop()
	match next_state:
		States.IDLE:
			anima.play("idle")
			state_time = 60
		States.WANDER:
			anima.play("walk")
			state_time = 100
			find_wander_target()
		States.CHASE:
			anima.play("walk")
			state_time = 200
			find_chase_target()
		States.FLEE:
			anima.play("walk")
			state_time = 500
			nav.set_target_position((global_position - Global.player.global_position).normalized() * 20)
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

func choose_target() -> CharacterBody3D: # TODO: make this select the nearest thing!
	return Global.player

func find_wander_target() -> void:
	var direction: Vector3 = global_transform.origin
	direction.x += randf_range(-5.0, 5.0)
	direction.z += randf_range(-5.0, 5.0)
	nav.set_target_position(direction)

func find_chase_target() -> void:
	target = Global.player
	var target_position = Vector3(target.global_position.x, 0.0, target.global_position.z)
	nav.set_target_position(target_position)

func _on_player_interacts() -> void:
	if self in Global.player.interact.get_overlapping_bodies():
		change_state(States.FLEE)

func _on_navigation_agent_3d_target_reached():
	if state in [States.WANDER, States.FLEE]:
		change_state(States.IDLE)
