extends RichTextEffect
class_name TriggerPos, "res://addons/BulletUpHell/Sprites/NodeIcons12.png"

enum AXIS { X, Y, BOTH}
export (AXIS) var on_axis = AXIS.BOTH
export (Vector2) var pos
export (NodePath) var target
export (float) var distance = 10

var node_target:Node2D

func _init():
	resource_name = "TrigPos"
