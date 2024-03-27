@tool
@icon("res://addons/BulletUpHell/Sprites/NodeIcons7.png")
extends Pattern
class_name PatternLine

@export_group("Line")
@export var offset = Vector2()
@export var center = 1
@export var symmetric = true
@export var symmetry_type = Spawning.SYMTYPE.Line


func _init():
	resource_name = "PatternLine"
