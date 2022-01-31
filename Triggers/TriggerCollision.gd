extends RichTextEffect
class_name TriggerCollision, "res://addons/BulletUpHell/Sprites/NodeIcons13.png"

export (String) var group_to_collide = "" # left empty for all
export (NodePath) var target_to_collide
export var on_bounce = false

var node_collide:Node2D

func _init():
	resource_name = "TrigCol"
