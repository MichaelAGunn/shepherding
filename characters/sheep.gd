class_name Sheep extends CharacterBody3D

@onready var body = $MeshInstance3D
@onready var space = $CollisionShape3D
@onready var anima = $AnimationPlayer
@onready var nav = $NavigationAgent3D

@export var wander_speed: float = 1.0
@export var follow_speed: float = 3.0
@export var flee_speed: float = 5.0

var state: int
var state_time: int

enum States {
	IDLE,
	WANDER,
	FOLLOW,
	FLEE,
	GRAZE,
	DRINK
}

func _ready() -> void:
	state = States.IDLE
	nav.target_position = Vector3.ZERO

func _physics_process(_delta: float) -> void:
	state_time -= 1
	match state:
		States.IDLE:
			idle()
		States.WANDER:
			wander()
		States.FOLLOW:
			follow()
		States.FLEE:
			flee()
		States.GRAZE:
			graze()
		States.DRINK:
			drink()
	move_and_slide()

func idle() -> void:
	velocity = Vector3.ZERO
	if state_time <= 0:
		change_state(randi_range(1, 3))

func wander() -> void:
	moving(wander_speed)
	if state_time <= 0:
		change_state(States.IDLE)

func follow() -> void:
	moving(follow_speed)
	if Global.player.global_position != nav.target_position:
		nav.set_target_position(Global.player.global_position)
	if state_time <= 0:
		change_state(States.IDLE)
	if self not in Global.player.follow.get_overlapping_bodies():
		change_state(States.IDLE)

func flee() -> void:
	moving(flee_speed)
	#if state_time <= 0:
	if self not in Global.predator.hostility.get_overlapping_bodies():
		change_state(States.IDLE)

func graze() -> void:
	pass

func drink() -> void:
	pass

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
		States.FOLLOW:
			anima.play("walk")
			state_time = 300
			nav.set_target_position(Global.player.global_position)
		States.FLEE:
			anima.play("walk")
			state_time = 300
			nav.set_target_position((global_position - Global.predator.global_position).normalized() * 20)
		States.GRAZE:
			anima.play("graze")
		States.DRINK:
			anima.play("drink")
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

func _on_navigation_agent_3d_target_reached():
	if state != States.IDLE:
		change_state(States.IDLE)
