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
var _last_movement_dir := Vector3.BACK

enum States {
	IDLE,
	WANDER,
	FOLLOW,
	FLEE,
	GRAZE,
	DRINK,
	INVERT,
	STRUGGLE,
	REVERT,
	HURT,
	DIE
}

func _ready() -> void:
	state = States.IDLE
	nav.target_position = Vector3.ZERO
	Global.rally.connect(_on_player_rallies)
	Global.interact.connect(_on_player_interacts)
	Global.all_struggle.connect(_debug_struggle)

func _debug_struggle() -> void:
	change_state(States.INVERT)

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
		States.INVERT:
			invert()
		States.STRUGGLE:
			struggle()
		States.REVERT:
			revert()
		States.HURT:
			pass
		States.DIE:
			pass
	move_and_slide()

func idle() -> void:
	velocity = Vector3.ZERO
	if state_time <= 0:
		change_state(States.WANDER)

func wander() -> void:
	moving(wander_speed)
	if state_time <= 0:
		change_state(States.IDLE)

func follow() -> void:
	moving(follow_speed)
	if Global.player.global_position != nav.target_position:
		nav.set_target_position(Global.player.global_position)
	#if state_time <= 0:
		#change_state(States.IDLE)
	if self in Global.player.close.get_overlapping_bodies():
		velocity = Vector3.ZERO
	if self not in Global.player.follow.get_overlapping_bodies():
		change_state(States.IDLE)

func flee() -> void:
	moving(flee_speed)
	#if state_time <= 0:
	if self not in Global.predator.hostility.get_overlapping_bodies():
		change_state(States.IDLE)

func graze() -> void:
	if state_time <= 0:
		change_state(States.IDLE)

func drink() -> void:
	if state_time <= 0:
		change_state(States.IDLE)

func invert() -> void: # TODO: Make sheep invertable!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	if self in Global.predator.threat.get_overlapping_bodies():
		pass #move away from predator
	else:
		pass #move in random direction
	if state_time <= 0:
		change_state(States.STRUGGLE)

func struggle() -> void:
	velocity = Vector3.ZERO
	if state_time <= 0:
		change_state(States.DIE)

func revert() -> void:
	if state_time <= 0:
		change_state(States.IDLE)

func hurt() -> void: # TODO: Make predators capable of hurting sheep!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
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
			state_time = 100
		States.DRINK:
			anima.play("drink")
			state_time = 100
		States.INVERT:
			anima.play("invert")
			state_time = 15
		States.STRUGGLE:
			anima.play("struggle")
			state_time = 1000
		States.REVERT:
			anima.play("revert")
			state_time = 15
		States.HURT:
			anima.play("hurt")
			state_time = 10
		States.DIE:
			anima.play("die")
			state_time = 25
	# Change state now!
	state = next_state
	# Post state changes.

func moving(speed: float) -> void:
	var next_location = nav.get_next_path_position()
	var new_velocity = (next_location - global_transform.origin).normalized() * speed
	velocity = velocity.move_toward(new_velocity, 0.25)
	velocity.y = 0.0
	var target_angle := Vector3.BACK.signed_angle_to(_last_movement_dir, Vector3.UP)
	global_rotation.y = target_angle
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

func _on_player_rallies() -> void:
	print(Global.player.follow.get_overlapping_bodies())
	if state in [States.IDLE, States.WANDER]:
		if self in Global.player.follow.get_overlapping_bodies():
			change_state(States.FOLLOW)

func _on_player_interacts() -> void:
	print("PRESSED INTERACT!")
	print(Global.player.interact.get_overlapping_bodies())
	if self in Global.player.interact.get_overlapping_bodies():
		if state == States.STRUGGLE:
			change_state(States.REVERT)
			return
		if state in [States.IDLE, States.FOLLOW, States.WANDER]:
			if self in Global.field.get_overlapping_bodies():
				change_state(States.GRAZE)
			elif self in Global.stream.get_overlapping_bodies():
				change_state(States.DRINK)
