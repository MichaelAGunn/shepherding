class_name Predator extends CharacterBody3D

@onready var body = $MeshInstance3D
@onready var space = $CollisionShape3D
@onready var anima = $AnimationPlayer
@onready var nav = $NavigationAgent3D
@onready var hostile = $HostileRange
@onready var threat = $MeshInstance3D/ThreatRange
@onready var roars = $RoarRange

@export var wander_speed: float = 2.0
@export var chase_speed: float = 5.0

var state: int
var state_time: int
var target: CharacterBody3D
var _last_movement_dir := Vector3.BACK
var health: int = 5
var sheep_nearby: int = 0
var player_nearby: bool = false
var current_target: CharacterBody3D

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
	Global.attack.connect(_on_player_attacks)
	Global.interact.connect(_on_player_interacts)
	Global.all_struggle.connect(_debug_struggle)

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

func chase() -> void:
	if state_time <= 0:
		change_state(States.IDLE)
	if current_target in threat.get_overlapping_bodies():
		change_state(States.BITE)
	moving(chase_speed)
	if current_target.global_position != nav.target_position:
		nav.set_target_position(current_target.global_position)

func flee() -> void:
	if state_time <= 0:
		change_state(States.IDLE)
	moving(chase_speed)

func roar() -> void:
	if state_time <= 0:
		if len(hostile.get_overlapping_bodies()) > 0:
			var new_target = hostile.get_overlapping_bodies()[0]
			change_state(States.CHASE, new_target)
		else:
			change_state(States.IDLE)
	velocity = Vector3.ZERO

func bite() -> void:
	if state_time <= 0:
		if current_target in hostile.get_overlapping_bodies():
			change_state(States.CHASE, current_target)
		else:
			change_state(States.ROAR)
	velocity = Vector3.ZERO

func hurt() -> void:
	if state_time <= 0:
		change_state(States.ROAR)
	if health == 0:
		change_state(States.DIE)
	velocity = Vector3.ZERO

func die() -> void:
	if state_time <= 0:
		queue_free()

func change_state(next_state: int, target=null) -> void:
	# Cleanup before changing state.
	#print("FROM: ", States.keys()[state], " TO: ", States.keys()[next_state])
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
			print("Chase target: ", target)
			anima.play("walk")
			state_time = 500
			find_chase_target(target)
		States.FLEE:
			anima.play("walk")
			state_time = 500 # Predator always flees from player
			nav.set_target_position((global_position - Global.player.global_position).normalized() * 20)
		States.ROAR:
			anima.play("roar")
			state_time = 15
			Global.roar.emit()
		States.BITE:
			anima.play("bite")
			state_time = 15
			Global.bite.emit()
		States.HURT:
			anima.play("hurt")
			state_time = 30
			health -= 1
			print("Predator health: ", health)
		States.DIE:
			anima.play("die")
			state_time = 15
	# Change state now!
	state = next_state
	# Post state changes.
	if state == States.CHASE:
		current_target = target

func moving(speed: float) -> void:
	var next_location = nav.get_next_path_position()
	var new_velocity = (next_location - global_transform.origin).normalized() * speed
	velocity = velocity.move_toward(new_velocity, 0.25)
	velocity.y = 0.0
	if velocity == Vector3.ZERO:
		change_state(States.IDLE)
	else:
		_last_movement_dir = velocity
		var target_angle := Vector3.BACK.signed_angle_to(_last_movement_dir, Vector3.UP)
		body.global_rotation.y = target_angle

func find_wander_target() -> void:
	var direction: Vector3 = global_transform.origin
	direction.x += randf_range(-5.0, 5.0)
	direction.z += randf_range(-5.0, 5.0)
	nav.set_target_position(direction)

func find_chase_target(target: CharacterBody3D) -> void:
	current_target = target
	var target_position = Vector3(target.global_position.x, 0.0, target.global_position.z)
	nav.set_target_position(target_position)

func _on_player_interacts() -> void:
	if self in Global.player.interact.get_overlapping_bodies():
		change_state(States.FLEE)

func _on_player_attacks() -> void:
	if self in Global.player.interact.get_overlapping_bodies():
		change_state(States.HURT)

func _on_navigation_agent_3d_target_reached():
	if state in [States.WANDER, States.FLEE]:
		change_state(States.IDLE)

func _on_hostile_range_body_entered(body: CharacterBody3D):
	if body is Sheep:
		sheep_nearby += 1
		print("Sheep entered!")
		if state in [States.IDLE, States.WANDER]:
			change_state(States.CHASE, body)
	elif body is Player:
		player_nearby == true
		print("Player entered!")

func _on_hostile_range_body_exited(body: CharacterBody3D):
	if body is Sheep:
		sheep_nearby -= 1
		print("Sheep exited!")
		if body == current_target:
			current_target = null
	elif body is Player:
		player_nearby = false
		print("Player exited!")

func _on_threat_range_body_entered(body: CharacterBody3D):
	if state == States.CHASE and body == current_target:
		change_state(States.BITE)
		Global.bite.emit()
