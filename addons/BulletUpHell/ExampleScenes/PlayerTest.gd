extends Area2D

func _ready() -> void:
	print("ok")
	Spawning.edit_special_target("Player", self)
