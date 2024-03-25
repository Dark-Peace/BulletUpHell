@icon("res://addons/BulletUpHell/Sprites/NodeIcons13.png")
extends RichTextEffect
class_name TriggerCollision

@export var group_to_collide:String = "" # left empty for all
@export var target_to_collide:NodePath
@export var on_bounce = false

var node_collide:Node2D

func _init():
	resource_name = "TrigCol"
