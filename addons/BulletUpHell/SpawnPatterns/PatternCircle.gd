@tool
@icon("res://addons/BulletUpHell/Sprites/NodeIcons6.png")
extends Pattern
class_name PatternCircle

@export_group("Circle")
@export var radius = 0
@export var angle_total = PI*2
@export var angle_decal = 0
@export var symmetric:bool = false
@export var center:int = 0
@export var symmetry_type = 0


func _init():
	resource_name = "PatternCircle"
