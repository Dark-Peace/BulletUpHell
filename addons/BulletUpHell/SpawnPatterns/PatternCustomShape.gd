@tool
@icon("res://addons/BulletUpHell/Sprites/NodeIcons9.png")
extends Pattern
class_name PatternCustomShape

var shape:Curve2D
var angles:Array = []
var pos:Array = []

@export_group("Custom Shape")
@export var closed_shape = false
@export var center_pos:Vector2
@export var symmetric:bool = false
@export var center:int = 0
@export var symmetry_type = Spawning.SYMTYPE.Line


func _init():
	resource_name = "PatternCustomShape"
