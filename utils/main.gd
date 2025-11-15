class_name Main extends Node

@export var world_3d: Node3D
@export var world_2d: Node2D
@export var gui: Control
var current_3d_scene
var current_2d_scene
var current_gui_scene
var player

func _ready() -> void:
	Global.main = self
	#player = load("res://characters/player.tscn").instantiate()
	change_3d_scene('res://environment/terrain.tscn')

func change_3d_scene(new_scene: String, delete: bool=true, keep_running=false) -> void:
	if current_3d_scene != null:
		if delete:
			current_3d_scene.queue_free() # Removes node entirely
		elif keep_running:
			current_3d_scene.visible = false # Hides scene while in memory and running
		else:
			world_3d.remove_child(current_3d_scene) # Keeps in memory but won't run
	var new = load(new_scene).instantiate()
	world_3d.add_child(new)
	current_3d_scene = new
	#player.global_transform = current_3d_scene.global_transform
