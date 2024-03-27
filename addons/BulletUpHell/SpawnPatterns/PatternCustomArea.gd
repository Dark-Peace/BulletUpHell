@tool
@icon("res://addons/BulletUpHell/Sprites/NodeIcons17.png")
extends Pattern
class_name PatternCustomArea

@export_group("Custom Area")
var polygon:PackedVector2Array
var pos:Array = []
@export var center_pos:Vector2

var limit_rect = Rect2(99999,99999,-99999,-99999)
@export var tries_max:int = 5
@export var pooling:int = 10
@export var grid_spawning:Vector2 = Vector2(0,0)


func _init():
	resource_name = "PatternCustomArea"
