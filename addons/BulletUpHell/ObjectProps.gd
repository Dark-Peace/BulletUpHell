@tool
@icon("res://addons/BulletUpHell/Sprites/NodeIcons18.png")
extends PackedDataContainer
class_name ObjectProps

@export var instance_id:String
@export var fixed_rotation:bool = true
@export var angle:float
@export var groups:PackedStringArray = []
@export var overwrite_groups:bool = false

@export_group("Triggers")
@export var trigger_container:String
@export var trigger_wait_for_shot = true
@export var r_trigger_choice:String

var node_container:Node2D

