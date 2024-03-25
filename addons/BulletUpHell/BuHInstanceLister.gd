extends Node
class_name InstanceLister


func _ready():
	for node in get_children():
		if node is Node2D:
			remove_child(node)
			Spawning.new_instance(node.name, node)
		else:
			push_warning("Children of InstanceLister are deleted upon game start. Node "\
						+ String(node.get_path()) + " isn't a 2D node so it can't be used for spawning.")
	queue_free()
