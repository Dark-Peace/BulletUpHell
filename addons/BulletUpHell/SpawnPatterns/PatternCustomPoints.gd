@tool
@icon("res://addons/BulletUpHell/Sprites/NodeIcons16.png")
extends Pattern
class_name PatternCustomPoints

@export_group("Custom Points")
enum ANGLE_TYPE{FromTangeant,FromCenter,Custom}
var shape:Curve2D
@export var calculate_angles:int = ANGLE_TYPE.FromTangeant
@export var angles:Array = []
var pos:Array = []
@export var center_pos:Vector2
@export var reversed_angle:bool=false
enum SYMTYPE{ClosedShape,Line}
@export var symmetric:bool = false
@export var center:int = 0
@export var symmetry_type = SYMTYPE.ClosedShape


func _init():
	resource_name = "PatternCustomPoints"

