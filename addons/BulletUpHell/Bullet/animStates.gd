@icon("res://addons/BulletUpHell/Sprites/NodeIcons24.png")
extends Resource
class_name animState

@export var ID:String
@export var texture:String
@export var collision:String
@export var SFX:String

func _init():
	resource_name = "animState"
