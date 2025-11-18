class_name Predator extends CharacterBody3D

@onready var body = $MeshInstance3D
@onready var space = $CollisionShape3D
@onready var anima = $AnimationPlayer
@onready var nav = $NavigationAgent3D
@onready var hostility = $HostilityRange
@onready var threat = $ThreatRange

func _ready() -> void:
	Global.predator = self
