@tool
extends EditorPlugin


func _enter_tree():
	add_custom_type("SpawnPattern", "Path2D", preload("res://addons/BulletUpHell/Nodes/BuHPattern.gd"), preload("res://addons/BulletUpHell/Sprites/NodeIcons1.png"))
	add_custom_type("BulletPattern", "Path2D", preload("res://addons/BulletUpHell/Nodes/BuHBulletProperties.gd"), preload("res://addons/BulletUpHell/Sprites/NodeIcons2.png"))
	add_custom_type("TriggerContainer", "Node", preload("res://addons/BulletUpHell/Nodes/BuHTriggerContainer.gd"), preload("res://addons/BulletUpHell/Sprites/NodeIcons3.png"))
	add_custom_type("SpawnPoint", "Node2D", preload("res://addons/BulletUpHell/Nodes/BuHSpawnPoint.gd"), preload("res://addons/BulletUpHell/Sprites/NodeIcons14.png"))
	add_custom_type("InstanceLister", "Node", preload("res://addons/BulletUpHell/Nodes/BuHInstanceLister.gd"), preload("res://addons/BulletUpHell/Sprites/NodeIcons20.png"))
	add_custom_type("BulletNode", "Area2D", preload("res://addons/BulletUpHell/Nodes/BuHBulletNode.gd"), preload("res://addons/BulletUpHell/Sprites/NodeIcons19.png"))
	add_autoload_singleton("Spawning", "res://addons/BulletUpHell/Spawning.tscn")
	pass

func _exit_tree():
	remove_custom_type("SpawnPoint")
	remove_custom_type("SpawnPattern")
	remove_custom_type("BulletPattern")
	remove_custom_type("TriggerContainer")
	remove_custom_type("InstanceLister")
	remove_custom_type("BulletNode")
	remove_autoload_singleton("Spawning")
	pass
